#!/usr/bin/env python3
"""AI Workstation's small native Process Compose and Dispatcher-client entrypoint.

The operator edits one host-local services.yaml. Process definitions stay in
Process Compose's native YAML; Docker Compose projects remain Docker-owned.
No service is started during init, validation, or client onboarding.
"""
from __future__ import annotations

import argparse
from collections import deque
from contextlib import contextmanager
import socket
import time
import hashlib
import io
import platform
import tarfile
import urllib.request
import urllib.error
import ssl
import socket
import zipfile
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import stat
import subprocess
import sys
import tempfile

import yaml

CLIENT_ID = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,63}\Z")
POLICIES = {"default", "enforce", "passthrough"}
DEFAULT_PORT = 19011
WIN_HELPER = Path(__file__).with_name("aiw-secret-windows.ps1")
WIN_DOWNLOADER = Path(__file__).with_name("aiw-download-windows.ps1")
MAX_ARCHIVE_BYTES = 40 * 1024 * 1024
VERSION_FILE = Path(__file__).resolve().parents[1] / "config" / "versions.json"
# The repository's central version manifest is authoritative, not this script.
RELEASE_PLATFORMS = {
    ("Windows", "AMD64"): "windows_amd64",
    ("Linux", "AMD64"): "linux_amd64",
    ("Linux", "ARM64"): "linux_arm64",
}


def pinned_release(system: str, machine: str) -> tuple[str, str, str]:
    ident = RELEASE_PLATFORMS.get((system, machine))
    if ident is None:
        raise ConfigError("Unsupported Process Compose OS/architecture.")
    try:
        cfg = json.loads(VERSION_FILE.read_text(encoding="utf-8"))["versions"]["process_compose"]
        version = cfg["version"]
        release = cfg["releases"][ident]
        filename, digest = release["filename"], release["sha256"]
    except (KeyError, ValueError, OSError, TypeError):
        raise ConfigError("Invalid central Process Compose version manifest.") from None
    if (not re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+", version)
        or not re.fullmatch(r"[0-9a-f]{64}", digest)
        or Path(filename).name != filename or not filename.startswith("process-compose_")):
        raise ConfigError("Invalid Process Compose release pin or digest.")
    return version, filename, digest


class ConfigError(Exception):
    pass


def default_dir() -> Path:
    custom = os.environ.get("AIW_SERVICES_DIR")
    if custom:
        return Path(custom).expanduser().resolve()
    if os.name == "nt":
        return Path(os.environ["LOCALAPPDATA"]) / "AIWorkstation" / "services"
    return Path.home() / ".config" / "ai-workstation" / "services"


def private_dir(folder: Path) -> None:
    if folder.is_symlink():
        raise ConfigError("Refusing a symlinked services directory.")
    folder.mkdir(parents=True, exist_ok=True)
    if os.name != "nt":
        os.chmod(folder, 0o700)


def private_write(path: Path, value: bytes, *, replace: bool = True) -> None:
    if path.is_symlink() or (path.exists() and not replace):
        raise ConfigError("Refusing to overwrite existing secret/config file.")
    private_dir(path.parent)
    fd, name = tempfile.mkstemp(prefix=".aiw-", dir=path.parent)
    try:
        if os.name != "nt":
            os.fchmod(fd, 0o600)
        with os.fdopen(fd, "wb") as out:
            out.write(value)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def settings_path(folder: Path) -> Path:
    return folder / "services.yaml"


def read_settings(folder: Path) -> dict:
    path = settings_path(folder)
    if not path.is_file() or path.is_symlink():
        raise ConfigError("Missing services.yaml; run: aiw services init")
    doc = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(doc, dict) or set(doc) != {"schema_version", "process_compose", "clients"}:
        raise ConfigError("Invalid services.yaml: expected schema_version, process_compose, clients.")
    if doc["schema_version"] != 1 or not isinstance(doc["clients"], dict):
        raise ConfigError("Unsupported service schema or clients mapping.")
    pc = doc["process_compose"]
    if not isinstance(pc, dict) or set(pc) != {"file", "port"}:
        raise ConfigError("process_compose requires only file and port.")
    if not isinstance(pc["file"], str) or not pc["file"] or Path(pc["file"]).is_absolute():
        raise ConfigError("process_compose.file must be a relative local filename.")
    if (".." in Path(pc["file"]).parts or type(pc["port"]) is not int or
        not 1 <= pc["port"] <= 65535 or pc["port"] == 8080):
        raise ConfigError("Invalid Process Compose file/port; never use Strata's port 8080.")
    for name, cfg in doc["clients"].items():
        if not isinstance(name, str) or not CLIENT_ID.fullmatch(name):
            raise ConfigError("Invalid client identity.")
        if (not isinstance(cfg, dict) or not {"policy"} <= set(cfg) or
            not set(cfg) <= {"policy", "origin"} or cfg["policy"] not in POLICIES or
            cfg.get("origin", "generated") not in {"generated", "imported"}):
            raise ConfigError("Each client requires a valid policy and optional credential origin.")
    return doc


def save_settings(folder: Path, doc: dict) -> None:
    private_write(settings_path(folder),
                  yaml.safe_dump(doc, sort_keys=False, allow_unicode=True).encode("utf-8"))


def project_path(folder: Path, doc: dict) -> Path:
    result = (folder / doc["process_compose"]["file"]).resolve()
    if not result.is_relative_to(folder.resolve()) or result.is_symlink():
        raise ConfigError("Process Compose project must stay inside the local services directory.")
    return result


def secret_file(folder: Path, name: str) -> Path:
    suffix = ".dpapi" if os.name == "nt" else ".token"
    return folder / "secrets" / (name + suffix)


def windows_secret(action: str, path: Path, token: str = "") -> str:
    if not WIN_HELPER.is_file():
        raise ConfigError("Windows DPAPI helper is missing.")
    pwsh = shutil.which("pwsh")
    if not pwsh:
        raise ConfigError("PowerShell 7 (pwsh) is required for Windows DPAPI.")
    result = subprocess.run(
        [pwsh, "-NoProfile", "-NonInteractive", "-File", str(WIN_HELPER),
         "-Action", action, "-Path", str(path)],
        input=token, text=True, capture_output=True, check=False
    )
    if result.returncode != 0:
        # Never return subprocess stderr; it might contain private data.
        raise ConfigError("Windows DPAPI operation failed. Check account and file permissions.")
    return result.stdout.rstrip("\r\n")


def write_secret(folder: Path, name: str) -> None:
    path = secret_file(folder, name)
    if path.exists() or path.is_symlink():
        raise ConfigError("Client credential already exists; never overwrite it.")
    token = secrets.token_urlsafe(48)
    private_dir(path.parent)
    if os.name == "nt":
        windows_secret("Store", path, token)
    else:
        private_write(path, (token + "\n").encode("ascii"), replace=False)


def read_secret(folder: Path, name: str) -> str:
    path = secret_file(folder, name)
    if not path.is_file() or path.is_symlink():
        raise ConfigError("Missing private credential for client " + name)
    if os.name == "nt":
        token = windows_secret("Read", path)
    else:
        mode = path.stat().st_mode
        if mode & (stat.S_IRWXG | stat.S_IRWXO):
            raise ConfigError("Client credential is accessible by group/others: " + name)
        token = path.read_text(encoding="ascii").strip()
    if not token or token.strip() != token or "\n" in token or "\r" in token:
        raise ConfigError("Malformed client secret: " + name)
    return token


def init(folder: Path) -> None:
    private_dir(folder)
    if settings_path(folder).exists():
        raise ConfigError("Already initialized; existing configuration left unchanged.")
    doc = {"schema_version": 1,
           "process_compose": {"file": "process-compose.yaml", "port": DEFAULT_PORT},
           "clients": {}}
    # Native Process Compose is the ONLY process definitions inventory.
    fixture = ("version: '0.5'\n"
               "processes:\n"
               "  aiw-smoke:\n"
               "    # Harmless, disabled; never auto-start production services.\n"
               "    command: 'echo aiw-process-compose-smoke'\n"
               "    disabled: true\n"
               "    namespace: validation\n")
    project = project_path(folder, doc)
    if project.exists():
        raise ConfigError("Existing Process Compose project; refusing to replace it.")
    private_write(project, fixture.encode("utf-8"), replace=False)
    api_token = folder / "secrets" / "process-compose.api-token"
    private_write(api_token, (secrets.token_urlsafe(48) + "\n").encode("ascii"), replace=False)
    if os.name == "nt":
        windows_secret("Protect", api_token)
    save_settings(folder, doc)
    print("Initialized:", folder)
    print("Edit:", project, "(native Process Compose YAML)")
    print("Add clients with: aiw services client add NAME --policy passthrough")


def client_add(folder: Path, name: str, policy: str) -> None:
    if not CLIENT_ID.fullmatch(name) or policy not in POLICIES:
        raise ConfigError("Invalid client name or policy.")
    doc = read_settings(folder)
    if name in doc["clients"]:
        raise ConfigError("Client exists already; no credential changed.")
    write_secret(folder, name)
    doc["clients"][name] = {"policy": policy, "origin": "generated"}
    save_settings(folder, doc)
    print("Created client:", name, "| policy:", policy)
    print("A unique original API key was generated automatically; it was NOT displayed.")
    print("Stored under Windows DPAPI/Linux private files:", secret_file(folder, name))
    print("On Windows, use the client-copy menu to transfer the key to a password manager.")
    print("clients.json holds one-way hashes; it is NOT a portable credential backup.")
    print("Run 'client render' to regenerate Dispatcher S02 hashes.")


def client_copy(folder: Path, name: str) -> None:
    """Explicit Windows-only DPAPI-to-clipboard transfer without stdout secrets."""
    if os.name != "nt":
        raise ConfigError("client copy is Windows-only; on Linux use client reveal carefully.")
    doc = read_settings(folder)
    if name not in doc["clients"]:
        raise ConfigError("Unknown registered client ID.")
    credential = secret_file(folder, name)
    if not credential.is_file() or credential.is_symlink():
        raise ConfigError("Missing protected client credential.")
    if doc["clients"][name].get("origin") == "imported":
        raise ConfigError(
            "Imported shared credential is retained for migration, not distributed "
            "as a new client key. Create a fresh client identity instead."
        )
    windows_secret("Copy", credential)
    print("Original API key copied to clipboard for client:", name)
    print("Paste it into your password manager's secret/password field.")
    print("Then clear the clipboard (and clipboard history if enabled).")
    print("No secret was printed or saved to clients.json.")


def client_set_policy(folder: Path, name: str, policy: str) -> None:
    """Change only a registered client's request policy; never rotate its key."""
    if not CLIENT_ID.fullmatch(name) or policy not in POLICIES:
        raise ConfigError("Invalid client ID or policy.")
    doc = read_settings(folder)
    if name not in doc["clients"]:
        raise ConfigError("Unknown registered client ID.")
    previous = doc["clients"][name]["policy"]
    if previous == policy:
        print("Policy already", policy, "for", name, "- no change.")
        return
    doc["clients"][name]["policy"] = policy
    save_settings(folder, doc)
    print("Updated client policy:", name, "|", previous, "->", policy)
    print("Original API key and provenance are unchanged.")
    print("Next: regenerate clients.json with 'client render';")
    print("then explicitly restart Dispatcher to activate this policy.")


def client_rename(folder: Path, old: str, new: str) -> None:
    """Rename logical identity without rotating or revealing the DPAPI secret."""
    if not CLIENT_ID.fullmatch(old) or not CLIENT_ID.fullmatch(new):
        raise ConfigError("Invalid client ID.")
    doc = read_settings(folder)
    if old not in doc["clients"]:
        raise ConfigError("Original client ID is not registered.")
    if old == new or new in doc["clients"]:
        raise ConfigError("New client ID must differ and be unused.")
    origin = secret_file(folder, old)
    target = secret_file(folder, new)
    if not origin.is_file() or origin.is_symlink() or target.exists() or target.is_symlink():
        raise ConfigError("Missing original or existing target credential.")
    doc["clients"] = {new if key == old else key: value
                      for key, value in doc["clients"].items()}
    origin.rename(target)
    try:
        save_settings(folder, doc)
    except Exception:
        target.rename(origin)
        raise
    print("Renamed client:", old, "->", new)
    print("Original protected credential preserved. Run client render.")
    print("Live S02 identity changes require explicit Dispatcher restart.")


def client_import_dpapi(folder: Path, name: str, policy: str, original: Path) -> None:
    """Retain an existing Windows DPAPI credential, e.g. legacy home-gateway."""
    if os.name != "nt":
        raise ConfigError("DPAPI credential import is Windows-only.")
    if not CLIENT_ID.fullmatch(name) or policy not in POLICIES:
        raise ConfigError("Invalid imported client name/policy.")
    doc = read_settings(folder)
    if name in doc["clients"]:
        raise ConfigError("Existing client identity cannot be overwritten.")
    original = original.expanduser().resolve()
    if not original.is_file() or original.is_symlink():
        raise ConfigError("Source must be an existing regular DPAPI file.")
    target = secret_file(folder, name)
    if target.exists() or target.is_symlink():
        raise ConfigError("Target credential already exists.")
    # Before copying, verify the encrypted value decrypts under this account.
    windows_secret("Read", original)
    private_write(target, original.read_bytes(), replace=False)
    doc["clients"][name] = {"policy": policy, "origin": "imported"}
    save_settings(folder, doc)
    print("Imported existing shared identity:", name)
    print("This is a transitional credential preserved for existing clients.")
    print("Do not copy it to new applications; provision fresh client keys instead.")
    print("Original protected file unchanged; no plaintext key was displayed.")
    print("Render S02 JSON before changing the active Dispatcher.")


def client_remove(folder: Path, name: str) -> None:
    doc = read_settings(folder)
    if name not in doc["clients"]:
        raise ConfigError("Unknown client.")
    # Remove from active policy, preserve private secret as a recovery backup.
    del doc["clients"][name]
    save_settings(folder, doc)
    print("Revoked in manifest:", name)
    print("Render JSON and restart authenticated Dispatcher to enforce the revocation.")
    print("Old encrypted credential is retained; purge after verifying revocation.")


def client_render(folder: Path, output: Path) -> None:
    doc = read_settings(folder)
    if not doc["clients"]:
        raise ConfigError("At least one client required; refuse empty S02 config (fail open).")
    clients = []
    seen = set()
    for name, cfg in doc["clients"].items():
        digest = hashlib.sha256(read_secret(folder, name).encode("utf-8")).hexdigest()
        if digest in seen:
            raise ConfigError("Duplicate client credential detected.")
        seen.add(digest)
        clients.append({"id": name, "token_sha256": digest, "policy": cfg["policy"]})
    if output.resolve().is_relative_to(folder.resolve()) is False:
        raise ConfigError("S02 output must stay inside private services directory.")
    private_write(output, (json.dumps({"schema_version": 1, "clients": clients},
                                      indent=2) + "\n").encode("utf-8"))
    print("Rendered S02 client identities:", ", ".join(doc["clients"]))
    print("Private digest-only JSON:", output)
    print("clients.json stores one-way digests, not usable API keys.")
    print("Back up generated keys individually in your preferred password manager.")
    print("Set DISPATCHER_CLIENT_CONFIG to this file; restart Dispatcher explicitly.")
    print("Caddy /v1 must forward Authorization without a single-token gate; retain")
    print("the existing protected /strata/v1 fallback. Do not change Caddy automatically.")


def download_failure_reason(exc: BaseException) -> str:
    """Actionable network diagnostics; never print credentials, URLs or response body."""
    if isinstance(exc, urllib.error.HTTPError):
        return "HTTP " + str(exc.code)
    reason = exc.reason if isinstance(exc, urllib.error.URLError) else exc
    if isinstance(reason, (ssl.SSLError, ssl.CertificateError)):
        return "TLS/certificate verification failed (" + type(reason).__name__ + ")"
    if isinstance(reason, (TimeoutError, socket.timeout)):
        return "connection timed out"
    if isinstance(reason, OSError):
        return "network/system error " + type(reason).__name__ + (
            f" (errno={reason.errno})" if reason.errno is not None else ""
        )
    return type(reason).__name__


def download_release(url: str, folder: Path) -> bytes:
    """Try standard verified HTTPS, then native Windows proxy/TLS handling."""
    req = urllib.request.Request(
        url, headers={"User-Agent": "ai-workstation-native-services/1.0"}
    )
    reason = None
    try:
        with urllib.request.urlopen(req, timeout=45) as response:
            return response.read(MAX_ARCHIVE_BYTES + 1)
    except (OSError, urllib.error.URLError, ssl.SSLError) as exc:
        reason = download_failure_reason(exc)
    if os.name == "nt":
        pwsh = shutil.which("pwsh")
        if pwsh and WIN_DOWNLOADER.is_file():
            # An ordinary PowerShell HTTPS download respects the Windows
            # network/proxy configuration. No TLS bypass or unverified binary.
            with tempfile.TemporaryDirectory(prefix="aiw-pc-", dir=folder) as tmp:
                output = Path(tmp) / "release.archive"
                proc = subprocess.run(
                    [pwsh, "-NoProfile", "-NonInteractive", "-File",
                     str(WIN_DOWNLOADER), "-Uri", url, "-Destination", str(output)],
                    capture_output=True, text=True, check=False,
                )
                if proc.returncode == 0 and output.is_file():
                    if output.stat().st_size > MAX_ARCHIVE_BYTES:
                        raise ConfigError("Downloaded archive is unexpectedly large; not installed.")
                    print("[SVC] Downloaded with native Windows PowerShell.")
                    return output.read_bytes()
        raise ConfigError(
            "Cannot download official Process Compose release (Python: " + reason +
            "; Windows PowerShell also unsuccessful). Check proxy/TLS/network policy, "
            "or download the official archive with your browser and use "
            "'install --archive PATH'. No binary was installed."
        )
    raise ConfigError(
        "Cannot download official Process Compose release (" + reason +
        "). Check network/TLS, or use 'install --archive PATH'."
    )


def install_process_compose(folder: Path, archive_path: Path | None = None) -> None:
    """Opt-in install from the pinned URL or a local archive, SHA-256 verified."""
    system = "Windows" if os.name == "nt" else "Linux"
    machine = platform.machine().upper().replace("X86_64", "AMD64").replace("AARCH64", "ARM64")
    version, filename, digest = pinned_release(system, machine)
    dest = folder / "bin" / ("process-compose.exe" if os.name == "nt" else "process-compose")
    if dest.exists() or dest.is_symlink():
        raise ConfigError("Native binary exists already; no automatic overwrite/upgrade.")
    url = ("https://github.com/F1bonacc1/process-compose/releases/download/" +
           version + "/" + filename)
    private_dir(folder / "bin")
    if archive_path is not None:
        source = archive_path.expanduser().resolve()
        if not source.is_file() or source.is_symlink():
            raise ConfigError("Specified offline archive is missing or not a regular file.")
        if source.stat().st_size > MAX_ARCHIVE_BYTES:
            raise ConfigError("Specified archive is too large; not installed.")
        archive = source.read_bytes()
        print("[SVC] Reading local archive:", source)
    else:
        print("[SVC] Downloading official release:", url, flush=True)
        archive = download_release(url, folder)
    if len(archive) > MAX_ARCHIVE_BYTES or hashlib.sha256(archive).hexdigest() != digest:
        raise ConfigError(
            "Process Compose archive SHA-256 mismatch (or oversized archive). "
            "Refusing installation; check that the correct version and platform was downloaded."
        )
    binary = "process-compose.exe" if os.name == "nt" else "process-compose"
    try:
        if filename.endswith(".zip"):
            with zipfile.ZipFile(io.BytesIO(archive)) as file:
                names = [n for n in file.namelist() if Path(n).name == binary]
                if len(names) != 1:
                    raise ConfigError("Missing or ambiguous executable in verified archive.")
                contents = file.read(names[0])
        else:
            with tarfile.open(fileobj=io.BytesIO(archive), mode="r:gz") as file:
                members = [x for x in file.getmembers() if x.isfile() and Path(x.name).name == binary]
                if len(members) != 1:
                    raise ConfigError("Missing or ambiguous executable in verified archive.")
                stream = file.extractfile(members[0])
                if stream is None:
                    raise ConfigError("Unable to extract executable.")
                contents = stream.read()
    except (zipfile.BadZipFile, tarfile.TarError, OSError):
        raise ConfigError("Verified archive could not be extracted; no binary installed.") from None
    private_write(dest, contents, replace=False)
    if os.name != "nt":
        dest.chmod(0o700)
    print("Installed checksum-verified", version, "to", dest)
    print("No host services or startup tasks were changed.")

def reviewed_windows_pilot_pin() -> dict:
    """Return the centrally reviewed Windows pilot source/build pin."""
    try:
        manifest = json.loads(VERSION_FILE.read_text(encoding="utf-8"))
        cfg = manifest["versions"]["process_compose"]["security"]["reviewed_windows_pilot"]
        digest = cfg["binary_sha256"]
        if not re.fullmatch(r"[a-f0-9]{64}", digest):
            raise ValueError("bad digest")
        if cfg["go_version"] != "go1.27.3" or cfg["source_commit"] != (
            "f471d83a5dfa4779d589d0a73182b6d6e22736b2"
        ):
            raise ValueError("unreviewed source or Go toolchain")
        return cfg
    except (OSError, KeyError, TypeError, ValueError):
        raise ConfigError("Missing or invalid pinned Windows pilot approval metadata.") from None


def pilot_binary(folder: Path) -> Path:
    return folder / "bin" / "process-compose-pilot.exe"


def pilot_marker(folder: Path) -> Path:
    return folder / "security" / "reviewed-windows-pilot.json"


def windows_reviewed_pilot_active(folder: Path) -> bool:
    """Private opt-in + exact pinned binary hash; unrelated hosts stay blocked."""
    marker = pilot_marker(folder)
    if not marker.exists() and not marker.is_symlink():
        return False
    if os.name != "nt" or platform.machine().upper().replace("X86_64", "AMD64") != "AMD64":
        return False
    if marker.is_symlink() or not marker.is_file():
        raise ConfigError("Invalid reviewed Windows pilot marker.")
    try:
        state = json.loads(marker.read_text(encoding="utf-8"))
        pin = reviewed_windows_pilot_pin()
        if state != {"sha256": pin["binary_sha256"],
                     "source_commit": pin["source_commit"],
                     "approval": "operator-opt-in"}:
            raise ValueError("pilot metadata mismatch")
    except (OSError, ValueError, TypeError):
        raise ConfigError("Unrecognized reviewed Windows pilot approval marker.") from None
    binary = pilot_binary(folder)
    if not binary.is_file() or binary.is_symlink():
        raise ConfigError("Reviewed Windows pilot binary missing or linked.")
    if hashlib.sha256(binary.read_bytes()).hexdigest() != pin["binary_sha256"]:
        raise ConfigError("Reviewed Windows pilot binary hash changed: refusing startup.")
    override = os.environ.get("AIW_PROCESS_COMPOSE_BIN")
    if override and os.path.normcase(os.path.realpath(override)) != os.path.normcase(os.path.realpath(binary)):
        raise ConfigError("Explicit supervisor binary conflicts with the reviewed Windows pilot.")
    return True


def install_windows_reviewed_pilot(folder: Path, archive_path: Path) -> None:
    """Deliberate limited Windows host pilot, never replace the official binary."""
    if os.name != "nt" or platform.machine().upper().replace("X86_64", "AMD64") != "AMD64":
        raise ConfigError("Reviewed pilot installation is available only on Windows AMD64.")
    if windows_supervisor_state_path(folder).exists() or windows_supervisor_state_path(folder).is_symlink():
        raise ConfigError("An AIW supervisor ownership record exists; stop it before installing a pilot.")
    doc = read_settings(folder)
    if port_accepts_connections(doc["process_compose"]["port"]):
        raise ConfigError("Native management port is occupied; refusing supervisor installation.")
    source = archive_path.expanduser().resolve()
    if source.is_symlink() or not source.is_file() or source.stat().st_size > MAX_ARCHIVE_BYTES:
        raise ConfigError("Reviewed pilot ZIP must be a local regular file within archive size limit.")
    pin = reviewed_windows_pilot_pin()
    try:
        with zipfile.ZipFile(source) as archive:
            infos = [item for item in archive.infolist()
                     if Path(item.filename).name == "process-compose.exe" and not item.is_dir()]
            if len(infos) != 1 or infos[0].file_size > 160 * 1024 * 1024:
                raise ConfigError("Expected one size-limited process-compose.exe in the pilot ZIP.")
            contents = archive.read(infos[0])
    except (zipfile.BadZipFile, OSError, RuntimeError):
        raise ConfigError("Invalid reviewed Windows pilot artifact ZIP.") from None
    if hashlib.sha256(contents).hexdigest() != pin["binary_sha256"]:
        raise ConfigError("Reviewed Windows pilot binary SHA-256 mismatch: refusing install.")
    dest = pilot_binary(folder)
    if dest.is_symlink():
        raise ConfigError("Refusing pilot installation through a symlink.")
    if dest.exists():
        if hashlib.sha256(dest.read_bytes()).hexdigest() != pin["binary_sha256"]:
            raise ConfigError("Different pilot binary already exists; no automatic replacement.")
    else:
        private_write(dest, contents, replace=False)
    record = (json.dumps({
        "sha256": pin["binary_sha256"], "source_commit": pin["source_commit"],
        "approval": "operator-opt-in",
    }) + "\n").encode("utf-8")
    if pilot_marker(folder).exists():
        if not windows_reviewed_pilot_active(folder):
            raise ConfigError("Pilot approval marker exists but does not match the reviewed build.")
        print("[OK] Reviewed Windows pilot already active for this host.")
        return
    private_write(pilot_marker(folder), record, replace=False)
    print("[OK] Reviewed Windows Process Compose pilot installed and opted in.")
    print("Pinned source:", pin["source_commit"], "| Go", pin["go_version"])
    print("Review:", pin["qualification_run"])
    print("Official binary preserved at", folder / "bin" / "process-compose.exe")
    print("No process started. Live takeover still needs free ports and explicit operator approval.")


def remove_windows_reviewed_pilot(folder: Path) -> None:
    if os.name != "nt":
        raise ConfigError("Reviewed pilot removal is Windows-only.")
    if windows_supervisor_state_path(folder).exists():
        raise ConfigError("Owned supervisor may still be running; stop and verify before removing pilot.")
    doc = read_settings(folder)
    if port_accepts_connections(doc["process_compose"]["port"]):
        raise ConfigError("Supervisor management port is occupied; refusing removal.")
    if not windows_reviewed_pilot_active(folder):
        print("No reviewed pilot currently active for this Windows account.")
        return
    pilot_marker(folder).unlink()
    pilot_binary(folder).unlink()
    print("[OK] Reviewed Windows pilot unregistered; ordinary production hold remains active.")


def native_binary(folder: Path) -> str:
    if os.name == "nt" and windows_reviewed_pilot_active(folder):
        return str(pilot_binary(folder))
    explicit = os.environ.get("AIW_PROCESS_COMPOSE_BIN")
    if explicit:
        if not Path(explicit).is_file():
            raise ConfigError("Explicit native Process Compose binary does not exist.")
        return explicit
    local = folder / "bin" / ("process-compose.exe" if os.name == "nt" else "process-compose")
    if local.is_file():
        return str(local)
    fallback = shutil.which("process-compose")
    if fallback:
        return fallback
    raise ConfigError("Native Process Compose missing. Run: aiw services install")


def check_production_security_gate(folder: Path, project: Path, action: str, process: str | None) -> None:
    """Known Go 1.27.0 official build: permit only the harmless fixture pilot."""
    if action not in {"up", "tui", "start", "restart"}:
        return
    try:
        manifest = json.loads(VERSION_FILE.read_text(encoding="utf-8"))["versions"]["process_compose"]
        blocked = manifest["security"]["production_adoption_blocked"]
    except (OSError, KeyError, ValueError, TypeError):
        raise ConfigError("Missing Process Compose production security gate.") from None
    if not blocked:
        return
    # The general production gate stays locked. The exact reviewed, locally
    # opted-in Windows-only Go 1.27.3 binary qualifies for a limited pilot.
    if os.name == "nt" and windows_reviewed_pilot_active(folder):
        # Reviewed Windows pilot applies to AIW-generated host projects ONLY,
        # not to arbitrary Process Compose YAML or unrelated native services.
        if project.read_text(encoding="utf-8").startswith("# AIW native-host project"):
            return
    try:
        doc = yaml.safe_load(project.read_text(encoding="utf-8"))
        services = doc["processes"]
        smoke = services["aiw-smoke"]
        fixture_only = (
            len(services) == 1 and
            set(doc) == {"version", "processes"} and
            isinstance(smoke, dict) and
            set(smoke) <= {"command", "disabled", "namespace"} and
            smoke.get("command") == "echo aiw-process-compose-smoke" and
            smoke.get("namespace") == "validation" and
            smoke.get("disabled", True) in (True, False)
        )
    except (OSError, KeyError, TypeError, ValueError, AttributeError, yaml.YAMLError):
        fixture_only = False
    if not fixture_only or (action in {"start", "restart"} and process != "aiw-smoke"):
        raise ConfigError(
            "Production native service start blocked: pinned Process Compose v1.124.0 "
            "was built with unpatched Go 1.27.0. Only the isolated aiw-smoke "
            "fixture may run until a patched release/build passes review."
        )


def windows_process_identity(pid: int) -> dict | None:
    """Windows kernel PID, executable path and creation FILETIME (PID reuse guard)."""
    if os.name != "nt":
        return None
    import ctypes
    from ctypes import wintypes

    class FILETIME(ctypes.Structure):
        _fields_ = [("low", wintypes.DWORD), ("high", wintypes.DWORD)]

    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.OpenProcess.argtypes = (wintypes.DWORD, wintypes.BOOL, wintypes.DWORD)
    kernel.OpenProcess.restype = wintypes.HANDLE
    kernel.QueryFullProcessImageNameW.argtypes = (
        wintypes.HANDLE, wintypes.DWORD, wintypes.LPWSTR, ctypes.POINTER(wintypes.DWORD)
    )
    kernel.GetProcessTimes.argtypes = (
        wintypes.HANDLE, ctypes.POINTER(FILETIME), ctypes.POINTER(FILETIME),
        ctypes.POINTER(FILETIME), ctypes.POINTER(FILETIME)
    )
    kernel.CloseHandle.argtypes = (wintypes.HANDLE,)
    handle = kernel.OpenProcess(0x1000, False, pid)  # QUERY_LIMITED_INFORMATION
    if not handle:
        return None
    try:
        size = wintypes.DWORD(32768)
        name = ctypes.create_unicode_buffer(32768)
        created, exited, kernel_t, user_t = FILETIME(), FILETIME(), FILETIME(), FILETIME()
        if not kernel.QueryFullProcessImageNameW(handle, 0, name, ctypes.byref(size)):
            return None
        if not kernel.GetProcessTimes(handle, ctypes.byref(created), ctypes.byref(exited),
                                      ctypes.byref(kernel_t), ctypes.byref(user_t)):
            return None
        return {"pid": pid, "exe": os.path.normcase(os.path.realpath(name.value)),
                "created": f"{created.high:08x}{created.low:08x}"}
    finally:
        kernel.CloseHandle(handle)


def windows_supervisor_state_path(folder: Path) -> Path:
    return folder / "runtime" / "process-compose-windows.json"



@contextmanager
def windows_start_lock(folder: Path):
    """Crash-released Windows mutex for start/recovery, not a persistent lock bit."""
    if os.name != "nt":
        raise ConfigError("Windows start lock is Windows-only.")
    import msvcrt
    directory = folder / "runtime"
    private_dir(directory)
    path = directory / "process-compose-start.lock"
    if path.is_symlink():
        raise ConfigError("Linked supervisor start lock; refusing startup.")
    with path.open("a+b") as stream:
        stream.seek(0, os.SEEK_END)
        if stream.tell() == 0:
            stream.write(b"\x00")
            stream.flush()
        stream.seek(0)
        try:
            msvcrt.locking(stream.fileno(), msvcrt.LK_NBLCK, 1)
        except OSError:
            raise ConfigError("Another AIW start is in progress; retry when it finishes.") from None
        try:
            yield
        finally:
            stream.seek(0)
            msvcrt.locking(stream.fileno(), msvcrt.LK_UNLCK, 1)


def windows_boot_id() -> str | None:
    """Record the Windows boot epoch; PID/executable/creation remain required."""
    try:
        result = subprocess.run(
            ["pwsh", "-NoProfile", "-NonInteractive", "-Command",
             "$ErrorActionPreference='Stop'; "
             "(Get-CimInstance Win32_OperatingSystem).LastBootUpTime."
             "ToUniversalTime().ToString('o')"],
            capture_output=True, text=True, check=False, timeout=12)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return result.stdout.strip() if result.returncode == 0 and result.stdout.strip() else None


def windows_process_compose_pids() -> set[int]:
    """Fail closed rather than assume an uninspectable process list is empty."""
    try:
        result = subprocess.run(
            ["pwsh", "-NoProfile", "-NonInteractive", "-Command",
             "$ErrorActionPreference='Stop'; "
             "@(Get-CimInstance Win32_Process -Filter "
             "\"Name LIKE 'process-compose%'\" -ErrorAction Stop | "
             "Select-Object -ExpandProperty ProcessId) -join ','"],
            capture_output=True, text=True, check=False, timeout=12)
    except (OSError, subprocess.TimeoutExpired):
        raise ConfigError("Cannot inspect Process Compose processes; refusing startup.") from None
    if result.returncode:
        raise ConfigError("Process Compose process inspection failed; refusing startup.")
    try:
        return {int(v) for v in result.stdout.strip().split(",") if v.strip()}
    except ValueError:
        raise ConfigError("Invalid Process Compose process inventory; refusing startup.") from None


def windows_prepare_start(folder: Path, binary: str, port: int,
                          service_ports: list[int]) -> bool:
    """True = existing exact supervisor. Archive only provably orphaned state.

    Must be invoked with the Windows start mutex. NEVER terminate a PID here.
    """
    state = windows_supervisor_state_path(folder)
    if state.is_symlink():
        raise ConfigError("Linked supervisor ownership record; refusing startup.")
    if not state.exists():
        if windows_process_compose_pids():
            raise ConfigError("Untracked Process Compose is running; no duplicate started. "
                              "Inspect 'aiw ports'.")
        return False
    if not state.is_file():
        raise ConfigError("Supervisor ownership record is not a regular file.")
    try:
        snapshot = state.read_bytes()
        record = json.loads(snapshot)
        identity = record["identity"]
        if type(identity) is not dict:
            raise ValueError("bad identity")
        pid = identity["pid"]
        if (type(pid) is not int or pid <= 0 or
                type(identity.get("exe")) is not str or
                type(identity.get("created")) is not str or
                type(record["port"]) is not int):
            raise ValueError("bad fields")
    except (OSError, ValueError, KeyError, TypeError):
        raise ConfigError("Invalid supervisor ownership record; refusing recovery.") from None
    current = windows_process_identity(pid)
    boot = windows_boot_id()
    recorded_boot = record.get("boot_id")
    if (current == identity and
            current["exe"] == os.path.normcase(os.path.realpath(binary)) and
            (not boot or not recorded_boot or recorded_boot == boot)):
        print("[OK] Supervisor already running (PID " + str(pid) +
              "). No duplicate started.")
        return True
    # A reused PID may belong to Adobe or any other application: never kill it.
    if windows_process_compose_pids():
        raise ConfigError("Supervisor identity changed but Process Compose is still running. "
                          "Refusing recovery and duplicate startup; inspect 'aiw ports'.")
    recorded_ports = windows_shutdown_ports(folder, identity)
    checked = sorted(set(recorded_ports + service_ports + [port]))
    occupied = windows_all_listeners(checked)
    if occupied:
        raise ConfigError("Stale ownership record but port(s) " +
                          ", ".join(map(str, sorted(occupied))) +
                          " still listening. Refusing recovery; inspect 'aiw ports'.")
    if state.is_symlink() or state.read_bytes() != snapshot:
        raise ConfigError("Ownership record changed during recovery; refusing startup.")
    state.rename(state.with_name(state.name + ".stale-" + str(time.time_ns()) + ".bak"))
    return False


def windows_ensure_owned(folder: Path, binary: str) -> dict:
    """Refuse to operate on an unknown, replaced or untracked port owner."""
    state_file = windows_supervisor_state_path(folder)
    if not state_file.is_file() or state_file.is_symlink():
        raise ConfigError(
            "No AI Workstation-owned Windows supervisor recorded. "
            "Refusing to control a possibly unrelated process."
        )
    try:
        record = json.loads(state_file.read_text(encoding="utf-8"))
        expected = record["identity"]
        pid = expected["pid"]
        if type(pid) is not int or type(expected) is not dict:
            raise ValueError("bad ownership record")
    except (OSError, ValueError, KeyError, TypeError):
        raise ConfigError("Invalid supervisor ownership record; refusing control.") from None
    current = windows_process_identity(pid)
    if (current is None or current != expected or
            current["exe"] != os.path.normcase(os.path.realpath(binary))):
        raise ConfigError(
            "Supervisor PID/executable/creation time does not match its ownership record. "
            "Refusing control; investigate manually."
        )
    return expected


def port_accepts_connections(port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as conn:
        conn.settimeout(0.25)
        return conn.connect_ex(("127.0.0.1", port)) == 0


def windows_launch_supervisor(folder: Path, binary: str, cmd: list[str],
                               status_command: list[str], port: int, env: dict,
                               service_ports: list[int] | None = None,
                               preflight=None) -> None:
    """Exactly one Windows process may reconcile/restart at a time."""
    with windows_start_lock(folder):
        return _windows_launch_supervisor_locked(
            folder, binary, cmd, status_command, port, env, service_ports or [],
            preflight)


def _windows_launch_supervisor_locked(folder: Path, binary: str, cmd: list[str],
                                      status_command: list[str], port: int, env: dict,
                                      service_ports: list[int], preflight) -> None:
    if windows_prepare_start(folder, binary, port, service_ports):
        return
    if preflight is not None:
        preflight()
    state = windows_supervisor_state_path(folder)
    busy = windows_all_listeners([port])
    if busy:
        raise ConfigError("Management port " + str(port) +
                          " already listens; inspect 'aiw ports'.")
    if port_accepts_connections(port):
        raise ConfigError(
            "Management port already has a listener. Refusing to take over "
            "an unknown Process Compose instance or other application."
        )
    private_dir(state.parent)
    log_path = state.parent / "process-compose-stdout.log"
    if log_path.is_symlink():
        raise ConfigError("Refusing to write supervisor logs through a symlink.")
    # A detached *console-less* supervisor makes each Windows console child
    # (cmd/pwsh/batch) create its own terminal window. Give the supervisor its
    # own HIDDEN console instead; descendants can inherit that same console,
    # while Process Compose still writes to durable private log files.
    # A separate console keeps the supervisor independent of the AIW menu
    # terminal. This is Windows-host behavior, verified by a real-host test.
    startup_info = subprocess.STARTUPINFO()
    startup_info.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup_info.wShowWindow = subprocess.SW_HIDE
    with open(log_path, "ab") as log:
        proc = subprocess.Popen(
            cmd, stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
            env=env, close_fds=True,
            startupinfo=startup_info, creationflags=subprocess.CREATE_NEW_CONSOLE,
        )
    identity = None
    for _ in range(8):
        identity = windows_process_identity(proc.pid)
        if identity is not None or proc.poll() is not None:
            break
        time.sleep(0.15)
    if identity is None:
        raise ConfigError(
            "Windows Process Compose exited before its process identity could be "
            "captured. See the private runtime/process-compose-stdout.log."
        )
    private_write(state, (json.dumps({"identity": identity,
                                      "port": port,
                                      "service_ports": service_ports, "boot_id": windows_boot_id()}) + "\n").encode("utf-8"),
                  replace=False)
    for _ in range(30):
        if proc.poll() is not None:
            state.unlink(missing_ok=True)
            raise ConfigError(
                "Windows Process Compose terminated during startup. "
                "See private runtime/process-compose-stdout.log."
            )
        if port_accepts_connections(port):
            result = subprocess.run(status_command, env=env, capture_output=True,
                                    text=True, check=False, timeout=4)
            if result.returncode == 0:
                print("[OK] Native Windows Process Compose supervisor ready.",
                      "PID:", identity["pid"], "| port:", port)
                print("Read service output using Run and monitor -> Read saved service logs.")
                print("All services are managed together; no extra visible terminal is intended.")
                print("Use Status/Logs/Stop for the AIW-owned supervisor.")
                return
        time.sleep(0.2)
    raise ConfigError(
        "Supervisor launch did not become ready. Ownership record is retained "
        "for safe manual inspection/Stop; see private runtime log."
    )


def windows_native_service_ports(folder: Path) -> list[int]:
    """Read declared native service ports; a smoke-only project has no host JSON."""
    path = folder / "native-host.json"
    if not path.exists():
        return []
    if not path.is_file() or path.is_symlink():
        raise ConfigError("Invalid native host configuration for shutdown verification.")
    try:
        services = json.loads(path.read_text(encoding="utf-8"))["services"]
        if not isinstance(services, dict) or not services:
            raise ValueError("No native services")
        ports = []
        for service in services.values():
            if not isinstance(service, dict) or type(service.get("enabled")) is not bool:
                raise ValueError("Invalid native service configuration")
            if not service["enabled"]:
                continue
            listed = service["listen_ports"]
            if not isinstance(listed, list) or not listed:
                raise ValueError("Missing service ports")
            ports.extend(listed)
        if (any(type(p) is not int or not 1 <= p <= 65535 for p in ports)
                or len(ports) != len(set(ports))):
            raise ValueError("Invalid service port")
        return sorted(ports)
    except (OSError, ValueError, KeyError, TypeError):
        raise ConfigError("Cannot read native service ports for shutdown verification.") from None


def windows_shutdown_ports(folder: Path, identity: dict) -> list[int]:
    """Prefer the startup snapshot, but support existing Windows ownership records."""
    path = windows_supervisor_state_path(folder)
    if not path.is_file() or path.is_symlink():
        raise ConfigError("Missing or linked supervisor ownership record.")
    try:
        record = json.loads(path.read_text(encoding="utf-8"))
        if record.get("identity") != identity:
            raise ValueError("Ownership changed")
        management = record["port"]
        if type(management) is not int or not 1 <= management <= 65535:
            raise ValueError("Invalid management port")
        declared = record.get("service_ports")
        if declared is None:  # Backward compatible with pre-change live supervisors.
            declared = windows_native_service_ports(folder)
        if not isinstance(declared, list) or any(
                type(p) is not int or not 1 <= p <= 65535 for p in declared):
            raise ValueError("Invalid saved service port list")
        return sorted(set(declared + [management]))
    except (OSError, KeyError, ValueError, TypeError):
        raise ConfigError("Cannot verify Windows supervisor shutdown port inventory.") from None


def windows_loopback_listeners(ports: list[int]) -> set[int]:
    """Cheap repeated check: no subprocess or command shell in the polling loop."""
    busy = set()
    for port in ports:
        if port_accepts_connections(port):
            busy.add(port)
            continue
        try:
            with socket.socket(socket.AF_INET6, socket.SOCK_STREAM) as conn:
                conn.settimeout(0.25)
                if conn.connect_ex(("::1", port)) == 0:
                    busy.add(port)
        except OSError:  # IPv6 loopback may not be configured.
            pass
    return busy


def windows_all_listeners(ports: list[int]) -> set[int]:
    """Final authoritative Windows listener check covers all IPv4/IPv6 bindings."""
    if not ports:
        return set()
    command = (
        "$ErrorActionPreference='Stop'; "
        "$wanted=@(" + ",".join(map(str, ports)) + "); "
        "@(Get-NetTCPConnection -State Listen -ErrorAction Stop | "
        "Where-Object { $wanted -contains [int]$_.LocalPort } | "
        "Select-Object -ExpandProperty LocalPort -Unique) -join ','"
    )
    try:
        result = subprocess.run(
            ["pwsh", "-NoProfile", "-NonInteractive", "-Command", command],
            capture_output=True, text=True, check=False, timeout=12,
        )
    except (OSError, subprocess.TimeoutExpired):
        raise ConfigError("Cannot inspect all Windows TCP listeners after shutdown.") from None
    if result.returncode:
        raise ConfigError("Windows TCP listener verification failed after shutdown.")
    try:
        busy = {int(item.strip()) for item in result.stdout.strip().split(",")
                if item.strip()}
    except ValueError:
        raise ConfigError("Unexpected Windows TCP listener verification output.") from None
    if not busy.issubset(set(ports)):
        raise ConfigError("Unexpected ports in Windows TCP listener verification.")
    return busy


def windows_wait_for_shutdown(folder: Path, identity: dict, ports: list[int],
                              timeout_seconds: float = 180) -> None:
    """Finish Stop only after supervisor exit AND all service listeners close."""
    path = windows_supervisor_state_path(folder)
    deadline = time.monotonic() + timeout_seconds
    next_report = time.monotonic() + 5
    print("Waiting for native services and supervisor to stop...", flush=True)
    while True:
        alive = windows_process_identity(identity["pid"]) == identity
        busy = windows_loopback_listeners(ports)
        if not alive and not busy:
            busy = windows_all_listeners(ports)
        if not alive and not busy:
            if not path.is_file() or path.is_symlink():
                raise ConfigError("Shutdown ownership record missing or linked; inspect manually.")
            try:
                record = json.loads(path.read_text(encoding="utf-8"))
            except (OSError, ValueError):
                raise ConfigError("Shutdown ownership record is unreadable.") from None
            if record.get("identity") != identity:
                raise ConfigError("Shutdown ownership changed; refusing to clear it.")
            path.unlink()
            print("[OK] Windows services stopped, all configured TCP ports free; "
                  "supervisor ownership released.")
            return
        now = time.monotonic()
        if now >= deadline:
            problems = []
            if alive:
                problems.append("supervisor still running")
            if busy:
                problems.append("TCP ports still listening: " +
                                ", ".join(map(str, sorted(busy))))
            raise ConfigError(
                "Shutdown incomplete (" + "; ".join(problems) +
                "). Ownership record retained; do not start a second instance."
            )
        if now >= next_report:
            print("[WAIT] Shutdown in progress: " +
                  ("supervisor still active; " if alive else "") +
                  ("busy TCP ports " + ", ".join(map(str, sorted(busy)))
                   if busy else "waiting for supervisor exit"), flush=True)
            next_report = now + 5
        time.sleep(1)


def native_host_setup(folder: Path, action: str, process: str | None = None, *, apply: bool = False) -> None:
    """Use the repo-owned, separate Windows host renderer without editing Git files."""
    cmd = [sys.executable, str(Path(__file__).with_name("aiw-native-host.py")),
           action, "--directory", str(folder)]
    if process:
        cmd += ["--service", process]
    if apply:
        cmd.append("--apply")
    result = subprocess.run(cmd, check=False)
    if result.returncode:
        raise ConfigError("Native Windows host " + action + " failed.")


NATIVE_LOG_NAMES = ("strata", "dispatcher", "caddy", "open-webui")


def saved_service_logs(folder: Path, service: str | None = None, lines: int = 100) -> None:
    """Inspect persistent native service logs, even after supervisor failure.

    No management API, process restart, or token lookup is performed.
    Files may contain private application output; display locally only.
    """
    if service and service not in NATIVE_LOG_NAMES:
        raise ConfigError("Unknown native service log name.")
    if not 1 <= lines <= 1000:
        raise ConfigError("Log line count must be 1..1000.")
    log_root = folder / "runtime" / "logs"
    if log_root.is_symlink():
        raise ConfigError("Refusing linked private service log directory.")
    for name in ((service,) if service else NATIVE_LOG_NAMES):
        path = log_root / (name + ".log")
        print("\n---", name, "saved startup/service log ---")
        print("File:", path)
        if path.is_symlink():
            raise ConfigError("Refusing linked native service log file.")
        if not path.is_file():
            print("No saved output from this service yet.")
            continue
        with path.open("r", encoding="utf-8", errors="replace") as stream:
            for line in deque(stream, maxlen=lines):
                print(line.rstrip("\r\n"))


def native(folder: Path, action: str, process: str | None) -> None:
    doc = read_settings(folder)
    project = project_path(folder, doc)
    if not project.is_file():
        raise ConfigError("Missing native Process Compose YAML.")
    check_production_security_gate(folder, project, action, process)
    # Generated native-host projects are explicitly provisioned. Before any
    # launch, require the private settings to still match the rendered project,
    # and refuse ports held by the previous unmanaged startup script.
    if (os.name == "nt" and action == "start" and
            project.read_text(encoding="utf-8").startswith(
                "# AIW native-host project")):
        native_host_setup(folder, "preflight", process)
    binary = native_binary(folder)
    port = doc["process_compose"]["port"]
    api_token = folder / "secrets" / "process-compose.api-token"
    if not api_token.is_file() or api_token.is_symlink():
        raise ConfigError("Missing private Process Compose management token.")
    if os.name != "nt" and (api_token.stat().st_mode & (stat.S_IRWXG | stat.S_IRWXO)):
        raise ConfigError("Process Compose management token permissions are too permissive.")
    basic = [binary, "--address", "127.0.0.1", "--port", str(port),
             "--token-file", str(api_token)]
    if action == "check":
        cmd = basic + ["--disable-dotenv", "--config", str(project), "up", "--dry-run"]
    elif action == "up":
        cmd = basic + ["--disable-dotenv", "--config", str(project), "up",
                       "--keep-project", "--tui=false"]
        if os.name != "nt":
            cmd.append("--detached")  # upstream registers this only outside Windows
    elif action == "tui":
        cmd = basic + ["attach"]  # never start a second supervisor
    else:
        if action == "logs" and process is None:
            # Upstream process logs requires an explicit name; unlike the TUI
            # there is no valid "logs all" without a namespace selector.
            project_doc = yaml.safe_load(project.read_text(encoding="utf-8"))
            configured = project_doc.get("processes", {})
            if not isinstance(configured, dict) or not configured:
                raise ConfigError("No processes configured for logs.")
            process = ",".join(configured)
        operations = {
            "status": ["process", "list"],
            "logs": ["process", "logs", process],
            "start": ["process", "start", process],
            "stop": ["process", "stop", process],
            "restart": ["process", "restart", process],
            "down": ["down"],
        }
        cmd = basic + operations[action]

    # Upstream may print benign global configuration search debug messages;
    # suppress only debug-level chatter, not real errors.
    env = os.environ.copy()
    # Official v1.124.0 searches XDG locations even with --config set;
    # its supported PROC_COMP_CONFIG avoids spurious "config home not found"
    # JSON diagnostics and keeps any optional native UI settings private.
    env["PROC_COMP_CONFIG"] = str(folder)
    env["PC_LOG_LEVEL"] = "warn"
    if os.name == "nt":
        if action == "up":
            print("Starting ONLY configured native processes under Process Compose.")
            print("Management: 127.0.0.1:", port, "| config:", project)
            service_ports = (windows_native_service_ports(folder)
                             if project.read_text(encoding="utf-8").startswith(
                                 "# AIW native-host project") else [])
            generated = project.read_text(encoding="utf-8").startswith(
                "# AIW native-host project")
            before_launch = (lambda: native_host_setup(folder, "preflight")
                             if generated else None)
            return windows_launch_supervisor(folder, binary, cmd,
                                             basic + ["process", "list"], port, env,
                                             service_ports, before_launch)
        if action in {"tui", "start", "stop", "restart", "down"}:
            record = windows_ensure_owned(folder, binary)
            if action == "down":
                shutdown_ports = windows_shutdown_ports(folder, record)
        if action in {"status", "logs"} and port_accepts_connections(port):
            # Read-only operations still must not talk to unknown listeners.
            windows_ensure_owned(folder, binary)
    if action == "up":
        print("Starting ONLY configured native processes under Process Compose.")
        print("Management: 127.0.0.1:", port, "| config:", project)
    try:
        result = subprocess.run(
            cmd, check=False, env=env,
            timeout=240 if os.name == "nt" and action == "down" else None,
        )
    except subprocess.TimeoutExpired:
        raise ConfigError(
            "Native Process Compose shutdown timed out. Ownership record retained; "
            "do not launch a duplicate supervisor."
        ) from None
    if result.returncode:
        raise ConfigError("Native Process Compose " + action + " failed (exit " +
                          str(result.returncode) + ").")
    if action == "down" and os.name == "nt":
        windows_wait_for_shutdown(folder, record, shutdown_ports)

    elif action == "check":
        print("[OK] Explicit private Process Compose project validated. Nothing started.")


def run(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="Native host services and S02 client identities")
    parser.add_argument("--directory", type=Path, default=default_dir())
    sub = parser.add_subparsers(dest="cmd", required=True)
    for k in ("init", "where", "install", "check", "up", "tui", "status", "down", "logs", "logs-file"):
        p = sub.add_parser(k)
        if k in {"logs", "logs-file"}:
            p.add_argument("name", nargs="?")
        if k == "logs-file":
            p.add_argument("--lines", type=int, default=100)
        if k == "install":
            p.add_argument("--archive", type=Path, help="Official local archive; SHA-256 verified")
    for k in ("start", "stop", "restart"):
        sub.add_parser(k).add_argument("name")
    host = sub.add_parser("host", help="Prepare native Windows Caddy/Dispatcher/Strata project")
    host.add_argument("action", choices=("init", "inspect", "validate", "render", "preflight", "quiet-probes",
                                         "integrity-review", "integrity-approve"))
    host.add_argument("--service", choices=("strata", "dispatcher", "caddy", "open-webui"))
    host.add_argument("--apply", action="store_true")
    pilot = sub.add_parser("pilot", help="Opt in to a pinned, independently qualified Windows test supervisor")
    pilot.add_argument("action", choices=("install", "status", "remove"))
    pilot.add_argument("--archive", type=Path)
    clients = sub.add_parser("client")
    group = clients.add_subparsers(dest="client_cmd", required=True)
    add = group.add_parser("add")
    add.add_argument("name")
    add.add_argument("--policy", required=True, choices=sorted(POLICIES))
    importing = group.add_parser("import-dpapi")
    importing.add_argument("name")
    importing.add_argument("--from-file", type=Path, required=True)
    importing.add_argument("--policy", choices=sorted(POLICIES), required=True)
    client_list = group.add_parser("list")
    client_list.add_argument("--format", choices=("text", "json", "tsv"), default="text")
    policy_edit = group.add_parser("set-policy")
    policy_edit.add_argument("name")
    policy_edit.add_argument("--policy", required=True, choices=sorted(POLICIES))
    group.add_parser("render")
    group.add_parser("reveal").add_argument("name")
    group.add_parser("copy").add_argument("name")
    rename = group.add_parser("rename")
    rename.add_argument("old")
    rename.add_argument("new")
    group.add_parser("remove").add_argument("name")
    args = parser.parse_args(argv)
    folder = args.directory.expanduser().resolve()
    if args.cmd == "init":
        init(folder)
    elif args.cmd == "install":
        install_process_compose(folder, args.archive)
    elif args.cmd == "pilot":
        if args.action == "install":
            if args.archive is None:
                raise ConfigError("Pilot installation requires --archive with the downloaded, reviewed ZIP.")
            install_windows_reviewed_pilot(folder, args.archive)
        elif args.action == "status":
            if os.name != "nt":
                print("Reviewed native-host pilot is Windows-only.")
            else:
                state = windows_reviewed_pilot_active(folder)
                print("Reviewed Windows pilot:", "enabled" if state else "not enabled")
                print("General Process Compose production hold remains active.")
        elif args.action == "remove":
            remove_windows_reviewed_pilot(folder)
    elif args.cmd == "host":
        native_host_setup(folder, args.action, args.service, apply=args.apply)
    elif args.cmd == "logs-file":
        saved_service_logs(folder, args.name, args.lines)
    elif args.cmd == "where":
        doc = read_settings(folder)
        print("Configuration:", settings_path(folder))
        print("Process Compose YAML:", project_path(folder, doc))
        print("Client registry:", folder / "clients.json")
    elif args.cmd == "client":
        if args.client_cmd == "add":
            client_add(folder, args.name, args.policy)
        elif args.client_cmd == "import-dpapi":
            client_import_dpapi(folder, args.name, args.policy, args.from_file)
        elif args.client_cmd == "list":
            doc = read_settings(folder)
            rows = [{"id": name, "policy": cfg["policy"],
                     "origin": cfg.get("origin", "unknown")}
                    for name, cfg in doc["clients"].items()]
            if args.format == "json":
                print(json.dumps({"clients": rows}, ensure_ascii=False))
            elif args.format == "tsv":
                for row in rows:
                    print(row["id"] + "\t" + row["origin"])
            else:
                print("Registered client identities (effective after Dispatcher restart):")
                for row in rows:
                    origin = {"imported": "imported shared key (do not redistribute)",
                              "generated": "individually generated key",
                              "unknown": "key origin not recorded (may be active)"}[row["origin"]]
                    print(" -", row["id"], "| policy:", row["policy"], "|", origin)
                print("Unknown origin does not mean an unused or expired key.")
                print("Use Dispatcher request metrics to establish actual client usage.")
        elif args.client_cmd == "copy":
            client_copy(folder, args.name)
        elif args.client_cmd == "rename":
            client_rename(folder, args.old, args.new)
        elif args.client_cmd == "set-policy":
            client_set_policy(folder, args.name, args.policy)
        elif args.client_cmd == "render":
            client_render(folder, folder / "clients.json")
        elif args.client_cmd == "reveal":
            if args.name not in read_settings(folder)["clients"]:
                raise ConfigError("Unknown client.")
            print("Sensitive credential: store directly in the intended client's secure provider settings.")
            print(read_secret(folder, args.name))
        elif args.client_cmd == "remove":
            client_remove(folder, args.name)
    else:
        native(folder, args.cmd, getattr(args, "name", None))


if __name__ == "__main__":
    try:
        run()
    except (ConfigError, ValueError, OSError, yaml.YAMLError) as exc:
        # Do not include private source/config contents from parser or subprocess.
        print("[XX] Services configuration/action failed: " +
              (str(exc) if isinstance(exc, ConfigError) else "invalid or unreadable configuration"),
              file=sys.stderr)
        sys.exit(1)
