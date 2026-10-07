#!/usr/bin/env bash
# Sourced by aiw-core. Provider configuration belongs to Goose, not the launcher.

goose_configure() {
    require_docker
    runtime_init
    if [[ -n "$(env_value GOOSE_PROVIDER "$RUNTIME_ENV_FILE")$(env_value GOOSE_MODEL "$RUNTIME_ENV_FILE")" ]]; then
        warn 'Legacy Goose routing in .env is ignored. Select the intended connection in this native menu.'
    fi
    printf '[..] Configure Goose without a project mount; settings persist in goose-home.\n'
    goose_compose run --rm --no-deps --entrypoint goose goose configure
}

goose_edit_env() {
    local editor_command=() editor_status=0
    IFS=' ' read -r -a editor_command <<< "${VISUAL:-${EDITOR:-sensible-editor}}"
    command -v "${editor_command[0]}" >/dev/null 2>&1 || fail 'No editor available. Set EDITOR to your installed terminal editor.'
    mkdir -p "$CONFIG_DIR" "$(dirname -- "$GOOSE_ENV_FILE")"
    chmod 700 "$CONFIG_DIR"
    if [[ ! -e "$GOOSE_ENV_FILE" ]]; then
        (umask 077; cat > "$GOOSE_ENV_FILE" <<'EOF_ENV'
# Optional Goose-only environment. One NAME=value per line.
# Values are literal: do not add shell quotes or rely on ${VAR} interpolation.
# Native `aiw goose configure` is the normal provider/model/credential setup.
# Add only settings you intend Goose to use; routing variables override native settings.
# Example for Goose releases that support separate subagent defaults:
# GOOSE_SUBAGENT_PROVIDER=your-native-provider-id
# GOOSE_SUBAGENT_MODEL=your-subtask-model-id
EOF_ENV
        )
    fi
    chmod 600 "$GOOSE_ENV_FILE"
    "${editor_command[@]}" "$GOOSE_ENV_FILE" || editor_status=$?
    chmod 600 "$GOOSE_ENV_FILE"
    return "$editor_status"
}

goose_config_summary() {
    local mode="${1:-check}" config_python=python3 pull_args=()
    [[ "$mode" != status ]] || pull_args+=(--pull never)
    [[ ! -x "${ROOT}/.venv/bin/python" ]] || config_python="${ROOT}/.venv/bin/python"
    if ! "$config_python" -c 'import yaml' >/dev/null 2>&1; then
        warn 'The workstation Python environment is missing. Run: aiw install'
        return 1
    fi
    # Only this pipe sees the raw configuration. Never print it or its parse errors.
    # No host bind mount, provider creation, extension startup or LLM request occurs.
    goose_compose run --rm --no-deps --no-TTY "${pull_args[@]}" --entrypoint /bin/sh goose -c '
        printf "%s\n" "${GOOSE_PROVIDER+x}:${GOOSE_PROVIDER-}" "${GOOSE_MODEL+x}:${GOOSE_MODEL-}" "${GOOSE_SUBAGENT_PROVIDER+x}:${GOOSE_SUBAGENT_PROVIDER-}" "${GOOSE_SUBAGENT_MODEL+x}:${GOOSE_SUBAGENT_MODEL-}"
        if [ -n "${GOOSE_PATH_ROOT-}" ]; then
            config_path="$GOOSE_PATH_ROOT/config/config.yaml"
        else
            config_path="${XDG_CONFIG_HOME:-$HOME/.config}/goose/config.yaml"
        fi
        if [ -f "$config_path" ]; then cat "$config_path"; fi
    ' | "$config_python" "${ROOT}/tools/goose-config-summary.py" "$mode"
}

require_goose_configuration() {
    goose_config_summary check || fail 'Goose configuration is missing, incomplete or unreadable. Run: aiw goose configure (or review aiw goose env).'
}

goose_check() {
    require_docker
    require_goose_configuration
    printf '[..] Testing only the selected connection with a short probe; no project is mounted.\n'
    goose_compose run --rm --no-deps --entrypoint goose goose info --check
}
