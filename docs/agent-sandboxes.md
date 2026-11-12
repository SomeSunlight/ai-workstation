# Agent sandboxes — Issue #59, PR 1 (opt-in Goose adapter)

**Reproducible infrastructure. Controlled agent autonomy.** This is a *review candidate*; it is not enabled by the installer. The existing `aiw goose session`, configuration, history, selected provider and Compose volume remain unchanged until the operator explicitly chooses this new workflow. No Windows service manager is involved.

## First use (Linux / WSL2)

Use **Goose → Sandboxes** in the normal `aiw` menu, or these equivalent direct commands:

```bash
aiw goose sandbox list
aiw goose sandbox migrate                  # explicit backup and migration consent
aiw goose sandbox build-standard           # operator-owned image build, no session launch
aiw goose sandbox create my-project --environment standard
aiw goose sandbox run SESSION_ID            # real Goose session in staged copy
aiw goose sandbox review SESSION_ID
aiw goose sandbox apply SESSION_ID README.md src/module.py  # separate typed approval
aiw goose sandbox discard SESSION_ID        # separate typed approval
```

Register the original project with `aiw goose workspace add my-project /path/to/project` first. `create` prints a 12-character session ID. A retained session can be resumed with another `run SESSION_ID`; its project copy and temporary home remain available until `discard`. A normal session exit never saves an environment and never applies files.

A **session** is a private project copy with temporary Goose state and tools. A **candidate** is different: it is an *unapproved recipe for a reusable environment revision* reconstructed from version-pinned `uv tool` installs. It is **not** a proposal to copy project files. The operator reviews and `promote`s the recipe to a named revision; `rollback` switches only what **new** sessions use, with existing sessions still pinned. If a tool is missing from a candidate, check that the correct session ID was used and that it was installed using `uv tool`.

**PR 1 operator limitation:** project review works, but applying 10–30 files currently requires enumerating relative paths. Human-editable session titles, menu selection instead of opaque IDs, guided environment revisions and Git-backed whole-changeset/diff/merge are deferred to [#64](https://github.com/SomeSunlight/ai-workstation/issues/64). This first slice does not yet support a Git-style batch merge.

### Migration and recovery

`migrate` takes an **exclusive Goose maintenance lock**, refuses a running legacy Compose Goose session, requires the locally installed selected Goose image and typed `MIGRATE` approval. It makes a **full, verified backup** of `ai-workstation_goose-home` in `aiw-agent-goose-legacy-backup` and copies the native `.config/goose`, `.local/share/goose` (sessions) and `.local/state/goose` into the protected `aiw-agent-goose-profile`. Both are Docker volumes; no private tar archive or credentials are written to the Git checkout or logs. Verification compares deterministic TAR SHA-256 sums before marking migration complete. The original home is **not deleted, edited or renamed**. If migration fails, the original is still the source of truth; inspect the incomplete backup/profile before retrying. The implementation intentionally refuses to overwrite them.

`aiw goose sandbox migrate-disable` disables new sandbox creation after typed approval; the original Goose commands still use the untouched legacy volume. It does not delete the backup or previously retained sandbox sessions. To roll back **without any migration command**, simply continue using `aiw goose configure`, `aiw goose session`, `aiw goose check`, `aiw goose inspect` and `aiw goose edit`; those commands still use their original Compose path. The migrated config/history is a **snapshot**; subsequent legacy config edits are not automatically replicated. Native config-root overrides (`GOOSE_PATH_ROOT` and `XDG_CONFIG_HOME`) are refused in this first adapter. Inspect `aiw goose sandbox list` before updating a template.

**History policy:** pre-existing Goose history is copied and remains accessible in the private sandbox session home. New sandbox session history is held with that resumable session, not written back to the legacy home or shared with unrelated sessions. `discard` destroys that session history and its temporary tools; do not discard sessions whose new conversation records you want to retain. This PR does not offer an automatic history merge into the native SQLite store.

## Approved environment catalogue

The versioned `standard` recipe is [containers/agent-sandbox/Dockerfile](../containers/agent-sandbox/Dockerfile). At an explicit operator build, AIW reads the locally selected **Goose image digest**, pulls the pinned `uv` image, pins its digest, adds managed Python 3.12.12 and the already present Git/diagnostics, verifies the resulting tools, and records the local immutable **image ID** (content-addressed SHA-256), source digests, recipe hash and approval timestamp. Image builds never use the project or private config as a Docker build context. No automatic `latest` upgrades occur when starting sessions. Runtime `uv`, `uvx`, Python installs, tool caches and binaries go into the **session's own writable home**, not into a shared directory. `/tmp` remains `noexec`.

To have Goose prepare a reusable variant:

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

Native Windows runs the Linux Goose adapter in **WSL**; this feature does not put new Goose services on the Windows host. Synthetic CI checks run on Ubuntu. Actual current-Goose image build, WSL/Ubuntu operator migration, credential/extension continuity and a Docker end-to-end test require a voluntary **host-side acceptance run**; until then this is not a validated production security feature. The original Goose path remains the recoverable baseline.
