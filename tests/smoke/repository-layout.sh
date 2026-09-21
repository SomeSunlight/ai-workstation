#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
required=(
  README.md LICENSE install.ps1 install.sh bin/aiw bin/aiw-core config/versions.json .env.example
  bootstrap/windows/Install-AiWorkstation.ps1 bootstrap/windows/Create-Shortcuts.ps1 bootstrap/linux/install.sh
  tools/adopt-prototype-lock.sh tools/check-version-consistency.py
  ansible/ansible.cfg ansible/requirements.yml
  ansible/playbooks/workstation.yml ansible/playbooks/verify.yml
  compose/goose.yml compose/open-webui.yml containers/goose/README.md
  runtimes/local-inference/README.md runtimes/local-inference/manage.sh
  tests/smoke/goose-runtime.sh tests/smoke/open-webui-runtime.sh tests/smoke/interactive-menu.sh
  tests/smoke/local-inference-runtime.sh tests/smoke/update-recovery.sh
)
for item in "${required[@]}"; do
  [[ -e "$ROOT/$item" ]] || { printf 'Missing: %s\n' "$item" >&2; exit 1; }
done
[[ "$ROOT" != /mnt/* ]] || { echo 'Repository must not be operated from /mnt.' >&2; exit 1; }

bootstrap_installer="$ROOT/bootstrap/linux/install.sh"
if grep -Fq 'normalize_permissions' "$bootstrap_installer" ||    grep -Eq -- '-type f .*chmod 0?644' "$bootstrap_installer"; then
  echo 'Linux installer must not rewrite Git-tracked file modes.' >&2
  exit 1
fi
[[ ! -e "$ROOT/tools/normalize-permissions.sh" ]] || {
  echo 'Legacy repository permission normalizer still exists.' >&2
  exit 1
}

for executable in   bin/aiw-core   runtimes/local-inference/manage.sh   tests/smoke/goose-runtime.sh   tests/smoke/interactive-menu.sh   tests/smoke/open-webui-runtime.sh; do
  mode="$(git -C "$ROOT" ls-files --stage -- "$executable" | awk '{print $1}')"
  [[ "$mode" == "100755" ]] || {
    echo "Expected Git executable mode 100755 for $executable, found ${mode:-missing}." >&2
    exit 1
  }
done

temp_home="$(mktemp -d)"
trap 'rm -rf "$temp_home"' EXIT
mkdir -p "$temp_home/.local/bin"
ln -s "$ROOT/bin/aiw" "$temp_home/.local/bin/aiw"
symlink_status="$(HOME="$temp_home" "$temp_home/.local/bin/aiw" status)"
grep -Fq "Repository           : $ROOT" <<< "$symlink_status" || {
  echo 'aiw did not resolve the repository root through its installed symlink.' >&2
  exit 1
}
grep -Fq 'Local inference       : false' <<< "$symlink_status" || {
  echo 'Remote-only status did not report local inference as disabled.' >&2
  exit 1
}

printf 'Repository layout is valid.\n'
