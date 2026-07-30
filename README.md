# AI Workstation

Reproducible AI workstation for Windows 11, WSL 2 and Ubuntu 24.04.

> **Current scope:** repeatable Windows/WSL bootstrap, locked Ansible host setup,
> Docker Engine, isolated Goose CLI sessions using OpenRouter, and a persistent
> Open WebUI service. Local model integration is intentionally deferred to the
> next phase.

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

Start `AI Workstation` from the Windows Start Menu or Desktop. The companion
shortcut `AI Workstation Terminal` opens a plain Ubuntu home terminal. The WSL startup
hint reminds you that the only command you need to remember is:

```bash
aiw
```

To update the Git checkout and rerun the idempotent Linux installation:

```bash
aiw update
```

`aiw update` performs `git pull --ff-only` in the Linux checkout and then reruns
`install.sh`. Ansible configures the host; it does not update the repository.

## Where to find it later

After installation, start AI Workstation from Windows:

```text
Start Menu -> AI Workstation
```

A Desktop shortcut with the same name is created as well. The shortcut opens the
correct WSL distribution directly inside:

```text
/home/moresunlight/ai-workstation
```

The installer also creates:

```text
Start Menu -> AI Workstation Terminal
Desktop    -> AI Workstation Terminal
```

This second shortcut opens:

```text
/home/moresunlight
```

Refresh only the Windows shortcuts without rerunning the Linux installation:

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
AI Workstation (Ubuntu-24.04-Test)
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

- No existing WSL distribution is unregistered or deleted.
- Conflicting Docker packages are reported, not removed automatically.
- Docker listens only on its local Unix socket.
- The interactive Linux user joins the powerful `docker` group.
- Goose receives one explicitly selected writable workspace and no Docker socket.
- Goose containers use a read-only root filesystem and are removed after use.
- Open WebUI is bound to localhost and receives no host workspace or Docker socket.
- Secrets stay outside Git and container images.

## Supported host

- Windows 11 with current Store WSL
- PowerShell 7.4 or newer
- Ubuntu 24.04 under WSL 2
- x86-64 Windows and WSL architecture

## Documentation

- [Architecture](docs/architecture.md)
- [Repository setup](docs/repository-setup.md)
- [Clean-room test](docs/clean-room-test.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Security](SECURITY.md)

## License

MIT
