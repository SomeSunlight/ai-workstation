#!/usr/bin/env bash
# Ephemeral CI runner ONLY. Never point this script at a live Goose volume.
set -Eeuo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
tmp="$(mktemp -d)"
export HOME="$tmp/home" AIW_AGENT_SANDBOX_DIR="$tmp/state"
mkdir -p "$HOME" "$tmp/project"
printf '# Original\n' > "$tmp/project/README.md"
cleanup() {
    for v in ai-workstation_goose-home aiw-agent-goose-legacy-backup aiw-agent-goose-profile; do
        docker volume rm "$v" >/dev/null 2>&1 || :
    done
    for v in $(docker volume ls --format '{{.Name}}' --filter name=aiw-agent-home-); do
        docker volume rm "$v" >/dev/null 2>&1 || :
    done
    rm -rf -- "$tmp"
}
trap cleanup EXIT
image="$(python3 - "$root/config/versions.json" <<'PY'
import json,sys
print(json.load(open(sys.argv[1]))["versions"]["goose"]["image"])
PY
)"
docker pull "$image"
docker volume create ai-workstation_goose-home >/dev/null
docker run --rm --network none --user 0 --entrypoint /bin/sh \
    --mount type=volume,src=ai-workstation_goose-home,dst=/home/goose "$image" \
    -c 'mkdir -p /home/goose/.config/goose /home/goose/.local/share/goose/sessions; printf "active_provider: synthetic\n" > /home/goose/.config/goose/config.yaml; echo synthetic-history > /home/goose/.local/share/goose/sessions/ci.txt'
printf 'MIGRATE\n' | python3 "$root/tools/agent_sandbox.py" migrate
printf 'BUILD\n' | python3 "$root/tools/agent_sandbox.py" build-standard
"$root/bin/aiw" goose workspace add ci-project "$tmp/project"
session="$(python3 "$root/tools/agent_sandbox.py" create ci-project --environment standard | sed -n 's/^Session ID: //p')"
[[ "$session" =~ ^[0-9a-f]{12}$ ]]
image_id="$(python3 - "$tmp/state/catalog.json" <<'PY'
import json,sys
e=json.load(open(sys.argv[1]))["environments"]["standard"]
print(e["versions"][e["active"]]["image_id"])
PY
)"
docker run --rm --pull never --read-only --user "$(id -u):$(id -g)" \
    --entrypoint /bin/sh --tmpfs /tmp:rw,noexec,size=128m \
    --mount "type=volume,src=aiw-agent-home-$session,dst=/home/goose" "$image_id" \
    -c 'set -eu; test -f /home/goose/.local/share/goose/sessions/ci.txt; uv tool install --no-cache --python 3.12.12 ruff==0.14.1; ruff --version'
python3 "$root/tools/agent_sandbox.py" candidate "$session" python-data
printf 'APPROVE python-data\n' | python3 "$root/tools/agent_sandbox.py" promote python-data
python3 "$root/tools/agent_sandbox.py" rebuild python-data 1
derived="$(python3 - "$tmp/state/catalog.json" <<'PY'
import json,sys
e=json.load(open(sys.argv[1]))["environments"]["python-data"]
print(e["versions"][e["active"]]["image_id"])
PY
)"
docker run --rm --pull never --network none --read-only --entrypoint /bin/sh "$derived" \
    -c 'ruff --version'
docker run --rm --pull never --network none --read-only --entrypoint /bin/sh "$image_id" \
    -c '! command -v ruff'
grep -Fxq '# Original' "$tmp/project/README.md"
echo 'Real Docker sandbox image, isolated uv tool and named environment verified.'
