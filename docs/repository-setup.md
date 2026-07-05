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

Create an empty **public** GitHub repository named `ai-workstation`, without a
server-generated README, license or `.gitignore`. Then connect and push:

```bash
git remote add origin https://github.com/SomeSunlight/ai-workstation.git
git push -u origin main
```

After the push, the GitHub validation workflow must pass before starting the
clean-room installation.
