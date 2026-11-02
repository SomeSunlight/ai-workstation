#!/usr/bin/env python3
"""AI Workstation's small native Process Compose and Dispatcher-client entrypoint.

The operator edits one host-local services.yaml. Process definitions stay in
Process Compose's native YAML; Docker Compose projects remain Docker-owned.
No service is started during init, validation, or client onboarding.
"""
from __future__ import annotations

import argparse
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

def native_binary(folder: Path) -> str:
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


def check_production_security_gate(project: Path, action: str, process: str | None) -> None:
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


def native(folder: Path, action: str, process: str | None) -> None:
    doc = read_settings(folder)
    project = project_path(folder, doc)
    if not project.is_file():
        raise ConfigError("Missing native Process Compose YAML.")
    check_production_security_gate(project, action, process)
    binary = native_binary(folder)
    port = str(doc["process_compose"]["port"])
    api_token = folder / "secrets" / "process-compose.api-token"
    if not api_token.is_file() or api_token.is_symlink():
        raise ConfigError("Missing Process Compose localhost management token; rerun init in clean directory.")
    if os.name != "nt" and (api_token.stat().st_mode & (stat.S_IRWXG | stat.S_IRWXO)):
        raise ConfigError("Process Compose management token permissions are too permissive.")
    basic = [binary, "--address", "127.0.0.1", "--port", port,
             "--token-file", str(api_token)]
    if action in ("check", "up", "tui"):
        cmd = basic + ["--disable-dotenv", "--config", str(project), "up"]
        if action == "check":
            cmd.append("--dry-run")
        if action == "up":
            cmd.append("--detached")
    else:
        cmd = basic + ({"status": ["process", "list"],
                        "logs": ["process", "logs", process] if process else ["process", "logs"],
                        "start": ["process", "start", process],
                        "stop": ["process", "stop", process],
                        "restart": ["process", "restart", process],
                        "down": ["down"]}[action])
    if action == "up":
        print("Starting a Process Compose project is an operator action.")
        print("Project:", project, "| loopback management port:", port)
        print("This does NOT take over already running Speedy services.")
    # Suppress benign debug discovery of a missing *global* config:
    # the real project was already explicitly supplied with --config.
    env = os.environ.copy()
    if action == "check":
        env.setdefault("PC_LOG_LEVEL", "warn")
    result = subprocess.run(cmd, check=False, env=env)
    if result.returncode:
        raise ConfigError("Native Process Compose command failed (exit " +
                          str(result.returncode) + ").")
    if action == "check":
        print("[OK] Explicit private Process Compose project validation succeeded.")
        print("No native service was started.")


def run(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="Native host services and S02 client identities")
    parser.add_argument("--directory", type=Path, default=default_dir())
    sub = parser.add_subparsers(dest="cmd", required=True)
    for k in ("init", "where", "install", "check", "up", "tui", "status", "down", "logs"):
        p = sub.add_parser(k)
        if k == "logs":
            p.add_argument("name", nargs="?")
        if k == "install":
            p.add_argument("--archive", type=Path, help="Official local archive; SHA-256 verified")
    for k in ("start", "stop", "restart"):
        sub.add_parser(k).add_argument("name")
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
    client_list.add_argument("--format", choices=("text", "json"), default="text")
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
                     "origin": cfg.get("origin", "generated")}
                    for name, cfg in doc["clients"].items()]
            if args.format == "json":
                print(json.dumps({"clients": rows}, ensure_ascii=False))
            else:
                print("Registered client identities:")
                for row in rows:
                    role = ("existing shared credential (migration only)"
                            if row["origin"] == "imported" else "individual client key")
                    print(" -", row["id"], "|", role)
                print("Only generated keys should be transferred to client applications.")
        elif args.client_cmd == "copy":
            client_copy(folder, args.name)
        elif args.client_cmd == "rename":
            client_rename(folder, args.old, args.new)
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
