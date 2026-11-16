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

## Owner finding 2026-11-16: native Docker WSL platform gate

A second real owner flight confirmed that `nemohermes onboard --no-gpu --resume` **is executed as designed**, and all existing Docker/NemoClaw installation checks are idempotent. However NVIDIA/NemoClaw **0.0.144** now stops at a separate platform check: `Native Docker Engine inside WSL is not the qualified Docker Desktop integration`. The continuing NVIDIA Container Toolkit/CDI advice is a secondary GPU diagnostic, not the blocker. Installing CUDA/Toolkit cannot satisfy this runtime qualification. **No Hermes/OpenRouter sandbox was admitted.**

For this pinned NemoClaw version, AIW now refuses this exact upstream-unqualified WSL/native-Docker combination before launching the interactive agent wizard and shows [Issue #77](https://github.com/SomeSunlight/ai-workstation/issues/77). This makes the limitation visible without repeating the lengthy idempotent host installation or inventing a host-level fix. The host and earlier WSL data remain intact. Do not patch out upstream host admission or claim production readiness for an unsupported runtime.

The current reference-architecture evaluation is **Ubuntu 26.04.1 LTS + rootless Podman 5.7**, both packages from official Ubuntu repositories. NemoClaw explicitly offers a qualified *rootless Podman* WSL provider, selected with `NEMOCLAW_GATEWAY_RUNTIME=podman`. Its upstream preflight requires **Podman >=5**; Ubuntu 24.04 official Podman is only **4.9.3**, so simply installing it in the existing AIW-Nemo will fail again. The exact extent of WSL Podman + Hermes + OpenRouter support is **not yet verified**; physical end-to-end qualification is limited. Ubuntu 26.04 NemoClaw's own Linux CI currently validates installer/CLI contracts but not the full OpenShell/Podman runtime. Before migrating, define a separate, reviewed, idempotent image and rootless Podman Ansible profile and test it in an independent WSL distribution; preserve the existing AIW-Nemo image until an explicitly approved retirement. See [Issue #77](https://github.com/SomeSunlight/ai-workstation/issues/77) for the acceptance gates and official source references.

### Remote-model (OpenRouter) mode: GPU disabled

**The AIW Hermes menu explicitly calls `nemohermes onboard --no-gpu`, including `--resume`.** This is a deliberate, stable first-test default, not a guess based on missing GPU binaries. Docker's `CDISpecDirs` may be configured even when this WSL installation has no `nvidia.com/gpu` CDI devices: NemoClaw would otherwise stop at preflight and propose installing NVIDIA Container Toolkit. For OpenRouter, **do not install NVIDIA Container Toolkit or NVIDIA CUDA solely to satisfy that check**. GPU passthrough and local NVIDIA inference require a later explicit profile and review.

A Windows host with a suitable NVIDIA GPU can expose CUDA inside WSL through its Windows NVIDIA driver, and NVIDIA Container Toolkit can expose it to Docker containers. This is *not* an intrinsic WSL restriction; it simply has no role in this remote-inference test. The older AIW/OpenShell Docker Engine path never provisioned NVIDIA Container Toolkit.

In a real installation test on 2026-11-15/16, pinned Ubuntu, Docker 29.6.1, Compose 5.3.0, Buildx and NemoHermes CLI 0.0.144 passed. The first `nemohermes onboard` stopped at the generic Docker/CDI probe **before** the provider or Hermes sandbox was created. The vendor output explicitly suggested `--no-gpu`. After updating the Windows checkout to this PR head, **rerun the same `install-nemoclaw.ps1`**: it advances the in-WSL Git checkout, checks the already provisioned Nemo environment, then offers to launch the CPU-only official wizard. No manual `nvidia-ctk` or WSL repair commands are required. The owner's CPU-mode onboarding result is not yet known.

### Windows WSL image import progress

The native Windows `wsl.exe --install --from-file` command formerly blocked the AIW console for an unknown duration without progress output. AIW now runs that *one* import as an observed subprocess: it reports elapsed wall-clock time and child PID every 15 seconds, virtual-disk size where detectable, and saves stdout/stderr logs separately. Its stdin is explicitly empty so an interactive prompt cannot silently demand a Return. The operation is **not** automatically terminated by a timeout, which would risk corrupting an in-progress WSL registration. An error leaves the target for diagnosis rather than deleting or reimporting it.

The first owner log shows the import was initiated in the Windows install started at 22:29, and the Linux installer log started at 00:18. The log has no per-command timestamps and cannot prove whether pressing Return released the import or merely coincided with its completion. No timing/success claim should be inferred from that observation.

The Windows installer also skips rewriting `/etc/wsl.conf` and **does not terminate a running NemoClaw distro** when systemd and its default user already match the intended configuration. The legacy installer retains its existing behavior.

**Defer-onboarding means the agent/gateway/provider is not fully configured by Ansible.** The same installation script offers to run the **official** interactive `nemohermes onboard` wizard when the CLI installation succeeds. The separate mascot launcher also exposes **Set up Hermes**, **Resume interrupted onboarding**, **Connect to a named sandbox**, and **Verify host**. Choose **OpenRouter** during the wizard and enter the API credential *there*, never in AIW configuration, source code, logs, Git or an answer pasted into chat.

Use NemoClaw's own CLI and documentation for agent management, snapshots, model changes and network policy. Do **not** also install standalone OpenShell or change its gateway through the old AIW adapter.

Native Ubuntu hosts can execute `./install.sh install --yes --profile nemoclaw` in their own AIW Git checkout; the same Ansible roles/versions and Linux front desk apply, without WSL or Windows shortcuts.

## Known limitations and security

WSL2 distributions share a Linux VM/kernel and can contend for host-visible network ports. A third Ubuntu distro isolates files and its Docker daemon, but is **not** a full independent VM. A gateway already listening on a port in an earlier WSL distro can conflict. NemoClaw documents a managed automatic alternate gateway-port selection; allow its official onboarding to assess this rather than launching another OpenShell gateway or modifying the old distro manually. If ports clash, record the precise symptom and stop.

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
