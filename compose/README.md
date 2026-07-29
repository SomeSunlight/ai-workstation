# Compose runtime

The runtime layer contains two deliberately different service models:

- `goose.yml` is a template for short-lived, isolated CLI session containers.
  `aiw` injects exactly one selected workspace mount per session.
- `open-webui.yml` is a persistent local web service with a named data volume and
  a loopback-only browser port.

Use the stable wrapper instead of invoking Compose directly:

```bash
aiw
aiw goose help
aiw open-webui help
```

A missing or incomplete `.env` does not break host installation or foundation
verification. Runtime commands validate the configuration they require.
