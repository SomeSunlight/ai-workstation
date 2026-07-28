# Compose runtime

`goose.yml` defines the first application runtime layer. It uses the pinned
official Goose CLI image and keeps a small utility container alive so sessions
can be launched through `docker compose exec` without rebuilding an image.

Use the stable wrapper instead of invoking Compose directly:

```bash
aiw goose init
aiw goose up
aiw goose session
aiw goose down
```

The host and Docker installation remain independent of service definitions. A
missing or incomplete `.env` therefore does not break installation or foundation
verification.
