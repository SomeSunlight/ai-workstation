# Repository setup

This document is only for creating the public repository from the tested
prototype. Normal users start with the root `README.md`.

## 1. Prepare the new tree

Extract the repository seed on Windows, then copy its directory into the WSL
Linux filesystem as `~/ai-workstation-next`. Do not operate the new tree under
`/mnt/c`. Because Windows archive extraction does not preserve Linux modes, run:

```bash
cd ~/ai-workstation-next
bash ./tools/normalize-permissions.sh
```

## 2. Adopt the tested lockfile

The seed intentionally does not contain an invented dependency lock. The
working prototype already generated and tested the authoritative `uv.lock`.

From the new tree:

```bash
cd ~/ai-workstation-next
./tools/adopt-prototype-lock.sh ~/ai-workstation
```

The helper first verifies that both repositories have the same `pyproject.toml`,
then copies the lockfile.

## 3. Validate the repository

```bash
./tools/release-check.sh
```

## 4. Create the Git history

```bash
git init -b main
git add .
git commit -m "Initial AI Workstation repository"
```

Create an empty **public** GitHub repository named `ai-workstation`. Prefer no
server-generated README, license or `.gitignore` because the repository already
contains them. If a server-generated MIT license was created, merge the remote
history later instead of force-pushing.

Then connect and push:

```bash
git remote add origin https://github.com/SomeSunlight/ai-workstation.git
git push -u origin main
```

After the push, the GitHub validation workflow must pass before starting the
clean-room installation.


## Existing server-side LICENSE

If GitHub already created a first commit containing `LICENSE`, the first push may
be rejected. Merge both histories:

```bash
git fetch origin
git merge origin/main --allow-unrelated-histories
```

Resolve `LICENSE` if necessary, keep the intended MIT text, then push.

## `gh auth login` from WSL

WSL may not have a browser. That is fine: `gh auth login` prints a URL and a
one-time device code. Open the URL in the Windows browser, enter the code and
return to the WSL terminal.
