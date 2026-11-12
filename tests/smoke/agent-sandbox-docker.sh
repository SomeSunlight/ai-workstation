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
build_log="$tmp/build-standard.log"
printf 'BUILD\n' | python3 "$root/tools/agent_sandbox.py" build-standard 2>&1 | tee "$build_log"
if grep -Eq 'InvalidDefaultArgInFrom:|Failed to initialize logging' "$build_log"; then
    echo 'Standard build emitted a Dockerfile or Goose startup warning' >&2
    exit 1
fi
"$root/bin/aiw" goose workspace add ci-project "$tmp/project"
session="$(python3 "$root/tools/agent_sandbox.py" create ci-project --environment standard --title 'Install ruff in sandbox' | sed -n 's/^Session ID: //p')"
[[ "$session" =~ ^[0-9a-f]{12}$ ]]
python3 "$root/tools/agent_sandbox.py" list | grep -Fq 'Install ruff in sandbox'
python3 "$root/tools/agent_sandbox.py" rename "$session" 'Install ruff (renamed)'
python3 "$root/tools/agent_sandbox.py" review 'Install ruff (renamed)' | grep -Fq 'No project changes'
python3 "$root/tools/agent_sandbox.py" list | grep -Fq 'Install ruff (renamed)'
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
promotion_log="$tmp/promote-python-data.log"
printf 'APPROVE python-data\n' | python3 "$root/tools/agent_sandbox.py" promote python-data 2>&1 | tee "$promotion_log"
if grep -Eq 'InvalidDefaultArgInFrom:|Failed to initialize logging' "$promotion_log"; then
    echo 'Candidate build emitted a Dockerfile or Goose startup warning' >&2
    exit 1
fi
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
# An approved variant can be reused and revised without overwriting r1.
session2="$(python3 "$root/tools/agent_sandbox.py" create ci-project --environment python-data | sed -n 's/^Session ID: //p')"
[[ "$session2" =~ ^[0-9a-f]{12}$ ]]
python3 "$root/tools/agent_sandbox.py" candidate "$session2" python-data --upgrade
printf 'APPROVE python-data\n' | python3 "$root/tools/agent_sandbox.py" promote python-data
printf 'ROLLBACK python-data\n' | python3 "$root/tools/agent_sandbox.py" rollback python-data 1
active="$(python3 - "$tmp/state/catalog.json" <<'PY'
import json,sys
print(json.load(open(sys.argv[1]))["environments"]["python-data"]["active"])
PY
)"
[[ "$active" == "1" ]] || { echo 'Rollback did not restore r1' >&2; exit 1; }
# Disable migration is reversible at the legacy entrance, with no volume deletion.
printf 'DISABLE\n' | python3 "$root/tools/agent_sandbox.py" migrate-disable
if python3 "$root/tools/agent_sandbox.py" create ci-project --environment standard >/dev/null 2>&1; then
    echo 'Disabled sandbox unexpectedly allowed new session' >&2
    exit 1
fi
docker volume inspect ai-workstation_goose-home >/dev/null
grep -Fxq '# Original' "$tmp/project/README.md"
echo 'Real Docker migration, standard, named variant, upgrade/rollback and opt-out verified.'
