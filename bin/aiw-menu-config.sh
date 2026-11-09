#!/usr/bin/env bash
# Shared, intentionally small menu configuration/learning-mode helpers.
# Sourced by both aiw front controller and aiw-core; never execute YAML as shell.
#
# Supported YAML scalar today: menu_command_preview: true|false
# Other keys are reserved for future settings and ignored by this reader.

aiw_menu_config_path() {
    printf '%s\n' "${AIW_MENU_CONFIG_FILE:-${HOME}/.config/ai-workstation/config.yaml}"
}

aiw_menu_ensure_config() {
    local file
    file="$(aiw_menu_config_path)"
    if [[ -e "$file" ]]; then
        [[ -f "$file" ]] || { printf '[XX] Configuration is not a regular file: %s\n' "$file" >&2; return 1; }
        return 0
    fi
    (umask 077
        mkdir -p -- "$(dirname -- "$file")"
        cat > "$file" <<'EOF_CONFIG'
# AI Workstation user settings (YAML).
# This file lives in your Linux home, not in the Git checkout. It survives
# closing and restarting WSL and is never overwritten by an aiw update.
#
# menu_command_preview:
#   false (default) = run interactive menu actions normally.
#   true = show the equivalent copyable "aiw ..." shell command before each
#          actionable menu selection and ask "Continue? [y/N]".
#          Only "y" or "Y" executes it; Enter, "n", or EOF cancels.
#          Direct aiw CLI commands are unaffected. Existing safety prompts
#          still apply. This previews the public aiw command, NOT every
#          internal Docker/Ansible subprocess.
#
# Future settings can be added here. Do not put passwords/API keys here.
menu_command_preview: false
EOF_CONFIG
    )
    chmod 600 -- "$file"
}

aiw_menu_preview_enabled() {
    local file line value='' seen=0
    file="$(aiw_menu_config_path)"
    [[ -e "$file" ]] || { printf 'false\n'; return 0; }
    [[ -r "$file" && -f "$file" ]] || { printf '[XX] Cannot read menu configuration: %s\n' "$file" >&2; return 1; }
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^[[:space:]]*menu_command_preview[[:space:]]*: ]]; then
            if [[ ! "$line" =~ ^[[:space:]]*menu_command_preview[[:space:]]*:[[:space:]]*(true|false)[[:space:]]*(#.*)?$ ]]; then
                printf '[XX] Invalid menu_command_preview in %s; use true or false.\n' "$file" >&2
                return 1
            fi
            ((seen += 1))
            if ((seen > 1)); then
                printf '[XX] Duplicate menu_command_preview key in %s.\n' "$file" >&2
                return 1
            fi
            value="${BASH_REMATCH[1]}"
        fi
    done < "$file"
    printf '%s\n' "${value:-false}"
}

aiw_menu_confirm_command() {
    local enabled reply
    enabled="$(aiw_menu_preview_enabled)" || return 1
    [[ "$enabled" == true ]] || return 0
    printf '\nCommand to run:'
    printf ' %q' "$@"
    printf '\n'
    printf 'Continue? [y/N] '
    if ! read -r reply; then
        printf '\n'
        return 1
    fi
    printf '\n'
    [[ "$reply" == y || "$reply" == Y ]]
}

# Shared editor selection for AIW YAML and Goose native configuration.
aiw_open_editor() {
    local file="$1" editor
    editor="${VISUAL:-${EDITOR:-}}"
    if [[ -n "$editor" ]]; then
        # No eval: only simple arguments; shell metacharacters are not executed.
        local -a argv=()
        IFS=' ' read -r -a argv <<< "$editor"
        "${argv[@]}" "$file"
    elif command -v sensible-editor >/dev/null 2>&1; then
        sensible-editor "$file"
    elif command -v nano >/dev/null 2>&1; then
        nano "$file"
    elif command -v vi >/dev/null 2>&1; then
        vi "$file"
    else
        printf '[XX] No editor found. Set VISUAL or EDITOR and retry.\n' >&2
        return 1
    fi
}

aiw_menu_edit_config() {
    aiw_menu_ensure_config || return 1
    aiw_open_editor "$(aiw_menu_config_path)"
}
