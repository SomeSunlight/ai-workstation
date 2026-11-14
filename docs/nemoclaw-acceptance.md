# NemoClaw + Hermes: owner's acceptance checklist

**Draft PR:** [NemoClaw reference environment](https://github.com/SomeSunlight/ai-workstation/pulls) · **Issue:** [#75](https://github.com/SomeSunlight/ai-workstation/issues/75)

**Date:** ________ · **Host:** ________ · **AIW commit:** ________ · **NemoClaw commit:** `82e1ad7474ec7175c5b860b2bfa9d7940bc6e75f`

Check boxes in this Markdown file or print it. A check means you actually observed the behavior on the target machine, **not** merely that a command returned 0 in CI. Note deviations below each section.

## A. Before installing

- [ ] The previous WSL distributions, their names and available disk space have been recorded; original Docker images/volumes, projects and OpenShell data are backed up if important.
- [ ] The new `AIW-Nemo` name and `C:\WSL\AIW-Nemo` directory are unused (or clearly belong to our previous partial install).
- [ ] Windows 11, WSL2, Ubuntu 24.04 image download and Linux sudo permissions are available; **no Docker Desktop** is installed or requested.
- [ ] Company policy permits WSL2, Docker Engine and processing only *approved test data*. OpenRouter testing will use synthetic data.
- [ ] At least 20 GB extra disk and 8 GB usable RAM exist, preferably 40 GB and 16 GB.
- [ ] The Git branch is the intended PR branch and the new `install-nemoclaw.ps1` is being executed from that checkout.

**Notes / blockers:**

## B. Windows installer & first reboot

- [ ] Running the AIW Nemo installation script creates exactly **one** new Ubuntu distro `AIW-Nemo`; no reinstall or unregister of existing distros.
- [ ] New distro uses the expected **hash-verified Ubuntu 24.04.4 image** and **systemd**.
- [ ] New Linux user is configured; the repository is cloned on the **Linux filesystem**, not under `/mnt/c`.
- [ ] Global Windows `.wslconfig` and default distribution settings are unchanged; prior WSL distributions still start.
- [ ] Two older penguin shortcuts remain untouched; exactly **one new** NemoClaw/Hermes shortcut exists on the Desktop and one in the Start Menu.
- [ ] The new shortcut displays a **penguin with claw and Hermes insignia**, starts only `AIW-Nemo`, and displays its dedicated Nemo menu.
- [ ] The Linux installation log path is shown and safe to share after redacting environment details; passwords/API keys are not printed.

**Notes / blockers:**

## C. Idempotent Docker Engine and NemoClaw

- [ ] Ubuntu is 24.04 and its Docker daemon, Compose plugin and Buildx plugin all pass verification.
- [ ] Docker Engine is **native inside WSL**; `docker info` points to that daemon, not Docker Desktop or the old Ubuntu.
- [ ] Installed Docker package versions match `config/versions.json`; no old Docker Engine was removed.
- [ ] The NemoClaw source checkout is at the **recorded immutable Git SHA**.
- [ ] `nemohermes --version` works; optional NVIDIA telemetry is disabled in the AIW menu and installer.
- [ ] **Second run of the same AIW script** succeeds, reuses the registered distro, does not install/upgrade NemoClaw again, and does not create duplicate shortcuts.
- [ ] Changing the recorded NemoClaw SHA without an explicit upgrade plan refuses silently overriding live state (can be checked offline before real production data).

**Notes / blockers:**

## D. Official NemoClaw onboarding with OpenRouter

- [ ] The **official NemoClaw Hermes wizard** starts from the new penguin menu or the installer prompt.
- [ ] It does **not** force Windows-host Ollama / Docker Desktop or install separate standalone OpenShell through AIW.
- [ ] OpenRouter provider is selectable, one working model is selected, credentials are supplied only to the official private wizard.
- [ ] The wizard creates **one** new Hermes sandbox and its OpenShell gateway with the expected policies. No unreviewed broad local mounts.
- [ ] NemoClaw shows the Hermes sandbox status; connection to Hermes works and the agent responds using OpenRouter.
- [ ] The Hermes workspace accepts a harmless Markdown test file and can read it.
- [ ] A harmless terminal test creates a Python file, runs it, and displays the result. No uncontrolled host writes.
- [ ] Interrupting an onboarding step (synthetic/empty sandbox only) and choosing **Resume onboarding** works without deleting unrelated state.

**Notes / blockers:**

## E. Persistence, safety and portability

- [ ] Stop/start or Windows WSL restart retains files in Hermes's own sandbox.
- [ ] A deliberately small harmless HTTPS request is allowed only according to the chosen effective OpenShell policy; a disallowed domain/request is blocked or asks for approval.
- [ ] Host Docker socket, Windows files outside explicit exports and unrelated WSL distro data are **not available** to Hermes.
- [ ] Inference credentials are not exposed in Hermes environment, shell history, project Git, diagnostic logs or downloaded files.
- [ ] A test Git project with Markdown context and a trivial change is handled through standard **CLI**, not a required MCP bridge.
- [ ] NemoClaw's documented snapshot/rebuild or backup/restore operation is tested against **synthetic data**; full recovery of conversation and sandbox state is confirmed or documented as a gap.
- [ ] No accidental knowledge transfer takes place between business and private installations or cloud providers.

**Notes / blockers:**

## F. Local models, second host and exit criteria

- [ ] NemoClaw's provider-selection flow identifies how to connect the OpenAI-compatible Llama Dispatcher without sending tokens through a public service unnecessarily.
- [ ] If access to the Windows Dispatcher is blocked, the required OpenShell/OpenAI-compatible endpoint rule is explicitly reviewed and approved; no automatic relaxation.
- [ ] The **same Linux installer and Ansible profile** can configure the private host (native Ubuntu or separate WSL2), with different local data and credentials.
- [ ] Hermes can read and extend project-local `AGENTS.md`, architecture documents and ContextCanon-produced Markdown without modifying ContextCanon generated files unintentionally.
- [ ] The old Goose/OpenShell project remains available as a fallback until NemoClaw passes acceptance.
- [ ] No data cleanup, deprecated-service deletion, default distribution switch or merge has occurred before explicit approval.

## Decision

- [ ] **Accept** NemoClaw/Hermes as the candidate reference architecture for this machine.
- [ ] **Keep as experimental**; repeat the failed checks.
- [ ] **Reject/rollback** the new approach without touching older WSL installations.

**Problems, error excerpt (without secrets), links, or suggested PR fixes:**

```text
```

**Operator decision and date:** ______________________________
