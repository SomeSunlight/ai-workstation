#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
required=(
  README.md LICENSE install.ps1 install.sh bin/aiw config/versions.json .env.example
  bootstrap/windows/Install-AiWorkstation.ps1 bootstrap/windows/Create-Shortcuts.ps1 bootstrap/linux/install.sh
  tools/adopt-prototype-lock.sh tools/check-version-consistency.py
  ansible/ansible.cfg ansible/requirements.yml
  ansible/playbooks/workstation.yml ansible/playbooks/verify.yml
  compose/goose.yml compose/open-webui.yml containers/goose/README.md
  tests/smoke/goose-runtime.sh tests/smoke/open-webui-runtime.sh tests/smoke/interactive-menu.sh
)
for item in "${required[@]}"; do
  [[ -e "$ROOT/$item" ]] || { printf 'Missing: %s\n' "$item" >&2; exit 1; }
done
[[ "$ROOT" != /mnt/* ]] || { echo 'Repository must not be operated from /mnt.' >&2; exit 1; }

temp_home="$(mktemp -d)"
trap 'rm -rf "$temp_home"' EXIT
mkdir -p "$temp_home/.local/bin"
ln -s "$ROOT/bin/aiw" "$temp_home/.local/bin/aiw"
symlink_status="$(HOME="$temp_home" "$temp_home/.local/bin/aiw" status)"
grep -Fq "Repository           : $ROOT" <<< "$symlink_status" || {
  echo 'aiw did not resolve the repository root through its installed symlink.' >&2
  exit 1
}

printf 'Repository layout is valid.\n'
