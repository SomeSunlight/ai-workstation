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

## I cannot find Linux in Windows

Do not search for `Linux` or `Debian`. The installed distribution is managed by
WSL.

Normal access after installation:

```text
Start Menu -> AI Workstation
```

Fallback in PowerShell:

```powershell
wsl -l -v
wsl -d Ubuntu-24.04
```

The project lives inside Linux:

```text
/home/moresunlight/ai-workstation
```

## The AI Workstation shortcut is missing

Rerun the Windows installer:

```powershell
.\install.ps1
```

It recreates the Desktop and Start Menu shortcuts. To create only the shortcuts
from a checkout:

```powershell
.\bootstrap\windows\Create-Shortcuts.ps1
```

For a test distribution:

```powershell
.\bootstrap\windows\Create-Shortcuts.ps1 `
  -DistroName Ubuntu-24.04-Test
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

From PowerShell this fully restarts WSL:

```powershell
wsl --shutdown
```

Then open the `AI Workstation` shortcut again.

## GitHub CLI login from WSL has no browser

Use the device-code flow printed by `gh auth login`. Open the shown URL in the
normal Windows browser, enter the code, then return to the WSL terminal.

## The GitHub repository already has a generated LICENSE

If the GitHub repository was created with a server-side MIT license, merge the
remote history instead of force-pushing:

```bash
git fetch origin
git merge origin/main --allow-unrelated-histories
```

If `LICENSE` conflicts, resolve the conflict, commit the merge and push.
