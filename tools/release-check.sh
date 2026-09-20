#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

[[ -f uv.lock ]] || { echo 'uv.lock is missing.' >&2; exit 1; }

bash -n install.sh bootstrap/linux/install.sh bin/aiw bin/aiw-core runtimes/local-inference/manage.sh tools/*.sh tests/smoke/*.sh
python3 -m json.tool config/versions.json >/dev/null
python3 tools/check-version-consistency.py
./tests/smoke/repository-layout.sh
bash ./tests/smoke/update-recovery.sh
bash ./tests/smoke/local-inference-runtime.sh

if [[ -x "${HOME}/.local/bin/uv" ]]; then
  "${HOME}/.local/bin/uv" lock --check --python /usr/bin/python3
fi

printf 'Release checks passed.\n'
