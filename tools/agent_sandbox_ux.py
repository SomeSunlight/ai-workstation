"""Small, operator-facing menu for the existing reviewed sandbox service.

All privileged operations remain in agent_sandbox.py / agent_sandbox_core.py.
This module only selects objects and sequences their existing approval gates.
"""
from __future__ import annotations

from pathlib import Path
import subprocess


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
        (m["id"], session_label(m, api))
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
    return choose("Choose a reusable environment (new sessions use the active version):", options)


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
            changes = f" | {count} project file change(s)"
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
        environment = choose("Choose tools for this session (Enter = first recommended choice):",
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
    action = choose("Turn the installed tools into a reusable environment:", action_items)
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
        name = choose("Prepared environment updates awaiting your approval:", items)
    if name is None:
        return
    folder = api.STATE / "candidates" / name
    proposal = api.load_json(folder / "candidate.json")
    if proposal.get("name") != name:
        print(f"\nArchived earlier test of environment {proposal.get('name')!r}. "
              "Its saved folder name is different from the approved environment name. "
              "It is NOT an approved revision and cannot be activated.")
        print(f"Source session: {proposal.get('session')} | "
              f"saved tool inventory: {'empty' if not proposal.get('detected_uv_tools') else 'present'}")
        action = choose("Archived environment test:", [
            ("discard", "Discard this old unapproved test (approval required)"),
            ("later", "Keep it for later")])
        if action == "discard":
            api.discard_candidate(name)
        return
    source = api.current_session(proposal["session"])[1]
    print(f"\nEnvironment update awaiting review: {name} from session {source.get('title', source['id'])!r} "
          f"(id {proposal['session']})")
    print(f"Approved parent: {proposal['parent']} (pinned image {proposal['parent_image_id']})")
    recipe = (folder / "Dockerfile").read_text()
    print("\nTools recipe for the next approved environment version:\n" + recipe)
    api.inspect_recipe(recipe)
    if not proposal.get("detected_uv_tools"):
        print("This proposal recorded an EMPTY session tool inventory. It may be from "
              "the wrong session; do not promote it blindly. Discard and re-create "
              "from the intended session.")
        if choose("Empty proposal:", [("discard", "Discard unapproved recipe"),
                                       ("later", "Keep for manual inspection")]) == "discard":
            api.discard_candidate(name)
        return
    print("This is NOT an approved environment version until separate typed approval. "
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


def existing_session(api, sid=None):
    sid = sid or choose_session(api)
    if sid is None:
        return
    while True:
        _, meta = api.current_session(sid)
        print("\nYour selected session:")
        print("  " + session_label(meta, api))
        action = choose("What next?", [
            ("run", "Continue working with Goose in this private copy"),
            ("review", "See all project changes before accepting anything"),
            ("rename", "Rename this session"),
            ("save", "Create or upgrade a reusable environment from this session's tools"),
            ("discard", "Discard this session and its private Goose history (approval required)")
        ])
        if action is None:
            return
        if action == "run":
            api.run_session(sid, [])
        elif action == "review":
            folder, _ = api.current_session(sid)
            print(api.review(folder)[1])
            print("Read-only review. No original project files changed. The Git-based "
                  "batch merge will be added as a separate #64 PR; advanced CLI "
                  "still supports individually approved file apply.")
        elif action == "rename":
            title = ask("New session title")
            if title is not None:
                api.rename_session(sid, title)
        elif action == "save":
            save_session_tools(api, sid)
        elif action == "discard":
            api.destroy(sid)
            return


def print_cockpit(api):
    """One complete inventory on arrival; no duplicate list command per tab."""
    projects = workspace_entries()
    sessions = api.list_sessions()
    environments = api.catalogue()["environments"]
    pending = api.pending_environment_updates()
    linked = {}
    for update in pending:
        linked.setdefault(update["session"], []).append(update["environment"])
    print("\n" + "=" * 52)
    print("Goose sandbox cockpit — your projects, sessions and tools")
    print("=" * 52)
    print(f"\nYour projects ({len(projects)} registered original folder(s)):")
    for name, path in projects:
        print(f"  {name}  ->  {path}")
    if not projects:
        print("  (none: register a project folder below)")
    print(f"\nYour sessions ({len(sessions)} private working copy/copies):")
    for index, meta in enumerate(sessions, 1):
        waiting = linked.get(meta["id"], [])
        print(f"  {index}. {session_label(meta, api)}"
              + (f" | unfinished tool update: {', '.join(waiting)}" if waiting else ""))
    if not sessions:
        print("  (none: start a new safe session below)")
    print(f"\nYour environments ({len(environments)} approved tool image(s)):")
    for name, record in sorted(environments.items(), key=lambda pair: (pair[0] != "standard", pair[0])):
        active = record.get("active")
        status = f"r{active} active" if active else "inactive"
        waiting = [u for u in pending if u["environment"] == name]
        print(f"  {name}: {status} | {len(record['versions'])} approved revision(s)"
              + (" | ready to use" if active else "")
              + (f" | {len(waiting)} unfinished tool update(s)" if waiting else ""))
    if not environments:
        print("  (none: perform initial setup below)")
    path = api.STATE / "migration.json"
    if not path.exists():
        print("\nInitial setup needed: copy/backup existing Goose settings, then build standard.")
    elif not api.load_json(path).get("enabled"):
        print("\nSandbox creation disabled (existing sessions are still retained).")
    print("\nNothing shown here is a live agent process. Your original projects"
          " are never mounted inside the sandbox.")


def workspace_menu(api):
    """Use the existing Bash implementation as the sole workspace registry writer."""
    while True:
        print("\nProject folders Goose may work with (via PRIVATE sandbox copies):")
        for name, target in workspace_entries():
            count = sum(m["workspace"] == name for m in api.list_sessions())
            print(f"  {name} -> {target} | {count} retained session(s)")
        action = choose("Project folders:", [
            ("add", "Register another original project folder"),
            ("remove", "Unregister a project folder (does not delete files)")
        ])
        if action is None:
            return
        if action == "add":
            name = ask("Short project name (letters, digits, dot, - and _)")
            if name is None:
                continue
            target = ask("Full path to the EXISTING project directory")
            if target is None:
                continue
            # Never use a shell or duplicate the Bash register/unregister policy.
            subprocess.run([str(api.ROOT / "bin/aiw"), "goose", "workspace",
                            "add", name, target], check=True)
        else:
            entries = workspace_entries()
            name = choose("Which registered project should be unregistered?", [
                (n, f"{n} | {target}") for n, target in entries
            ])
            if name is None:
                continue
            if any(m["workspace"] == name for m in api.list_sessions()):
                print("This project still has retained sessions. Review/discard those "
                      "first; its original directory has NOT been changed.")
                continue
            api.confirm(f"Only the AIW registration for {name!r} will be removed. "
                        "The real project files stay where they are.", "UNREGISTER " + name)
            subprocess.run([str(api.ROOT / "bin/aiw"), "goose", "workspace",
                            "remove", name], check=True)


def cleanup_sessions(api):
    """Housekeeping follows session status; unapproved tool updates are inline."""
    sessions = api.list_sessions()
    if not sessions:
        print("No retained sessions to clean up. Ready for your first safe session.")
        return
    pending = api.pending_environment_updates()
    linked = {}
    for update in pending:
        linked.setdefault(update["session"], []).append(update)
    empty, blocked = [], []
    print("\nYour earlier sessions (even unchanged sessions may contain Goose history):")
    for meta in sessions:
        sid = meta["id"]
        count = api.pending_changes(sid)
        updates = linked.get(sid, [])
        if updates:
            detail = "; ".join(f"{u['environment']} (unfinished environment update)"
                               for u in updates)
            blocked.append(sid)
        else:
            detail = ""
        print(f"  {session_label(meta)} | {count} project file change(s)"
              + (f" | {detail}" if detail else ""))
        if count == 0 and not updates:
            empty.append(sid)
    print(f"\n{len(empty)} unchanged session(s) ready to discard; "
          f"{len(blocked)} session(s) have unfinished environment updates.")
    print("Only PRIVATE session copies/history/tools will be removed. Your projects,"
          " approved environment revisions, migrated Goose profile and legacy history remain.")
    actions = [
        ("empty", f"Discard {len(empty)} ready sessions (ONE typed approval)"),
    ]
    if blocked:
        actions.append(("resolve", "Inspect the unfinished tool-environment update blocking cleanup"))
    actions.append(("one", "Inspect/discard a specific session, including one with project changes"))
    action = choose("Tidy up:", actions)
    if action == "empty":
        if empty:
            api.discard_empty_sessions(empty)
        else:
            print("No sessions are ready to discard. Inspect remaining changes or "
                  "saved environment updates first.")
    elif action == "resolve":
        updates = [u for u in pending if u["session"] in blocked]
        folder = choose("Choose a session's unfinished environment update:", [
            (u["folder"], f"Environment {u['environment']} | "
             f"session ...{u['session'][-6:]} | "
             f"{'empty tool list' if u['empty_tools'] else 'saved tools'}")
            for u in updates])
        if folder is not None:
            approve_candidate(api, folder)
    elif action == "one":
        existing_session(api)


def environment_actions(api, name):
    while True:
        record = api.catalogue()["environments"].get(name)
        if record is None:
            print("Environment no longer exists; returning to cockpit.")
            return
        active = record.get("active")
        print(f"\nReusable environment: {name}"
              f"\n  Active version: {('r' + active) if active else '(inactive)'}"
              f"\n  All approved revisions: {', '.join('r' + r for r in sorted(record['versions'], key=int))}")
        print("Changing the active version affects NEW sessions only; existing "
              "sessions keep their original tools.")
        actions = [
            ("start", "Start safe Goose session using this environment"),
            ("update", f"Create an improved revision of {name} from a session"),
            ("rollback", "Choose which approved revision new sessions use"),
            ("rebuild", "Verify/rebuild an existing approved revision (no activation)"),
        ]
        candidate_dir = api.STATE / "candidates" / name
        if candidate_dir.is_dir():
            actions.append(("candidate", "Review a prepared but NOT YET approved revision"))
        if name != "standard":
            actions.append(("remove", "Deactivate this environment (keep all revisions)"))
        action = choose(f"What do you want to do with {name}?", actions)
        if action is None:
            return
        if action == "start":
            if not active:
                print("Environment inactive. Activate an approved revision first.")
            else:
                new_session(api, environment=name)
        elif action == "update":
            if name == "standard":
                print("The standard base is upgraded through Initial setup. To add tools,"
                      " use a new named environment built from a standard session.")
                continue
            eligible = [m for m in api.list_sessions()
                        if m["environment"] == name and m["revision"] == active]
            sid = choose(f"Choose a session already using {name} r{active}:", [
                (m["id"], session_label(m, api)) for m in eligible
            ])
            if sid is None:
                print(f"To update {name}, start a session with its ACTIVE revision,"
                      " install the desired tools inside Goose, then return here.")
            else:
                save_session_tools(api, sid)
        elif action in ("rollback", "rebuild"):
            rev = choose_revision(api, name)
            if rev is not None:
                (api.rollback if action == "rollback" else api.rebuild)(name, rev)
        elif action == "candidate":
            approve_candidate(api, name)
        elif action == "remove":
            api.remove_environment(name)


def environments_menu(api):
    while True:
        records = api.catalogue()["environments"]
        options = [
            (name, f"{name} | "
             f"{'r' + record['active'] + ' active' if record.get('active') else 'inactive'}"
             f" | {len(record['versions'])} approved revision(s)")
            for name, record in sorted(records.items(), key=lambda pair: (pair[0] != "standard", pair[0]))
        ]
        options += [
            ("create-from-session", "Create a NEW reusable environment from a session's installed tools"),
            ("pending", "Review prepared environment updates awaiting approval"),
            ("standard-setup", "Build/upgrade the standard environment"),
        ]
        choice = choose("Select an environment, or create one from a session:", options)
        if choice is None:
            return
        if choice == "create-from-session":
            save_session_tools(api)
        elif choice == "pending":
            approve_candidate(api)
        elif choice == "standard-setup":
            record = records.get("standard", {})
            api.build_standard(bool(record.get("active")))
        else:
            environment_actions(api, choice)


def help_text():
    print("""
A quick mental model:
  PROJECT: your real folder. Goose cannot write to it from a sandbox.
  SESSION: a temporary private copy of that folder + Goose history/tools.
  ENVIRONMENT: reusable approved tools, e.g. standard r1 or python-tools r2.

Takeoff: select your project -> choose standard (recommended) -> name what
you want to do -> start Goose. Your original is not mounted in the container.
When Goose finishes, select that named session to resume or inspect changes.
Project review shows changes; accepting them is a separate host approval
(the future Git batch review/merge is NOT yet in this PR).

Example: Use python-tools r1, install black==25.1.0 with uv tool in its
session, then improve python-tools from THAT session. Review exact tool pins;
only typed approval makes r2 active for future sessions. Older sessions stay
on their pinned revisions. Rollback restores r1 for future sessions.

You do not need to learn 'candidate': it is an INTERNAL unapproved recipe
for a future environment revision. Not a project merge. It may be discarded.

The old direct Goose workflow remains under the separate legacy menu as
a recovery/compatibility route. It writes its registered project directly.
The sandbox route is the recommended default, but this is NOT hardened
against hostile code/network access; provider credentials are accessible
inside Goose. Inspect the security contract in docs/agent-sandboxes.md.
""")


def setup_menu(api):
    action = choose("Initial setup / recovery (preserves your legacy Goose data):", [
        ("migrate", "First-time: verified backup + isolated Goose settings/history"),
        ("standard", "Build/upgrade the reusable standard environment"),
        ("disable", "Disable NEW sandbox sessions (keep existing work/history)")
    ])
    if action == "migrate":
        api.migration("enable")
    elif action == "standard":
        api.build_standard(bool(api.catalogue()["environments"].get("standard", {}).get("active")))
    elif action == "disable":
        api.migration("disable")


def menu(api):
    """Single integrated cockpit; no new Docker or original-project privileges."""
    while True:
        try:
            print_cockpit(api)
            action = choose("What would you like to do?", [
                ("start", "Start a NEW safe Goose session (recommended)"),
                ("sessions", "Continue or inspect one of your sessions"),
                ("projects", "Manage the original project folders Goose can work on"),
                ("environments", "Manage reusable tool environments and revisions"),
                ("cleanup", "Tidy up earlier test sessions (no full reset)"),
                ("setup", "Initial setup and recovery (advanced)"),
                ("help", "How this works — one practical example")
            ], default="start")
            if action is None:
                return
            if action == "start":
                new_session(api)
            elif action == "sessions":
                existing_session(api)
            elif action == "projects":
                workspace_menu(api)
            elif action == "environments":
                environments_menu(api)
            elif action == "cleanup":
                cleanup_sessions(api)
            elif action == "help":
                help_text()
            elif action == "setup":
                setup_menu(api)
        except (api.Refused, OSError, subprocess.SubprocessError) as exc:
            print(f"Operation blocked: {exc}")
            print("Review your selection; no approval was bypassed. "
                  "A failed multi-step operation may retain a private session/proposal "
                  "for later inspection.")
        except KeyboardInterrupt:
            print("\nCancelled. Returning to the Goose menu.")
            return
