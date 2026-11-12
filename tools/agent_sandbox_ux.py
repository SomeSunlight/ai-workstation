"""Small, operator-facing menu for the existing reviewed sandbox service.

All privileged operations remain in agent_sandbox.py / agent_sandbox_core.py.
This module only selects objects and sequences their existing approval gates.
"""
from __future__ import annotations

from pathlib import Path
import subprocess
import re


def choose(heading: str, items: list[tuple[str, str]], *, default: str | None = None) -> str | None:
    """Numbered choices; never interpret user text as an ID or command."""
    print("\n" + heading)
    if not items:
        print("  Nothing available.")
        return None
    for number, (_, label) in enumerate(items, 1):
        print(f"  {number}) {label}")
    if default is not None:
        print("  Enter) Use recommended choice")
    print("  b) Back / cancel")
    while True:
        try:
            value = input("Select: ").strip()
        except EOFError:
            return None
        if value.lower() in ("b", "q"):
            return None
        if not value:
            return default
        if value.isascii() and value.isdecimal() and 1 <= int(value) <= len(items):
            return items[int(value) - 1][0]
        print("Enter a listed number or b to cancel. No changes made.")


def ask(prompt: str, *, default: str = "") -> str | None:
    try:
        value = input(f"{prompt}{f' [{default}]' if default else ''} (b = back): ").strip()
    except EOFError:
        return None
    if value.lower() == "b":
        return None
    return value or default or None


def choose_session(api):
    sessions = api.list_sessions()
    return choose("Select a session to continue or inspect:", [
        (m["id"], f"{session_label(m)}")
        for m in sessions
    ])


def choose_environment(api, *, named_only=False, include_inactive=False):
    options = []
    for name, record in sorted(api.catalogue()["environments"].items()):
        active = record.get("active")
        if (active or include_inactive) and (not named_only or name != "standard"):
            options.append((name, f"{name} | "
                          f"{'active r' + active if active else 'inactive'} | "
                          f"{len(record['versions'])} approved revision(s)"))
    return choose("Approved environments (only new sessions use the active revision):", options)


def choose_revision(api, name):
    record = api.catalogue()["environments"][name]
    return choose(f"Approved revisions of {name}:", [
        (rev, f"r{rev}{' (active)' if rev == record.get('active') else ''} | "
         f"approved {data.get('approved_at', '?')} | {data['image_id'][:19]}")
        for rev, data in sorted(record["versions"].items(), key=lambda v: int(v[0]))
    ])


def workspace_entries() -> list[tuple[str, str]]:
    """Use the pre-existing Bash registry; registration stays Bash-owned."""
    registry = Path.home() / ".config/ai-workstation/goose-workspaces"
    if not registry.is_dir():
        return []
    entries = []
    for link in sorted(registry.iterdir()):
        if link.is_symlink():
            try:
                path = str(link.resolve(strict=True))
            except (OSError, RuntimeError):
                path = "(unavailable)"
            entries.append((link.name, path))
    return entries


def session_label(meta: dict, api=None) -> str:
    name = meta.get("title") or "[older untitled session]"
    changes = ""
    if api is not None:
        try:
            count = api.pending_changes(meta["id"])
            changes = f" | {count} proposed change(s)"
        except (api.Refused, OSError) as exc:
            changes = f" | review unavailable: {exc}"
    return (f"{name} | project {meta['workspace']} | "
            f"{meta['environment']} r{meta['revision']}{changes} "
            f"| created {meta['created']} | id …{meta['id'][-6:]}")


def choose_workspace(api):
    return choose("Choose the ORIGINAL project to copy into your safe session:", [
        (name, f"{name} | {path}") for name, path in workspace_entries()
    ])


def new_session(api, environment=None, project=None):
    work = project or choose_workspace(api)
    if work is None:
        print("Register a project folder from the cockpit first; no session created.")
        return
    envs = api.catalogue()["environments"]
    if environment is None:
        choices = [(name, f"{name} r{record['active']}"
                    + (" (recommended for a fresh start)" if name == "standard" else ""))
                   for name, record in sorted(envs.items(), key=lambda pair: (pair[0] != "standard", pair[0]))
                   if record.get("active")]
        if not choices:
            print("No approved environment yet. Choose 'Initial setup' in the cockpit first.")
            return
        environment = choose("Choose tools for this session (Enter = standard):",
                             choices, default=choices[0][0])
    if environment is None:
        return
    title = ask("What do you want Goose to do? Give the session a memorable title",
                default=f"Explore {work}")
    if title is None:
        return
    sid = api.start(work, environment, title=title)
    print(f"Ready: {title!r} | original project {work} untouched | "
          f"environment {environment}.")
    if choose("Ready to work?", [("run", "Start Goose safely now"),
                                 ("later", "Keep session for later")], default="run") == "run":
        api.run_session(sid, [])


def save_session_tools(api, sid=None):
    sid = sid or choose_session(api)
    if sid is None:
        return
    _, meta = api.current_session(sid)
    print(f"\nSource session: {meta.get('title', meta['id'])!r} | {meta['workspace']} | "
          f"{meta['environment']} r{meta['revision']} | id {meta['id']}")
    tools = api.inventory(sid)
    print("Session uv tool inventory: " +
          (", ".join(f"{package}=={version}" for package, version in tools) or "(empty)"))
    if not tools:
        print("No session-installed uv tools detected. Wrong session? Check its title and "
              "ID. uvx caches and arbitrary shell/apt installs cannot be captured.")
        return
    existing = api.catalogue()["environments"]
    action_items = [("new", "Create a new named environment from this session")]
    if meta["environment"] != "standard" and meta["environment"] in existing:
        action_items.append(("upgrade", f"Update {meta['environment']} to a new approved revision"))
    action = choose("Save session tools as a reusable environment:", action_items)
    if action is None:
        return
    if action == "new":
        name = ask("New environment name (lowercase letters, numbers, - and _)")
        if name is None:
            return
        api.validate_name(name)
        if name in existing:
            print(f"{name} already exists. Choose a session from that named environment to update it.")
            return
    else:
        name = meta["environment"]
    print(f"\nProposed {name}: parent is the pinned {meta['environment']} r{meta['revision']}.")
    print("Only exact version-pinned uv tool installs are proposed. The sandbox's "
          "project files, Goose history, uvx caches, shell and apt changes are NOT copied.")
    if choose("Continue?", [("yes", "Prepare the private, unapproved recipe"),
                            ("no", "Cancel without creating a proposal")]) != "yes":
        return
    api.candidate(sid, name, upgrade=(action == "upgrade"))
    approve_candidate(api, name)


def approve_candidate(api, name=None):
    if name is None:
        path = api.STATE / "candidates"
        items = []
        if path.is_dir():
            for folder in sorted(path.iterdir()):
                if folder.is_dir() and (folder / "candidate.json").is_file():
                    items.append((folder.name, folder.name))
        name = choose("Unapproved environment proposals:", items)
    if name is None:
        return
    folder = api.STATE / "candidates" / name
    proposal = api.load_json(folder / "candidate.json")
    source = api.current_session(proposal["session"])[1]
    print(f"\nProposal: {name} from session {source.get('title', source['id'])!r} "
          f"(id {proposal['session']})")
    print(f"Approved parent: {proposal['parent']} (pinned image {proposal['parent_image_id']})")
    recipe = (folder / "Dockerfile").read_text()
    print("\nProposed pinned recipe:\n" + recipe)
    api.inspect_recipe(recipe)
    if not proposal.get("detected_uv_tools"):
        print("This proposal recorded an EMPTY session tool inventory. It may be from "
              "the wrong session; do not promote it blindly. Discard and re-create "
              "from the intended session.")
        if choose("Empty proposal:", [("discard", "Discard unapproved recipe"),
                                       ("later", "Keep for manual inspection")]) == "discard":
            api.discard_candidate(name)
        return
    print("This is NOT an approved environment until the separate typed approval. "
          "You may edit the private Dockerfile outside Goose, then review it again.")
    action = choose("Proceed?", [
        ("approve", "Verify/build/activate (requires typed approval)"),
        ("later", "Leave proposal unapproved for later review"),
        ("discard", "Discard this unapproved recipe (requires typed approval)")
    ])
    if action == "approve":
        api.promote(name)
        print("Only future sessions use the newly active revision; existing sessions are pinned.")
    elif action == "discard":
        api.discard_candidate(name)
    else:
        print("Proposal retained, unapproved. No active environment changed.")


def existing_session(api):
    sid = choose_session(api)
    if sid is None:
        return
    while True:
        _, meta = api.current_session(sid)
        print(f"\nSession: {meta.get('title', sid)!r} | workspace {meta['workspace']} | "
              f"{meta['environment']} r{meta['revision']} | {meta['created']} | id {sid}")
        action = choose("Session actions:", [
            ("run", "Run / resume Goose"),
            ("review", "Review project changes (read-only; no original writes)"),
            ("rename", "Rename session title"),
            ("save", "Save installed uv tools as an approved environment revision"),
            ("discard", "Discard private session and its Goose history (requires approval)")
        ])
        if action is None:
            return
        if action == "run":
            api.run_session(sid, [])
        elif action == "review":
            folder, _ = api.current_session(sid)
            print(api.review(folder)[1])
            print("No files were applied. The batch Git review/merge is a separate "
                  "follow-up; the existing explicit CLI apply remains available.")
        elif action == "rename":
            title = ask("New title")
            if title is not None:
                api.rename_session(sid, title)
        elif action == "save":
            save_session_tools(api, sid)
        elif action == "discard":
            api.destroy(sid)
            return


def sessions_menu(api):
    while True:
        action = choose("Sessions (isolated project copies):", [
            ("list", "Show session status and pending changes"),
            ("create", "Create session (select project, environment and title)"),
            ("existing", "Select retained session to run, review, rename or discard")
        ])
        if action is None:
            return
        if action == "list":
            api.report()
        elif action == "create":
            new_session(api)
        else:
            existing_session(api)


def environments_menu(api):
    while True:
        action = choose("Environments (pinned recipes, not project files):", [
            ("list", "Show approved environments and revisions"),
            ("save", "Save tools from a selected session (guided revision)"),
            ("candidate", "Review existing unapproved proposal"),
            ("rollback", "Activate an older approved revision for future sessions"),
            ("rebuild", "Rebuild/verify an approved revision (no activation)"),
            ("standard", "Build or upgrade the pinned standard base"),
            ("remove", "Deactivate a named environment (retain recipes and images)")
        ])
        if action is None:
            return
        if action == "list":
            api.report()
        elif action == "save":
            save_session_tools(api)
        elif action == "candidate":
            approve_candidate(api)
        elif action in ("rollback", "rebuild"):
            env = choose_environment(api, include_inactive=True)
            if env is not None:
                rev = choose_revision(api, env)
                if rev is not None:
                    (api.rollback if action == "rollback" else api.rebuild)(env, rev)
        elif action == "standard":
            record = api.catalogue()["environments"].get("standard", {})
            api.build_standard(bool(record.get("active")))
        elif action == "remove":
            env = choose_environment(api, named_only=True)
            if env is not None:
                api.remove_environment(env)


def help_text():
    print("""
A workspace is your registered ORIGINAL project. Goose receives only a private copy.
A session is that private copy + its own Goose home/tools and pinned environment.
An environment is an approved, versioned tool image: 'standard' or a named one.
Example: create session 'Add black' from python-tools r1, install black==25.1.0
with uv tool, then use Environments > Save tools to propose and approve r2.
The unapproved recipe is internal; nothing is activated until typed approval.
Rollback chooses r1 for NEW sessions; r2 sessions stay pinned.
Project review is separate: a diff is NOT permission to write the original.
Existing CLI apply requires exact file paths and typed consent; a Git-based batch
review/merge UI is planned separately. No original .git is given to Goose.
Use 'aiw goose sandbox --help' for stable-ID scripting and advanced commands.
Bridge networking/provider credentials are NOT a hostile-code security boundary.
""")


def menu(api):
    """Interaction only. Deliberately no new authority or Docker lifecycle."""
    while True:
        try:
            action = choose("Goose sandboxes (opt-in):", [
                ("sessions", "Sessions: create, resume, review, rename, discard"),
                ("environments", "Environments: approve revisions, rollback, rebuild"),
                ("setup", "One-time Goose profile setup / standard image"),
                ("help", "Concepts and safety, with an example")
            ])
            if action is None:
                return
            if action == "sessions":
                sessions_menu(api)
            elif action == "environments":
                environments_menu(api)
            elif action == "help":
                help_text()
            elif action == "setup":
                step = choose("Setup (legacy Goose volume is never overwritten):", [
                    ("migrate", "Back up legacy Goose data and initialize isolated profile"),
                    ("standard", "Build/upgrade pinned standard image"),
                    ("disable", "Disable creation of new sandboxes (preserve existing)")
                ])
                if step == "migrate":
                    api.migration("enable")
                elif step == "standard":
                    api.build_standard(bool(api.catalogue()["environments"].get("standard", {}).get("active")))
                elif step == "disable":
                    api.migration("disable")
        except (api.Refused, OSError, subprocess.SubprocessError) as exc:
            print(f"Operation blocked: {exc}")
            print("Check the selected session/environment and try again; no approval was bypassed.")
        except KeyboardInterrupt:
            print("\nCancelled. Returning to sandboxes.")
            return
