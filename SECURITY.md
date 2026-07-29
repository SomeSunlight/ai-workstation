# Security

## Design principles

- The Docker daemon is exposed only through its local Unix socket.
- Only the interactive Linux user joins the powerful `docker` group.
- Agent and application containers do not receive the Docker socket.
- Secrets must not be committed, copied into images or stored in Compose files.
- Runtime credentials are read from the Git-ignored `.env` file with mode `600`.
- Existing conflicting container packages are never removed automatically.

## Goose workspace boundary

Each Goose session starts a short-lived container with:

- exactly one explicitly registered host workspace mounted read-write;
- a stable container path under `/workspaces/NAME`;
- a read-only root filesystem;
- dropped Linux capabilities and `no-new-privileges`;
- no access to unrelated WSL or Windows directories unless they are deliberately
  registered as the selected workspace.

The selected workspace is delegated authority. Goose can edit or delete files
inside it and can modify its Git repository. Review changes before committing or
pushing them. Broad workspace paths such as `/`, `/home`, `$HOME`, `/mnt` and
`/mnt/c` are rejected by the wrapper.

## Open WebUI boundary

Open WebUI:

- binds only to `127.0.0.1` on the WSL host by default;
- stores state in a named Docker volume;
- receives no host workspace and no Docker socket;
- reaches configured model providers over the network;
- keeps authentication enabled.

The first account is the local administrator. Use a strong password and do not
publish the localhost port through a proxy or LAN interface without adding the
appropriate TLS, authentication and network controls.

## Reporting

Do not open a public issue for a vulnerability that includes credentials,
private host data or an exploitable proof of concept. Contact the repository
owner privately first.
