#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
compose_file="${ROOT}/compose/open-webui.yml"
env_example="${ROOT}/.env.example"
cli="${ROOT}/bin/aiw"
open_webui_image="$(
  python3 - "${ROOT}/config/versions.json" <<'PYTHON'
import json
import sys
from pathlib import Path

print(json.loads(Path(sys.argv[1]).read_text())["versions"]["open_webui"]["image"])
PYTHON
)"

[[ -f "$compose_file" ]] || { echo 'Missing compose/open-webui.yml' >&2; exit 1; }
[[ -f "$env_example" ]] || { echo 'Missing .env.example' >&2; exit 1; }
[[ -x "$cli" ]] || { echo 'bin/aiw is not executable' >&2; exit 1; }

grep -Fq 'name: ai-workstation-open-webui' "$compose_file"
grep -Fq "$open_webui_image" "$compose_file"
grep -Fq "OPEN_WEBUI_IMAGE=$open_webui_image" "$env_example"
grep -Fq '127.0.0.1:${OPEN_WEBUI_PORT:-3000}:8080' "$compose_file"
grep -Fq 'source: open-webui-data' "$compose_file"
grep -Fq 'name: ai-workstation_open-webui-data' "$compose_file"
grep -Fq 'target: /app/backend/data' "$compose_file"
grep -Fq 'WEBUI_AUTH: "True"' "$compose_file"
grep -Fq 'ENABLE_OLLAMA_API: "False"' "$compose_file"
grep -Fq 'ENABLE_OPENAI_API: "True"' "$compose_file"
grep -Fq 'OPENAI_API_BASE_URL:' "$compose_file"
grep -Fq 'OPENAI_API_KEY:' "$compose_file"
grep -Fq 'no-new-privileges:true' "$compose_file"
! grep -Fq '/var/run/docker.sock' "$compose_file"

grep -Eq '^OPEN_WEBUI_PORT=3000$' "$env_example"
grep -Eq '^OPEN_WEBUI_OPENAI_API_BASE_URL=https://openrouter.ai/api/v1$' "$env_example"
grep -Fq 'aiw open-webui open' < <("$cli" open-webui help)


temp_home="$(mktemp -d)"
trap 'rm -rf "$temp_home"' EXIT
mock_bin="${temp_home}/mock-bin"
mock_log="${temp_home}/docker.log"
mock_env="${temp_home}/runtime.env"
mkdir -p "$mock_bin"
cat > "${mock_bin}/docker" <<'MOCK_DOCKER'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >> "${MOCK_DOCKER_LOG}"
if [[ "${1:-}" == "compose" && "${2:-}" == "version" ]]; then
  printf 'Docker Compose version v5.3.0\n'
fi
MOCK_DOCKER
chmod +x "${mock_bin}/docker"
cat > "$mock_env" <<EOF_ENV
OPENROUTER_API_KEY=test-only
OPEN_WEBUI_IMAGE=$open_webui_image
OPEN_WEBUI_PORT=3000
OPEN_WEBUI_OPENAI_API_BASE_URL=https://openrouter.ai/api/v1
OPEN_WEBUI_MODEL_LIST_TIMEOUT=30
EOF_ENV
PATH="${mock_bin}:$PATH" MOCK_DOCKER_LOG="$mock_log" AIW_RUNTIME_ENV_FILE="$mock_env" \
  HOME="$temp_home" "$cli" open-webui up >/dev/null
mock_command="$(tail -n 1 "$mock_log")"
grep -Fq -- '--project-name ai-workstation-open-webui' <<< "$mock_command"
grep -Fq -- 'up --detach --remove-orphans open-webui' <<< "$mock_command"

printf 'Open WebUI runtime layout is valid.\n'
