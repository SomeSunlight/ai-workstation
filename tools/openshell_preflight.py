#!/usr/bin/env python3
"""OpenShell v0.1.8 passive Linux/WSL capability inventory (Issue #68).

No installation, service/container invocation, network connection, write, sudo
or privileged operation. The only syscalls issued are Landlock ABI VERSION
query and seccomp GET_ACTION_AVAIL(USER_NOTIF). Neither installs a policy.
All output is a small allowlist of normalized capability classifications.
A passing capability is NOT a qualified OpenShell sandbox.
"""
from __future__ import annotations

import argparse
import ctypes
import errno
import json
import os
from pathlib import Path
import platform
import re
import stat
import sys

SCHEMA_VERSION = "1.0"
UPSTREAM_VERSION = "v0.1.8"
STATUSES = {"PASS", "FAIL", "UNKNOWN", "POLICY-APPROVAL-NEEDED"}
# Linux syscall numbers for these architectures only. No fallback guessing.
SYSCALLS = {"x86_64": (444, 317), "aarch64": (444, 277)}
SECCOMP_GET_ACTION_AVAIL = 2
SECCOMP_RET_USER_NOTIF = 0x7FC00000
LANDLOCK_CREATE_RULESET_VERSION = 1

NEXT_TESTS = [
    "Obtain explicit enterprise/operator approval for any runtime installation, daemon, host configuration or active testing.",
    "Confirm WSL release and whether the approved container backend is Docker Desktop, in-WSL Docker Engine, or rootless Podman.",
    "In an expressly authorized disposable workload, run OpenShell's own Landlock/seccomp ADDFD, task-memory, SO_BINDTODEVICE and supervisor qualification.",
    "Adversarially test WSL automount/interop, private mounts, Docker socket isolation, network egress (IPv4/IPv6/UDP/DNS/raw), and Windows host/LAN reachability.",
    "Verify effective policy (L7 enforce versus audit; Landlock hard_requirement versus best_effort), provider placeholders and inference-endpoint data egress.",
    "Prove stop/start, restart, image update, delete/recreate, independent Git history, backups and WSL shutdown recovery.",
]


def _read_fixed(path: str) -> str | None:
    """Read only one of two fixed, nonsecret capability files; never return raw text."""
    if path not in ("/etc/os-release", "/proc/self/status"):
        raise ValueError("Non-allowlisted probe path")
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as stream:
            return stream.read(8192)
    except OSError:
        return None


def _syscall_query(number: int, *args: object) -> tuple[int | None, int | None]:
    """Safe, non-installing kernel feature query; never expose raw error messages."""
    try:
        libc = ctypes.CDLL(None, use_errno=True)
        libc.syscall.restype = ctypes.c_long
        ctypes.set_errno(0)
        result = libc.syscall(ctypes.c_long(number), *args)
        return (int(result), ctypes.get_errno() if result == -1 else 0)
    except (OSError, AttributeError, TypeError, ValueError):
        return (None, None)


def _landlock_abi(arch: str) -> int | str | None:
    if arch not in SYSCALLS:
        return None
    result, error = _syscall_query(
        SYSCALLS[arch][0], ctypes.c_void_p(0), ctypes.c_size_t(0),
        ctypes.c_uint(LANDLOCK_CREATE_RULESET_VERSION)
    )
    if result is not None and result >= 0:
        return result
    if error in (errno.ENOSYS, errno.EOPNOTSUPP, errno.EINVAL):
        return "unavailable"
    return None


def _seccomp_user_notification(arch: str) -> bool | None:
    if arch not in SYSCALLS:
        return None
    action = ctypes.c_uint32(SECCOMP_RET_USER_NOTIF)
    result, error = _syscall_query(
        SYSCALLS[arch][1], ctypes.c_uint(SECCOMP_GET_ACTION_AVAIL),
        ctypes.c_uint(0), ctypes.byref(action)
    )
    if result == 0:
        return True
    if error in (errno.ENOSYS, errno.EOPNOTSUPP, errno.EINVAL):
        return False
    return None


def _os_info() -> tuple[str, str]:
    """Strictly classify distro and numeric version; discard everything else."""
    body = _read_fixed("/etc/os-release") or ""
    values = {}
    for line in body.splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            if key in ("ID", "VERSION_ID"):
                values[key] = value.strip().strip('"').strip("'")
    name = values.get("ID", "")
    name = name if name in ("ubuntu", "debian") else "other-or-unavailable"
    version = values.get("VERSION_ID", "")
    version = version if re.fullmatch(r"[0-9]{1,2}(?:\.[0-9]{1,2})?", version) else "unavailable"
    return name, version


def _self_status() -> tuple[str, str]:
    """Read caller's process flags, NOT the future sandbox's enforcement state."""
    body = _read_fixed("/proc/self/status") or ""
    found = {}
    for key in ("Seccomp", "NoNewPrivs"):
        match = re.search(r"^" + key + r":\s*([0-2])\s*$", body, re.M)
        found[key] = match.group(1) if match else "?"
    return (found["Seccomp"], found["NoNewPrivs"])


def _socket_present(path: str) -> bool:
    try:
        return stat.S_ISSOCK(os.stat(path).st_mode)
    except OSError:
        return False


def _client_present(name: str) -> bool:
    """Only inspect fixed usual executable paths; do not consult PATH or run CLI."""
    return any(
        p.is_file() and os.access(p, os.X_OK)
        for p in (Path("/usr/bin") / name, Path("/usr/local/bin") / name)
    )


def collect_capabilities() -> dict:
    """The only live collection entry point. All probes are local and passive."""
    system = platform.system().lower()
    raw_arch = platform.machine().lower()
    arch = {"amd64": "x86_64", "arm64": "aarch64"}.get(raw_arch, raw_arch)
    if arch not in SYSCALLS:
        arch = "other-or-unavailable"
    # Kernel build suffixes may include identifying strings: never output them.
    release = platform.release().lower()
    version_match = re.match(r"^(\d{1,2})\.(\d{1,2})", release)
    kernel = tuple(map(int, version_match.groups())) if version_match else None
    wsl = "microsoft" in release or "wsl" in release
    distro, distro_version = _os_info()
    seccomp, nnp = _self_status()
    uid = os.getuid() if hasattr(os, "getuid") else None
    podman_sock = (f"/run/user/{uid}/podman/podman.sock"
                   if uid is not None else "")
    return {
        "system": "linux" if system == "linux" else "other",
        "arch": arch,
        "environment": "wsl-signature" if wsl else "native-or-other-linux",
        "kernel": kernel,
        "distro": distro,
        "distro_version": distro_version,
        "landlock_abi": _landlock_abi(arch) if system == "linux" else None,
        "user_notif": _seccomp_user_notification(arch) if system == "linux" else None,
        "self_seccomp": seccomp,
        "self_nnp": nnp,
        "cgroup2": Path("/sys/fs/cgroup/cgroup.controllers").is_file(),
        "namespace_handles": all(
            Path("/proc/self/ns", n).exists() for n in ("mnt", "net", "pid", "user")
        ),
        "docker_client": _client_present("docker"),
        "docker_socket": any(
            _socket_present(p) for p in ("/var/run/docker.sock", "/run/docker.sock")
        ),
        "podman_client": _client_present("podman"),
        "podman_socket": _socket_present(podman_sock) if podman_sock else False,
        "interop_hint": Path("/proc/sys/fs/binfmt_misc/WSLInterop").exists() if wsl else False,
    }


def example_capabilities() -> dict:
    """Entirely synthetic; no syscalls, file reads, env access or host inspection."""
    return {
        "system": "linux", "arch": "x86_64", "environment": "wsl-signature",
        "kernel": (6, 6), "distro": "ubuntu", "distro_version": "24.04",
        "landlock_abi": 5, "user_notif": True,
        "self_seccomp": "2", "self_nnp": "0",
        "cgroup2": True, "namespace_handles": True,
        "docker_client": True, "docker_socket": True,
        "podman_client": False, "podman_socket": False,
        "interop_hint": True,
    }


def evaluate(raw: dict, *, example: bool = False) -> dict:
    """Only hardcoded output strings and sanitized integers; never echo raw data."""
    checks = []

    def add(identifier: str, status: str, observation: str, limit: str) -> None:
        assert status in STATUSES
        checks.append({"id": identifier, "status": status,
                       "observation": observation, "limit": limit})

    system = raw.get("system")
    arch = raw.get("arch") if raw.get("arch") in SYSCALLS else "other-or-unavailable"
    environment = raw.get("environment")
    environment = environment if environment in ("wsl-signature", "native-or-other-linux") else "unknown"
    distro = raw.get("distro") if raw.get("distro") in ("ubuntu", "debian") else "other-or-unavailable"
    ver = raw.get("distro_version")
    ver = ver if isinstance(ver, str) and re.fullmatch(r"[0-9]{1,2}(?:\.[0-9]{1,2})?", ver) else "unavailable"
    k = raw.get("kernel")
    kernel = f"{k[0]}.{k[1]}" if (isinstance(k, (tuple, list)) and len(k) == 2
              and all(type(n) is int and 0 <= n <= 99 for n in k)) else "unavailable"

    add("linux_host", "PASS" if system == "linux" else "FAIL",
        "linux" if system == "linux" else "not-linux",
        "This is an OS classifier, not sandbox validation.")
    add("supported_architecture", "PASS" if arch in SYSCALLS else "UNKNOWN",
        arch, "Only x86_64 and aarch64 have query syscall numbers in this tool.")
    add("distribution", "PASS" if distro in ("ubuntu", "debian") else "UNKNOWN",
        distro + "-" + ver if distro != "other-or-unavailable" else "not-classified",
        "Official Linux platform list is Debian/Ubuntu; packaging and approval are not tested.")
    add("wsl_support_tier",
        "POLICY-APPROVAL-NEEDED" if environment == "wsl-signature" else "UNKNOWN",
        "wsl2-experimental-only-with-docker-desktop" if environment == "wsl-signature"
        else "not-identified-as-wsl",
        "WSL without Docker Desktop and the selected runtime are not upstream-qualified here.")
    add("kernel_version", "UNKNOWN", "major-minor-" + kernel,
        "Kernel version does not prove enabled LSM or runtime seccomp features.")

    abi = raw.get("landlock_abi")
    if type(abi) is int and 0 <= abi <= 99:
        add("landlock_abi", "PASS" if abi >= 3 else "FAIL", "abi-" + str(abi),
            "Read-only VERSION syscall on this process; sandbox must enforce mandatory baseline.")
    elif abi == "unavailable":
        add("landlock_abi", "FAIL", "kernel-query-reported-unavailable",
            "No qualifying ABI observed; policy/outer-filter interaction may need investigation.")
    else:
        add("landlock_abi", "UNKNOWN", "query-not-conclusive",
            "Query may be blocked, unsupported on architecture, or unavailable.")
    user_notif = raw.get("user_notif")
    add("seccomp_user_notif_action",
        "PASS" if user_notif is True else "FAIL" if user_notif is False else "UNKNOWN",
        "action-available" if user_notif is True else
        "action-not-available" if user_notif is False else "query-not-conclusive",
        "GET_ACTION_AVAIL only; nested USER_NOTIF, ADDFD_FLAG_SEND and attribution untested.")
    sec = raw.get("self_seccomp")
    sec = sec if sec in ("0", "1", "2") else "?"
    add("seccomp_runtime_enforcement", "UNKNOWN",
        {"0": "caller-unconfined", "1": "caller-strict", "2": "caller-filtered", "?": "caller-unknown"}[sec],
        "The invoking Python process is not an OpenShell sandbox.")
    nnp = raw.get("self_nnp")
    nnp = nnp if nnp in ("0", "1") else "?"
    add("no_new_privs_runtime", "UNKNOWN",
        {"0": "caller-flag-off", "1": "caller-flag-on", "?": "caller-unknown"}[nnp],
        "No claim about a future sandbox process or capabilities.")
    add("cgroups_v2", "PASS" if raw.get("cgroup2") is True else "UNKNOWN",
        "controllers-file-present" if raw.get("cgroup2") is True else "not-observed",
        "Presence does not establish controller delegation or Docker/Podman compatibility.")
    add("namespaces", "PASS" if raw.get("namespace_handles") is True else "UNKNOWN",
        "self-namespace-handles-present" if raw.get("namespace_handles") is True else "not-observed",
        "Namespace creation, mount isolation and guest exposure are not tested.")
    add("task_memory_access", "UNKNOWN", "not-probed",
        "Production parent-to-executed-child access requires an active OpenShell qualification.")
    add("socket_bind_to_device", "UNKNOWN", "not-probed",
        "SO_BINDTODEVICE without added capabilities requires active workload testing.")
    for name in ("docker", "podman"):
        add(name + "_client", "PASS" if raw.get(name + "_client") is True else "UNKNOWN",
            "fixed-path-executable-present" if raw.get(name + "_client") is True else "not-observed",
            "No CLI execution or version check; other installation paths may exist.")
        add(name + "_socket", "PASS" if raw.get(name + "_socket") is True else "UNKNOWN",
            "socket-in-standard-location" if raw.get(name + "_socket") is True else "not-observed",
            "Not opened; no daemon access, version, usability or approval established.")
    add("wsl_host_boundary",
        "POLICY-APPROVAL-NEEDED" if environment == "wsl-signature" else "UNKNOWN",
        "interop-hint-present" if (environment == "wsl-signature" and raw.get("interop_hint") is True)
        else "host-integration-not-established",
        "Does not inspect Windows mounts or run Windows executables; verify mounts, interop and networking in gate 2.")
    add("runtime_install_approval", "POLICY-APPROVAL-NEEDED", "not-checked",
        "Existing corporate permission to run WSL does not authorize installing a daemon or changing host configuration.")
    blocked = any(c["status"] == "FAIL" for c in checks)
    return {
        "schema_version": SCHEMA_VERSION,
        "tool": "openshell-preflight",
        "upstream_reference": UPSTREAM_VERSION,
        "mode": "example" if example else "passive",
        "synthetic": example,
        "host": {"platform": "linux" if system == "linux" else "other",
                 "architecture": arch, "environment": environment,
                 "distribution": distro, "distribution_version": ver,
                 "kernel_major_minor": kernel},
        "checks": checks,
        "passive_verdict": "BLOCKED" if blocked else "INCOMPLETE",
        "compatibility_certified": False,
        "next_tests": NEXT_TESTS[:],
    }


def format_human(report: dict) -> str:
    lines = [
        f"OpenShell {UPSTREAM_VERSION} read-only preflight [{report['mode']}]",
        f"Passive verdict: {report['passive_verdict']} (NOT an OpenShell compatibility certificate)",
        "All results describe this caller or a static kernel query, never enforced sandbox behavior.",
    ]
    lines.extend(f"  {c['id']}: {c['status']} ({c['observation']})"
                 for c in report["checks"])
    lines.append("Next tests (require separate explicit approval):")
    lines.extend(f"  - {item}" for item in report["next_tests"])
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="Emit sanitized versioned JSON to stdout")
    parser.add_argument("--example", action="store_true",
                        help="Use fixed synthetic data; do not touch host features")
    args = parser.parse_args(argv)
    result = evaluate(example_capabilities() if args.example else collect_capabilities(),
                      example=args.example)
    print(json.dumps(result, indent=2, sort_keys=True) if args.json else format_human(result))
    return 0  # Even BLOCKED is a reported result, not an execution failure.


if __name__ == "__main__":
    sys.exit(main())
