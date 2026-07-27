# AI Workstation

Reproducible WSL 2 and Docker foundation for local AI agents on Windows.

> **Current scope:** Ubuntu 24.04, a locked Ansible runtime and Docker Engine.
> The Goose runtime image, Compose services, OpenRouter configuration and local
> model integration are not included yet. They are the next phase after the
> installer has passed a clean-room rebuild.

## Quick start

## Check the current installation state

At any time from the Windows checkout:

```powershell
.\install.ps1 -Action Status
```

The installer may open a separate elevated PowerShell window. Watch that
elevated window; it stays open after the installer finishes so errors and the
log path remain visible.


Clone the repository on Windows, then open **PowerShell 7 as Administrator** in
that checkout:

```powershell
git clone https://github.com/SomeSunlight/ai-workstation.git
cd ai-workstation
.\install.ps1
```

The installer may request:

1. a Windows restart;
2. a Linux password for the `moresunlight` user;
3. the Linux sudo password during host installation.

The installer is designed to be rerun until everything is present. It does not
unregister or delete existing WSL distributions.

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

## Daily commands

```bash
aiw status
aiw verify
aiw update
```

The future Goose phase will activate:

```bash
aiw start
aiw stop
aiw logs
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
containers/             Future service images
compose/                Future service runtime
tests/                  Repository smoke tests
tools/                  Maintenance and release helpers
docs/                   Architecture and operating documentation
```

## Safety model

- No existing WSL distribution is unregistered or deleted.
- Conflicting Docker packages are reported, not removed automatically.
- Docker listens only on its local Unix socket.
- The interactive Linux user joins the powerful `docker` group.
- Future agent containers will not receive the Docker socket.
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
