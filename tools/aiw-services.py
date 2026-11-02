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
PROCESS_COMPOSE_VERSION = "v1.124.0"
# Official release archive SHA-256 digests (not version string checks).
ARCHIVES = {
    ("Windows", "AMD64"): ("process-compose_windows_amd64.zip",
                           "a77d51dcb34e3e8d2b88af372ada7ca8a62cb87f0c6af0f78834c0fd6c95e2a7"),
    ("Linux", "AMD64"): ("process-compose_linux_amd64.tar.gz",
                         "487ce011d5324b4578d3ec1860aaa1dd3a95bd4b2b433e03791f73a23d215fd3"),
    ("Linux", "ARM64"): ("process-compose_linux_arm64.tar.gz",
                         "98e02400a05d1da74a6506a4ffb2682b1205f18f02ecfbfdea1005f9389fc52d"),
}


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
        if not isinstance(cfg, dict) or set(cfg) != {"policy"} or cfg["policy"] not in POLICIES:
            raise ConfigError("Each client must have an explicit valid policy.")
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
    doc["clients"][name] = {"policy": policy}
    save_settings(folder, doc)
    print("Created identity:", name, "policy:", policy)
    print("Credential stored privately. Use 'client reveal' only for secure transfer.")
    print("Run 'client render' to regenerate the private S02 hash-only JSON.")


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
    print("Set DISPATCHER_CLIENT_CONFIG to this file; restart Dispatcher explicitly.")
    print("Caddy /v1 must forward Authorization without a single-token gate; retain")
    print("the existing protected /strata/v1 fallback. Do not change Caddy automatically.")


def install_process_compose(folder: Path) -> None:
    """Explicit opt-in native binary install, pinned release + checked artifact."""
    system = "Windows" if os.name == "nt" else "Linux"
    machine = platform.machine().upper().replace("X86_64", "AMD64").replace("AARCH64", "ARM64")
    selection = ARCHIVES.get((system, machine))
    if not selection:
        raise ConfigError("This OS/architecture has no pinned Process Compose artifact.")
    filename, digest = selection
    dest = folder / "bin" / ("process-compose.exe" if os.name == "nt" else "process-compose")
    if dest.exists():
        raise ConfigError("Native binary exists already; no automatic overwrite/upgrade.")
    url = ("https://github.com/F1bonacc1/process-compose/releases/download/" +
           PROCESS_COMPOSE_VERSION + "/" + filename)
    private_dir(folder / "bin")
    try:
        with urllib.request.urlopen(url, timeout=45) as response:
            archive = response.read(40 * 1024 * 1024 + 1)
    except OSError:
        raise ConfigError("Failed to fetch official Process Compose release.") from None
    if len(archive) > 40 * 1024 * 1024 or hashlib.sha256(archive).hexdigest() != digest:
        raise ConfigError("Official Process Compose archive digest mismatch; not installed.")
    binary = "process-compose.exe" if os.name == "nt" else "process-compose"
    if filename.endswith(".zip"):
        with zipfile.ZipFile(io.BytesIO(archive)) as file:
            names = [n for n in file.namelist() if Path(n).name == binary]
            if len(names) != 1:
                raise ConfigError("Missing or ambiguous executable in signed-hash archive.")
            contents = file.read(names[0])
    else:
        with tarfile.open(fileobj=io.BytesIO(archive), mode="r:gz") as file:
            members = [x for x in file.getmembers() if x.isfile() and Path(x.name).name == binary]
            if len(members) != 1:
                raise ConfigError("Missing or ambiguous executable in checked archive.")
            stream = file.extractfile(members[0])
            if stream is None:
                raise ConfigError("Unable to extract executable.")
            contents = stream.read()
    private_write(dest, contents, replace=False)
    if os.name != "nt":
        dest.chmod(0o700)
    print("Installed checksum-verified", PROCESS_COMPOSE_VERSION, "to", dest)
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


def native(folder: Path, action: str, process: str | None) -> None:
    doc = read_settings(folder)
    project = project_path(folder, doc)
    if not project.is_file():
        raise ConfigError("Missing native Process Compose YAML.")
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
    result = subprocess.run(cmd, check=False)
    if result.returncode:
        raise ConfigError("Native Process Compose command failed (exit " +
                          str(result.returncode) + ").")


def run(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="Native host services and S02 client identities")
    parser.add_argument("--directory", type=Path, default=default_dir())
    sub = parser.add_subparsers(dest="cmd", required=True)
    for k in ("init", "where", "install", "check", "up", "tui", "status", "down", "logs"):
        p = sub.add_parser(k)
        if k == "logs":
            p.add_argument("name", nargs="?")
    for k in ("start", "stop", "restart"):
        sub.add_parser(k).add_argument("name")
    clients = sub.add_parser("client")
    group = clients.add_subparsers(dest="client_cmd", required=True)
    add = group.add_parser("add")
    add.add_argument("name")
    add.add_argument("--policy", required=True, choices=sorted(POLICIES))
    group.add_parser("list")
    group.add_parser("render")
    group.add_parser("reveal").add_argument("name")
    group.add_parser("remove").add_argument("name")
    args = parser.parse_args(argv)
    folder = args.directory.expanduser().resolve()
    if args.cmd == "init":
        init(folder)
    elif args.cmd == "install":
        install_process_compose(folder)
    elif args.cmd == "where":
        doc = read_settings(folder)
        print("Configuration:", settings_path(folder))
        print("Process Compose YAML:", project_path(folder, doc))
        print("Client registry:", folder / "clients.json")
    elif args.cmd == "client":
        if args.client_cmd == "add":
            client_add(folder, args.name, args.policy)
        elif args.client_cmd == "list":
            doc = read_settings(folder)
            for name, cfg in doc["clients"].items():
                print(name, cfg["policy"])
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
