# Security

## Design principles

- The Docker daemon is exposed only through its local Unix socket.
- Only the interactive Linux user joins the `docker` group.
- The Goose container does not receive the Docker socket.
- The Goose root filesystem is read-only apart from explicit workspace, state and temporary mounts.
- Linux capabilities are dropped and `no-new-privileges` is enabled.
- Secrets must not be committed, copied into images or stored in Compose files.
- Runtime credentials are read from the Git-ignored `.env` file with mode `600`.
- Existing conflicting container packages are never removed automatically.

The selected Goose workspace is intentionally writable because the agent must be
able to edit project files. Treat every mounted workspace as delegated authority.
Review changes with Git before committing or pushing them.

## Reporting

Do not open a public issue for a vulnerability that includes credentials,
private host data or an exploitable proof of concept. Contact the repository
owner privately first.
