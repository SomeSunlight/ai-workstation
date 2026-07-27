# Changelog

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
