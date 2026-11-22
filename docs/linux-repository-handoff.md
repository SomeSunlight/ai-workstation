# Linux repository handoff — independent release boundary (#78)

Status: **approved for extraction, not yet cut over** (2026-11-18).
This is a migration contract, not a command to install or modify the live host.

## Outcomes, not new abstractions

- **Windows repository** `SomeSunlight/ai-workstation`: native Windows/Speedy services,
  DPAPI, Windows Process Compose, optional WSL image import, Windows desktop shortcuts,
  and **selection of one immutable Linux release**. It must not implement agent
  sandbox lifecycle, NemoClaw policy manipulation, Linux Ansible internals or the
  Hermes TUI.
- **Linux repository** `SomeSunlight/ai-workstation-linux`: portable Ubuntu Linux
  bootstrap, Ansible and rootless Podman, official NemoClaw/OpenShell/Hermes
  orchestration delegated to upstream, and a small discoverable Linux CLI.
  Must run on native Ubuntu without calling `wsl.exe`, PowerShell or the Windows
  registry. No dependency on the Windows/Speedy repository.
- **Operational runtime**: existing `AIW-Nemo` WSL distribution with the existing
  `testhermes01` sandbox, not necessarily a clean install. The repository is
  installation and operator code; the sandbox and secrets are independently
  persisted runtime data.

Keep both tools readable and debuggable; do not add a universal deployment
manager, a second sandbox registry or a third cross-platform monorepo.

## Stable, narrow handoff

| Area | Windows role | Linux role |
| --- | --- | --- |
| Installation | Verify signed/pinned Ubuntu WSL image; select pinned Linux Git commit; invoke Linux `install` | `./install.sh install [--yes]` on Ubuntu |
| Verification | Validate Linux entrypoint and expected contract without interpreting Podman internals | `./install.sh verify` |
| Status | Display distro/revision and relay Linux command output | `./install.sh status` |
| Version | Show own Windows source identity and **which Linux revision is selected** | `--version` reports own release + Git branch/commit/dirty, offline |
| Update | Explicit owner-approved change of the **40-character Linux commit pin** and separate Linux rollout | No implicit pull/fetch during normal menu or status |
| Runtime | Start the Linux operator entrypoint only | Delegate Hermes start/stop/status/recover to `nemohermes` |
| Inference | Existing native Dispatcher/Caddy/Strata, separately managed | Existing operator-approved compatible endpoint, with vendor-managed credentials/policy |

The Linux repository URL and commit SHA belong in Windows configuration, not
hard-coded into its PowerShell entrypoint. The revision MUST be an immutable,
verified commit, **not** an always-moving `main` or the matching Windows branch.
Use one short, versioned CLI/exit-code contract and a narrow CI fixture that
mocks the Linux side. Never run Linux-specific Ansible/Podman CI as part of
ordinary Windows/Dispatcher changes.

Linux's `--version` is **offline**; compare remote revisions only on an explicit
read-only `version check` action, per ContextCanon Development Workflow
CCW-014 and CCW-017. Release labels and Git provenance are different things.

## Extraction inventory (ownership and dependency audit)

Initial Linux candidates from the existing monorepo:

- `bootstrap/linux/`, Linux-specific `ansible/` roles/playbooks/inventory,
  `tools/host-platform.sh`, Linux `install.sh`, NemoClaw
  `bin/aiw-nemo`, and their _Linux-only_ tests.
- `uv.lock`, `pyproject.toml`, Linux Python pins, `config/versions.json`
  split into new Linux-local pins (NemoClaw vendor commit, Ubuntu release,
  Podman, uv/Ansible). New Linux repo has its own release version and CI.
- `docs/nemoclaw-operator.md`, `docs/nemoclaw-recovery.md` and Linux-only
  troubleshooting, audited and scrubbed of hostnames/secrets/private records.

Review **each transitive dependency** before copying. The current
`bootstrap/linux/install.sh` calls the monolithic `bin/aiw` and reads
mixed Windows/Docker/Goose version config. Blindly copying its directory
would produce a non-runnable 'independent' installer. Either replace the
monolithic calls with a focused Linux CLI or migrate only required
functions; then verify in a clean native Ubuntu/WSL environment.

Remain **only** in the Windows repository: `bootstrap/windows/`,
`install-nemoclaw.ps1`, `aiw.cmd`, native Dispatcher/DPAPI/
Process Compose management, WSL imports, the Windows penguin shortcut,
and the immutable Linux-project pin. Delete duplicate Linux code in
Windows **only after** tested cutover, never in the initial extraction.

ContextCanon: create an independent Linux `CONTEXT.src.md` with Linux scope,
its own source pins and generated outputs. The current Windows context
still pins Development Workflow `0.3.0-draft` whereas upstream is
`0.3.9-draft`; use ContextCanon's official `source update/adopt/build`
rather than hand-editing generated `.context` data. Updating a parent
is a separate, reviewable generated-context change.

## Protected migration sequence

1. **Owner creates** the new empty GitHub repository
   `SomeSunlight/ai-workstation-linux` and chooses its visibility.
   This is an explicit ownership/permission action; do not silently
   create another project or commit credentials to it.
2. **Extract** Linux-owned files into the new repo on its own branch,
   revise the monolithic `bin/aiw` / installer dependencies and create a
   fully portable Linux-only `install / verify / status / --version`.
   Run Linux tests there; no Windows checkout required.
3. **Preserve the old live runtime**. Read-only record of sandbox and
   provider identities (`nemohermes list --json`, `testhermes01 status`)
   with sensitive output redacted; export user-owned artifacts and
   validate a documented, restorable, owner-approved backup of workspace
   and necessary credentials **without writing secrets into either repo**.
4. **Side-by-side source trial:** clone the new repo to a *different*
   Linux directory under the same `AIW-Nemo` distribution. Run
   `--version`, `status`, `verify` first. They must not reinstall
   NemoClaw or reset any active sandbox. Keep the old checkout untouched
   for rollback. No simultaneous independent supervisors.
5. **Only after owner acceptance**, point the Windows bootstrap/penguin
   to the new immutable Linux commit and CLI. Test it in a clean
   disposable Ubuntu native/WSL environment, then in the owner's WSL.
   Windows and Linux each display their own independently changing
   version identity.
6. **Lifecycle acceptance:** `testhermes01` status / launch / exit /
   stop / start / launch; confirm local Dispatcher inference, policy
   boundaries, workspace persistence, forwards and error reporting.
   Then separate WSL stop/start and controlled Windows reboot trials.
   A forced crash exercise remains a distinct, explicitly scoped test.
7. **Optional clean reinstall:** owner has explicitly said a new Hermes
   install is acceptable if it materially improves architecture.
   This is a fallback after verified export/backup, **not** permission
   to rebuild/destroy the existing sandbox without a separate cutover
   decision. Never replace `testhermes01` silently.
8. **Retire old code only last:** merge the new Linux repo separately,
   cut over Windows pin, stop referencing monolithic Linux installer,
   then remove unused old files and stale CI from Windows in a reviewable
   PR. Preserve old historical PRs and WSL data until owner signs off.

## Explicit blockers and acceptance

As of 2026-11-18 the destination repository has not been confirmed to
exist. The GitHub connection in this session can change files and PRs,
but **cannot create a repository**. No split can be called 'complete'
until the owner creates the destination and we verify an independently
runnable Linux release and a pinned Windows handoff.

**Acceptance:** changing the NemoClaw policy or Linux launcher requires
no Windows service CI; changing native Windows dispatcher requires no Linux
Ansible/Podman CI. Native Linux works without Windows. The Windows Pinguin
only invokes an explicitly selected Linux commit; does not silently update,
reinstall, rebuild or destroy a sandbox. The old WSL test stays recoverable.


## Fresh WSL provisioning is an AIW operation (2026-11-22)

The original migration included only a read-only Linux handoff. The
owner requires **reproducible fresh installation without manual WSL setup**.
The Windows project therefore reuses the existing pinned-image
`Install-AiWorkstation.ps1` Windows WSL importer, while **all Linux
packages, rootless Podman, NVIDIA NemoClaw/OpenShell and Hermes bootstrap
remain delegated to the independent Linux project**.

From a reviewed Windows PR #85 checkout, one command performs the
side-by-side candidate installation:

```powershell
./install-linux-workstation.ps1 -Action Install
```

Defaults: new WSL `AIW-Nemo-New` at `C:\WSL\AIW-Nemo-New`;
user `moresunlight`. Options `-Action Status` and `-Action Verify`
delegate via the existing immutable-pin Windows/Linux adapter.
Owner can override name and location explicitly; no manually typed
`wsl --install`, `git clone`, Ubuntu package list or standalone
`nemohermes` installation commands are required.

**Install flow:** confirm WSL version, protect registered historical distro
names, require a fresh or AIW-independent-marked target, install the
checksum-pinned Ubuntu 26.04.1 WSL image with the pre-existing monitored
Windows importer, confirm actual guest `ID=ubuntu` and `VERSION_ID=26.04`,
prepare this distribution's user/systemd and small system prerequisites,
fetch `SomeSunlight/ai-workstation-linux` from `config/linux-project.json`
at **exact Git commit** (no branch-following or overwrite of dirty checkout),
then call the Linux project's official `./install.sh install` with its
visible confirmation/sudo prompts. Verify that the Linux checkout, AIW
receipt and NVIDIA vendor CLI build identity match the pin; only after
successful verification generate the new distribution's two penguin
shortcuts. Offer *separate, explicitly chosen* vendor NemoClaw onboarding;
stop Windows transcription for any credential prompts.

**Safety:** no `wsl --unregister`, no automatic Linux distro deletion or
global WSL config overwrite, no sandbox rebuild/destroy, no unauthorized
replacement of `AIW-Nemo`, `Ubuntu-24.04` (productive), or `Ubuntu-26.04`
(historical, internally actually 24.04). An existing WSL installation
cannot be adopted simply because its name or old Nemo profile matches.
An interrupted explicitly marked new install may be resumed after review.

The pin presently selects the exact reviewed **Linux Draft PR #7** commit
`6dc45a81d8f5a305ec9f159584db3e181df83985` for **isolated testing
only**. After successful Linux acceptance and owner squash-merge, update
the Windows pin to the accepted immutable Linux *merge commit*. This
draft Windows PR must not change the owner's active shortcuts or live
old NemoClaw environment until separately accepted. Offline mocked
CI proves source and refusal contracts; real Windows/WSL installation
remains operator-driven.


## Real first-run result and bounded resume (2026-11-22)

The owner's first two AIW imports failed in the Microsoft WSL service with
`RegisterDistro/WSAETIMEDOUT`. **An ordinary Windows restart cleared this
condition.** On the next attempt the monitored Ubuntu 26.04.1 WSL import
succeeded, the Linux user was created and the independent Linux checkout was
pinned to `6dc45a8`. The separate Linux installer then completed all 35
Ansible host tasks (`failed=0`), including **rootless Podman** and official
**NemoClaw v0.0.145** CLI.

The post-install read-only Ansible verification exposed an **AIW-side bug**:
it expected the NVIDIA build identity at
`~/.nemoclaw/source/dist/build-identity.json`, even though we explicitly
install from a source checkout owned by this project at
`~/.local/share/aiw-nemoclaw/source/dist/build-identity.json`.
NVIDIA's `scripts/install.sh` v0.0.145 builds the CLI within the source
checkout when invoked there. The corrected Linux
[Draft PR #7](https://github.com/SomeSunlight/ai-workstation-linux/pull/7)
uses this actual path in recovery and verification, and its offline
regression tests both matching and mismatched build revisions.

**The new WSL is valuable and must NOT be reinstalled.** With the refreshed
Windows PR #85 code, the *same* entrypoint
`./install-linux-workstation.ps1 -Action Install` continues the
interrupted installation:

- Allow **only** a clean, correct-origin existing AIW Linux checkout whose
  HEAD is the explicitly reviewed prior candidate
  `6dc45a81d8f5a305ec9f159584db3e181df83985`.
- Fetch and detach to the immutable corrected Linux PR #7 Git commit
  from `config/linux-project.json`; reject any unrelated or dirty HEAD.
- If an AIW NemoClaw installation receipt exists, run the **read-only**
  Linux verifier **first**. On success, preserve Podman and NVIDIA CLI,
  register only the missing user-local `aiw` command, reverify via pinned
  Windows handoff, and then create the new penguin shortcuts.
- If the existing installation does **not** verify, **stop**. Never
  automatically reinstall, rebuild, destroy, migrate or upgrade a
  previously installed vendor runtime. A completely new host without
  a vendor receipt still follows the existing explicit installation path.

Real-world completion of this resumed verification and first Hermes
onboarding is still pending owner acceptance. The immutable candidate pin
is for side-by-side test only; repin after the accepted Linux squash-merge,
then separately review Windows production cutover.
