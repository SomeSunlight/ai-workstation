# Security

## Design principles

AI Workstation keeps Docker control local, limits Docker-group access, isolates application containers from the Docker socket, keeps secrets out of tracked/container definitions, and avoids automatic removal of conflicting container packages. Runtime credentials live in the Git-ignored mode-`600` `.env` file. Maintained security rules are in [Project Context](CONTEXT.md).

## Goose workspace boundary

A Goose session delegates exactly one registered writable workspace to a short-lived, hardened container; broad or unrelated host paths are not implicitly available. The selected workspace is real delegated authority, so changes must be reviewed before commit or push. Maintained boundary details are in [Project Context](CONTEXT.md).

## Open WebUI boundary

Open WebUI is a localhost-bound authenticated service with persistent Docker-managed state, network access to configured model providers, and no host workspace or Docker socket. The first account is the local administrator; use a strong password and do not expose the service beyond localhost without appropriate TLS, authentication and network controls. Maintained boundary details are in [Project Context](CONTEXT.md).

## Reporting

Do not open a public issue for a vulnerability that includes credentials,
private host data or an exploitable proof of concept. Contact the repository
owner privately first.
