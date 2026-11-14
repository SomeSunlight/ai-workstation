# NemoClaw reference environment: one new penguin

**Status:** experimental, owner acceptance required. See [Issue #75](https://github.com/SomeSunlight/ai-workstation/issues/75). This is **not** a migration of the existing AIW Goose/OpenShell environment and does not install Docker Desktop.

## Goal and responsibility

One independent Ubuntu 24.04 environment, reproducible under WSL2 and native Ubuntu Linux:

| Component | Responsible for |
| --- | --- |
| AIW **Windows installer** | Creates **only** the selected new WSL distro, user, repository checkout and one mascot shortcut; never unregisters existing WSL systems |
| AIW **Ansible** | Installs pinned Ubuntu bootstrap prerequisites and **open-source Docker Engine** from Docker's official Ubuntu APT repository; installs pinned upstream NemoClaw CLI |
| **NemoClaw** | Creates/manages OpenShell, Hermes, images, providers, policies, lifecycle and backup/rebuild |
| **Hermes** | Uses CLI tools, develops architecture/code, reads project Markdown |
| **Markdown and Git** | Canonical portable knowledge; business and private files live in separate systems, never copied automatically |

The optional `install-nemoclaw.ps1` is the single **Windows entry point**. It reuses the well-tested, checksum-verified Ubuntu 24.04.4 WSL image in `config/versions.json` and the legacy Windows WSL bootstrap without invoking the old Linux Goose/Open WebUI roles.

The newly registered distribution defaults to **`AIW-Nemo`**, stored in **`C:\WSL\AIW-Nemo`**. The original `Ubuntu-24.04` and any second research distributions are **left in place**, including their Docker images, volumes and OpenShell configurations. A marker in `/etc/aiw-install-profile` prevents the new installer from silently adopting an unrelated pre-existing WSL distro under the requested name.

The profile deliberately does **not** rewrite the globally shared `%USERPROFILE%\.wslconfig`, update WSL when WSL is already available, install Docker Desktop or change the default Windows WSL distro. A separate **NemoClaw Hermes (AIW-Nemo)** shortcut appears on the Windows Desktop and Start Menu. It opens the AIW Nemo front desk, not the legacy Goose menu.

## How to use it

In a checkout of the new AIW branch, open **PowerShell 7** and run the repository's **`install-nemoclaw.ps1`** once. Reopen and rerun exactly that script on failure: it detects the already-registered distribution and reuses Docker and the NemoClaw installation. Administrator permission may be required for new WSL registration; a Linux password/sudo prompt is expected.

The script checks out the **same Git branch** in the new WSL distro. The current branch is read from Git automatically (or explicitly set using `-RepositoryRef`); you do not need to remember WSL commands.

| Script action | Behavior |
| --- | --- |
| `Install` (default) | New WSL distro if missing, Ubuntu user, Git checkout, Ansible Docker Engine, pinned NemoClaw CLI, one shortcut; then **offers** the official Hermes onboarding |
| `Status` | Read-only state of chosen distribution and Nemo host |
| `Verify` | Read-only Ubuntu/Docker/pinned NemoClaw checks |
| `Shortcuts` | Recreate **only** the new NemoClaw shortcut without recreating the distro |

The upstream install stage is explicitly version-pinned to NVIDIA/NemoClaw Git commit `82e1ad7474ec7175c5b860b2bfa9d7940bc6e75f`; it uses the upstream `scripts/install.sh --defer-onboarding` with `NEMOCLAW_AGENT=hermes`, disables Express (which would prefer a Windows-host Ollama path), and disables optional NemoClaw telemetry. The upstream installer is still able to download dependencies and to install or upgrade **its own OpenShell** components; this is why the new distribution must be independent and empty.

**Defer-onboarding means the agent/gateway/provider is not fully configured by Ansible.** The same installation script offers to run the **official** interactive `nemohermes onboard` wizard when the CLI installation succeeds. The separate mascot launcher also exposes **Set up Hermes**, **Resume interrupted onboarding**, **Connect to a named sandbox**, and **Verify host**. Choose **OpenRouter** during the wizard and enter the API credential *there*, never in AIW configuration, source code, logs, Git or an answer pasted into chat.

Use NemoClaw's own CLI and documentation for agent management, snapshots, model changes and network policy. Do **not** also install standalone OpenShell or change its gateway through the old AIW adapter.

Native Ubuntu hosts can execute `./install.sh install --yes --profile nemoclaw` in their own AIW Git checkout; the same Ansible roles/versions and Linux front desk apply, without WSL or Windows shortcuts.

## Known limitations and security

**WSL2 with Docker Engine running directly inside Ubuntu is not the formally NVIDIA-qualified WSL path.** NVIDIA's WSL qualification focuses on Docker Desktop's WSL backend or supported rootless Podman. OpenShell already worked once with native Docker in the research environment, but that does **not** prove NemoClaw/Hermes onboarding. If upstream preflight refuses the configuration, stop and capture the log; no automatic switch to Docker Desktop or alteration of existing distros is permitted.

Docker group membership confers **root-equivalent control of the new Linux Docker host**. All agent-executed code belongs in OpenShell's separate sandbox, never on the privileged WSL/Docker host. File access inside an approved work area and approved inference/network endpoints can still leak data. Do not send corporate/confidential documents to OpenRouter unless expressly approved under the relevant data-processing rules.

The upstream NemoClaw installer is executed without application secrets, pinned by Git revision and without piped curl-to-bash. It downloads npm packages and external OpenShell artifacts, which must be assessed in the owner test. Updating the pin is a **reviewed PR**, never an implicit update during reinstall. Once NemoClaw is installed, its own managed state must not be destroyed, repaired or migrated by AIW.

The first test requires at least **8 GB available RAM** and ~20 GB free disk; 16 GB RAM and ~40 GB free disk are recommended by NVIDIA, in addition to the old distros and their volumes. WSL memory configuration is shared globally and intentionally **not changed by this profile**.

Existing installer actions and `./install.sh install` remain the **legacy** installation route; `--profile nemoclaw` is explicitly opt-in. Nothing is merged, deployed, unregistered or removed by authoring this Draft PR.

## Owner verification

Use the editable checklist in [NemoClaw acceptance checklist](nemoclaw-acceptance.md) after the first installation. Record failed steps and rerun the same installer after fixes, rather than issuing manual command sequences. The checklist is the boundary between offline GitHub CI qualification and actual WSL/agent acceptance.

Upstream references:
- [NemoClaw prerequisites](https://docs.nvidia.com/nemoclaw/latest/user-guide/hermes/get-started/prerequisites)
- [NemoClaw Hermes quickstart](https://docs.nvidia.com/nemoclaw/latest/user-guide/hermes/get-started/quickstart-hermes)
- [Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
