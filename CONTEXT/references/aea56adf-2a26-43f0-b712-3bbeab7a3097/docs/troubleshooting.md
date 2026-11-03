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

## Native Ubuntu (no WSL)

A native Ubuntu installation uses `./install.sh` and `aiw` directly. There
is no Windows launcher or `wsl.exe`. See [Native Linux guide](native-linux.md)
for the experimental scope and host requirements.

If Docker works only with `sudo`, first confirm the installation added your
user to the `docker` group, then log out and back in. A native Linux login
session must acquire new group membership; **do not** run `wsl --shutdown` on
a native host.

On a headless remote host, `aiw open-webui open` prints the server-local URL.
Use SSH port forwarding to access the loopback-only service from your laptop;
see the guide. A local `localhost` URL shown on the server is not your
laptop's localhost until a tunnel is active.

## I cannot find Linux in Windows

The installed Linux distribution is managed by WSL; it is not a separate
Windows application named Ubuntu or Debian.

Normal access after installation:

```text
Start Menu -> Linux AI Workstation
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

## The penguin shortcut cannot start WSL

Both **Linux AI Workstation** and **Linux Terminal** start the existing Ubuntu
WSL distribution automatically, even when `wsl --list --verbose` reports
`Stopped`. You do **not** have to open a separate PowerShell session first.
The generated shortcut opens **PowerShell 7** directly, executes an actual
Linux command to check startup, retries once after a failure, and leaves the
window open to show the error. The older `cmd.exe` launcher could report
`WSL_E_DISTRO_NOT_FOUND` under `call wsl.exe` even though **the exact same
System32 `wsl.exe` invocation worked from PowerShell** under the same user.
This observation does not establish whether `call` or CMD itself was at fault.

Manual equivalents in ordinary **Windows PowerShell**:

```powershell
wsl --list --verbose
wsl -d Ubuntu-24.04
wsl -d Ubuntu-24.04 --cd /home/moresunlight/ai-workstation
```

If the launcher says `Wsl/Service/WSL_E_DISTRO_NOT_FOUND` but the **same**
Windows account's `wsl --list --verbose` also lists `Ubuntu-24.04`, do not
unregister or reinstall the distribution. A stopped distribution is registered;
the contradiction may be transient WSL initialization, account/registration
state, or an invocation problem. The error alone does not establish the cause.

Try the plain `wsl -d Ubuntu-24.04` first, without `--cd`. If that opens
Linux, check whether `/home/moresunlight/ai-workstation` exists and then
test the second command. If the plain command fails, inspect `wsl --status`
and the message directly above the failure. When no other WSL work is running,
you may try `wsl --shutdown` from PowerShell followed by the plain command.
`wsl --shutdown` stops **all** running WSL distributions; the launcher never
runs it automatically.

After updating the Windows-side AI Workstation checkout, recreate **only**
the Windows shortcuts (no WSL reinstall needed):

```powershell
.\install.ps1 -Action Shortcuts
```

For a non-default distribution, include `-DistroName` so both icons target
that name. If WSL remains inaccessible, capture the complete launcher output
and the results of the PowerShell commands above before changing packages.

## The Linux AI Workstation shortcut is missing

Rerun the Windows installer:

```powershell
.\install.ps1
```

It recreates **Linux AI Workstation** (project directory) and **Linux Terminal**
(home directory) on the Desktop and Start Menu. Existing installer-owned links
under the old names are safely replaced; unrelated shortcuts are preserved.
For shortcuts only, without Linux reinstall, use:

```powershell
.\install.ps1 -Action Shortcuts
```

For a test distribution:

```powershell
.\install.ps1 -Action Shortcuts `
  -DistroName Ubuntu-24.04-Test
```

## `ansible.cfg` is ignored

The repository must not be world-writable. Normal installations clone the
repository directly inside the Linux filesystem, and Git is authoritative for
tracked file modes.

If the checkout has incorrect permissions, fix the checkout ownership or clone a
fresh copy inside Linux rather than rewriting permissions across the repository.

## Docker works only with sudo (WSL)

Open a new WSL session after the first installation. The `docker` group
membership is applied to new login sessions.

From PowerShell this fully restarts WSL:

```powershell
wsl --shutdown
```

Then open the `Linux AI Workstation` shortcut again.

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


## The installer returns to the prompt immediately

When administrator rights are required, `install.ps1` starts a separate
elevated PowerShell window. Continue watching that elevated window. The original
PowerShell session can return to the prompt while the elevated installer is
still running.

To inspect the current state later:

```powershell
.\install.ps1 -Action Status
```

Windows logs are written below:

```text
%LOCALAPPDATA%\AiWorkstationBootstrap\logs
```

## WSL update check looks idle

The command `wsl --update` can take several minutes and may produce little or no
output. The installer now announces this explicitly and prints a completion
message when the check returns.


## Which actions need administrator rights?

`Install` may need administrator rights and therefore opens a UAC prompt when
started from a normal PowerShell window. This is expected.

For ordinary inspection, use these commands without opening an administrator
shell:

```powershell
.\install.ps1 -Action Status
.\install.ps1 -Action Verify
```

If `Install` elevates itself, the original PowerShell session may return to the
prompt while a separate elevated window continues the installation.
