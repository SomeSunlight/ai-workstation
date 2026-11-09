#!/usr/bin/env bash
# Fully mocked Docker: exercise Goose operator flows without touching real volumes.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
temp="$(mktemp -d)"
trap 'rm -rf -- "$temp"' EXIT
export HOME="$temp/home" MOCK_VOLUME="$temp/volume" MOCK_DOCKER_LOG="$temp/docker.log"
export AIW_RUNTIME_ENV_FILE="$temp/runtime.env" AIW_GOOSE_ENV_FILE="$temp/goose.env"
export MOCK_GOOSE_BUSY=0 MOCK_VOLUME_MISSING=0 MOCK_IMAGE_MISSING=0
mkdir -p "$HOME" "$MOCK_VOLUME/.config/goose" "$temp/bin"
export PATH="$temp/bin:$PATH"
cat > "$AIW_RUNTIME_ENV_FILE" <<'EOF_ENV'
GOOSE_IMAGE=ghcr.io/aaif-goose/goose:v1.44.0
EOF_ENV
cat > "$AIW_GOOSE_ENV_FILE" <<'EOF_ENV'
OPENAI_BASE_URL=https://user:password@llm.example.net/v1?token=env-secret
GOOSE_SUBAGENT_MODEL=agent
OPENAI_API_KEY=secret-in-env
EOF_ENV
cat > "$MOCK_VOLUME/.config/goose/config.yaml" <<'YAML'
active_provider: custom
providers:
  custom:
    model: sparringpartner
    base_url: https://user:password@local.example.net/v1?api_key=secret-in-url
    api_key: secret-in-yaml
custom_providers:
  - name: another
    api_base: https://user:password@another.example.net/v1?token=secret-list
YAML
cat > "$temp/bin/docker" <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >> "$MOCK_DOCKER_LOG"
if [[ "$1" == compose ]]; then
    if [[ " $* " == *' goose --version '* || " $* " == *' goose --version' ]]; then
        echo 'goose 1.44.0'
    fi
    exit 0
fi
if [[ "$1" == info ]]; then exit 0; fi
if [[ "$1" == volume && "$2" == inspect ]]; then
    [[ "$MOCK_VOLUME_MISSING" != 1 ]]
    exit
fi
if [[ "$1" == image && "$2" == inspect ]]; then
    [[ "$MOCK_IMAGE_MISSING" != 1 ]]
    exit
fi
if [[ "$1" == ps ]]; then
    [[ "$MOCK_GOOSE_BUSY" != 1 ]] || echo 'running-container'
    exit 0
fi
if [[ "$1" == run ]]; then
    config_path=''
    while (($#)); do
        if [[ "$1" == --env && "$2" == AIW_CONFIG_PATH=* ]]; then
            config_path="$2"
            config_path="${config_path#AIW_CONFIG_PATH=}"
            shift 2
            continue
        fi
        if [[ "$1" == -c ]]; then
            shift
            script="$1"
            shift
            suffix="${config_path#/home/goose}"
            export AIW_CONFIG_PATH="$MOCK_VOLUME$suffix"
            exec /bin/sh -c "$script" "$@"
        fi
        shift
    done
fi
echo 'Unexpected Docker command' >&2
exit 2
MOCK
chmod +x "$temp/bin/docker"
cli="$ROOT/bin/aiw"
output="$("$cli" goose version)"
grep -Fq 'goose 1.44.0' <<< "$output"
grep -Fq -- '--pull never' "$MOCK_DOCKER_LOG"

output="$("$cli" goose inspect)"
grep -Fq 'custom' <<< "$output"
grep -Fq 'sparringpartner' <<< "$output"
grep -Fq 'https://local.example.net/v1' <<< "$output"
grep -Fq 'https://llm.example.net/v1' <<< "$output"
grep -Fq 'https://another.example.net/v1' <<< "$output"
grep -Fq 'GOOSE_SUBAGENT_MODEL: agent' <<< "$output"
for secret in secret-in-url secret-in-yaml secret-in-env secret-list password; do
    ! grep -Fq "$secret" <<< "$output"
done
grep -Fq -- '--network none' "$MOCK_DOCKER_LOG"
grep -Fq -- 'target=/home/goose,readonly' "$MOCK_DOCKER_LOG"
! grep -Fq -- '/workspaces' "$MOCK_DOCKER_LOG"

cat > "$temp/next.yaml" <<'YAML'
active_provider: custom
providers:
  custom:
    model: agent
    base_url: https://local.example.net/v1
    api_key: secret-new
YAML
cat > "$temp/bin/editor" <<'EDITOR'
#!/usr/bin/env bash
cp "$MOCK_NEW_CONFIG" "$1"
EDITOR
chmod +x "$temp/bin/editor"
export MOCK_NEW_CONFIG="$temp/next.yaml"
printf 'y\n' | VISUAL= EDITOR=editor "$cli" goose edit > "$temp/edited-output"
grep -Fq 'model: agent' "$MOCK_VOLUME/.config/goose/config.yaml"
grep -Fq 'model: sparringpartner' "$MOCK_VOLUME/.config/goose/config.yaml.aiw-backup"
[[ "$(stat -c %a "$MOCK_VOLUME/.config/goose/config.yaml")" == 600 ]]
! grep -Fq 'secret-new' "$temp/edited-output"

# Invalid YAML must leave the previously saved file untouched.
printf 'not: [valid\n' > "$temp/invalid.yaml"
export MOCK_NEW_CONFIG="$temp/invalid.yaml"
if printf 'y\n' | VISUAL= EDITOR=editor "$cli" goose edit > "$temp/output" 2>&1; then
    echo 'Invalid YAML was accepted' >&2; exit 1
fi
grep -Fq 'model: agent' "$MOCK_VOLUME/.config/goose/config.yaml"

# Detect an out-of-band edit while the operator is in the editor.
cat > "$temp/bin/editor-race" <<'EDITOR'
#!/usr/bin/env bash
cp "$MOCK_NEW_CONFIG" "$1"
printf '# external edit\n' >> "$MOCK_VOLUME/.config/goose/config.yaml"
EDITOR
chmod +x "$temp/bin/editor-race"
export MOCK_NEW_CONFIG="$temp/next.yaml"
if printf 'y\n' | VISUAL= EDITOR=editor-race "$cli" goose edit > "$temp/output" 2>&1; then
    echo 'Stale Goose configuration was overwritten' >&2; exit 1
fi
grep -Fq '# external edit' "$MOCK_VOLUME/.config/goose/config.yaml"

# Explicit rejection (default) and concurrent session both fail closed.
export MOCK_NEW_CONFIG="$temp/next.yaml"
printf 'active_provider: another\n' > "$temp/next.yaml"
printf 'n\n' | VISUAL= EDITOR=editor "$cli" goose edit > "$temp/output"
grep -Fq 'model: agent' "$MOCK_VOLUME/.config/goose/config.yaml"
if MOCK_GOOSE_BUSY=1 VISUAL= EDITOR=editor "$cli" goose edit > "$temp/output" 2>&1; then
    echo 'Busy Goose allowed an edit' >&2; exit 1
fi
if MOCK_VOLUME_MISSING=1 "$cli" goose inspect > "$temp/output" 2>&1; then exit 1; fi
if MOCK_IMAGE_MISSING=1 "$cli" goose inspect > "$temp/output" 2>&1; then exit 1; fi
if "$cli" goose shell </dev/null > "$temp/output" 2>&1; then exit 1; fi

# New menu entries are discoverable; no Docker change required for menu navigation.
output="$(printf '1\n1\nb\nq\nq\n' | "$cli")"
grep -Fq '12) Show Goose version' <<< "$output"
grep -Fq '13) Inspect Goose configuration' <<< "$output"
grep -Fq '14) Edit Goose configuration' <<< "$output"
grep -Fq '15) Maintenance shell' <<< "$output"
printf 'Goose operator maintenance and safety checks passed.\n'
