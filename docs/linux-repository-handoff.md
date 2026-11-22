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


## Real interrupted-install resume log #04 — Windows output/exitcode separation

After Linux PR #7's corrected NVIDIA identity-check pin was adopted, Windows
AIW successfully advanced **only** the reviewed Linux checkout
`6dc45a8` -> `7c858a6`, preserved the existing Ubuntu 26.04 user/systemd
configuration and found the NemoClaw install receipt. The following read-only
`verify` returned only a Node SQLite experimental warning in the Windows
transcript, followed by a misleading failure message.

A source-level review identified a PowerShell **output-channel bug**:
`Invoke-Wsl -AllowFailure` forwarded native `wsl.exe` standard output to
its PowerShell success stream **and also** returned the numeric exit code.
The caller's `$verifyCode` therefore became an array when Linux printed
normal status. PowerShell's array `-ne 0` comparison then yielded nonzero
string elements even with a final native exit code of 0. This explains both
the hidden Linux result and the reported error; the old log does not allow
recovering the actual native exit code conclusively.

In Windows Draft PR #85 the helper now streams native stdout to the
operator/installer log with `Out-Host`, and returns only the native numeric
code. An isolated mock regression executes that helper with Linux text plus
both exit `0` and exit `17`, ensuring the two pathways cannot be confused.
The synthetic test resets its own mocked `LASTEXITCODE` before exiting.
No WSL service, Linux package, runtime or sandbox lifecycle action is
performed by the offline regression. Re-run the **same** Windows AIW installer
from the updated draft PR after CI; if the guest verifier actually returned a
nonzero exit code, its diagnostic output will now be visible and AIW will
still stop without automatic vendor reinstalls.


## Onboarding preflight #05 — reused historical no-GPU resolution (22 Nov 2026)

The owner chose `Y` for first Hermes onboarding after the **new** Linux
host had verified successfully. NVIDIA NemoClaw `v0.0.145` stopped at
`[1/8] Preflight checks`: Ubuntu 26.04 host-release qualification
**warning** plus `NVIDIA Container Toolkit is missing` **blocking**
GPU integration finding. The Windows launcher claimed
`GPU passthrough is disabled (--no-gpu)` but accidentally invoked the
official `nemohermes onboard` command **without** passing `--no-gpu`.

This is a **regression of a previously resolved configuration**:
On 15–16 Nov the initial WSL native-Docker attempt hit the same toolkit
finding; passing `--no-gpu` correctly bypassed the irrelevant GPU gate
for remotely served models, revealing the separate **native Docker in
WSL** qualification problem. The subsequent Ubuntu 26.04 + native
rootless Podman 5.7 host was able to onboard Hermes and successfully
complete gateway/OpenRouter smoke testing. CUDA/CDI was unnecessary for
that mode. No GPU toolkit installation is authorized here. Local
Windows dispatcher inference likewise does not require GPU passthrough
into the Hermes sandbox.

The existing *Linux* operator at pinned checkout
`bin/aiw-nemo onboard` already implements the reviewed solution:
`NEMOCLAW_GATEWAY_RUNTIME=podman`, `NEMOCLAW_NO_EXPRESS=1`,
`vendor_hermes onboard --no-gpu "$@"`, and rootless socket preflight.
**Root cause:** the *Windows* onboarding prompt bypassed this Linux
operator and called the vendor CLI directly.

**Correction in Windows Draft PR #85:** Windows delegates both first
and resumed onboarding via `/bin/bash <pinned Linux checkout>/bin/aiw-nemo
onboard [--resume]`, preserving `--no-gpu` through the existing
Linux-owned profile without redundant Windows-side policy. Windows
still stops transcript before official credential prompts. New Windows
offline regression rejects the previous direct vendor bypass.
No previously installed Linux runtime, distro or sandbox is modified.

NVIDIA v0.0.145's host-readiness source treats Ubuntu releases other
than 24.04 as **warning** (`host.os.release_unqualified`), not a
standalone fatal failure. Its onboarding admission policy explicitly
waives GPU-toolkit/CDI findings for CPU-only `--no-gpu` intent.
**Remaining acceptance risks:** actual v0.0.145 onboarding and
gateway/sandbox restart persistence under Ubuntu 26.04 + rootless
Podman require live owner validation. The prior missing loopback alias
`169.254.2.2/32` after Windows restart is a separate unresolved
lifecycle/network issue; this preflight fix makes no claim to solve it.


## 2026-11-23 — Live Windows reboot acceptance and safe shell-penguin handoff

The separate `AIW-Nemo-New` distro now runs official NemoClaw v0.0.145,
rootless Podman/OpenShell and Hermes sandbox `testhermes04`. After the
first install-only verifications passed, the optional onboarding exposed
a missing `--no-gpu` argument in our Windows wrapper. The fix delegates
to Linux-owned `aiw-nemo onboard` instead. Because upstream onboarding
aborted before naming its first sandbox, the **owner** completed the
special case with `./bin/aiw-nemo onboard --resume --name testhermes04`.
Do not add a general Windows resume-name recovery engine for this
already finished initial setup.

The owner rebooted Windows while that sandbox was running, without
stopping it first. The same named sandbox was still present with phase
`Stopped` and preserved workspace, the user-systemd gateway and Podman
socket active, and vendor-required `169.254.2.2/32` missing from `lo`
again. The existing Linux operator only offered a vendor-equivalent
repair **with explicit approval**, checked the host address, and
delegated sandbox start. Owner reports the *same* Hermes sandbox in
operation afterwards, including a new model answer. This is a real
full Windows reboot recovery **with manual preparation**, not evidence
that NemoClaw automatically fixes the route on boot or that crashed
databases and historical OpenShell Error sandboxes were recovered.
Vendor follow-up: [Linux issue #3](https://github.com/SomeSunlight/ai-workstation-linux/issues/3).

The last Windows shortcut defect: `AIW-Nemo-New` originally launched
from `~/ai-workstation` instead of the independent checkout
`~/ai-workstation-linux`; the owner used a direct `wsl.exe` launch
to bypass it. The branch must not resurrect the obsolete one-penguin
auto-menu while merging `main`: merged Windows PR #84 defines **two
genuine interactive WSL Linux shell penguins** for workbench and home.
Windows PR #85 now supplies the workbench dir from the immutable
Linux manifest, preserves the existing home-mode and old WSL shortcuts,
and exposes a `Shortcuts`-only repair. From the Windows PR checkout:

```powershell
./install-linux-workstation.ps1 -Action Shortcuts
```

This action only regenerates owned Windows links / launcher copies. It
does **not** reinstall Linux packages, update source or NemoClaw,
re-onboard Hermes, destroy sandboxes, or start old distributions. Start
the workbench penguin and type `aiw` in its real Linux shell.
The final two-penguin behavior requires owner acceptance after PR CI.

**Release train:** first owner squash-merge Linux PR #7. Replace the
Windows manifest's Linux candidate SHA with that **new Linux main
squash commit**, rerun Windows CI, and only then owner squash-merges
Windows PR #85. Preserve old distributions until explicit separate
cleanup authorization; do not combine with the separate NVIDIA
upstream bug task.


## 2026-11-23 — Post-squash pin reconciliation (merge order reversed)

The owner squash-merged **Windows PR #85 first** (Windows `main` commit
`777a07054add9fecdd0209efdae61751a9a81293`), then **Linux PR #7**
(Linux `main` commit
`d4020aa2da26597c8c1eb2a81f9346cccc47a723`). Both merges
succeeded; only the cross-repository immutable Git pin remained pointing
at the pre-squash Linux candidate
`7c858a6daac83af01bed727c6c4c437f5f5d81f5`.

**No broken runtime:** `AIW-Nemo-New` and the operational Hermes sandbox
`testhermes04` are unaffected. The Linux source checkout can still be at
its original detached candidate revision; the strict Windows read-only
adapter will correctly reject it once the immutable pin is changed.

This narrowly scoped follow-up changes only the Windows Linux manifest
and pin assertions. The new pin is the **actual Linux `main` squash
commit**, with `resumeFromCommit` set to the **single known installed
old candidate**. The installer already performs all of the needed
checks: isolated distro identity, expected origin, clean working tree,
exact old SHA, explicit fetch of exact new SHA, then strict verification
of the result. Other old/unrecognized or dirty source checkouts remain
blocked. The pinned source files for NVIDIA Ansible install, verifier,
Linux operator and version metadata were compared by Git blob identity;
**all are identical** before/after the Linux squash. Only release-history
and documentation changed. This is not a NemoClaw/OpenShell or Podman
upgrade.

**Owner action only after the follow-up PR is squash-merged** and the
Windows checkout is refreshed. A read-only `-Action Verify` is *not*
the first step, because it correctly rejects the pre-squash SHA. Instead
invoke the existing bounded installer with NVIDIA onboarding disabled:

```powershell
cd C:\\Services\\AI\\ai-workstation
git switch main
git pull --ff-only origin main
.\\install-linux-workstation.ps1 -Action Install -SkipOnboarding
```

This uses the reviewed one-time clean source pin migration, then
read-only Linux host verification, user-local CLI registration and
shortcut refresh. The existing NVIDIA install receipt means no
vendor-package reinstall or re-onboarding is authorized. It may still
inspect and preserve the known WSL distro configuration as usual; it
will **fail closed** if the checkout is dirty or unrecognized. It must
not unregister any distro, mutate the `testhermes04` sandbox, or
silently start another Hermes onboarding session. The owner can choose
to do the bounded checkout migration later; there is no reason to
interrupt a running Hermes session merely to change Git metadata.

Do not delete or migrate the old `Ubuntu-24.04`, `Ubuntu-26.04` or
`AIW-Nemo` distributions. The separate NVIDIA Podman gateway-loopback
upstream issue remains open in Linux Issue #3.
