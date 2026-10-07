#!/usr/bin/env bash
set -Eeuo pipefail
trap 'printf "Goose configuration smoke check failed at line %s.\n" "$LINENO" >&2' ERR
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT
export HOME="$temp_dir/operator" MOCK_GOOSE_HOME="$temp_dir/volume"
export AIW_RUNTIME_ENV_FILE="$temp_dir/runtime.env" MOCK_DOCKER_LOG="$temp_dir/docker.log"
export AIW_GOOSE_ENV_FILE="$HOME/.config/ai-workstation/goose.env"
# Real Compose does not inherit these host variables unless explicitly configured.
unset GOOSE_PROVIDER GOOSE_MODEL GOOSE_SUBAGENT_PROVIDER GOOSE_SUBAGENT_MODEL GOOSE_PATH_ROOT XDG_CONFIG_HOME
mkdir -p "$HOME" "$MOCK_GOOSE_HOME/.config/goose" "$temp_dir/bin" "$temp_dir/project" "$temp_dir/unrelated"
export PATH="$temp_dir/bin:$PATH"
ln -s "$ROOT/bin/aiw" "$temp_dir/bin/aiw"
native_config="$MOCK_GOOSE_HOME/.config/goose/config.yaml"
cat > "$AIW_RUNTIME_ENV_FILE" <<'EOF_ENV'
GOOSE_PROVIDER=openrouter
GOOSE_MODEL=openrouter/auto
OPENROUTER_API_KEY=old-cloud-secret
EOF_ENV
cat > "$temp_dir/bin/docker" <<'MOCK_DOCKER'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >> "$MOCK_DOCKER_LOG"
if [[ " $* " == *' image inspect '* && "${MOCK_IMAGE_MISSING:-0}" != 0 ]]; then exit 1; fi
if [[ " $* " == *' --entrypoint /bin/sh '* ]]; then
    [[ "${MOCK_READ_FAIL:-0}" == 0 ]] || exit 42
    if [[ -f "$AIW_GOOSE_ENV_FILE" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -n "$line" && "$line" != \#* && "$line" == *=* ]] || continue
            export "$line"
        done < "$AIW_GOOSE_ENV_FILE"
    fi
    HOME="$MOCK_GOOSE_HOME" exec /bin/sh -c "${@: -1}"
fi
if [[ " $* " == *' goose configure ' ]]; then
    [[ "${MOCK_CONFIGURE_FAIL:-0}" == 0 ]] || exit 43
    if [[ -n "${MOCK_SETUP_FILE:-}" ]]; then
        cp "$MOCK_SETUP_FILE" "$MOCK_GOOSE_HOME/.config/goose/config.yaml"
    fi
fi
if [[ " $* " == *' goose info --check ' ]]; then
    exit "${MOCK_CHECK_STATUS:-0}"
fi
MOCK_DOCKER
chmod +x "$temp_dir/bin/docker"
cd "$temp_dir/unrelated"
aiw goose workspace add private "$temp_dir/project" >/dev/null

# Legacy cloud values cannot start Goose or be imported automatically.
if aiw goose session private > "$temp_dir/output" 2>&1; then
    echo 'Missing native configuration launched a project session.' >&2; exit 1
fi
! grep -Fq -- '--volume' "$MOCK_DOCKER_LOG"

: > "$MOCK_DOCKER_LOG"
MOCK_IMAGE_MISSING=1 aiw goose status > "$temp_dir/output"
! grep -Fq -- '--entrypoint' "$MOCK_DOCKER_LOG"
! grep -Fq 'old-cloud-secret' "$temp_dir/output"

# Native configuration is provider-neutral, directory-independent and mount-free.
cat > "$temp_dir/setup.yaml" <<'EOF_CONFIG'
active_provider: selfhosted-custom
providers:
  selfhosted-custom:
    model: sparringpartner
OPENAI_API_KEY: private-sentinel
EOF_CONFIG
MOCK_SETUP_FILE="$temp_dir/setup.yaml" aiw goose configure > "$temp_dir/output"
grep -Fq 'goose configure' "$MOCK_DOCKER_LOG"
! grep -Fq -- '--volume' "$MOCK_DOCKER_LOG"
[[ "$(stat -c %a "$AIW_RUNTIME_ENV_FILE")" == 600 ]]
aiw goose session private --model special-model > "$temp_dir/output"
grep -Fq 'selfhosted-custom' "$temp_dir/output"
grep -Fq 'sparringpartner' "$temp_dir/output"
! grep -Fq 'private-sentinel' "$temp_dir/output"
launch="$(tail -n 1 "$MOCK_DOCKER_LOG")"
[[ "$launch" == *"--volume $temp_dir/project:/workspaces/private"* ]]
[[ "$launch" == *'--workdir /workspaces/private'* ]]
[[ "$launch" == *'goose session --model special-model'* ]]
[[ "$launch" != *"$temp_dir/unrelated"* ]]
[[ "$launch" != *'openrouter'* ]]

# Incomplete/malformed settings and failed offline reads never mount the project.
for kind in incomplete malformed; do
    if [[ "$kind" == incomplete ]]; then
        printf 'active_provider: local\nproviders: {}\n' > "$native_config"
    else
        printf 'token: [private-sentinel\n' > "$native_config"
    fi
    : > "$MOCK_DOCKER_LOG"
    if aiw goose run private --text test > "$temp_dir/output" 2>&1; then exit 1; fi
    ! grep -Fq -- '--volume' "$MOCK_DOCKER_LOG"
    ! grep -Fq 'private-sentinel' "$temp_dir/output"
done
cp "$temp_dir/setup.yaml" "$native_config"
: > "$MOCK_DOCKER_LOG"
if MOCK_READ_FAIL=1 aiw goose session private > "$temp_dir/output" 2>&1; then exit 1; fi
! grep -Fq -- '--volume' "$MOCK_DOCKER_LOG"

# Legacy native YAML remains supported; no key is required by the launcher.
printf 'GOOSE_PROVIDER: ollama\nGOOSE_MODEL: local-model\n' > "$native_config"
aiw goose run private --text test > "$temp_dir/output"
grep -Fq 'ollama' "$temp_dir/output"

# Environment editing preserves literal credentials and protects the file again.
cat > "$temp_dir/bin/test-editor" <<'EDITOR'
#!/usr/bin/env bash
cat > "$1" <<'ENV_FILE'
GOOSE_PROVIDER=custom-api
GOOSE_MODEL=sparringpartner
GOOSE_SUBAGENT_PROVIDER=custom-api
GOOSE_SUBAGENT_MODEL=agent
OPENAI_API_KEY=literal-$key-with-"quotes"
ENV_FILE
chmod 666 "$1"
EDITOR
chmod +x "$temp_dir/bin/test-editor"
EDITOR=test-editor VISUAL= aiw goose env
[[ "$(stat -c %a "$AIW_GOOSE_ENV_FILE")" == 600 ]]
[[ "$(stat -c %a "$(dirname "$AIW_GOOSE_ENV_FILE")")" == 700 ]]
grep -Fq 'literal-$key-with-"quotes"' "$AIW_GOOSE_ENV_FILE"
aiw goose run private --text test > "$temp_dir/output"
grep -Fq 'custom-api' "$temp_dir/output"
grep -Fq 'agent (release-dependent)' "$temp_dir/output"
! grep -Fq 'literal-' "$temp_dir/output"
! grep -Fq 'literal-' "$MOCK_DOCKER_LOG"

# Explicit empty routing overrides fail rather than restoring an old provider.
cp "$AIW_GOOSE_ENV_FILE" "$temp_dir/environment-backup"
printf 'GOOSE_PROVIDER=\nGOOSE_MODEL=\n' > "$AIW_GOOSE_ENV_FILE"
: > "$MOCK_DOCKER_LOG"
if aiw goose session private > "$temp_dir/output" 2>&1; then exit 1; fi
! grep -Fq -- '--volume' "$MOCK_DOCKER_LOG"
cp "$temp_dir/environment-backup" "$AIW_GOOSE_ENV_FILE"

# Configuration, checks and editing are reachable from the existing menus.
: > "$MOCK_DOCKER_LOG"
printf '1\n1\n9\n\n10\n\n11\n\nb\nq\nq\n' | EDITOR=test-editor VISUAL= aiw > "$temp_dir/menu"
grep -Fq 'goose configure' "$MOCK_DOCKER_LOG"
! grep -Fq -- '--volume' "$MOCK_DOCKER_LOG"
grep -Fq '10) Edit Goose environment' "$temp_dir/menu"
grep -Fq 'goose info --check' "$MOCK_DOCKER_LOG"
: > "$MOCK_DOCKER_LOG"
aiw goose status > "$temp_dir/output"
grep -Fq -- '--pull never' "$MOCK_DOCKER_LOG"
! grep -Fq 'literal-' "$temp_dir/output"
! grep -Fq -- '--volume' "$MOCK_DOCKER_LOG"

# An explicitly selected relative env path refers to the caller's directory.
cp "$AIW_GOOSE_ENV_FILE" relative.env
AIW_GOOSE_ENV_FILE=relative.env aiw goose run private --text test > "$temp_dir/output"
grep -Fq 'custom-api' "$temp_dir/output"
: > "$MOCK_DOCKER_LOG"
aiw goose check >/dev/null
grep -Fq 'goose info --check' "$MOCK_DOCKER_LOG"
! grep -Fq -- '--volume' "$MOCK_DOCKER_LOG"
if MOCK_CHECK_STATUS=44 aiw goose check >/dev/null 2>&1; then exit 1; fi
if MOCK_CONFIGURE_FAIL=1 aiw goose configure >/dev/null 2>&1; then exit 1; fi

printf 'Native Goose configuration, migration, environment and workspace boundaries are valid.\n'
