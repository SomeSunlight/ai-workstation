# Architecture

| Layer | Responsibility |
|---|---|
| PowerShell | Windows, WSL, reboot continuation and distribution lifecycle |
| Linux bootstrap | Minimal packages, uv and the locked Ansible runtime |
| Ansible | Ubuntu host state and Docker Engine |
| Dockerfile | Contents of a service image |
| Compose | Services, mounts, networks and resource limits |
| `aiw` | Stable user interface for installation and operation |

The repository is the installation specification. Running containers and
manually modified hosts are not treated as the source of truth.
