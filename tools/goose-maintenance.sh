#!/usr/bin/env bash
# Admin-only Goose access; no agent start, workspace mount or network.

goose_maintenance_lock() {
    local mode="$1" result_name="$2" fd
    mkdir -p -- "$CONFIG_DIR"
    chmod 700 -- "$CONFIG_DIR"
    (umask 077; : >> "$CONFIG_DIR/goose-maintenance.lock")
    chmod 600 -- "$CONFIG_DIR/goose-maintenance.lock"
    exec {fd}>"$CONFIG_DIR/goose-maintenance.lock"
    if [[ "$mode" == shared ]]; then
        flock --shared --nonblock "$fd" ||
            fail 'Goose configuration is being edited.'
    else
        flock --exclusive --nonblock "$fd" ||
            fail 'A Goose session or another editor is active.'
    fi
    printf -v "$result_name" '%s' "$fd"
}

goose_maintenance_config_path() {
    local config_root='' xdg_root=''
    if [[ -f "$GOOSE_ENV_FILE" ]]; then
        config_root="$(env_value GOOSE_PATH_ROOT "$GOOSE_ENV_FILE")"
        xdg_root="$(env_value XDG_CONFIG_HOME "$GOOSE_ENV_FILE")"
    fi
    python3 - "$config_root" "$xdg_root" <<'PYTHON'
import posixpath
import sys
root, xdg = sys.argv[1:]
path = posixpath.join(root, "config", "config.yaml") if root else posixpath.join(
    xdg or "/home/goose/.config", "goose", "config.yaml"
)
path = posixpath.normpath(path)
if not path.startswith("/home/goose/"):
    sys.exit("Goose config must reside inside its persistent home volume.")
print(path)
PYTHON
}

goose_maintenance_preflight() {
    require_docker
    docker volume inspect ai-workstation_goose-home >/dev/null 2>&1 ||
        fail 'Goose home volume is absent. Configure Goose first.'
    local image
    image="$(runtime_selected_image goose GOOSE_IMAGE)"
    docker image inspect "$image" >/dev/null 2>&1 ||
        fail 'Selected Goose image is not installed. Use Goose update/pull.'
}

goose_maintenance_run() {
    local access="$1" operation="$2" image config_path mount_spec
    shift 2
    image="$(runtime_selected_image goose GOOSE_IMAGE)"
    config_path="$(goose_maintenance_config_path)" || return 1
    mount_spec='type=volume,source=ai-workstation_goose-home,target=/home/goose'
    [[ "$access" == rw ]] || mount_spec+=',readonly'
    local tty=(-i)
    [[ "$operation" != shell ]] || tty=(-it)
    docker run "${tty[@]}" --rm --pull=never --network none --read-only \
        --cap-drop ALL --security-opt no-new-privileges:true --pids-limit 64 \
        --mount "$mount_spec" \
        --env HOME=/home/goose --env "AIW_CONFIG_PATH=$config_path" \
        --entrypoint /bin/sh "$image" "$@"
}

goose_maintenance_read() {
    goose_maintenance_run ro read -c '
        if [ ! -f "$AIW_CONFIG_PATH" ] || [ -L "$AIW_CONFIG_PATH" ]; then
            echo "Native Goose configuration missing or not a regular file." >&2
            exit 2
        fi
        cat "$AIW_CONFIG_PATH"
    '
}

goose_maintenance_python() {
    if [[ -x "${ROOT}/.venv/bin/python" ]]; then
        "${ROOT}/.venv/bin/python" "${ROOT}/tools/goose-maintenance.py" "$@"
    else
        python3 "${ROOT}/tools/goose-maintenance.py" "$@"
    fi
}

goose_maintenance_inspect() {
    goose_maintenance_preflight
    goose_maintenance_read | goose_maintenance_python inspect "$GOOSE_ENV_FILE"
}

goose_maintenance_assert_idle() {
    local running
    running="$(docker ps --quiet \
        --filter label=com.docker.compose.project=ai-workstation-goose \
        --filter label=com.docker.compose.service=goose)" ||
        fail 'Cannot determine whether Goose sessions are running.'
    [[ -z "$running" ]] ||
        fail 'Stop active Goose sessions before editing shared configuration.'
}

goose_maintenance_edit() (
    set -Eeuo pipefail
    goose_maintenance_preflight
    local lock_fd
    goose_maintenance_lock exclusive lock_fd
    goose_maintenance_assert_idle
    mkdir -p -- "$CONFIG_DIR"
    chmod 700 -- "$CONFIG_DIR"
    local temp_dir
    temp_dir="$(umask 077; mktemp -d "$CONFIG_DIR/.goose-edit.XXXXXXXX")"
    trap 'rm -rf -- "$temp_dir"' EXIT
    local original="$temp_dir/original.yaml" edited="$temp_dir/config.yaml"
    (umask 077; goose_maintenance_read > "$original") ||
        fail 'Could not read Goose configuration; nothing changed.'
    cp -- "$original" "$edited"
    chmod 600 -- "$edited"
    printf 'Editing a private copy. Changes are validated before applying.\n'
    aiw_open_editor "$edited" || fail 'Editor failed; nothing changed.'
    [[ -f "$edited" && ! -L "$edited" ]] ||
        fail 'Edited configuration must remain a regular file.'
    chmod 600 -- "$edited"
    if cmp -s -- "$original" "$edited"; then
        printf '[OK] Configuration unchanged.\n'
        return 0
    fi
    goose_maintenance_python validate < "$edited" ||
        fail 'Invalid Goose YAML; original is unchanged.'
    goose_maintenance_assert_idle
    local reply
    read -r -p 'Apply validated config and retain a private backup? [y/N] ' reply ||
        return 1
    [[ "$reply" == y || "$reply" == Y ]] || {
        printf 'Cancelled; original retained.\n'
        return 0
    }
    local expected_sha
    expected_sha="$(sha256sum "$original")"
    expected_sha="${expected_sha%% *}"
    goose_maintenance_run rw write -c '
        set -eu
        [ -f "$AIW_CONFIG_PATH" ] && [ ! -L "$AIW_CONFIG_PATH" ] ||
            { echo "Original Goose config is missing or unsafe." >&2; exit 2; }
        [ "$(sha256sum "$AIW_CONFIG_PATH" | cut -d " " -f 1)" = "$1" ] ||
            { echo "Original Goose config changed during edit; refusing overwrite." >&2; exit 2; }
        dest="${AIW_CONFIG_PATH%/*}"
        staged="$(mktemp "$dest/.aiw-goose-stage.XXXXXXXX")"
        backup="$(mktemp "$dest/.aiw-goose-backup.XXXXXXXX")"
        trap "rm -f -- \"$staged\" \"$backup\"" EXIT
        umask 077
        cat > "$staged"
        chmod 600 "$staged"
        cp "$AIW_CONFIG_PATH" "$backup"
        chmod 600 "$backup"
        mv -f "$backup" "$AIW_CONFIG_PATH.aiw-backup"
        mv -f "$staged" "$AIW_CONFIG_PATH"
    ' sh "$expected_sha" < "$edited" ||
        fail 'Volume update failed; inspect original/backup before retrying.'
    printf '[OK] Goose config updated; previous file retained as config.yaml.aiw-backup.\n'
)

goose_maintenance_shell() {
    [[ -t 0 && -t 1 ]] || fail 'Maintenance shell requires an interactive terminal.'
    goose_maintenance_preflight
    printf 'Read-only Goose home, no network, no agent, no project. Type exit to close.\n'
    goose_maintenance_run ro shell -i
}
