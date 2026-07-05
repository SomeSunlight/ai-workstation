# Security

## Design principles

- The Docker daemon is exposed only through its local Unix socket.
- Only the interactive Linux user joins the `docker` group.
- Future agent containers will not receive the Docker socket.
- Secrets must not be committed, copied into images or stored in Compose files.
- Existing conflicting container packages are never removed automatically.

## Reporting

Do not open a public issue for a vulnerability that includes credentials,
private host data or an exploitable proof of concept. Contact the repository
owner privately first.
