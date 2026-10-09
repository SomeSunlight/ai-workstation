# AI Workstation

**Rebuild a complete AI-capable Linux workstation on a supported Windows laptop — without days of manual setup.** One repeatable PowerShell entry point handles Windows/WSL provisioning and hands off to automated Linux installation. Useful for a new computer, a hardware replacement, or a corporate laptop that has been completely reset.

The goal is a **fast, reproducible start-to-finish installation**, across supported hardware, with minimal Linux/Docker expertise:

1. **Windows bootstrap:** `install.ps1` checks/configures WSL 2, the Ubuntu distribution and Windows integration (including launchers), with guided elevation and restart handling where necessary.
2. **Inside WSL:** the Linux bootstrap and Ansible set up the host toolchain and Docker; AI Workstation installs its managed runtimes and provides the `aiw` command/menu for Goose and Open WebUI. Optional host-local `llama.cpp`/Llama Dispatcher setup is available separately.
3. **Daily operation:** choose tools from the menu or use the same `aiw ...` commands directly. Re-run the installer safely after interruption; the Git repository remains the reproducible installation specification.

You should not have to reconstruct a working Docker/WSL stack with dozens of ad hoc commands and LLM conversations after a laptop reset. **The installer rebuilds software, not deleted personal data:** restore secrets, user-owned workspaces, models and persistent volumes from their backups. Company security policies, Windows/WSL downloads, reboots and hardware-specific GPU prerequisites can still require attention; installation time varies.

### Two desktop shortcuts, one Ubuntu environment

| Windows shortcut | Opens the same WSL distribution in | Best for |
| --- | --- | --- |
| **Linux AI Workstation** | `/home/moresunlight/ai-workstation` | Managing/updating the installation or running `aiw` |
| **Linux Terminal** | `/home/moresunlight` | General Linux work outside the project |

Both are created on the Desktop and in the Start Menu. Neither starts another Ubuntu instance or automatically launches an AI application. See [Where to find it later](#where-to-find-it-later) for re-creating launchers and troubleshooting.

## Quick start

Clone the repository on Windows, then run the installer from PowerShell 7:

```powershell
git clone https://github.com/SomeSunlight/ai-workstation.git
cd ai-workstation
.\install.ps1
```

`Install` needs administrator rights for WSL setup and host-level changes. If
PowerShell is not already elevated, the installer opens a UAC prompt and starts
a separate elevated PowerShell window. Watch that elevated window; it stays open
after the installer finishes so progress, errors and the log path remain
visible.

The installer may request:

1. a Windows restart;
2. a Linux password for the `moresunlight` user;
3. the Linux sudo password during host installation.

The installer is designed to be rerun until everything is present. It does not
unregister or delete existing WSL distributions.

## Human-friendly entry point

After installation, every new WSL boot shows a short reminder:

```text
AI Workstation ready

  aiw              Open the interactive tool menu
  aiw status       Show the complete system status

Available tools: Goose, Open WebUI
```

Run one command to discover everything else:

```bash
aiw
```

The interactive menu provides Goose workspace selection, Open WebUI lifecycle
commands, status, update and help. Direct commands remain available for scripts,
documentation and troubleshooting.

## Learn the commands behind menu actions

The menu is a starting point, not a requirement. To learn the equivalent commands
you can run later yourself, choose **Configure AI Workstation (edit YAML settings)**
in the main `aiw` menu. Your Linux editor opens:

```text
~/.config/ai-workstation/config.yaml
```

Change the documented option to:

```yaml
# Show each actionable menu command and require explicit y/Y before running it.
menu_command_preview: true
```

After that, selecting an action shows its direct CLI equivalent, shell-quoted if
necessary, e.g. `aiw open-webui restart`, followed by `Continue? [y/N]`.
Press `y` to run it or `n`/Enter to cancel. Menus, editor access and direct
non-menu `aiw ...` invocations work normally. Existing operation-specific
confirmation prompts may still appear. The preview intentionally teaches the
public `aiw` command, not every internal Docker/Ansible subprocess.

The settings are private to your Linux user, survive WSL restarts, and are not
overwritten by installation updates. Set the option back to `false` to turn
the mode off. If no explicit editor is configured, Ubuntu's `sensible-editor`
is used; you can select your preferred editor via `select-editor` or
`VISUAL`/`EDITOR`.

## Update Open WebUI or Goose

Open a WSL terminal in **any directory** and run `aiw`. Choose:

```text
Standard tools -> Open WebUI / Goose -> Update application -> Latest stable official release
```

The menu shows the current selection and target version, asks before applying it,
and performs the Docker steps. Open WebUI data is backed up before the service is
recreated; Goose uses the new image in the next session. See
[Application updates](docs/container-updates.md) for details and recovery.

`aiw update` updates the workstation repository and host installation. Application
updates are separate; pulling an existing pinned image alone does not select a
new version.

## Check the current installation state

`Status` and `Verify` do not require an elevated PowerShell window for ordinary
use:

```powershell
.\install.ps1 -Action Status
.\install.ps1 -Action Verify
```

Inside Ubuntu:

```bash
aiw status
```

## Configure the shared OpenRouter key

Goose and Open WebUI use the same Git-ignored `.env` file:

```bash
cd ~/ai-workstation
aiw goose init
nano .env
```

Set at least:

```dotenv
OPENROUTER_API_KEY=replace-with-your-key
GOOSE_MODEL=provider/model-id
```

The `.env` file is ignored by Git and changed to mode `600` by `aiw`. Do not put
credentials in `.env.example`, Compose files, images or commits.

## Goose: explicit isolated workspaces

A Goose session never receives the complete WSL home directory. Each session
starts a short-lived container and mounts exactly one registered workspace
read-write. The container is removed when the session ends; Goose state and
session history remain in the persistent `goose-home` volume.

The repository is registered automatically as the first workspace:

```text
ai-workstation -> /home/moresunlight/ai-workstation
```

Manage additional workspaces through the menu or direct commands:

```bash
aiw goose workspace add confluence-dump ~/projects/confluenceDumpWithPython
aiw goose workspace list
aiw goose workspace remove confluence-dump
```

Start Goose through the interactive chooser:

```bash
aiw
```

Or directly:

```bash
aiw goose session ai-workstation
aiw goose session ai-workstation --resume
aiw goose run ai-workstation --text "Inspect this repository and summarize its architecture."
```

Before every interactive session, `aiw` prints the selected host path, the
container path, the access boundary and the most useful Goose slash commands.

Other Goose commands:

```bash
aiw goose init
aiw goose status
aiw goose pull
aiw goose update
aiw goose version
aiw goose help
```

## Open WebUI

Open WebUI runs as a persistent Docker service. No Linux desktop GUI is needed:
the Windows browser connects to the service through WSL localhost forwarding.
The default address is:

```text
http://localhost:3000
```

Start it through the interactive menu:

```bash
aiw
```

Choose:

```text
Open WebUI -> Start and open in Windows browser
```

Or use direct commands:

```bash
aiw open-webui init
aiw open-webui pull
aiw open-webui update
aiw open-webui up
aiw open-webui open
aiw open-webui status
aiw open-webui logs
aiw open-webui restart
aiw open-webui down
```

The service:

- uses the pinned official Open WebUI image;
- binds only to `127.0.0.1` on the WSL host;
- persists accounts, chats, settings and knowledge data in a named Docker volume;
- connects to OpenRouter through the shared API key;
- disables the unused Ollama connection for this phase;
- does not receive the Docker socket or a host workspace.

On the first browser visit, create the initial account. The first account becomes
the administrator. Configure later provider details and model visibility in the
Open WebUI Admin Panel; settings stored there can override environment defaults.

Stopping the service keeps all Open WebUI data:

```bash
aiw open-webui down
```

## Return after several weeks

Start `Linux AI Workstation` from the Windows Start Menu or Desktop to open the
project checkout; `Linux Terminal` opens the same Ubuntu at the home
directory. Both launch ordinary WSL shells. The WSL startup
hint reminds you that the only command you need to remember is:

```bash
aiw
```

To update the Git checkout and rerun the idempotent Linux installation:

```bash
aiw update
```

`aiw update` fetches/prunes the Linux checkout, keeps fast-forward-only update safety, and then reruns `install.sh`. If the current local review branch tracks an `origin` branch that was deleted after merge, the local branch is preserved and the installed checkout automatically returns to `main` / `origin/main`. Ansible configures the host; it does not update the repository.

## Where to find it later

After installation, start AI Workstation from Windows:

```text
Start Menu -> Linux AI Workstation
```

A Desktop shortcut with the same name is created as well. The shortcut opens the
correct WSL distribution directly inside:

```text
/home/moresunlight/ai-workstation
```

The installer also creates:

```text
Start Menu -> Linux Terminal
Desktop    -> Linux Terminal
```

This second shortcut opens:

```text
/home/moresunlight
```

Refresh only the Windows shortcuts without rerunning the Linux installation.
The refresh also removes older **AI Workstation** / **AI Workstation Terminal**
links when they can be identified as installer-created; other shortcuts are preserved:

```powershell
.\install.ps1 -Action Shortcuts
```

Fallback commands, if the shortcut is ever missing:

```powershell
wsl -l -v
wsl -d Ubuntu-24.04
wsl -d Ubuntu-24.04 --cd /home/moresunlight/ai-workstation
wsl -d Ubuntu-24.04 --cd /home/moresunlight
wsl --shutdown
```

## Daily foundation commands

```bash
aiw
aiw status
aiw verify
aiw update
```

## Rerun the installer

Windows side:

```powershell
.\install.ps1
```

Linux side:

```bash
cd ~/ai-workstation
./install.sh
```

Both entry points are idempotent and may be run again after an interruption.
Application runtimes are additive and do not change the working host foundation
roles unnecessarily.

## Clean-room installation

A second Ubuntu distribution can be used without modifying or unregistering the
working reference distribution:

```powershell
.\install.ps1 `
  -DistroName Ubuntu-24.04-Test `
  -InstallLocation C:\WSL\Ubuntu-24.04-Test
```

This creates a separate Windows shortcut named:

```text
Linux AI Workstation (Ubuntu-24.04-Test)
Linux Terminal (Ubuntu-24.04-Test)
```

See [Clean-room test](docs/clean-room-test.md).

## Local reset for a reinstall test

To test the installer again inside an existing WSL distribution, delete only the
Linux checkouts, not the distribution:

```bash
cd ~
rm -rf ai-workstation ai-workstation-next
```

Then run the Windows installer again from a Windows checkout. It will clone the
repository back into Linux.

## Repository layout

```text
install.ps1             Windows entry point
install.sh              Linux entry point
bin/aiw                 Interactive and scriptable operational CLI
bootstrap/windows/      WSL, Windows shortcuts and Windows implementation
bootstrap/linux/        Minimal Linux bootstrap
ansible/                Host configuration and verification
config/                 Central version definitions
containers/goose/       Goose runtime design notes
compose/goose.yml       Isolated Goose session runtime
compose/open-webui.yml  Persistent Open WebUI service
tests/                  Repository and runtime smoke tests
tools/                  Maintenance and release helpers
docs/                   Architecture and operating documentation
```

## Safety model

AI Workstation favors non-destructive host changes, local Docker control, tightly bounded application runtimes, and secrets outside Git and images. Maintained safety invariants are in [Project Context](CONTEXT.md); vulnerability reporting remains in [Security](SECURITY.md).

## Supported host

AI Workstation targets Windows with WSL 2 and Ubuntu. Exact supported Windows, PowerShell, Ubuntu and architecture values are maintained in [Project Context](CONTEXT.md).

## Documentation

- [Architecture](docs/architecture.md)
- [Repository setup](docs/repository-setup.md)
- [Clean-room test](docs/clean-room-test.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Application updates](docs/container-updates.md)
- [Security](SECURITY.md)

## License

MIT
