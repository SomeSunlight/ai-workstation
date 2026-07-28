# AI Workstation

Reproducible AI workstation for Windows 11, WSL 2 and Ubuntu 24.04.

> **Current scope:** repeatable Windows/WSL bootstrap, locked Ansible host setup,
> Docker Engine and a Dockerized Goose CLI runtime using OpenRouter. Local model
> integration is intentionally deferred to the next phase.

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

## Check the current installation state

`Status` and `Verify` do not require an elevated PowerShell window for ordinary
use:

```powershell
.\install.ps1 -Action Status
.\install.ps1 -Action Verify
```

Inside Ubuntu, `aiw status` includes the Goose configuration and container state.

## Configure Goose with OpenRouter

Open the Windows shortcut and initialize the local secret file:

```bash
aiw goose init
nano .env
```

Set at least:

```dotenv
GOOSE_MODEL=provider/model-id
OPENROUTER_API_KEY=replace-with-your-key
```

The model value is an OpenRouter model ID. The `.env` file is ignored by Git and
is changed to mode `600` by `aiw`. Do not put credentials in `.env.example`, the
Compose file, images or commits.

The default workspace mount is this repository. To let Goose work on another
project, set an absolute WSL path:

```dotenv
AIW_GOOSE_WORKSPACE=/home/moresunlight/projects/example
```

Pull and start the pinned container, then open a session:

```bash
aiw goose pull
aiw goose up
aiw goose session
```

The container is a long-running utility container around the official Goose CLI.
It is not an HTTP service. Sessions execute inside it and work in `/workspace`.

## Goose commands

```bash
aiw goose init
aiw goose status
aiw goose pull
aiw goose up
aiw goose down
aiw goose logs
aiw goose session
aiw goose run --text "Inspect this repository and summarize its architecture."
aiw goose version
```

Compatibility aliases are available:

```bash
aiw start
aiw stop
aiw logs
```

`down` removes the container but keeps the `goose-home` volume containing
Goose configuration, sessions, state and cache.

## Return after several weeks

Start `AI Workstation` from the Windows Start Menu or Desktop, then run:

```bash
cd ~/ai-workstation
aiw status
aiw goose up
aiw goose session
```

To update the Git checkout and rerun the idempotent Linux installation:

```bash
aiw update
```

If `.env` is missing, run `aiw goose init` and restore the API key and model.

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

Fallback commands, if the shortcut is ever missing:

```powershell
wsl -l -v
wsl -d Ubuntu-24.04
```

Inside Ubuntu:

```bash
cd ~/ai-workstation
```

## Daily foundation commands

```bash
aiw status
aiw verify
aiw update
```

## Rerun the installer

Windows side:

```powershell
.\install.ps1
```

Linux side, after opening the AI Workstation shortcut:

```bash
./install.sh
```

Both entry points are idempotent and may be run again after an interruption.
The Goose runtime is additive and does not change the host foundation roles.

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
bin/aiw                 Stable operational CLI
bootstrap/windows/      WSL, Windows shortcuts and Windows implementation
bootstrap/linux/        Minimal Linux bootstrap
ansible/                Host configuration and verification
config/                 Central version definitions
containers/goose/       Goose runtime design notes
compose/goose.yml       Goose Compose runtime
tests/                  Repository and runtime smoke tests
tools/                  Maintenance and release helpers
docs/                   Architecture and operating documentation
```

## Safety model

- No existing WSL distribution is unregistered or deleted.
- Conflicting Docker packages are reported, not removed automatically.
- Docker listens only on its local Unix socket.
- The interactive Linux user joins the powerful `docker` group.
- The Goose container does not receive the Docker socket.
- The Goose container runs read-only apart from explicit workspace and state mounts.
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
