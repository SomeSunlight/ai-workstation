# Goose runtime

The runtime uses the official image selected through `compose/goose.yml` and
machine-local image overrides.
No derivative image is currently required.

Security boundaries:

- the image runs as the upstream non-root `goose` user;
- the Docker socket is not mounted;
- Linux capabilities are dropped and privilege escalation is disabled;
- the root filesystem is read-only;
- exactly one registered host workspace is mounted at `/workspaces/NAME`;
- the persistent `/home/goose` volume and `/tmp` remain writable;
- configuration and connection checks use the same image/home without a project mount.

Sessions run in short-lived containers. Goose owns provider, model, extension
and secret configuration in `ai-workstation_goose-home`. Optional Goose-only
environment values come from the protected file exposed by `aiw goose env`.
Shared `.env` OpenRouter/provider/model entries are not injected into Goose.
No public provider is selected automatically by AI Workstation.

Network access remains available for chosen APIs and extensions; workspace
isolation is not a network allowlist. See
[Goose configuration](../../docs/goose-configuration.md) for local API setup,
subagent defaults and confidential-workflow limits.
