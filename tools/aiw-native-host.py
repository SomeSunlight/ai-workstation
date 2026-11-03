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
from urllib.parse import urlsplit

import yaml

REQUIRED_NAMES = ("strata", "dispatcher", "caddy")
NAMES = REQUIRED_NAMES + ("open-webui",)
MARKER = "# AIW native-host project — generated from private host configuration"
ENV_NAME = __import__("re").compile(r"^[A-Za-z_][A-Za-z_0-9]*$")
SECRET_NAME = __import__("re").compile(r"(?:SECRET|TOKEN|KEY|PASS|AUTH|CREDENTIAL)", __import__("re").I)
DEFAULT_PORTS = {"strata": [8080], "dispatcher": [8001], "caddy": [443],
                 "open-webui": [3000]}


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
                if not Path(path).is_absolute() or (verify_paths and not Path(path).exists()):
                    raise ConfigurationError(name + ": missing or relative required path.")
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
        for key, value in secret_environment.items():
            if not isinstance(key, str) or not ENV_NAME.fullmatch(key):
                raise ConfigurationError(name + ": invalid secret environment variable name.")
            if not isinstance(value, str) or not value.lower().endswith(".dpapi"):
                raise ConfigurationError(name + ": use a Windows DPAPI encrypted file reference.")
            if os.name == "nt" and (not Path(value).is_absolute()
                                    or verify_paths and not Path(value).is_file()):
                raise ConfigurationError(name + ": missing or nonabsolute DPAPI reference.")
        readiness = service["readiness"]
        if not isinstance(readiness, dict) or set(readiness) != {
            "url", "expected_status", "bearer_dpapi"
        }:
            raise ConfigurationError(name + ": missing readiness settings.")
        url = readiness["url"]
        if not isinstance(url, str):
            raise ConfigurationError(name + ": readiness URL must be a string.")
        parsed = urlsplit(url)
        if (not url or parsed.scheme not in ("http", "https") or not parsed.hostname
                or parsed.username or parsed.password or parsed.fragment or parsed.query):
            raise ConfigurationError(name + ": readiness requires an HTTP(S) URL without credentials.")
        if type(readiness["expected_status"]) is not int or not 100 <= readiness["expected_status"] <= 599:
            raise ConfigurationError(name + ": invalid readiness status.")
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
    processes = {}
    for name in config["services"]:
        service = config["services"][name]
        p = {
            "command": encoded_command(launcher, native_config_path(folder), name),
            "disabled": not service["enabled"],
            "readiness_probe": {
                "exec": {"command": encoded_command(prober, native_config_path(folder), name)},
                "initial_delay_seconds": 2, "period_seconds": 5,
                "timeout_seconds": 6, "failure_threshold": 3,
            },
            "availability": {"restart": "no"},
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
    print("No processes started. Next: AIW Validate, then supervised start only after security approval.")
    return project


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
    parser.add_argument("action", choices=("init", "render", "preflight"))
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--service", choices=NAMES)
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
    elif args.action == "render":
        if os.name != "nt":
            raise ConfigurationError("Native Windows host adapter only; use Windows PowerShell.")
        render(folder)
    else:
        preflight(folder, args.service)


if __name__ == "__main__":
    try:
        main()
    except ConfigurationError as exc:
        print("[XX] Native host setup: " + str(exc), file=sys.stderr)
        sys.exit(1)
