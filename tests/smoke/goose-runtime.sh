#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
compose_file="${ROOT}/compose/goose.yml"
env_example="${ROOT}/.env.example"
cli="${ROOT}/bin/aiw"
goose_image="$(
  python3 - "${ROOT}/config/versions.json" <<'PYTHON'
import json
import sys
from pathlib import Path

print(json.loads(Path(sys.argv[1]).read_text())["versions"]["goose"]["image"])
PYTHON
)"

[[ -f "$compose_file" ]] || { echo 'Missing compose/goose.yml' >&2; exit 1; }
[[ -f "$env_example" ]] || { echo 'Missing .env.example' >&2; exit 1; }
[[ -x "$cli" ]] || { echo 'bin/aiw is not executable' >&2; exit 1; }

grep -Fq "$goose_image" "$compose_file"
grep -Fq "GOOSE_IMAGE=$goose_image" "$env_example"
grep -Fq 'read_only: true' "$compose_file"
grep -Fq 'no-new-privileges:true' "$compose_file"
grep -Fq 'cap_drop:' "$compose_file"
! grep -Fq '/var/run/docker.sock' "$compose_file"

grep -Eq '^GOOSE_MODEL=$' "$env_example"
grep -Eq '^OPENROUTER_API_KEY=$' "$env_example"
grep -Fq 'aiw goose up' < <("$cli" goose help)

printf 'Goose runtime layout is valid.\n'
