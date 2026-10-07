#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cli="${ROOT}/bin/aiw"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -p "$test_dir/mock-bin" "$test_dir/data" "$test_dir/unrelated directory"
printf 'saved chats and settings\n' > "$test_dir/data/webui.db"
export AIW_RUNTIME_ENV_FILE="$test_dir/runtime.env"
export AIW_STATE_DIR="$test_dir/state"
export MOCK_DOCKER_LOG="$test_dir/docker.log"
export MOCK_CURL_LOG="$test_dir/curl.log"
export MOCK_DATA_DIR="$test_dir/data"
export PATH="$test_dir/mock-bin:$PATH"

cat > "$test_dir/mock-bin/docker" <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >> "$MOCK_DOCKER_LOG"
case "${1:-}" in
    pull) [[ "${MOCK_PULL_FAIL:-0}" == 0 ]] ;;
    volume)
        [[ "${MOCK_VOLUME_FAIL:-0}" == 0 ]] || exit 1
        if [[ "${MOCK_NO_VOLUME:-0}" == 0 ]]; then
            printf 'ai-workstation_open-webui-data\n'
        fi
        ;;
    inspect)
        case "${3:-}" in
            '{{.Config.Image}}') printf 'ghcr.io/open-webui/open-webui:v0.11.0\n' ;;
            '{{.State.Running}}')
                [[ "${MOCK_STOPPED:-0}" == 0 ]] && printf 'true\n' || printf 'false\n'
                ;;
            *) printf '%s\n' "${MOCK_DATA_VOLUME:-ai-workstation_open-webui-data}" ;;
        esac
        ;;
    run)
        [[ "${MOCK_BACKUP_FAIL:-0}" == 0 ]] || exit 1
        tar czf - -C "$MOCK_DATA_DIR" .
        ;;
    compose)
        if [[ "${2:-}" == version ]]; then
            printf 'Docker Compose version v5.3.0\n'
        elif [[ " $* " == *' ps '* ]]; then
            [[ "${MOCK_PS_FAIL:-0}" == 0 ]] || exit 1
            if [[ "${MOCK_NO_CONTAINER:-0}" == 0 ]]; then
                if [[ " $* " == *' --quiet '* ]]; then
                    printf 'mock-container-id\n'
                elif [[ " $* " == *' --status running '* && "${MOCK_STOPPED:-0}" == 0 ]]; then
                    printf 'open-webui\n'
                fi
            fi
        elif [[ " $* " == *' up '* ]]; then
            grep '^OPEN_WEBUI_IMAGE=' "$AIW_RUNTIME_ENV_FILE" >> "$MOCK_DOCKER_LOG"
            [[ "${MOCK_UP_FAIL:-0}" == 0 ]] || exit 1
        fi
        ;;
esac
MOCK
cat > "$test_dir/mock-bin/curl" <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >> "$MOCK_CURL_LOG"
if [[ " $* " == *'/releases/latest '* ]]; then
    [[ "${MOCK_RELEASE_FAIL:-0}" == 0 ]] || exit 22
    printf '%s' "${MOCK_RELEASE_JSON}"
else
    [[ "${MOCK_HEALTH_FAIL:-0}" == 0 ]]
fi
MOCK
cat > "$test_dir/mock-bin/sleep" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
chmod +x "$test_dir/mock-bin/"*

reset_case() {
    rm -rf -- "$AIW_STATE_DIR"
    : > "$MOCK_DOCKER_LOG"
    : > "$MOCK_CURL_LOG"
    cat > "$AIW_RUNTIME_ENV_FILE" <<'ENV'
# Keep this comment and credential unchanged.
OPENROUTER_API_KEY='test-only-credential'
GOOSE_IMAGE=ghcr.io/aaif-goose/goose:v1.44.0
OPEN_WEBUI_IMAGE=ghcr.io/open-webui/open-webui:v0.11.0
OPEN_WEBUI_PORT=3456
CUSTOM_OPTION="literal $VALUE with spaces"
ENV
    chmod 600 "$AIW_RUNTIME_ENV_FILE"
    cp "$AIW_RUNTIME_ENV_FILE" "$test_dir/before.env"
    unset MOCK_PULL_FAIL MOCK_NO_VOLUME MOCK_NO_CONTAINER MOCK_BACKUP_FAIL MOCK_STOPPED MOCK_PS_FAIL
    unset MOCK_UP_FAIL MOCK_RELEASE_FAIL MOCK_HEALTH_FAIL
    unset MOCK_VOLUME_FAIL
    unset MOCK_DATA_VOLUME
    export MOCK_RELEASE_JSON='{"tag_name":"v0.11.4","draft":false,"prerelease":false}'
}

expect_failure() {
    if "$cli" "$@" > "$test_dir/output" 2>&1; then
        printf 'Expected update failure: %s\n' "$*" >&2
        exit 1
    fi
}

# Invoke the installed symlink from a directory with spaces, outside the checkout.
reset_case
ln -s "$cli" "$test_dir/mock-bin/aiw"
(cd "$test_dir/unrelated directory" && aiw open-webui update --yes > "$test_dir/output")
grep -Fq 'OPEN_WEBUI_IMAGE=ghcr.io/open-webui/open-webui:v0.11.4' "$AIW_RUNTIME_ENV_FILE"
grep -Fq 'pull ghcr.io/open-webui/open-webui:v0.11.4' "$MOCK_DOCKER_LOG"
grep -Fq -- "--file $ROOT/compose/open-webui.yml" "$MOCK_DOCKER_LOG"
grep -Fq -- '--project-name ai-workstation-open-webui' "$MOCK_DOCKER_LOG"
grep -Fq -- 'stop open-webui' "$MOCK_DOCKER_LOG"
grep -Fq -- 'type=volume,src=ai-workstation_open-webui-data,dst=/data,readonly' "$MOCK_DOCKER_LOG"
grep -Fq -- 'up --detach --force-recreate --pull never open-webui' "$MOCK_DOCKER_LOG"
grep -Fq 'http://localhost:3456/health' "$MOCK_CURL_LOG"
grep -Fq 'updated and healthy' "$test_dir/output"
[[ "$(stat -c '%a' "$AIW_RUNTIME_ENV_FILE")" == 600 ]]
python3 - "$AIW_STATE_DIR" "$test_dir/before.env" "$AIW_RUNTIME_ENV_FILE" "$MOCK_DOCKER_LOG" <<'PYTHON'
import sys, tarfile
from pathlib import Path

state, before, after, log = map(Path, sys.argv[1:])
archive_path, = state.glob("backups/open-webui/*/data.tar.gz")
with tarfile.open(archive_path) as archive:
    assert archive.extractfile("./webui.db").read() == b"saved chats and settings\n"
assert (archive_path.parent / "runtime.env").read_bytes() == before.read_bytes()
assert (archive_path.parent / "previous-image.txt").read_text().strip().endswith(":v0.11.0")
assert archive_path.stat().st_mode & 0o777 == 0o600
assert archive_path.parent.stat().st_mode & 0o777 == 0o700
assert before.read_bytes().replace(b"open-webui:v0.11.0", b"open-webui:v0.11.4") == after.read_bytes()
events = log.read_text()
assert events.index("pull ghcr.io/") < events.index("stop open-webui") < events.index("run --rm") < events.index("up --detach")
assert "down" not in events and "--volumes" not in events and "prune" not in events
PYTHON

# Goose changes only its selected image; no workspace, volume or session lifecycle.
reset_case
export MOCK_RELEASE_JSON='{"tag_name":"v1.53.0","draft":false,"prerelease":false}'
printf 'GOOSE_IMAGE=old-duplicate\n' >> "$AIW_RUNTIME_ENV_FILE"
"$cli" goose update --yes > "$test_dir/output"
[[ "$(grep -c '^GOOSE_IMAGE=' "$AIW_RUNTIME_ENV_FILE")" == 1 ]]
grep -Fq 'GOOSE_IMAGE=ghcr.io/aaif-goose/goose:v1.53.0' "$AIW_RUNTIME_ENV_FILE"
! grep -Eq ' (stop|down|up|run|volume) ' "$MOCK_DOCKER_LOG"
grep -Fq 'next session' "$test_dir/output"

# Explicit versions and repository defaults need no release API call.
reset_case
"$cli" goose update 1.52.0 --yes > /dev/null
grep -Fq 'GOOSE_IMAGE=ghcr.io/aaif-goose/goose:v1.52.0' "$AIW_RUNTIME_ENV_FILE"
[[ ! -s "$MOCK_CURL_LOG" ]]
"$cli" goose update --repository --yes > /dev/null
default_goose="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["versions"]["goose"]["image"])' "$ROOT/config/versions.json")"
grep -Fxq "GOOSE_IMAGE=$default_goose" "$AIW_RUNTIME_ENV_FILE"

# Declines, unsupported versions and release errors cannot mutate configuration.
reset_case
printf 'n\n' | "$cli" open-webui update > /dev/null
cmp "$test_dir/before.env" "$AIW_RUNTIME_ENV_FILE"
[[ ! -s "$MOCK_DOCKER_LOG" ]]
for version in main latest-dev v1.2.3-rc1 '1.2.3;echo bad'; do
    expect_failure goose update "$version" --yes
done
for metadata in '{"tag_name":"v1.53.0","draft":false,"prerelease":true}' '{"tag_name":"v1.53.0-rc1","draft":false,"prerelease":false}' 'not-json'; do
    export MOCK_RELEASE_JSON="$metadata"
    expect_failure goose update --yes
done
export MOCK_RELEASE_FAIL=1
expect_failure goose update --yes
cmp "$test_dir/before.env" "$AIW_RUNTIME_ENV_FILE"
[[ ! -s "$MOCK_DOCKER_LOG" ]]

# Missing target images fail before stopping a service or writing a selection.
reset_case
export MOCK_PULL_FAIL=1
expect_failure open-webui update v0.11.4 --yes
cmp "$test_dir/before.env" "$AIW_RUNTIME_ENV_FILE"
! grep -Fq 'stop open-webui' "$MOCK_DOCKER_LOG"

# A failed backup restarts the old running service and leaves the old pin intact.
reset_case
export MOCK_BACKUP_FAIL=1
expect_failure open-webui update v0.11.4 --yes
cmp "$test_dir/before.env" "$AIW_RUNTIME_ENV_FILE"
grep -Fq 'start open-webui' "$MOCK_DOCKER_LOG"
! grep -Fq 'up --detach' "$MOCK_DOCKER_LOG"
[[ -z "$(find "$AIW_STATE_DIR" -name data.tar.gz -print)" ]]
reset_case
export MOCK_BACKUP_FAIL=1 MOCK_STOPPED=1
expect_failure open-webui update v0.11.4 --yes
! grep -Fq 'start open-webui' "$MOCK_DOCKER_LOG"

# An update failure in the menu returns to the chooser instead of exiting aiw.
reset_case
printf '1\n2\n10\n2\nbogus\n\nb\nq\nq\n' | "$cli" > "$test_dir/output" 2>&1
grep -Fq 'The command failed' "$test_dir/output"
[[ ! -s "$MOCK_DOCKER_LOG" ]]

# Recreation/health failures retain backup evidence and never claim success or
# blindly start an older image against a potentially migrated database.
for failure in MOCK_UP_FAIL MOCK_HEALTH_FAIL; do
    reset_case
    export "$failure=1"
    expect_failure open-webui update v0.11.4 --yes
    grep -Fq 'Backup:' "$test_dir/output"
    grep -Fq 'aiw open-webui logs' "$test_dir/output"
    ! grep -Fq 'updated and healthy' "$test_dir/output"
    [[ -n "$(find "$AIW_STATE_DIR" -name data.tar.gz -print)" ]]
done

# Fresh installation can start without a pre-existing volume; Docker failures
# inspecting an existing service cannot be mistaken for an empty installation.
reset_case
export MOCK_NO_VOLUME=1 MOCK_NO_CONTAINER=1
"$cli" open-webui update v0.11.4 --yes > /dev/null
! grep -Fq 'run --rm' "$MOCK_DOCKER_LOG"
reset_case
export MOCK_NO_VOLUME=1
expect_failure open-webui update v0.11.4 --yes
cmp "$test_dir/before.env" "$AIW_RUNTIME_ENV_FILE"
! grep -Fq 'up --detach' "$MOCK_DOCKER_LOG"
reset_case
export MOCK_NO_CONTAINER=1 MOCK_VOLUME_FAIL=1
expect_failure open-webui update v0.11.4 --yes
cmp "$test_dir/before.env" "$AIW_RUNTIME_ENV_FILE"
! grep -Fq 'up --detach' "$MOCK_DOCKER_LOG"
reset_case
export MOCK_DATA_VOLUME=unexpected-recovery-volume
expect_failure open-webui update v0.11.4 --yes
cmp "$test_dir/before.env" "$AIW_RUNTIME_ENV_FILE"
! grep -Fq 'stop open-webui' "$MOCK_DOCKER_LOG"

# Serialize updates sharing .env, before either can pull or stop a service.
reset_case
mkdir -p "$AIW_STATE_DIR"
exec 8> "$AIW_STATE_DIR/runtime-update.lock"
flock --nonblock 8
expect_failure goose update v1.53.0 --yes
flock --unlock 8
exec 8>&-
cmp "$test_dir/before.env" "$AIW_RUNTIME_ENV_FILE"
[[ ! -s "$MOCK_DOCKER_LOG" ]]

reset_case
if OPEN_WEBUI_IMAGE='' "$cli" open-webui update --yes > /dev/null 2>&1; then
    echo 'An exported image override was accepted.' >&2
    exit 1
fi
[[ ! -s "$MOCK_DOCKER_LOG" ]]
printf 'Application update behavior is valid.\n'
