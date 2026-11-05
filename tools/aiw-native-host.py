#!/usr/bin/env python3
"""Render a private Windows-native inference/gateway project for Process Compose.

No production process is started by this tool. The existing AIW process-compose
runtime remains the only process owner. All host paths and credentials stay local.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
from urllib.parse import urlsplit, urlunsplit

import yaml

REQUIRED_NAMES = ("strata", "dispatcher", "caddy")
NAMES = REQUIRED_NAMES + ("open-webui",)
MARKER = "# AIW native-host project — generated from private host configuration"
ENV_NAME = __import__("re").compile(r"^[A-Za-z_][A-Za-z_0-9]*$")
SECRET_NAME = __import__("re").compile(r"(?:SECRET|TOKEN|KEY|PASS|AUTH|CREDENTIAL)", __import__("re").I)
DEFAULT_PORTS = {"strata": [8080], "dispatcher": [8001], "caddy": [443],
                 "open-webui": [3000]}
# Startup checks are *not* liveness checks. A cold Strata model load can take
# minutes, while a gateway that fails to bind should be reported sooner.
# These conservative defaults apply to already-existing private JSON files.
DEFAULT_STARTUP_GRACE_SECONDS = {
    "strata": 300, "dispatcher": 120, "caddy": 90, "open-webui": 180,
}
READINESS_PERIOD_SECONDS = 5
READINESS_FIRST_CHECK_SECONDS = 5


class ConfigurationError(Exception):
    pass


def template() -> dict:
    return {
        "schema_version": 1,
        "services": {
            name: {
                "enabled": False,
                "executable": "",
                "working_directory": "",
                "arguments": [],
                "required_paths": [],
                "listen_ports": DEFAULT_PORTS[name],
                "environment": {},
                "secret_environment": {},
                "readiness": {
                    "url": "",
                    "expected_status": 200 if name != "caddy" else 401,
                    "bearer_dpapi": "",
                },
            }
            for name in NAMES
        },
    }


def native_config_path(folder: Path) -> Path:
    return folder / "native-host.json"


def validate(config: dict, *, verify_paths: bool = True) -> None:
    if not isinstance(config, dict) or set(config) != {"schema_version", "services"}:
        raise ConfigurationError("Expected schema_version and services.")
    if type(config["schema_version"]) is not int or config["schema_version"] != 1:
        raise ConfigurationError("Unsupported native host configuration version.")
    services = config["services"]
    if not isinstance(services, dict) or not set(REQUIRED_NAMES) <= set(services) or not set(services) <= set(NAMES):
        raise ConfigurationError("Strata, Dispatcher and Caddy required; Open WebUI optional.")
    # A dependent enabled process cannot wait for a disabled prerequisite.
    for child, parent in (("dispatcher", "strata"), ("caddy", "dispatcher"),
                          ("open-webui", "caddy")):
        if child in services and services[child].get("enabled") and not services[parent].get("enabled"):
            raise ConfigurationError(child + ": enable prerequisite " + parent + " first.")
    registered_ports = set()
    for name in services:
        service = services[name]
        if not isinstance(service, dict) or not {
            "enabled", "executable", "working_directory", "arguments", "listen_ports",
            "environment", "secret_environment", "readiness"
        } <= set(service) or not set(service) <= {
            "enabled", "executable", "working_directory", "arguments", "required_paths",
            "listen_ports", "environment", "secret_environment", "readiness"
        }:
            raise ConfigurationError(name + ": invalid service fields.")
        if type(service["enabled"]) is not bool:
            raise ConfigurationError(name + ": enabled must be a boolean.")
        executable, directory = service["executable"], service["working_directory"]
        if not isinstance(executable, str) or not isinstance(directory, str):
            raise ConfigurationError(name + ": executable and working_directory must be strings.")
        if not executable or not directory:
            raise ConfigurationError(name + ": configure program and working directory before rendering.")
        # Path.is_absolute() on Linux cannot validate Windows paths. Windows is the
        # supported target for this adapter; CI tests can use Windows-relative synthetics.
        if os.name == "nt":
            if not Path(executable).is_absolute() or not Path(directory).is_absolute():
                raise ConfigurationError(name + ": use absolute Windows executable and working directory.")
            if verify_paths and (not Path(executable).is_file() or not Path(directory).is_dir()):
                raise ConfigurationError(name + ": executable or working directory not found.")
        args = service["arguments"]
        if not isinstance(args, list) or not all(isinstance(x, str) for x in args):
            raise ConfigurationError(name + ": arguments must be an array of strings.")
        required = service.get("required_paths", [])
        if not isinstance(required, list) or not all(isinstance(x, str) and x for x in required):
            raise ConfigurationError(name + ": required_paths must be an array of paths.")
        if os.name == "nt":
            for path in required:
                target = Path(path)
                if not target.is_absolute() or (verify_paths and not target.exists()):
                    raise ConfigurationError(name + ": missing or relative required path.")
                if verify_paths and target.is_file() and target.suffix.lower() == ".json":
                    try:
                        control = json.loads(target.read_text(encoding="utf-8-sig"))
                    except (OSError, ValueError):
                        raise ConfigurationError(name + ": required JSON control file is invalid.") from None
                    if name == "strata" and not (
                            isinstance(control, dict) and {"exe", "args"} <= set(control)
                    ):
                        raise ConfigurationError(name + ": Strata JSON is missing exe/args.")
        ports = service["listen_ports"]
        if not isinstance(ports, list) or not ports:
            raise ConfigurationError(name + ": declare listening ports for collision checks.")
        for port in ports:
            if type(port) is not int or not 1 <= port <= 65535 or port in registered_ports:
                raise ConfigurationError(name + ": invalid or duplicate listening port.")
            registered_ports.add(port)
        environment, secret_environment = service["environment"], service["secret_environment"]
        if not isinstance(environment, dict) or not isinstance(secret_environment, dict):
            raise ConfigurationError(name + ": environment mappings must be objects.")
        if set(environment) & set(secret_environment):
            raise ConfigurationError(name + ": same environment variable is both plain and protected.")
        for key, value in environment.items():
            if not isinstance(key, str) or not ENV_NAME.fullmatch(key) or SECRET_NAME.search(key):
                raise ConfigurationError(name + ": credential-like names must use secret_environment.")
            if not isinstance(value, str):
                raise ConfigurationError(name + ": environment values must be strings.")
        if name == "open-webui" and service["enabled"] and os.name == "nt" and verify_paths:
            data_root = environment.get("DATA_DIR")
            if not data_root or not Path(data_root).is_absolute() or not Path(data_root).is_dir():
                raise ConfigurationError("open-webui: original DATA_DIR missing; refusing fresh database.")
        for key, value in secret_environment.items():
            if not isinstance(key, str) or not ENV_NAME.fullmatch(key):
                raise ConfigurationError(name + ": invalid secret environment variable name.")
            if not isinstance(value, str) or not value.lower().endswith(".dpapi"):
                raise ConfigurationError(name + ": use a Windows DPAPI encrypted file reference.")
            if os.name == "nt" and (not Path(value).is_absolute()
                                    or verify_paths and not Path(value).is_file()):
                raise ConfigurationError(name + ": missing or nonabsolute DPAPI reference.")
        readiness = service["readiness"]
        if not isinstance(readiness, dict) or not {
            "url", "expected_status", "bearer_dpapi"
        } <= set(readiness) or not set(readiness) <= {
            "url", "expected_status", "bearer_dpapi", "startup_grace_seconds", "probe_mode"
        }:
            raise ConfigurationError(name + ": invalid readiness settings.")
        startup_grace = readiness.get(
            "startup_grace_seconds", DEFAULT_STARTUP_GRACE_SECONDS[name])
        if (type(startup_grace) is not int or not 30 <= startup_grace <= 1800):
            raise ConfigurationError(name + ": startup_grace_seconds must be an integer 30..1800.")
        url = readiness["url"]
        if not isinstance(url, str):
            raise ConfigurationError(name + ": readiness URL must be a string.")
        parsed = urlsplit(url)
        if (not url or parsed.scheme not in ("http", "https") or not parsed.hostname
                or parsed.username or parsed.password or parsed.fragment or parsed.query):
            raise ConfigurationError(name + ": readiness requires an HTTP(S) URL without credentials.")
        if type(readiness["expected_status"]) is not int or not 100 <= readiness["expected_status"] <= 599:
            raise ConfigurationError(name + ": invalid readiness status.")
        probe_mode = readiness.get("probe_mode", "http")
        if probe_mode not in ("http", "tls"):
            raise ConfigurationError(name + ": unsupported readiness probe_mode.")
        if probe_mode == "tls" and (name != "caddy" or parsed.scheme != "https"
                                    or readiness["bearer_dpapi"]):
            raise ConfigurationError(
                name + ": TLS-only health requires HTTPS Caddy without a readiness bearer."
            )
        bearer = readiness["bearer_dpapi"]
        if not isinstance(bearer, str) or bearer and not bearer.lower().endswith(".dpapi"):
            raise ConfigurationError(name + ": readiness bearer must reference a DPAPI file.")
        if bearer and parsed.hostname not in ("127.0.0.1", "::1", "localhost"):
            raise ConfigurationError(name + ": bearer readiness probe must use a local loopback URL.")
        if bearer and os.name == "nt" and (not Path(bearer).is_absolute()
                                           or verify_paths and not Path(bearer).is_file()):
            raise ConfigurationError(name + ": missing readiness DPAPI file.")


def load(folder: Path, *, verify_paths: bool = True) -> dict:
    file = native_config_path(folder)
    if file.is_symlink() or not file.is_file():
        raise ConfigurationError("Missing or linked private native-host.json. Run native-host init.")
    try:
        config = json.loads(file.read_text(encoding="utf-8"))
    except (ValueError, OSError):
        raise ConfigurationError("Unreadable private native-host.json.") from None
    validate(config, verify_paths=verify_paths)
    return config


def inspect(folder: Path) -> None:
    """Friendly read-only onboarding summary; never reveal secret contents."""
    file = native_config_path(folder)
    print("Windows native AI service configuration")
    print("Settings:", file)
    if not file.is_file() or file.is_symlink():
        print("[SETUP NEEDED] No private native-host.json exists.")
        print("Choose First-time preparation, then Edit service startup settings.")
        return
    try:
        config = json.loads(file.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        raise ConfigurationError("The private native-host.json is not valid JSON.") from None
    if not isinstance(config, dict) or config.get("schema_version") != 1:
        raise ConfigurationError("Unsupported native host configuration version.")
    services = config.get("services")
    if not isinstance(services, dict):
        raise ConfigurationError("Missing native host services mapping.")
    for name in NAMES:
        if name not in services:
            if name in REQUIRED_NAMES:
                print("[INCOMPLETE]", name, "- missing service definition")
            else:
                print("[OPTIONAL]", name, "- not configured")
            continue
        service = services[name]
        if not isinstance(service, dict):
            print("[INVALID]", name, "- expected a service object")
            continue
        enabled = service.get("enabled")
        executable = service.get("executable")
        directory = service.get("working_directory")
        ready = service.get("readiness")
        url = ready.get("url") if isinstance(ready, dict) else None
        complete = bool(executable and directory and url)
        if os.name == "nt" and complete:
            complete = Path(executable).is_file() and Path(directory).is_dir()
        status = "configured" if complete else "needs program/path/health settings"
        mode = "start enabled" if enabled is True else "not selected for startup"
        ports = service.get("listen_ports")
        ports_label = ", ".join(str(x) for x in ports) if isinstance(ports, list) else "not set"
        grace = (ready.get("startup_grace_seconds",
                 DEFAULT_STARTUP_GRACE_SECONDS[name])
                 if isinstance(ready, dict) else DEFAULT_STARTUP_GRACE_SECONDS[name])
        print(name + ":", mode, "|", status, "| TCP", ports_label,
              "| startup grace", str(grace) + "s")
    print("This summary has not started or stopped any application.")
    print("When ready, use Check edited settings, then Apply settings for next startup.")


def validate_only(folder: Path) -> None:
    config = load(folder)
    print("[OK] Private Windows service startup settings are structurally valid.")
    for name, service in config["services"].items():
        print(" -", name, "|", "enabled" if service["enabled"] else "disabled",
              "| TCP", ", ".join(str(p) for p in service["listen_ports"]))
    print("No processes started or stopped; no network requests sent.")
    print("Next: apply edited settings for the next startup, then inspect port collisions.")


def encoded_command(script: Path, config_path: Path, name: str) -> str:
    # Windows PowerShell -EncodedCommand uses UTF-16LE. Only paths and a fixed
    # service name are encoded; credentials never enter command lines or YAML.
    def psquote(value: str) -> str:
        return "'" + value.replace("'", "''") + "'"
    body = ("& " + psquote(str(script)) + " -Config " +
            psquote(str(config_path)) + " -Service " + psquote(name) +
            "; if (-not $?) { exit 1 }")
    payload = base64.b64encode(body.encode("utf-16le")).decode("ascii")
    return "pwsh -NoProfile -NonInteractive -EncodedCommand " + payload


def render(folder: Path, *, verify_paths: bool = True) -> Path:
    config = load(folder, verify_paths=verify_paths)
    script_dir = Path(__file__).resolve().parent
    launcher = script_dir / "aiw-native-child.ps1"
    prober = script_dir / "aiw-native-health.ps1"
    if not launcher.is_file() or not prober.is_file():
        raise ConfigurationError("Native service PowerShell adapters are missing.")
    project = folder / "process-compose.yaml"
    if project.is_symlink():
        raise ConfigurationError("Refusing a symlinked Process Compose file.")
    if project.exists():
        existing = project.read_text(encoding="utf-8")
        is_fixture = "command: 'echo aiw-process-compose-smoke'" in existing and "aiw-smoke:" in existing
        if not (existing.startswith(MARKER) or is_fixture):
            raise ConfigurationError("Existing custom Process Compose project: refusing overwrite.")
    if (folder / "runtime" / "process-compose-windows.json").exists():
        raise ConfigurationError("A Windows supervisor ownership record exists. Stop it before rendering.")
    log_dir = folder / "runtime" / "logs"
    if log_dir.is_symlink():
        raise ConfigurationError("Refusing symlinked private process log directory.")
    log_dir.mkdir(parents=True, exist_ok=True)
    if log_dir.is_symlink():
        raise ConfigurationError("Refusing linked process log directory.")
    processes = {}
    for name in config["services"]:
        service = config["services"][name]
        startup_grace = service["readiness"].get(
            "startup_grace_seconds", DEFAULT_STARTUP_GRACE_SECONDS[name])
        failure_threshold = max(
            1, (startup_grace - READINESS_FIRST_CHECK_SECONDS +
                READINESS_PERIOD_SECONDS - 1) // READINESS_PERIOD_SECONDS
        )
        p = {
            "command": encoded_command(launcher, native_config_path(folder), name),
            "disabled": not service["enabled"],
            "readiness_probe": {
                "exec": {"command": encoded_command(prober, native_config_path(folder), name)},
                "initial_delay_seconds": READINESS_FIRST_CHECK_SECONDS,
                "period_seconds": READINESS_PERIOD_SECONDS,
                "timeout_seconds": 6,
                "failure_threshold": failure_threshold,
            },
            "availability": {"restart": "no"},
            "log_location": str(log_dir / (name + ".log")),
            "log_configuration": {
                "rotation": {
                    "max_size_mb": 10, "max_age_days": 14,
                    "max_backups": 5, "compress": True,
                },
            },
        }
        if name == "dispatcher":
            p["depends_on"] = {"strata": {"condition": "process_healthy"}}
        elif name == "caddy":
            p["depends_on"] = {"dispatcher": {"condition": "process_healthy"}}
        elif name == "open-webui":
            p["depends_on"] = {"caddy": {"condition": "process_healthy"}}
        processes[name] = p
    source_digest = hashlib.sha256(native_config_path(folder).read_bytes()).hexdigest()
    body = MARKER + "\n# aiw-config-sha256: " + source_digest + "\n" + yaml.safe_dump(
        {"version": "0.5", "processes": processes}, sort_keys=False
    )
    # Same-directory temp + atomic replacement, never clobber a custom project.
    import tempfile
    from os import replace
    folder.mkdir(parents=True, exist_ok=True)
    fd, temp = tempfile.mkstemp(prefix=".aiw-native-", dir=folder)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            stream.write(body)
        replace(temp, project)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)
    print("[OK] Rendered private Process Compose:", project)
    for name, spec in processes.items():
        window = spec["readiness_probe"]
        print(" -", name, "startup grace ~",
              window["initial_delay_seconds"] +
              window["period_seconds"] * window["failure_threshold"], "seconds")
    print("Persistent service logs:", log_dir)
    print("No processes started; the next check is a Process Compose dry-run.")
    return project


def quiet_probes(folder: Path, *, apply: bool = False) -> None:
    """Explicit private configuration migration to log-free readiness.

    Uses /health for Strata and Dispatcher, an HTTPS TLS handshake for Caddy.
    The handshake validates Caddy's certificate but does not make HTTP calls.
    """
    config = load(folder)
    proposed = []
    for name, old_path, new_path, status in (
        ("strata", "/v1/models", "/health", 200),
        ("dispatcher", "/v1/models", "/health", 200),
        ("caddy", "/v1/models", "/v1/models", 401),
    ):
        probe = config["services"][name]["readiness"]
        uri = urlsplit(probe["url"])
        if probe["expected_status"] != status:
            raise ConfigurationError(name + ": unexpected readiness HTTP status; refusing automatic edit.")
        if name == "caddy":
            if uri.scheme != "https" or probe["bearer_dpapi"]:
                raise ConfigurationError("Caddy TLS probe requires existing HTTPS URL without token.")
            if probe.get("probe_mode", "http") == "tls":
                continue
            if probe.get("probe_mode", "http") != "http":
                raise ConfigurationError("Unknown Caddy readiness mode.")
            proposed.append((name, "HTTP GET /v1/models", "certificate-validated TLS handshake"))
            probe["probe_mode"] = "tls"
            continue
        if uri.hostname not in ("localhost", "127.0.0.1", "::1"):
            raise ConfigurationError(name + ": quiet health URL must use local loopback.")
        if uri.path == new_path:
            if name == "dispatcher" and probe["bearer_dpapi"]:
                raise ConfigurationError("Dispatcher /health must not carry a bearer token.")
            continue
        if uri.path != old_path:
            raise ConfigurationError(name + ": custom readiness URL; refusing automatic edit.")
        proposed.append((name, old_path, new_path))
        probe["url"] = urlunsplit(uri._replace(path=new_path))
        if name == "dispatcher":
            probe["bearer_dpapi"] = ""
    if not proposed:
        print("[OK] Native readiness is already configured without routine model-list requests.")
        return
    for name, old, new in proposed:
        print("[REVIEW]", name, old, "->", new)
    print("Original client credentials and native program commands are unchanged.")
    if not apply:
        print("Preview only; once stopped run: aiw host quiet-probes --apply")
        return
    owned = folder / "runtime" / "process-compose-windows.json"
    if owned.exists() or owned.is_symlink():
        raise ConfigurationError("Supervisor ownership record still exists; stop AIW before changing its JSON.")
    path = native_config_path(folder)
    backup = folder / "native-host.before-quiet-probes.json"
    if backup.exists() or backup.is_symlink():
        raise ConfigurationError("Quiet-probes backup already exists; refusing overwrite.")
    validate(config)
    original = path.read_bytes()
    # The original private file stays byte-for-byte available for rollback.
    with backup.open("xb") as out:
        out.write(original)
    import tempfile
    fd, temp = tempfile.mkstemp(prefix=".aiw-quiet-probes-", dir=folder)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as out:
            json.dump(config, out, indent=2, ensure_ascii=False)
            out.write("\n")
        os.replace(temp, path)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)
    print("[OK] Quiet probe config staged, local original backed up:", backup)
    print("No process started. Next: aiw host render ; aiw check")


def preflight(folder: Path, process: str | None = None, *, verify_paths: bool = True) -> None:
    config = load(folder, verify_paths=verify_paths)
    project = folder / "process-compose.yaml"
    if project.exists():
        if project.is_symlink():
            raise ConfigurationError("Linked Process Compose project: refusing startup.")
        source_digest = hashlib.sha256(native_config_path(folder).read_bytes()).hexdigest()
        contents = project.read_text(encoding="utf-8")
        if (not contents.startswith(MARKER + "\n") or
                "\n# aiw-config-sha256: " + source_digest + "\n" not in contents[:200]):
            raise ConfigurationError("Private host configuration differs from rendered project; render again while stopped.")
    names = [process] if process else list(config["services"])
    for name in names:
        if name not in config["services"]:
            raise ConfigurationError("Unknown native service.")
        if not config["services"][name]["enabled"]:
            continue
        for port in config["services"][name]["listen_ports"]:
            if os.name == "nt":
                # Also catches IPv6-only and non-loopback Windows listeners.
                # Fail closed if port ownership cannot be checked.
                ps_command = (
                    "$ErrorActionPreference='Stop'; "
                    "if (@(Get-NetTCPConnection -State Listen -LocalPort " +
                    str(port) + " -ErrorAction SilentlyContinue).Count -gt 0) "
                    "{ exit 42 }; exit 0"
                )
                try:
                    probe = subprocess.run(
                        ["pwsh", "-NoProfile", "-NonInteractive", "-Command", ps_command],
                        check=False, stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL, timeout=8,
                    )
                except (OSError, subprocess.TimeoutExpired):
                    raise ConfigurationError("Cannot verify Windows TCP port ownership.") from None
                if probe.returncode == 42:
                    raise ConfigurationError(
                        name + ": port " + str(port) +
                        " is already listening. Refusing duplicate service startup."
                    )
                if probe.returncode:
                    raise ConfigurationError("Windows TCP port preflight unavailable.")
            else:
                with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                    s.settimeout(0.3)
                    if s.connect_ex(("127.0.0.1", port)) == 0:
                        raise ConfigurationError(
                            name + ": port " + str(port) +
                            " is already listening. Refusing duplicate service startup."
                        )
    print("[OK] Config paths and declared loopback ports validated; no service started.")
    print("Note: final Windows port/PID ownership and endpoint readiness require real-host verification.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Prepare native Windows inference host.")
    parser.add_argument("action", choices=("init", "inspect", "validate", "render", "preflight", "quiet-probes"))
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--service", choices=NAMES)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    folder = args.directory.expanduser().resolve()
    config_path = native_config_path(folder)
    if args.action == "init":
        if config_path.exists() or config_path.is_symlink():
            raise ConfigurationError("Native-host config already exists; refusing overwrite.")
        if not (folder / "services.yaml").is_file():
            raise ConfigurationError("Run AIW native services Initialize first.")
        folder.mkdir(parents=True, exist_ok=True)
        with config_path.open("x", encoding="utf-8") as file:
            file.write(json.dumps(template(), indent=2) + "\n")
        print("[OK] Private native host template:", config_path)
        print("Set paths, argv, DPAPI references, health URLs and explicit enabled flags.")
        print("Nothing was installed, started or stopped.")
    elif args.action == "inspect":
        inspect(folder)
    elif args.action == "validate":
        validate_only(folder)
    elif args.action == "render":
        if os.name != "nt":
            raise ConfigurationError("Native Windows host adapter only; use Windows PowerShell.")
        render(folder)
    elif args.action == "quiet-probes":
        if os.name != "nt":
            raise ConfigurationError("Native Windows quiet health only.")
        quiet_probes(folder, apply=args.apply)
    else:
        preflight(folder, args.service)


if __name__ == "__main__":
    try:
        main()
    except ConfigurationError as exc:
        print("[XX] Native host setup: " + str(exc), file=sys.stderr)
        sys.exit(1)
