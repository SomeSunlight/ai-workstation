# AI Workstation

Reproducible WSL 2 and Docker foundation for local AI agents on Windows.

> **Current scope:** Ubuntu 24.04, a locked Ansible runtime and Docker Engine.
> The Goose runtime image and Compose services are the next phase.

## Quick start

These commands apply after the public GitHub repository has been created. The
maintainer bootstrap is documented in [Repository setup](docs/repository-setup.md).

### Windows

Clone the repository on Windows, then open **PowerShell 7 as Administrator**
in that checkout:

```powershell
git clone https://github.com/SomeSunlight/ai-workstation.git
cd ai-workstation
.\install.ps1
```

The installer may request:

1. a Windows restart;
2. a Linux password for the `moresunlight` user;
3. the Linux sudo password during host installation.

It installs the Linux checkout directly at:

```text
/home/moresunlight/ai-workstation
```

### Linux-only rerun

Inside Ubuntu:

```bash
cd ~/ai-workstation
./install.sh
```

Both entry points are idempotent and may be run again after an interruption.

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

## Clean-room installation

A second Ubuntu distribution can be used without modifying or unregistering the
working reference distribution:

```powershell
.\install.ps1 `
  -DistroName Ubuntu-24.04-Test `
  -InstallLocation C:\WSL\Ubuntu-24.04-Test
```

See [Clean-room test](docs/clean-room-test.md).

## Repository layout

```text
install.ps1             Windows entry point
install.sh              Linux entry point
bin/aiw                 Stable operational CLI
bootstrap/windows/      WSL and Windows implementation
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
