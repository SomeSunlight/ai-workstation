# Troubleshooting

## Logs

Windows logs:

```text
%LOCALAPPDATA%\AiWorkstationBootstrap\logs
```

Linux logs:

```text
~/.local/state/ai-workstation/logs
```

## `ansible.cfg` is ignored

The repository must not be world-writable. Run:

```bash
./tools/normalize-permissions.sh
```

Normal installations clone the repository directly inside Linux and therefore
do not inherit synthetic Windows permissions.

## Docker works only with sudo

Open a new WSL session after the first installation. The `docker` group
membership is applied to new login sessions.
