#!/usr/bin/env python3
"""Thin, opt-in OpenShell operator adapter. No AIW sandbox state or security layer."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import platform
import re
import subprocess
import sys
import tempfile
import unicodedata
from urllib.parse import urlsplit

OPENSHELL_VERSION = "0.1.8"  # First-flight tested version, not an auto-upgrade target.
GOOSE_IMAGE = "ghcr.io/aaif-goose/goose@sha256:18e801642a134d3d3975b563ab6185593b53fac270167b1acbfb4368baca1c96"
AGENT_LABEL = "aiw.agent=goose"
WORKSPACE_REGISTRY = Path.home() / ".config/ai-workstation/goose-workspaces"
RESTRICTED_POLICY = Path(__file__).resolve().parents[1] / "config/openshell/policies/restricted.yaml"
PROFILE_TITLES = {
    "restricted": "Protected — no general Internet",
    "website": "One website — HTTPS read-only",
    "flexible": "Flexible web — automatic low-risk public-site approvals (experimental)",
    "custom": "Custom policy (advanced)",
}
RISK_DOC = "docs/openshell-network-profiles.md"


class Refused(Exception):
    """A safe, user-explainable refusal (including an unavailable upstream CLI)."""


def openshell(*args: str, capture: bool = False) -> str:
    """Invoke the trusted upstream CLI directly, never through a shell."""
    try:
        result = subprocess.run(
            ["openshell", *args], check=False, text=True,
            stdout=subprocess.PIPE if capture else None,
            stderr=subprocess.PIPE if capture else None,
        )
    except FileNotFoundError as exc:
        raise Refused("OpenShell is not installed in this Linux environment.") from exc
    if result.returncode:
        # Captured output can include sandbox metadata; do not reproduce it in exceptions.
        raise Refused(f"OpenShell command failed ({args[0]}, exit {result.returncode}). "
                      "Inspect its output locally; no automatic retry was attempted.")
    return result.stdout if capture else ""


def require_runtime() -> None:
    if platform.system() != "Linux":
        raise Refused("OpenShell workstations are currently Linux/WSL-only; Windows services are unchanged.")
    version = openshell("--version", capture=True).strip()
    if not re.search(r"(?<![\d.])0\.1\.8(?![\d.])", version):
        raise Refused(f"This adapter was validated for OpenShell {OPENSHELL_VERSION}; "
                      "review compatibility before changing any sandbox.")


def sandbox_name(title: str) -> str:
    title = title.strip()
    if not title or len(title) > 100 or any(ord(c) < 32 for c in title):
        raise Refused("Choose a nonempty workstation title (up to 100 printable characters).")
    normalized = unicodedata.normalize("NFKD", title).encode("ascii", "ignore").decode().lower()
    short = re.sub(r"[^a-z0-9]+", "-", normalized).strip("-")[:32].strip("-") or "workspace"
    fingerprint = hashlib.sha256(title.casefold().encode("utf-8")).hexdigest()[:10]
    return f"aiw-goose-{short}-{fingerprint}"


def list_workstations() -> list[dict[str, str]]:
    """Use OpenShell labels + annotations, not a second registry or AIW database."""
    result: list[dict[str, str]] = []
    page_token = ""
    visited: set[str] = set()
    while True:
        args = ["sandbox", "list", "--selector", AGENT_LABEL, "-o", "json"]
        if page_token:
            args += ["--page-token", page_token]
        try:
            payload = json.loads(openshell(*args, capture=True))
        except (ValueError, TypeError) as exc:
            raise Refused("Could not read OpenShell's structured sandbox list.") from exc
        if not isinstance(payload, dict) or not isinstance(payload.get("sandboxes"), list):
            raise Refused("Unexpected OpenShell sandbox-list format; refusing to guess.")
        for raw in payload["sandboxes"]:
            if not isinstance(raw, dict):
                raise Refused("Unexpected OpenShell sandbox entry.")
            metadata = raw.get("metadata") if isinstance(raw.get("metadata"), dict) else {}
            name = raw.get("name") or metadata.get("name")
            annotations = raw.get("annotations") or metadata.get("annotations") or {}
            status = raw.get("status") or {}
            phase = raw.get("phase") or (status.get("phase") if isinstance(status, dict) else status)
            if not isinstance(name, str) or not name or not isinstance(annotations, dict):
                raise Refused("Incomplete OpenShell sandbox metadata; refusing to guess.")
            title = annotations.get("aiw.title") or name
            result.append({"name": name, "title": str(title), "phase": str(phase or "Unknown"),
                           "profile": str(annotations.get("aiw.profile") or "unknown"),
                           "site": str(annotations.get("aiw.site") or "")})
        next_page = payload.get("next_page_token") or ""
        if not next_page:
            break
        if not isinstance(next_page, str) or next_page in visited:
            raise Refused("OpenShell sandbox pagination failed; refusing an incomplete list.")
        visited.add(next_page)
        page_token = next_page
    return sorted(result, key=lambda item: item["title"].casefold())


def select_workstation(title: str, entries: list[dict[str, str]] | None = None) -> dict[str, str]:
    entries = list_workstations() if entries is None else entries
    matches = [e for e in entries if e["title"].casefold() == title.casefold()]
    if len(matches) != 1:
        raise Refused("Workstation title is unknown or ambiguous. Choose one from 'list'.")
    return matches[0]


def show_list() -> None:
    entries = list_workstations()
    if not entries:
        print("No Goose workspaces yet. Existing research sandboxes are left alone.")
    for i, entry in enumerate(entries, 1):
        print(f" {i}) {entry['title']} — {entry['phase']} (OpenShell, {entry.get('profile', 'unknown')})")


def website_hostname(url: str) -> str:
    """Restrict a human URL to a single DNS name over HTTPS:443, never a subnet."""
    if not isinstance(url, str) or len(url) > 2048:
        raise Refused("Enter one https:// website address.")
    try:
        parsed = urlsplit(url.strip())
        port = parsed.port
        host = (parsed.hostname or "").encode("idna").decode("ascii").lower()
    except (ValueError, UnicodeError) as exc:
        raise Refused("Invalid HTTPS website address.") from exc
    if (parsed.scheme != "https" or port not in (None, 443)
            or parsed.username or parsed.password or parsed.fragment
            or not host or len(host) > 253 or host.endswith(".")
            or not re.fullmatch(r"[a-z0-9.-]+", host)):
        raise Refused("Enter an HTTPS address without login information or a custom port.")
    labels = host.split(".")
    if (len(labels) < 2 or any(not re.fullmatch(r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?", item)
                                for item in labels)
            or host.endswith((".local", ".internal", ".localhost", ".invalid", ".test"))):
        raise Refused("Choose a public DNS hostname, not a local or private network name.")
    return host


def website_policy(host: str) -> str:
    """Small OpenShell network rule; no home-grown network enforcement."""
    baseline = RESTRICTED_POLICY.read_text(encoding="utf-8")
    if "network_policies: {}" not in baseline:
        raise Refused("The bundled strict policy changed unexpectedly; refusing to broaden it.")
    # The policy is YAML and JSON strings are valid YAML scalars. host is validated.
    entry = f"""network_policies:
  approved_website:
    name: "Read-only website for Goose and developer tools"
    endpoints:
      - host: {json.dumps(host)}
        port: 443
        protocol: rest
        enforcement: enforce
        access: read-only
    binaries:
      - path: /usr/local/bin/goose
      - path: /usr/bin/curl
      - path: /usr/local/bin/curl
      - path: /usr/bin/git
"""
    return baseline.replace("network_policies: {}", entry)


def create(title: str, policy_file: str | None = None, *,
           profile: str = "restricted", website: str | None = None) -> None:
    # CLI --policy remains an expert escape hatch; the interactive menu never asks for files.
    if profile not in ("restricted", "website", "flexible"):
        raise Refused("Unknown network choice.")
    if policy_file and (profile != "restricted" or website):
        raise Refused("Choose either a custom policy file or a built-in profile.")
    if website and profile != "website":
        raise Refused("A website address is accepted only with the website profile.")
    host = website_hostname(website or "") if profile == "website" else ""
    selected_profile = "custom" if policy_file else profile
    policy = (Path(policy_file).expanduser().resolve(strict=True)
              if policy_file else RESTRICTED_POLICY)
    if not policy.is_file():
        raise Refused("The selected OpenShell policy file is missing.")
    if not title.strip():
        raise Refused("Enter a name for your Goose work area.")
    entries = list_workstations()
    if any(e["title"].casefold() == title.casefold() for e in entries):
        raise Refused("A Goose work area with this name already exists.")
    name = sandbox_name(title)
    if any(e["name"] == name for e in entries):
        raise Refused("An OpenShell work area already uses this name.")
    print(f"\nName: {title}")
    print(f"Network choice: {PROFILE_TITLES[selected_profile]}")
    if host:
        print(f"Allowed website: {host}:443 (GET/HEAD/OPTIONS, entire host; not other redirect hosts)")
        print("This does not grant arbitrary network access to subprocesses or other domains.")
    if profile == "flexible":
        print("WARNING: OpenShell may automatically approve low-risk PUBLIC website requests.")
        print("Not unrestricted Internet: flagged requests still require approval or fail.")
        print("This has not been qualified with interactive Goose or other tools.")
        print(f"Security limitations: {RISK_DOC}")
    print("OpenShell owns the sandbox. Nothing is mounted from your original projects.")
    approval = "ALLOW" if profile == "flexible" else "CREATE"
    if not confirm(f"Create this persistent Goose work area?", approval):
        return
    args = ["sandbox", "create", "--name", name, "--from", GOOSE_IMAGE,
            "--label", AGENT_LABEL, "--annotation", f"aiw.title={title}",
            "--annotation", f"aiw.profile={selected_profile}", "--detach",
            "--cpu", "2", "--memory", "4Gi"]
    if host:
        args += ["--annotation", f"aiw.site={host}"]
    if profile == "flexible":
        # Upstream OpenShell's policy-advisor path, not a custom permissive firewall.
        args += ["--approval-mode", "auto"]
    if host:
        # This temporary file is NOT an AIW-managed policy catalogue or durable state.
        # The trusted OpenShell CLI reads it at creation; its gateway retains the policy.
        with tempfile.TemporaryDirectory(prefix="aiw-openshell-policy-") as tmp:
            generated = Path(tmp) / "website.yaml"
            generated.write_text(website_policy(host), encoding="utf-8")
            generated.chmod(0o600)
            openshell(*args, "--policy", str(generated))
    else:
        openshell(*args, "--policy", str(policy))
    print(f"Created '{title}'. Private data survives stop/start, not deletion.")
    print("Inference requires separately approved OpenShell provider configuration.")

def status(entry: dict[str, str]) -> None:
    print(f"\n{entry['title']} — {entry['phase']} / Goose / OpenShell {OPENSHELL_VERSION}")
    print("Persistence: OpenShell-owned; stop/start retains observed workspace data.")
    profile = entry.get("profile", "unknown")
    print(f"Initial network choice: {PROFILE_TITLES.get(profile, 'Unknown / existing configuration')}")
    if entry.get("site"):
        print(f"Initial website: {entry['site']}:443")
    print("The actual effective OpenShell policy/providers can differ from this creation label.")
    print("Approved model endpoints allow data egress; credentials mediation is not DLP.")
    print(f"Details: {RISK_DOC}")
    print("Approved inference endpoints are deliberate data-egress paths, not DLP.")
    print("For local policy/provider details, use the advanced OpenShell commands:")
    print("  openshell sandbox get <sandbox-name>")
    print("  openshell policy get <sandbox-name> --full")
    # The actual policy is intentionally not reconstructed or certified by AIW.


def start(entry: dict[str, str]) -> None:
    if entry["phase"].lower() == "ready":
        print(f"'{entry['title']}' is already ready.")
        return
    openshell("sandbox", "start", entry["name"])
    print(f"Started '{entry['title']}'.")


def stop(entry: dict[str, str]) -> None:
    if not confirm(f"Stop '{entry['title']}' (keep private data)?", "STOP"):
        return
    openshell("sandbox", "stop", entry["name"])
    print("Stopped; OpenShell keeps the private workspace. This is not a backup.")


def check_ready(entry: dict[str, str]) -> None:
    if entry["phase"].lower() != "ready":
        raise Refused(f"'{entry['title']}' is not Ready. Start it before this operation.")


def shell(entry: dict[str, str]) -> None:
    check_ready(entry)
    openshell("sandbox", "exec", "-n", entry["name"], "--tty", "--", "bash")


def goose(entry: dict[str, str], endpoint: str, session: str, model: str = "agent", directory: str = ".") -> None:
    check_ready(entry)
    parsed = urlsplit(endpoint)
    if parsed.scheme != "https" or not parsed.netloc or parsed.username or parsed.password or parsed.path not in ("", "/") or parsed.query or parsed.fragment:
        raise Refused("The approved inference endpoint must be a bare HTTPS origin (no credentials/path).")
    if not re.fullmatch(r"[A-Za-z0-9._-]{1,64}", session) or not re.fullmatch(r"[A-Za-z0-9._-]{1,64}", model):
        raise Refused("Session and model names must be 1–64 simple characters.")
    remote = PurePosixPath(directory)
    if (not directory or remote.is_absolute() or any(p in ("..", "") for p in directory.split("/"))
            or any(ord(c) < 32 for c in directory)):
        raise Refused("Choose a relative directory inside the private sandbox workspace.")
    workdir = [] if directory == "." else ["--workdir", "/sandbox/" + directory]
    print("Interactive Goose is experimental: developer extension readiness is not yet qualified.")
    print("Use the separately attached OpenShell provider; no API key is passed by AIW.")
    openshell("sandbox", "exec", "-n", entry["name"], "--tty", *workdir,
              "--env", f"OPENAI_HOST={endpoint}",
              "--env", "OPENAI_BASE_PATH=v1/chat/completions",
              "--env", "GOOSE_PROVIDER=openai", "--env", f"GOOSE_MODEL={model}",
              "--env", "GOOSE_MODE=approve", "--",
              "goose", "session", "--name", session, "--no-profile", "--with-builtin", "developer")


def registered_projects() -> list[tuple[str, Path]]:
    if not WORKSPACE_REGISTRY.is_dir():
        return []
    items = []
    for link in sorted(WORKSPACE_REGISTRY.iterdir()):
        if link.is_symlink():
            try:
                target = link.resolve(strict=True)
            except OSError:
                continue
            if target.is_dir():
                items.append((link.name, target))
    return items


def reject_wsl_mount(path: Path) -> None:
    if "microsoft" in platform.release().lower() and (path == Path("/mnt") or Path("/mnt") in path.parents):
        raise Refused("WSL-mounted host paths are not accepted for this first integration slice.")


def import_project(entry: dict[str, str], project_name: str) -> None:
    check_ready(entry)
    project = dict(registered_projects()).get(project_name)
    if project is None:
        raise Refused("No such registered Linux project. Use 'aiw goose workspace list' first.")
    reject_wsl_mount(project)
    if project == Path("/") or project == Path.home():
        raise Refused("Refusing a broad source directory.")
    print(f"Source project: {project_name} — {project}")
    print("Copies the WHOLE directory, including .git, ignored files and possible secrets.")
    print("The copy is private to the sandbox; there is no bind mount or automatic sync.")
    print("Do not copy confidential files until the outstanding security tests are accepted.")
    if not confirm("Import this complete project copy?", "COPY"):
        return
    # Refuse merging into an existing name. OpenShell preserves directory basename.
    check = subprocess.run(["openshell", "sandbox", "exec", "-n", entry["name"],
                            "--no-login-shell", "--", "sh", "-c",
                            'test ! -e "$1" && test ! -L "$1"', "sh", project.name],
                           check=False)
    if check.returncode:
        raise Refused("Destination may already exist (or could not be checked). No overwrite attempted.")
    openshell("sandbox", "upload", entry["name"], str(project), "--no-git-ignore")
    print(f"Imported as '{project.name}' in the sandbox work directory. Verify files and Git history.")


def export_path(entry: dict[str, str], source: str, target: str) -> None:
    check_ready(entry)
    remote = PurePosixPath(source)
    if (not source or remote.is_absolute() or any(part in ("..", "") for part in source.split("/"))
            or source in (".", "..") or any(ord(c) < 32 for c in source)):
        raise Refused("Choose a relative path within the sandbox working directory.")
    dest = Path(target).expanduser().absolute()
    if dest.exists() or dest.is_symlink():
        raise Refused("Destination already exists; choose a new export path to avoid overwriting.")
    if not dest.parent.is_dir():
        raise Refused("Create the destination parent directory explicitly before exporting.")
    reject_wsl_mount(dest.parent.resolve(strict=True))
    print(f"Copy from '{entry['title']}' : {source}")
    print(f"To trusted Linux host          : {dest}")
    print("Exported data and active HTML/JS can be untrusted; inspect before use.")
    if not confirm("Download this file/directory?", "EXPORT"):
        return
    openshell("sandbox", "download", entry["name"], source, str(dest))
    print("Downloaded. This targeted transfer is NOT a full workspace or conversation backup.")


def confirm(question: str, word: str) -> bool:
    print(f"{question} Type {word} to proceed, or Enter to cancel.")
    return input("Approval: ").strip() == word


def choose(items: list[tuple[str, object]], heading: str) -> object | None:
    print(f"\n{heading}")
    for i, (title, _) in enumerate(items, 1):
        print(f" {i}) {title}")
    print(" b) Back")
    choice = input("Number: ").strip()
    if choice.lower() == "b" or not choice:
        return None
    if not choice.isascii() or not choice.isdecimal() or int(choice) not in range(1, len(items) + 1):
        print("Choose a displayed number; no changes made.")
        return None
    return items[int(choice) - 1][1]


def workstation_menu(entry: dict[str, str]) -> None:
    while True:
        entry = select_workstation(entry["title"])
        print(f"\n{entry['title']} — {entry['phase']}")
        print("1) Start / resume sandbox   2) Interactive Goose   3) Developer shell")
        print("4) Import registered project 5) Export file/folder 6) Stop (preserve data)")
        print("7) Status and security notes   b) Back")
        choice = input("Action: ").strip().lower()
        if choice == "b":
            return
        try:
            if choice == "1":
                start(entry)
            elif choice == "2":
                if entry["phase"].lower() != "ready":
                    start(entry)
                    entry = select_workstation(entry["title"])
                endpoint = input("Approved HTTPS inference origin: ").strip()
                session = input("Goose session title (simple name) [work]: ").strip() or "work"
                directory = input("Sandbox work folder [.] (e.g. imported project name): ").strip() or "."
                goose(entry, endpoint, session, directory=directory)
            elif choice == "3":
                shell(entry)
            elif choice == "4":
                projects = registered_projects()
                selected = choose([(f"{name} — {path}", name) for name, path in projects], "Registered source folders")
                if selected is not None:
                    import_project(entry, str(selected))
            elif choice == "5":
                src = input("Sandbox-relative file/folder: ").strip()
                dest = input("NEW Linux destination path (parent must exist): ").strip()
                export_path(entry, src, dest)
            elif choice == "6":
                stop(entry)
            elif choice == "7":
                status(entry)
            else:
                print("Unknown action.")
        except Refused as exc:
            print(f"[!] {exc}", file=sys.stderr)


def menu() -> None:
    require_runtime()
    while True:
        entries = list_workstations()
        print("\nGoose work areas")
        print("Each is a private, persistent OpenShell sandbox. It may hold many projects")
        print("and several Goose conversations. Stopping it does not delete its files.")
        choices = [(f"{item['title']} — {item['phase']}", item) for item in entries]
        choices.append(("Create a new Goose work area", "create"))
        selected = choose(choices, "Choose a work area")
        if selected is None:
            return
        if selected == "create":
            title = input("Name of the work area (e.g. My Goose project): ").strip()
            print("\nWhat websites may Goose and its tools access?")
            profile = choose([
                ("Protected — no general Internet (recommended, like our first test)", "restricted"),
                ("One HTTPS website — read-only downloads from that host", "website"),
                ("Flexible web — auto-approve some public websites (experimental, riskier)", "flexible"),
            ], "Network access")
            if profile is None:
                continue
            website = ""
            if profile == "website":
                website = input("Website URL (https://...): ").strip()
            try:
                create(title, profile=profile, website=website or None)
            except (Refused, OSError) as exc:
                print(f"[!] {exc}", file=sys.stderr)
        else:
            workstation_menu(selected)

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Persistent Goose work areas powered by OpenShell")
    sub = parser.add_subparsers(dest="action")
    sub.add_parser("menu")
    sub.add_parser("list")
    c = sub.add_parser("create")
    c.add_argument("title")
    c.add_argument("--policy", help="Advanced: custom policy file; otherwise bundled restricted policy")
    c.add_argument("--profile", choices=("restricted", "website", "flexible"), default="restricted")
    c.add_argument("--website", help="HTTPS URL for website profile; allows read-only requests to its host")
    for name in ("status", "start", "stop", "shell"):
        cmd = sub.add_parser(name)
        cmd.add_argument("title")
    g = sub.add_parser("goose")
    g.add_argument("title")
    g.add_argument("--endpoint", required=True, help="Approved HTTPS inference origin; never an API key")
    g.add_argument("--session", default="work")
    g.add_argument("--model", default="agent")
    g.add_argument("--directory", default=".", help="Relative directory inside the sandbox workspace")
    imp = sub.add_parser("import-project")
    imp.add_argument("title")
    imp.add_argument("registered_project")
    exp = sub.add_parser("export")
    exp.add_argument("title")
    exp.add_argument("sandbox_path")
    exp.add_argument("new_linux_destination")
    args = parser.parse_args(argv)
    try:
        require_runtime()
        if args.action in (None, "menu"):
            menu()
        elif args.action == "list":
            show_list()
        elif args.action == "create":
            create(args.title, args.policy, profile=args.profile, website=args.website)
        else:
            entry = select_workstation(args.title)
            if args.action == "status":
                status(entry)
            elif args.action == "start":
                start(entry)
            elif args.action == "stop":
                stop(entry)
            elif args.action == "shell":
                shell(entry)
            elif args.action == "goose":
                goose(entry, args.endpoint, args.session, args.model, args.directory)
            elif args.action == "import-project":
                import_project(entry, args.registered_project)
            elif args.action == "export":
                export_path(entry, args.sandbox_path, args.new_linux_destination)
    except (Refused, OSError, EOFError) as exc:
        print(f"[!] {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
