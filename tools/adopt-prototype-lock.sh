#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SOURCE="${1:-${HOME}/ai-workstation}"

[[ "$ROOT" != "$SOURCE" ]] || { echo 'Source and target repository are identical.' >&2; exit 1; }
[[ -f "$SOURCE/pyproject.toml" ]] || { echo "Missing $SOURCE/pyproject.toml" >&2; exit 1; }
[[ -f "$SOURCE/uv.lock" ]] || { echo "Missing $SOURCE/uv.lock" >&2; exit 1; }

if ! cmp -s "$ROOT/pyproject.toml" "$SOURCE/pyproject.toml"; then
    echo 'pyproject.toml differs from the tested prototype; refusing to copy uv.lock.' >&2
    exit 1
fi

install -m 0644 "$SOURCE/uv.lock" "$ROOT/uv.lock"
printf 'Copied tested lockfile from %s to %s/uv.lock\n' "$SOURCE" "$ROOT"
