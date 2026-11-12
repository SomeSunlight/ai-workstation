# Agent sandboxes — #59 isolation, #64 guided operator workflow

**Reproducible infrastructure. Controlled agent autonomy.** The sandbox adapter is opt-in. Regular `aiw goose session`, existing Docker Compose Goose, its credentials/history and running services are untouched. Native Windows runs this adapter inside WSL; Linux works directly.

## Start here: selectable menu (Linux / WSL2)

Run `aiw` → **Goose → Sandboxes** (or `aiw goose sandbox menu`). The compact menu separates **Sessions**, **Environments**, **Setup** and **Help**. Select registered workspaces, retained sessions and approved environment revisions by **number**; you do not need to memorize the internal 12-character IDs.

1. **Setup:** back up/migrate the legacy Goose profile once and build the pinned `standard` image, each with its existing typed approval. Registered projects are managed under Goose → Manage workspaces.
2. **Sessions → Create:** select a registered original workspace and an approved environment, give the session an intention/title, then optionally run Goose. The agent works on a private copy.
3. **Sessions → Select:** resume, review the proposed project changes, rename the session or discard its private work/history. The original is never mounted. Discard still requires typing `DESTROY <stable-id>`.
4. **Environments → Save tools:** select the *correct* session (shown with its title, workspace, pinned environment/revision and stable ID). See its installed `uv tool` inventory, choose new named image or upgrade the session's named parent, review the proposed pinned recipe, then explicitly type `APPROVE <name>` before AIW builds/verifies and activates it. Incomplete proposals remain unapproved for later review.
5. **Environments → Rollback / Rebuild:** choose the named environment and approved revision by number. Rollback changes **only future session selection** and requires typed `ROLLBACK <name>`; existing sessions stay pinned. Rebuild only verifies and never activates an image.

Example: an approved `python-tools` r1 contains `ruff`. Create session **Add black** from `python-tools` r1, install `black==25.1.0` with `uv tool` inside Goose, then choose Environments → Save tools → Update python-tools. Review r2's proposed recipe and approve it. A newly created r2 session sees both tools; rolling back to r1 makes future sessions use r1 while existing r2 sessions remain unchanged.

**Vocabulary:** a *workspace* is the registered original project. A *session* is an isolated working copy with its own Goose home and tools, backed by an immutable internal ID and a human-editable title. An *environment* is an approved, pinned image: `standard` or a named revision. A *candidate* is only an unapproved environment **recipe**, not a proposed project merge and not a separately managed user inventory type. *Review* reads proposed project differences; *apply* writes only explicitly accepted files after host-side hash checks and approval.

## CLI for scripting / advanced use

The menu uses the same existing commands, not a second approval mechanism. For scripting, keep the immutable IDs; for interactive CLI use, a unique exact (case-insensitive) title is accepted as an alternative. Ambiguous titles are rejected with the matching IDs; quote titles containing spaces.

```bash
aiw goose sandbox list
aiw goose sandbox create my-project --environment standard --title "Inspect config files"
aiw goose sandbox rename SESSION_ID "Prepare configuration changes"
aiw goose sandbox run SESSION_ID
aiw goose sandbox review SESSION_ID
aiw goose sandbox apply SESSION_ID README.md src/module.py  # typed approval, selected paths only
aiw goose sandbox discard SESSION_ID                        # typed approval, deletes session history
aiw goose sandbox rollback python-tools 1                   # typed approval
aiw goose sandbox rebuild python-tools 1                    # verification only
```

**Project-merge limitation (planned separate #64 PR):** the first UX slice improves selection and environment revision approval; it does **not** yet provide batch Git staging or hunk/3-way merge. The existing reviewed CLI `apply` still accepts explicit relative files and refuses drift. Do not confuse saving session tools with applying project edits. No session action grants the agent direct access to the original.

### Migration and recovery

`migrate` takes an **exclusive Goose maintenance lock**, refuses a running legacy Compose Goose session, requires the locally installed selected Goose image and typed `MIGRATE` approval. It makes a **full, verified backup** of `ai-workstation_goose-home` in `aiw-agent-goose-legacy-backup` and copies the native `.config/goose`, `.local/share/goose` (sessions) and `.local/state/goose` into the protected `aiw-agent-goose-profile`. Both are Docker volumes; no private tar archive or credentials are written to the Git checkout or logs. Verification compares deterministic TAR SHA-256 sums before marking migration complete. The original home is **not deleted, edited or renamed**. If migration fails, the original is still the source of truth; inspect the incomplete backup/profile before retrying. The implementation intentionally refuses to overwrite them.

`aiw goose sandbox migrate-disable` disables new sandbox creation after typed approval; the original Goose commands still use the untouched legacy volume. It does not delete the backup or previously retained sandbox sessions. To roll back **without any migration command**, simply continue using `aiw goose configure`, `aiw goose session`, `aiw goose check`, `aiw goose inspect` and `aiw goose edit`; those commands still use their original Compose path. The migrated config/history is a **snapshot**; subsequent legacy config edits are not automatically replicated. Native config-root overrides (`GOOSE_PATH_ROOT` and `XDG_CONFIG_HOME`) are refused in this first adapter. Inspect `aiw goose sandbox list` before updating a template.

**History policy:** pre-existing Goose history is copied and remains accessible in the private sandbox session home. New sandbox session history is held with that resumable session, not written back to the legacy home or shared with unrelated sessions. `discard` destroys that session history and its temporary tools; do not discard sessions whose new conversation records you want to retain. This PR does not offer an automatic history merge into the native SQLite store.

## Approved environment catalogue

The versioned `standard` recipe is [containers/agent-sandbox/Dockerfile](../containers/agent-sandbox/Dockerfile). At an explicit operator build, AIW reads the locally selected **Goose image digest**, pulls the pinned `uv` image, pins its digest, adds managed Python 3.12.12 and the already present Git/diagnostics, verifies the resulting tools, and records the local immutable **image ID** (content-addressed SHA-256), source digests, recipe hash and approval timestamp. Image builds never use the project or private config as a Docker build context. No automatic `latest` upgrades occur when starting sessions. Runtime `uv`, `uvx`, Python installs, tool caches and binaries go into the **session's own writable home**, not into a shared directory. `/tmp` remains `noexec`.

For advanced/automated operation, Goose can prepare a reusable variant directly (the menu is preferred):

```bash
aiw goose sandbox create my-project --environment standard
aiw goose sandbox run SESSION_ID
# Inside the session, e.g. install and test a harmless versioned uv tool.
aiw goose sandbox candidate SESSION_ID python-data
# Review/edit the private candidate Dockerfile outside Goose.
aiw goose sandbox promote python-data     # typed 'APPROVE python-data'
aiw goose sandbox create my-project --environment python-data
aiw goose sandbox rebuild python-data 1   # verify recipe/pinned package versions
```

Candidate generation inventories **installed `uv tool` packages**, captures exact versions and generates a small allowlisted recipe. It **does not** image-commit or snapshot the agent's home volume. `uvx` caches, arbitrary shell installs and extra interpreters installed by Goose are **not** automatically reproduced; where needed, make a separately reviewed enhancement rather than promote opaque state. The builder accepts only pinned `uv tool install` lines, verifies the resulting pinned tools, and records a local image ID. A candidate is never selectable without typed promotion. The agent container cannot mount or write the host catalogue or Docker daemon.

For an upgrade, create a session *from that named environment* and use `candidate SESSION_ID NAME --upgrade`, then `promote NAME`; previous approved revisions are retained. `rollback NAME REVISION` changes only the approved selection, after typed confirmation. `remove NAME` deactivates a named environment but keeps its image and recipe for recovery, and refuses dependent child environments or retained sessions. `standard` cannot be removed. `rebuild NAME REVISION` tests an approved recipe and reports whether the content digest matches; pinned package/version checks are the minimum reproducibility gate. Different timestamps or upstream build artifacts may produce a different Docker image ID, in which case no automatic promotion occurs.

## Project review contract

AIW resolves a **registered** original workspace to a canonical path, stages a private file-level copy, and mounts **only** that copy read-write at `/workspace`. Original `.git` internals and obvious credential files are not copied. Source, Markdown and other ordinary files work without Git. Symlinks, hardlinks, other filesystem devices and special files in the staged content are rejected; nested `.git` trees are excluded rather than followed. The host keeps SHA-256 baselines and private metadata outside the container. Review shows adds, deletes, modifications, same-hash renames and UTF-8 diffs; large or binary changes are identified without pretending to present a meaningful textual diff. No GitHub PR is automatically opened.

`apply` requires typed acceptance and explicitly selected relative paths. It rechecks original hashes and refuses drift/symlink/traversal paths, backs up existing selected files into the private session directory, and uses host-side directory-descriptor operations to write only the selected files. Binary writes additionally require `--allow-binary`. Unselected files stay untouched. Multi-file application is **not fully transactional**: if a host filesystem fails during application, private backups remain for recovery. Inspect changes before attempting another apply. No agent tool or model has authority to call the host-side apply action.

## Boundary and limitations (PR 2 is separate)

This first mode is ordinary nonprivileged Docker execution: read-only root filesystem, dropped capabilities, no-new-privileges, separate RW session home, no Docker socket and no writable original project bind. Tool execution, extensions and subagents launched *inside* Goose use this boundary. It does **not** mediate independently configured tools that run outside the container, defend against a malicious container runtime, protect confidential information already copied into the session, or block unrestricted Docker bridge network access. Goose must receive provider credentials to use native authenticated providers. **Do not use this basic profile for hostile code or sensitive projects**, and never interpret CLI instructions as an enforcement barrier. PR 2 will evaluate stronger runtime/network/credential restrictions.

Native Windows runs the Linux Goose adapter in **WSL**; this feature does not put new Goose services on the Windows host. Synthetic CI checks run on Ubuntu. The #59 baseline was accepted in a real owner WSL trial and disposable Docker CI; further native extension/history continuity and reboot durability remain separate host-side acceptance checks. The original Goose path remains the recoverable baseline.
