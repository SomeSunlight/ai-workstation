#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
find "$ROOT" \( -path "$ROOT/.git" -o -path "$ROOT/.venv" -o -path "$ROOT/.ansible" \) -prune -o -type d -exec chmod 0755 {} +
find "$ROOT" \( -path "$ROOT/.git" -o -path "$ROOT/.venv" -o -path "$ROOT/.ansible" \) -prune -o -type f -exec chmod 0644 {} +
chmod 0755 "$ROOT/install.sh" "$ROOT/bin/aiw" "$ROOT/bootstrap/linux/install.sh" "$ROOT/tools/normalize-permissions.sh" "$ROOT/tools/release-check.sh" "$ROOT/tools/adopt-prototype-lock.sh" "$ROOT/tests/smoke/repository-layout.sh"
printf 'Repository permissions normalized.\n'
