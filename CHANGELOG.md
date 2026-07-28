# Changelog

<<<<<<< HEAD
=======
## 0.5.1

- Resolve the real `bin/aiw` path before deriving the repository root, so the installed `~/.local/bin/aiw` symlink works correctly.
- Validate Git worktrees with `git rev-parse` instead of requiring `.git` to be a directory.
- Add a smoke test for invoking `aiw` through its installed symlink.
- Document that `aiw update`, not Ansible, performs the Linux-side Git pull.
- Document the Linux-first maintainer patch workflow.

>>>>>>> d25a635 (Add Dockerized Goose runtime and fix aiw symlink resolution)
## 0.5.0

- Add a pinned Docker Compose runtime for Goose `v1.44.0` with OpenRouter configuration from a Git-ignored `.env` file.
- Add `aiw goose init`, `status`, `pull`, `up`, `down`, `logs`, `session`, `run` and `version` commands.
- Persist Goose configuration, sessions, state and cache while keeping the container root filesystem read-only.
- Run Goose without the Docker socket, Linux capabilities or privilege escalation.
- Document first use, daily operation and recovery after a long pause.
- Add runtime smoke checks to CI without changing the working host foundation.

## 0.4.9

- Remove duplicated Windows-side Ubuntu release parsing from `Verify`.
- Let the Linux verifier be the single source of truth for Ubuntu, systemd, Python, uv, Ansible and Docker checks.
- Harden the Windows default-user check against null/scalar native WSL output.
## 0.4.8

- Fix `install.ps1 -Action Verify` when native WSL output is empty or scalar by normalizing command output before calling `.Trim()`.
- Add clearer errors when Windows cannot read the Ubuntu release or default Linux user from WSL.
## 0.4.7

- Prompt once for the Linux sudo password during `install.sh install` and pass it to Ansible through a temporary become-password file.
- Keep sudo alive using the same temporary credential path.
- Allow the Windows installer to drive the Linux host installation without Ansible failing on missing sudo input.

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
