# Changelog

## 0.4.6

- Fix ansible-lint variable naming violations in the `project_directories` role.
- Replace deprecated injected Ansible fact usage in `bootstrap-verify.yml`.

## 0.4.5

- Normalize PowerShell here-string line endings before sending Bash snippets to WSL.
- Replace `echo` with `printf` for base64 payload transfer into WSL.

## 0.4.4

- Fix Windows installer path normalization for existing WSL distributions by replacing an invalid regular expression with explicit `StartsWith` / `Substring` logic.

## 0.4.3

- Fix `install.ps1 -Action Status` when WSL returns a single distribution name.
- Make Windows administrator/elevation behavior explicit in README and troubleshooting.
- Clarify that `Status` and `Verify` do not normally require an elevated shell.

## 0.4.2

- Keep the elevated Windows installer window open so progress and errors remain visible.
- Make the WSL update check explicitly visible as a potentially long-running step.
- Add a final Windows status hint after successful installation.
- Fix Ansible lint failures by using role-prefixed variables and moving the Docker APT refresh into a handler.

## 0.4.1

- Fix a PowerShell parser error in the WSL error message path by delimiting `${code}` before a colon.
- Keep the Windows installer startable under PowerShell 7.6.x.

## 0.4.0

- Add automatic Windows Desktop and Start Menu shortcuts for the WSL checkout.
- Add a standalone shortcut repair script.
- Document how to find the installed workstation after weeks away from the setup.
- Document safe local reinstall testing by deleting only Linux checkouts.
- Document WSL/GitHub lessons from the first prototype installation.
- Keep the installer idempotent and rerunnable on both Windows and Linux.

## 0.3.0

- Consolidate the prototype into a public English repository structure.
- Add Windows and Linux entry points.
- Add locked Ansible runtime, Docker Engine role and verification.
- Add clean-room test documentation.
