#!/usr/bin/env python3
"""Opt-in AI Workstation agent sandbox service; Goose is the first adapter.

AIW owns Docker, private metadata, environment approval and project application.
No Docker socket or original project is mounted in Goose. Ordinary Docker
isolation is NOT a hostile-code or network-exfiltration security profile.
"""
from __future__ import annotations
import argparse
import contextlib
import datetime as dt
try:
    import fcntl
except ImportError:  # native Windows may validate recipes; execution is WSL/Linux only
    fcntl = None
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path
from agent_sandbox_core import (Refused, apply, load_json, private_dir,
                                review, save_json, stage, validate_name)

ROOT = Path(__file__).resolve().parent.parent
STATE = Path(os.environ.get("AIW_AGENT_SANDBOX_DIR",
                 str(Path.home() / ".local/state/ai-workstation/agent-sandboxes")))
PROFILE = "aiw-agent-goose-profile"
BACKUP = "aiw-agent-goose-legacy-backup"
LEGACY = "ai-workstation_goose-home"
VERSION = json.loads((ROOT / "config/versions.json").read_text())["versions"]
PYTHON_VERSION = "3.12.12"
UV_VERSION = VERSION["uv"]
GOOSE_DEFAULT = VERSION["goose"]["image"]
TOOL_LINE = re.compile(r"^RUN UV_TOOL_DIR=/opt/aiw/tools UV_TOOL_BIN_DIR=/opt/aiw/bin uv tool install --no-cache --python 3\.12\.12 ([a-zA-Z0-9][\w.-]*)==([a-zA-Z0-9][\w.+!-]*)$")
UV_RESULT = re.compile(r"^([a-zA-Z0-9][\w.-]*) v([a-zA-Z0-9][\w.+!-]*)$", re.M)

def now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")

def docker(*args: str, show: bool = False) -> str:
    completed = subprocess.run(["docker", *map(str, args)], check=False,
                               text=True, capture_output=not show)
    if completed.returncode:
        raise Refused(f"Docker {args[0]} failed (exit {completed.returncode}); inspect Docker locally.")
    return (completed.stdout or "").strip()

def inspect_volume(name: str) -> bool:
    return subprocess.run(["docker", "volume", "inspect", name],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0

def inspect_image(ref: str) -> dict:
    return json.loads(docker("image", "inspect", ref))[0]

def digest_ref(ref: str) -> str:
    data = inspect_image(ref)
    digest = next((s for s in data.get("RepoDigests", [])
                   if s.startswith(ref.split(":")[0] + "@sha256:")), None)
    if not digest:
        raise Refused(f"No installed registry digest for {ref}; use a reviewed tagged image.")
    return digest

def catalogue() -> dict:
    path = STATE / "catalog.json"
    return load_json(path) if path.exists() else {"environments": {}}

def save_catalog(data: dict) -> None:
    save_json(STATE / "catalog.json", data)

def entry(name: str) -> dict:
    record = catalogue()["environments"].get(name)
    if not record or not record.get("active"):
        raise Refused(f"Unknown or inactive approved environment: {name}")
    version = record["versions"][record["active"]]
    image = version["image_id"]
    local_tag = version.get("local_tag")
    if not local_tag or inspect_image(local_tag)["Id"] != image:
        raise Refused("Approved image tag/digest mismatch; restore through AIW.")
    return {"name": name, "image": image, "tag": local_tag,
            "revision": record["active"]}

@contextlib.contextmanager
def owner_lock(exclusive: bool = True):
    if fcntl is None:
        raise Refused("Run the agent sandbox service inside WSL/Linux, not native Windows.")
    config = private_dir(Path.home() / ".config/ai-workstation")
    fd = os.open(config / "goose-maintenance.lock", os.O_CREAT | os.O_RDWR, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX if exclusive else fcntl.LOCK_SH)
        yield
    finally:
        fcntl.flock(fd, fcntl.LOCK_UN)
        os.close(fd)

def confirm(prompt: str, expected: str) -> None:
    print(prompt)
    if input(f"Type {expected!r} to proceed: ").strip() != expected:
        raise Refused("Cancelled; no approval recorded.")

def host_selected_goose_image() -> str:
    env = Path(os.environ.get("AIW_RUNTIME_ENV_FILE", ROOT / ".env"))
    if not env.exists():
        return GOOSE_DEFAULT
    selected = next((s.split("=", 1)[1].strip() for s in env.read_text().splitlines()
                     if s.startswith("GOOSE_IMAGE=")), "")
    if selected and not re.fullmatch(r"ghcr\.io/aaif-goose/goose:v[0-9][a-zA-Z0-9._-]*", selected):
        raise Refused("Selected Goose image must be a versioned official tag.")
    return selected or GOOSE_DEFAULT

def goose_env() -> Path:
    path = Path(os.environ.get("AIW_GOOSE_ENV_FILE",
                  Path.home() / ".config/ai-workstation/goose.env")).expanduser()
    if path.exists():
        info = path.lstat()
        if not path.is_file() or path.is_symlink() or info.st_mode & 0o077:
            raise Refused("Goose-only env file must be regular and private (mode 0600).")
        for line in path.read_text().splitlines():
            if line.startswith(("GOOSE_PATH_ROOT=", "XDG_CONFIG_HOME=")):
                raise Refused("Custom Goose config-root paths require a reviewed adapter.")
    return path

def ensure_docker() -> None:
    docker("info")

def no_legacy_sessions() -> None:
    out = docker("ps", "--quiet",
                 "--filter", "label=com.docker.compose.project=ai-workstation-goose",
                 "--filter", "label=com.docker.compose.service=goose")
    if out:
        raise Refused("Stop legacy Goose sessions before migration.")

def helper(image: str, mounts: list[str], script: str) -> str:
    args = ["run", "--rm", "--pull", "never", "--network", "none", "--read-only",
            "--cap-drop", "ALL", "--cap-add", "CHOWN", "--cap-add", "FOWNER", "--cap-add", "DAC_OVERRIDE",
            "--security-opt", "no-new-privileges:true",
            "--user", "0:0", "--entrypoint", "/bin/sh"]
    for mount in mounts:
        args += ["--mount", mount]
    return docker(*args, image, "-c", script)

def migration(command: str) -> None:
    ensure_docker()
    with owner_lock():
        marker = STATE / "migration.json"
        if command == "disable":
            if not marker.exists():
                raise Refused("Sandbox migration is not enabled.")
            confirm("Disable the sandbox profile. No Docker volumes will be deleted.", "DISABLE")
            data = load_json(marker)
            data["enabled"] = False
            save_json(marker, data)
            print("Legacy Goose unchanged; sandbox profile disabled.")
            return
        if marker.exists() or inspect_volume(PROFILE) or inspect_volume(BACKUP):
            raise Refused("Existing migration/profile/backup found. Refusing to overwrite private data.")
        no_legacy_sessions()
        if not inspect_volume(LEGACY):
            raise Refused("Legacy Goose home volume missing; configure Goose first.")
        image = host_selected_goose_image()
        inspect_image(image)  # never pull the Goose image here
        confirm("Back up and verify the complete legacy Goose home, then copy only "
                "native config/history into a separate sandbox profile.", "MIGRATE")
        private_dir(STATE)
        docker("volume", "create", BACKUP)
        docker("volume", "create", PROFILE)
        # Extraction stays entirely in Docker volumes, not host directories.
        script = r"""
set -eu
cp -a /old/. /backup/
a="$(tar --sort=name -cf - -C /old . | sha256sum | cut -d ' ' -f1)"
b="$(tar --sort=name -cf - -C /backup . | sha256sum | cut -d ' ' -f1)"
[ "$a" = "$b" ] || exit 4
mkdir -p /profile/.config /profile/.local/share /profile/.local/state
for p in .config/goose .local/share/goose .local/state/goose; do
  if [ -d "/old/$p" ] && [ ! -L "/old/$p" ]; then
    cp -a "/old/$p" "/profile/$p"
  fi
done
for p in .config/goose .local/share/goose .local/state/goose; do
  if [ -d "/old/$p" ]; then
    a="$(tar --sort=name -cf - -C "/old/$p" . | sha256sum | cut -d ' ' -f1)"
    b="$(tar --sort=name -cf - -C "/profile/$p" . | sha256sum | cut -d ' ' -f1)"
    [ "$a" = "$b" ] || exit 5
  fi
done
"""
        helper(image, [f"type=volume,src={LEGACY},dst=/old,readonly",
                       f"type=volume,src={BACKUP},dst=/backup",
                       f"type=volume,src={PROFILE},dst=/profile"], script)
        save_json(marker, {"enabled": True, "created": now(), "legacy": LEGACY,
                           "backup": BACKUP, "profile": PROFILE, "source_image": image})
        print("Migration verified. Original Goose volume untouched. "
              "Disable: aiw goose sandbox migrate-disable.")

def require_migration() -> None:
    path = STATE / "migration.json"
    if not path.exists() or not load_json(path).get("enabled") or not inspect_volume(PROFILE):
        raise Refused("Run 'aiw goose sandbox migrate' first (backed-up opt-in).")

def build_image(dockerfile: Path, base: str, tag: str, uv_base: str = "") -> str:
    with tempfile.TemporaryDirectory(prefix="aiw-sandbox-build-") as folder:
        shutil.copy2(dockerfile, Path(folder) / "Dockerfile")
        cmd = ["build", "--pull=false", "-t", tag, "--build-arg", f"BASE={base}"]
        if uv_base:
            cmd += ["--build-arg", f"UV_BASE={uv_base}"]
        docker(*(cmd + [folder]), show=True)
    image = inspect_image(tag)["Id"]
    if not re.fullmatch(r"sha256:[0-9a-f]{64}", image):
        raise Refused("Docker did not return a verifiable image ID.")
    return image

def next_revision(record: dict) -> str:
    return str(1 + max([int(v) for v in record.get("versions", {})] or [0]))

def build_standard(upgrade: bool) -> None:
    ensure_docker()
    data = catalogue()
    record = data["environments"].get("standard", {"versions": {}, "active": None})
    if record["active"] and not upgrade:
        raise Refused("Standard exists; use --upgrade for an explicit new revision.")
    base = digest_ref(host_selected_goose_image())
    uv_tag = f"ghcr.io/astral-sh/uv:{UV_VERSION}"
    # Only the operator-owned build step downloads the pinned uv image.
    docker("pull", uv_tag, show=True)
    uv_base = digest_ref(uv_tag)
    confirm("Build the pinned standard from reviewed Goose/uv image digests?",
            "UPGRADE" if record["active"] else "BUILD")
    recipe = ROOT / "containers/agent-sandbox/Dockerfile"
    revision = next_revision(record)
    local_tag = f"aiw-agent-standard:r{revision}"
    image = build_image(recipe, base, local_tag, uv_base)
    docker("run", "--rm", "--pull", "never", "--network", "none",
           "--read-only", "--entrypoint", "/bin/sh", image,
           "-c", "uv --version && python3 --version && git --version && goose --version", show=True)
    record["versions"][revision] = {
        "image_id": image, "local_tag": local_tag, "parent": None,
        "goose_base": base, "uv_base": uv_base,
        "approved_at": now(), "recipe": "containers/agent-sandbox/Dockerfile",
        "recipe_sha256": hashlib.sha256(recipe.read_bytes()).hexdigest(),
        "uv": UV_VERSION, "python": PYTHON_VERSION}
    record["active"] = revision
    data["environments"]["standard"] = record
    save_catalog(data)
    print(f"Approved standard r{revision}: {image}")

def workspace(name: str) -> Path:
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", name):
        raise Refused("Invalid workspace name.")
    registry = Path.home() / ".config/ai-workstation/goose-workspaces" / name
    if not registry.is_symlink():
        raise Refused("Unknown registered Goose workspace.")
    path = registry.resolve(strict=True)
    if not path.is_dir() or path in (Path("/"), Path.home()):
        raise Refused("Workspace path too broad or unavailable.")
    return path

def session_dir(identifier: str) -> Path:
    if not re.fullmatch(r"[0-9a-f]{12}", identifier):
        raise Refused("Invalid session identifier.")
    return STATE / "sessions" / identifier

def current_session(identifier: str) -> tuple[Path, dict]:
    folder = session_dir(identifier)
    return folder, load_json(folder / "session.json")

def clone_profile(home_volume: str, image: str) -> None:
    uid, gid = os.getuid(), os.getgid()
    helper(image, [f"type=volume,src={PROFILE},dst=/profile,readonly",
                   f"type=volume,src={home_volume},dst=/target"],
           f"set -eu; cp -a /profile/. /target/; chown -R {uid}:{gid} /target")

def start(workspace_name: str, env_name: str) -> str:
    require_migration()
    goose_env()
    info = entry(env_name)
    original = workspace(workspace_name)
    identifier = uuid.uuid4().hex[:12]
    private_dir(STATE / "sessions")
    folder = session_dir(identifier)
    folder.mkdir(mode=0o700, exist_ok=False)
    baseline = stage(original, folder / "work")
    save_json(folder / "baseline.json", baseline)
    volume = "aiw-agent-home-" + identifier
    metadata = {"id": identifier, "created": now(), "original": str(original),
                "workspace": workspace_name, "environment": env_name,
                "image_id": info["image"], "revision": info["revision"],
                "home_volume": volume, "applied": []}
    save_json(folder / "session.json", metadata)
    docker("volume", "create", volume)
    clone_profile(volume, info["image"])
    print(f"Prepared {identifier} from {env_name} r{info['revision']}.")
    print(f"Original not mounted: {original}")
    print(f"Review: aiw goose sandbox review {identifier}")
    return identifier

def run_session(identifier: str, goose_args: list[str]) -> None:
    folder, meta = current_session(identifier)
    if inspect_image(meta["image_id"])["Id"] != meta["image_id"]:
        raise Refused("Approved image unavailable or changed.")
    if not inspect_volume(meta["home_volume"]):
        raise Refused("Session home volume missing; project proposal retained.")
    env = goose_env()
    container = "aiw-agent-session-" + identifier
    cmd = ["run", "--rm", "--pull", "never", "--name", container,
           "--label", "aiw.agent-session=" + identifier,
           "--read-only", "--cap-drop", "ALL", "--security-opt",
           "no-new-privileges:true", "--pids-limit", "256",
           "--tmpfs", "/tmp:rw,noexec,nosuid,nodev,size=512m",
           "--mount", f"type=bind,src={folder / 'work'},dst=/workspace",
           "--mount", f"type=volume,src={meta['home_volume']},dst=/home/goose",
           "--workdir", "/workspace", "--user", f"{os.getuid()}:{os.getgid()}",
           ]
    if env.exists():
        cmd += ["--env-file", str(env)]
    # Explicit policy values win over optional env-file entries.
    cmd += ["--env", "HOME=/home/goose", "--env", "GOOSE_DISABLE_KEYRING=1",
            "--env", "GOOSE_DISABLE_TELEMETRY=1"]
    if sys.stdin.isatty() and sys.stdout.isatty():
        cmd += ["-it"]
    else:
        cmd += ["-i"]
    cmd += [meta["image_id"], "session", *goose_args]
    print("PR 1 uses Docker bridge networking: not safe for hostile code or network secrets.")
    with owner_lock(exclusive=False):
        try:
            code = subprocess.call(["docker", *cmd])
        except KeyboardInterrupt:
            subprocess.run(["docker", "rm", "-f", container],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            raise Refused("Interrupted; isolated session retained.")
    print(f"Session {identifier} exited; no project changes applied.")
    if code:
        raise Refused(f"Goose exited with code {code}; session retained.")

def inventory(identifier: str) -> list[tuple[str, str]]:
    folder, meta = current_session(identifier)
    output = docker("run", "--rm", "--pull", "never", "--network", "none",
                    "--read-only", "--tmpfs", "/tmp:rw,noexec,size=64m",
                    "--mount", f"type=volume,src={meta['home_volume']},dst=/home/goose",
                    "--user", f"{os.getuid()}:{os.getgid()}",
                    "--env", "HOME=/home/goose", "--env", "UV_CACHE_DIR=/tmp/uv",
                    "--entrypoint", "/usr/local/bin/uv",
                    meta["image_id"], "tool", "list")
    return sorted(set(UV_RESULT.findall(output)))

def candidate(identifier: str, name: str, upgrade: bool = False) -> None:
    validate_name(name)
    if bool(catalogue()["environments"].get(name)) != upgrade:
        raise Refused("Use --upgrade for existing names; new names cannot request upgrades.")
    folder, meta = current_session(identifier)
    directory = STATE / "candidates" / name
    if directory.exists():
        raise Refused("Candidate already exists.")
    tools = inventory(identifier)
    private_dir(directory)
    recipe = ["# Proposed from installed uv tools; no session filesystem snapshot.",
              "# uvx cache/manual/apt installs are NOT captured.",
              "ARG BASE", "FROM ${BASE}", "USER goose"]
    for package, version in tools:
        recipe.append("RUN UV_TOOL_DIR=/opt/aiw/tools UV_TOOL_BIN_DIR=/opt/aiw/bin "
                      f"uv tool install --no-cache --python {PYTHON_VERSION} {package}=={version}")
    (directory / "Dockerfile").write_text("\n".join(recipe) + "\n")
    save_json(directory / "candidate.json",
              {"name": name, "session": identifier, "parent": meta["environment"],
               "parent_image_id": meta["image_id"], "created": now(),
               "upgrade": upgrade, "detected_uv_tools": [{"package": p, "version": v} for p, v in tools],
               "uncaptured": ["uvx cache", "manual and apt installations"]})
    print(f"Candidate recipe: {directory / 'Dockerfile'}")
    print("Review/edit as operator; no image built or approved yet.")

def inspect_recipe(text: str) -> list[tuple[str, str]]:
    if len(text) > 32768 or any(ord(c) < 32 and c not in "\n\t" for c in text):
        raise Refused("Unreviewable recipe.")
    lines = [s.strip() for s in text.splitlines()
             if s.strip() and not s.lstrip().startswith("#")]
    if lines[:3] != ["ARG BASE", "FROM ${BASE}", "USER goose"]:
        raise Refused("Recipe must start ARG BASE / FROM ${BASE} / USER goose.")
    result = []
    for line in lines[3:]:
        match = TOOL_LINE.fullmatch(line)
        if not match:
            raise Refused("Only version-pinned uv tool installs are supported in PR 1.")
        result.append(match.groups())
    return result

def verify_pinned_tools(image: str, tools: list[tuple[str, str]]) -> None:
    """Check installed Python distribution metadata without writing a uv temp file."""
    if not tools:
        return
    source = """
import importlib.metadata as md
import json
import re
import sys
from pathlib import Path
normalize = lambda s: re.sub(r"[-_.]+", "-", s).lower()
expected = {normalize(n): v for n, v in json.loads(sys.argv[1])}
actual = {}
for site in Path("/opt/aiw/tools").glob("*/lib/python*/site-packages"):
    for dist in md.distributions(path=[str(site)]):
        actual[normalize(dist.metadata["Name"])] = dist.version
for name, version in expected.items():
    if actual.get(name) != version:
        raise SystemExit("Pinned uv tool verification failed: " + name)
"""
    docker("run", "--rm", "--pull", "never", "--network", "none",
           "--read-only", "--entrypoint", "/usr/local/bin/python3",
           image, "-B", "-c", source, json.dumps(tools))


def promote(name: str) -> None:
    validate_name(name)
    folder = STATE / "candidates" / name
    proposal = load_json(folder / "candidate.json")
    recipe = folder / "Dockerfile"
    tools = inspect_recipe(recipe.read_text())
    parent = entry(proposal["parent"])
    if proposal["parent_image_id"] != parent["image"]:
        raise Refused("Parent image changed; start a new candidate.")
    data = catalogue()
    existing = data["environments"].get(name)
    if bool(existing) != bool(proposal.get("upgrade")):
        raise Refused("Candidate/new-name or upgrade status disagrees with the catalogue.")
    if existing and proposal["parent"] != name:
        raise Refused("Upgrades must derive from the currently approved named environment.")
    revision = next_revision(existing or {"versions": {}})
    print(recipe.read_text())
    print(f"Approved parent image: {parent['image']}")
    print(f"Rebuildable pins: {tools}")
    confirm("Build and approve this reviewed recipe under a permanent name?", "APPROVE " + name)
    local_tag = f"aiw-agent-{name}:r{revision}"
    image = build_image(recipe, parent["tag"], local_tag)
    verify_pinned_tools(image, tools)
    target = private_dir(STATE / "recipes" / name / revision)
    shutil.copyfile(recipe, target / "Dockerfile")
    record = existing or {"versions": {}, "active": None}
    record["versions"][revision] = {
        "image_id": image, "local_tag": local_tag, "parent": parent["name"],
        "parent_image_id": parent["image"], "parent_local_tag": parent["tag"],
        "recipe": str(target / "Dockerfile"),
        "recipe_sha256": hashlib.sha256(recipe.read_bytes()).hexdigest(),
        "uv_tools": tools, "approved_at": now()}
    record["active"] = revision
    data["environments"][name] = record
    save_catalog(data)
    # Reviewed recipe is now versioned under recipes/, so the candidate name is
    # free for a future explicit --upgrade proposal.
    shutil.rmtree(folder)
    print(f"Approved {name}: {image}. Standard unchanged.")

def rollback(name: str, revision: str) -> None:
    data = catalogue()
    record = data["environments"].get(name)
    if not record or revision not in record["versions"]:
        raise Refused("Unknown approved environment revision.")
    image = record["versions"][revision]["image_id"]
    if not record["versions"][revision].get("local_tag") or (
        inspect_image(record["versions"][revision]["local_tag"])["Id"] != image
    ):
        raise Refused("Requested rollback image tag/digest is unavailable locally.")
    confirm(f"Restore {name} selection to approved r{revision} ({image})?", "ROLLBACK " + name)
    record["active"] = revision
    save_catalog(data)
    print(f"Active {name} is now approved revision {revision}; retained sessions are unchanged.")


def rebuild(name: str, revision: str) -> None:
    record = catalogue()["environments"].get(name)
    if not record or revision not in record["versions"]:
        raise Refused("Unknown approved environment revision.")
    approved = record["versions"][revision]
    recipe = (ROOT / approved["recipe"]) if name == "standard" else Path(approved["recipe"])
    if hashlib.sha256(recipe.read_bytes()).hexdigest() != approved["recipe_sha256"]:
        raise Refused("Approved recipe has changed; no rebuild allowed.")
    parent = approved["goose_base"] if name == "standard" else approved["parent_local_tag"]
    if name != "standard" and inspect_image(parent)["Id"] != approved["parent_image_id"]:
        raise Refused("Pinned approved parent image tag no longer matches its digest.")
    uv_base = approved.get("uv_base", "")
    print(f"Rebuild {name} r{revision} offline from approved parent and recipe.")
    image = build_image(recipe, parent, f"aiw-agent-verification-{name}:r{revision}", uv_base)
    verify_pinned_tools(image, approved.get("uv_tools", []))
    if image == approved["image_id"]:
        print("Rebuild digest matches approved image.")
    else:
        print("Rebuild package versions verified; image digest differs. "
              "Investigate upstream apt/uv artifact nondeterminism; no promotion performed.")


def remove_environment(name: str) -> None:
    validate_name(name)
    data = catalogue()
    if name not in data["environments"]:
        raise Refused("Environment missing.")
    for other, record in data["environments"].items():
        if other != name and any(v.get("parent") == name for v in record["versions"].values()):
            raise Refused(f"Dependent child: {other}")
    for sess in (STATE / "sessions").glob("*/session.json"):
        if load_json(sess).get("environment") == name:
            raise Refused("Environment has retained sessions; destroy them first.")
    confirm("Deactivate name? Images/recipes retained for manual recovery.", "REMOVE " + name)
    data["environments"][name]["active"] = None
    save_catalog(data)

def destroy(identifier: str) -> None:
    folder, meta = current_session(identifier)
    confirm("Destroy isolated work, tools and its temporary Goose history? "
            "Original and legacy data remain untouched.", "DESTROY " + identifier)
    subprocess.run(["docker", "rm", "-f", "aiw-agent-session-" + identifier],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    docker("volume", "rm", meta["home_volume"])
    shutil.rmtree(folder)
    print(f"Discarded {identifier}; original unchanged.")

def report() -> None:
    print("Approved sandbox environments:")
    for name, record in sorted(catalogue()["environments"].items()):
        active = record.get("active")
        suffix = f"r{active} {record['versions'][active]['image_id']}" if active else "inactive"
        print(f"  {name}: {suffix}")
    print("Retained sessions:")
    for path in sorted((STATE / "sessions").glob("*/session.json")):
        m = load_json(path)
        print(f"  {m['id']}  {m['workspace']}  {m['environment']}  {m['created']}")

def main() -> int:
    parser = argparse.ArgumentParser(description="AIW reviewed agent sandboxes (Goose adapter)")
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("list", "migrate", "migrate-disable"):
        sub.add_parser(name)
    b = sub.add_parser("build-standard")
    b.add_argument("--upgrade", action="store_true")
    c = sub.add_parser("create")
    c.add_argument("workspace")
    c.add_argument("--environment", default="standard")
    r = sub.add_parser("run")
    r.add_argument("id")
    r.add_argument("goose_args", nargs=argparse.REMAINDER)
    p = sub.add_parser("review")
    p.add_argument("id")
    a = sub.add_parser("apply")
    a.add_argument("id")
    a.add_argument("files", nargs="+")
    a.add_argument("--allow-binary", action="store_true")
    d = sub.add_parser("discard")
    d.add_argument("id")
    n = sub.add_parser("candidate")
    n.add_argument("id")
    n.add_argument("name")
    n.add_argument("--upgrade", action="store_true")
    t = sub.add_parser("promote")
    t.add_argument("name")
    x = sub.add_parser("remove")
    x.add_argument("name")
    rb = sub.add_parser("rollback")
    rb.add_argument("name")
    rb.add_argument("revision")
    bv = sub.add_parser("rebuild")
    bv.add_argument("name")
    bv.add_argument("revision")
    args = parser.parse_args()
    try:
        if args.command == "list":
            report()
        elif args.command == "migrate":
            migration("enable")
        elif args.command == "migrate-disable":
            migration("disable")
        elif args.command == "build-standard":
            build_standard(args.upgrade)
        elif args.command == "create":
            print("Session ID: " + start(args.workspace, args.environment))
        elif args.command == "run":
            run_session(args.id, args.goose_args)
        elif args.command == "review":
            folder, meta = current_session(args.id)
            print(f"Review for {meta['workspace']} (not applied):")
            print(review(folder)[1])
        elif args.command == "apply":
            folder, meta = current_session(args.id)
            print(review(folder)[1])
            confirm("Apply only selected files after hash/conflict verification?", "APPLY " + args.id)
            print("Accepted: " + ", ".join(apply(folder, args.files,
                                                allow_binary=args.allow_binary)))
        elif args.command == "discard":
            destroy(args.id)
        elif args.command == "candidate":
            candidate(args.id, args.name, args.upgrade)
        elif args.command == "rollback":
            rollback(args.name, args.revision)
        elif args.command == "rebuild":
            rebuild(args.name, args.revision)
        elif args.command == "promote":
            promote(args.name)
        elif args.command == "remove":
            remove_environment(args.name)
        return 0
    except (Refused, OSError, subprocess.SubprocessError, EOFError) as exc:
        print(f"[XX] Sandbox operation refused: {exc}", file=sys.stderr)
        return 2

if __name__ == "__main__":
    sys.exit(main())
