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

grep -Fq 'name: ai-workstation-goose' "$compose_file"
grep -Fq "$goose_image" "$compose_file"
grep -Fq "GOOSE_IMAGE=$goose_image" "$env_example"
grep -Fq 'read_only: true' "$compose_file"
grep -Fq 'no-new-privileges:true' "$compose_file"
grep -Fq 'cap_drop:' "$compose_file"
grep -Fq 'source: goose-home' "$compose_file"
grep -Fq 'name: ai-workstation_goose-home' "$compose_file"
! grep -Fq '/var/run/docker.sock' "$compose_file"
! grep -Fq 'AIW_GOOSE_WORKSPACE' "$compose_file"

grep -Eq '^GOOSE_MODEL=$' "$env_example"
grep -Eq '^OPENROUTER_API_KEY=$' "$env_example"
grep -Fq 'aiw goose workspace add NAME [PATH]' < <("$cli" goose help)
grep -Fq 'isolated per session' < <(HOME="$(mktemp -d)" "$cli" goose status)

temp_home="$(mktemp -d)"
temp_project="$(mktemp -d)"
trap 'rm -rf "$temp_home" "$temp_project"' EXIT
HOME="$temp_home" "$cli" goose workspace add sample "$temp_project" >/dev/null
workspace_list="$(HOME="$temp_home" "$cli" goose workspace list)"
grep -Fq 'sample' <<< "$workspace_list"
grep -Fq "$temp_project" <<< "$workspace_list"
[[ -L "$temp_home/.config/ai-workstation/goose-workspaces/sample" ]]
[[ "$(stat -c '%a' "$temp_home/.config/ai-workstation/goose-workspaces")" == '700' ]]

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
GOOSE_IMAGE=$goose_image
GOOSE_PROVIDER=openrouter
GOOSE_MODEL=openrouter/auto
GOOSE_DISABLE_KEYRING=1
GOOSE_DISABLE_TELEMETRY=1
EOF_ENV
PATH="${mock_bin}:$PATH" MOCK_DOCKER_LOG="$mock_log" AIW_RUNTIME_ENV_FILE="$mock_env" \
  HOME="$temp_home" "$cli" goose session sample --help >/dev/null
mock_command="$(tail -n 1 "$mock_log")"
grep -Fq -- '--project-name ai-workstation-goose' <<< "$mock_command"
grep -Fq -- "--volume ${temp_project}:/workspaces/sample" <<< "$mock_command"
grep -Fq -- '--workdir /workspaces/sample' <<< "$mock_command"
grep -Fq -- 'goose session --help' <<< "$mock_command"

HOME="$temp_home" "$cli" goose workspace remove sample >/dev/null
[[ ! -e "$temp_home/.config/ai-workstation/goose-workspaces/sample" ]]

if HOME="$temp_home" "$cli" goose workspace add too-broad "$temp_home" >/dev/null 2>&1; then
  echo 'Broad home-directory workspace was accepted.' >&2
  exit 1
fi

printf 'Goose runtime layout is valid.\n'
