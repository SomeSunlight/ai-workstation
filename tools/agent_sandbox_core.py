"""Host-side, agent-neutral project staging and reviewed file application.

No Docker calls here. Agent containers may see only the work/ directory, never
the session metadata, original directory or this module.
"""
from __future__ import annotations

import difflib
import hashlib
import json
import os
import re
import shutil
import stat
import tempfile
from pathlib import Path

MAX_TEXT_DIFF = 128 * 1024
FORBIDDEN_NAMES = {".git", ".ssh", ".aws", ".kube", ".gnupg"}
PRIVATE_NAMES = {"secrets.yaml", "credentials.json", "id_rsa", "id_ed25519"}
SAFE_ID = re.compile(r"^[a-z][a-z0-9_-]{0,39}$")


class Refused(ValueError):
    """An operation failed its host-side review boundary."""


def validate_name(name: str) -> str:
    if not SAFE_ID.fullmatch(name) or name == "standard":
        raise Refused("Use a lower-case name starting with a letter (standard is reserved).")
    return name


def private_dir(path: Path) -> Path:
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(path, 0o700)
    return path


def save_json(path: Path, data: dict) -> None:
    private_dir(path.parent)
    fd, tmp = tempfile.mkstemp(prefix=".aiw-", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(data, stream, indent=2, sort_keys=True)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(tmp, 0o600)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def load_json(path: Path) -> dict:
    if path.is_symlink() or not path.is_file():
        raise Refused(f"Missing or unsafe private metadata: {path}")
    with path.open(encoding="utf-8") as stream:
        return json.load(stream)


def safe_path(rel: str) -> None:
    p = Path(rel)
    if (not rel or p.is_absolute() or "\\" in rel or
            any(part in ("", ".", "..") or part in FORBIDDEN_NAMES for part in rel.split("/")) or
            any(ord(c) < 32 or ord(c) == 127 for c in rel)):
        raise Refused(f"Unsafe project path: {rel!r}")


def excluded(rel: str) -> bool:
    parts = rel.split("/")
    name = parts[-1].lower()
    if any(p in FORBIDDEN_NAMES for p in parts):
        return True
    # Never copy obvious credential material into an agent's working directory.
    return (name in PRIVATE_NAMES or name == ".env" or
            (name.startswith(".env.") and name != ".env.example") or
            name.endswith((".pem", ".p12", ".pfx", ".key")))


def hash_file(path: Path) -> str:
    digest = hashlib.sha256()
    fd = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
    with os.fdopen(fd, "rb") as stream:
        while chunk := stream.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def scan_tree(root: Path) -> dict[str, dict]:
    root = root.resolve(strict=True)
    root_device = root.stat().st_dev
    result = {}
    for base, dirs, files in os.walk(root, followlinks=False):
        base_path = Path(base)
        for name in list(dirs):
            rel = (base_path / name).relative_to(root).as_posix()
            if excluded(rel):
                dirs.remove(name)
                continue
            safe_path(rel)
            entry = base_path / name
            info = entry.lstat()
            if not stat.S_ISDIR(info.st_mode) or info.st_dev != root_device:
                raise Refused(f"Symlink, nested mount or special directory: {rel}")
        for name in files:
            path = base_path / name
            rel = path.relative_to(root).as_posix()
            if excluded(rel):
                continue
            safe_path(rel)
            info = path.lstat()
            if (not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or
                    info.st_dev != root_device):
                raise Refused(f"Symlink, hardlink, mount or special file: {rel}")
            result[rel] = {"sha256": hash_file(path), "bytes": info.st_size,
                           "mode": stat.S_IMODE(info.st_mode)}
    return result


def stage(original: Path, work: Path) -> dict:
    original = original.resolve(strict=True)
    if not original.is_dir() or original == Path("/") or original == Path.home():
        raise Refused("A specific existing project directory is required.")
    if work.exists():
        raise Refused("Session working copy already exists.")
    source = scan_tree(original)
    private_dir(work)
    for rel, entry in source.items():
        dst = work / rel
        private_dir(dst.parent) if dst.parent != work else None
        src = original / rel
        # No symlinks/hardlinks from the source are ever copied across.
        with os.fdopen(os.open(src, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)), "rb") as inp:
            with dst.open("xb") as out:
                shutil.copyfileobj(inp, out)
        os.chmod(dst, entry["mode"])
        if hash_file(dst) != entry["sha256"]:
            raise Refused(f"Source changed while staging: {rel}")
    # Owner-only baseline snapshots: agent sees work/, never these originals.
    # Diff remains accurate even if someone edits the original during the session.
    shutil.copytree(work, work.parent / "baseline-files", symlinks=False)
    return source


def changes(baseline: dict, current: dict) -> list[tuple[str, str]]:
    return [(rel, "added" if rel not in baseline else "deleted" if rel not in current else "modified")
            for rel in sorted(set(baseline) | set(current))
            if baseline.get(rel, {}).get("sha256") != current.get(rel, {}).get("sha256")]


def review(session: Path) -> tuple[list[tuple[str, str]], str]:
    metadata = load_json(session / "session.json")
    baseline = load_json(session / "baseline.json")
    current = scan_tree(session / "work")
    entries = changes(baseline, current)
    lines = []
    deleted = {v["sha256"]: k for k, v in baseline.items()
               if k not in current}
    for rel, kind in entries:
        old = baseline.get(rel)
        new = current.get(rel)
        rename = f" (same bytes as deleted {deleted[new['sha256']]})" if (
            kind == "added" and new["sha256"] in deleted) else ""
        lines.append(f"{kind.upper()}: {rel}{rename}")
        if ((old and old["bytes"] > MAX_TEXT_DIFF) or
                (new and new["bytes"] > MAX_TEXT_DIFF)):
            lines.append("  Large file; hashes/size only. Inspect before accepting.")
            continue
        old_bytes = (session / "baseline-files" / rel).read_bytes() if old else b""
        if old and hashlib.sha256(old_bytes).hexdigest() != old["sha256"]:
            raise Refused(f"Private baseline snapshot changed: {rel}")
        new_bytes = (session / "work" / rel).read_bytes() if new else b""
        if b"\0" in old_bytes or b"\0" in new_bytes:
            lines.append(f"  Binary: old={old['sha256'] if old else '-'} new={new['sha256'] if new else '-'}")
            continue
        try:
            old_text = old_bytes.decode("utf-8").splitlines(keepends=True)
            new_text = new_bytes.decode("utf-8").splitlines(keepends=True)
        except UnicodeDecodeError:
            lines.append("  Non-UTF-8 file; hashes/size only.")
            continue
        lines.extend(line.rstrip("\n") for line in difflib.unified_diff(
            old_text, new_text, fromfile="original/" + rel, tofile="proposal/" + rel))
    return entries, "\n".join(lines) or "No project changes."


def _parent_fd(root: Path, rel: str, *, create: bool) -> tuple[int, str]:
    safe_path(rel)
    fd = os.open(root, os.O_RDONLY | os.O_DIRECTORY | getattr(os, "O_NOFOLLOW", 0))
    try:
        for part in rel.split("/")[:-1]:
            if create:
                try:
                    os.mkdir(part, mode=0o755, dir_fd=fd)
                except FileExistsError:
                    pass
            next_fd = os.open(part, os.O_RDONLY | os.O_DIRECTORY |
                              getattr(os, "O_NOFOLLOW", 0), dir_fd=fd)
            os.close(fd)
            fd = next_fd
        return fd, rel.split("/")[-1]
    except BaseException:
        os.close(fd)
        raise


def current_entry(root: Path, rel: str) -> dict | None:
    try:
        fd, leaf = _parent_fd(root, rel, create=False)
    except FileNotFoundError:
        return None
    try:
        try:
            info = os.stat(leaf, dir_fd=fd, follow_symlinks=False)
        except FileNotFoundError:
            return None
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
            raise Refused(f"Original is not a safe regular file: {rel}")
        file_fd = os.open(leaf, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0), dir_fd=fd)
        h = hashlib.sha256()
        with os.fdopen(file_fd, "rb") as stream:
            while data := stream.read(1024 * 1024):
                h.update(data)
        return {"sha256": h.hexdigest(), "bytes": info.st_size,
                "mode": stat.S_IMODE(info.st_mode)}
    finally:
        os.close(fd)


def apply(session: Path, selected: list[str], *, allow_binary: bool = False) -> list[str]:
    metadata = load_json(session / "session.json")
    baseline = load_json(session / "baseline.json")
    original = Path(metadata["original"]).resolve(strict=True)
    if str(original) != metadata["original"]:
        raise Refused("Original project path changed since staging.")
    current = scan_tree(session / "work")
    changed = dict(changes(baseline, current))
    applied = set(metadata.get("applied", []))
    if not selected or len(set(selected)) != len(selected):
        raise Refused("Select one or more distinct changed files.")
    for rel in selected:
        safe_path(rel)
        if rel not in changed or rel in applied:
            raise Refused(f"Not an unapplied changed path: {rel}")
        now = current_entry(original, rel)
        before = baseline.get(rel)
        if ((now or {}).get("sha256") != (before or {}).get("sha256")):
            raise Refused(f"Original changed since staging; refusing all writes: {rel}")
        if rel in current and not allow_binary:
            content = (session / "work" / rel).read_bytes()
            try:
                if b"\0" in content:
                    raise UnicodeError("Contains NUL")
                content.decode("utf-8")
            except UnicodeError:
                raise Refused(f"Binary/non-UTF-8 file requires explicit --allow-binary: {rel}")
        if before and before["bytes"] <= MAX_TEXT_DIFF:
            # The review must not show another person's newer original as a proposed diff.
            if hash_file(original / rel) != before["sha256"]:
                raise Refused(f"Original drift: {rel}")
    # Freeze the selected proposal bytes outside the agent mount before writing
    # anything to the original. Refuse a changed/symlinked staged source.
    accepted_dir = private_dir(session / "accepted")
    for rel in selected:
        if rel in current:
            target = accepted_dir / rel
            private_dir(target.parent)
            with os.fdopen(os.open(session / "work" / rel,
                                   os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)), "rb") as inp:
                with target.open("wb") as out:
                    shutil.copyfileobj(inp, out)
            if hash_file(target) != current[rel]["sha256"]:
                raise Refused(f"Proposed file changed during acceptance: {rel}")
    backup_dir = private_dir(session / "backups")
    for rel in selected:
        if rel in baseline:
            dest = backup_dir / rel
            private_dir(dest.parent)
            parent_fd, leaf = _parent_fd(original, rel, create=False)
            try:
                source_fd = os.open(leaf, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0),
                                    dir_fd=parent_fd)
                with os.fdopen(source_fd, "rb") as inp:
                    with dest.open("wb") as out:
                        shutil.copyfileobj(inp, out)
            finally:
                os.close(parent_fd)
            if hash_file(dest) != baseline[rel]["sha256"]:
                raise Refused(f"Backup verification failed: {rel}")
    # After complete preflight and verified private backup, apply selected files only.
    # A partial OS failure retains backups and is reported, never silently hidden.
    for rel in selected:
        fd, leaf = _parent_fd(original, rel, create=rel in current)
        try:
            if rel not in current:
                os.unlink(leaf, dir_fd=fd)
            else:
                content = accepted_dir / rel
                temp_name = ".aiw-" + next(tempfile._get_candidate_names())
                tmp_fd = os.open(temp_name, os.O_WRONLY | os.O_CREAT | os.O_EXCL,
                                 mode=0o600, dir_fd=fd)
                try:
                    with os.fdopen(tmp_fd, "wb") as stream:
                        with content.open("rb") as inp:
                            shutil.copyfileobj(inp, stream)
                        stream.flush()
                        os.fsync(stream.fileno())
                    os.chmod(temp_name, current[rel]["mode"], dir_fd=fd,
                             follow_symlinks=False)
                    os.replace(temp_name, leaf, src_dir_fd=fd, dst_dir_fd=fd)
                finally:
                    try:
                        os.unlink(temp_name, dir_fd=fd)
                    except FileNotFoundError:
                        pass
        finally:
            os.close(fd)
        applied.add(rel)
        metadata["applied"] = sorted(applied)
        save_json(session / "session.json", metadata)
    return selected
