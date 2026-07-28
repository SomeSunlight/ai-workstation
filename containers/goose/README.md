# Goose runtime

The runtime uses the pinned official image configured in `compose/goose.yml`.
No derivative image is currently required.

Security boundaries:

- the image runs as the upstream non-root `goose` user;
- the Docker socket is not mounted;
- Linux capabilities are dropped and privilege escalation is disabled;
- the root filesystem is read-only;
- only `/workspace`, the persistent `/home/goose` volume and `/tmp` are writable;
- OpenRouter credentials are injected from the Git-ignored `.env` file.

The official image contains the Goose CLI. AI Workstation therefore models it as
a long-running Compose utility container and starts sessions with `goose session`
inside that container. It does not pretend to expose an unsupported HTTP daemon.
