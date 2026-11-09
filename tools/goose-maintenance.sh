#!/usr/bin/env bash
# Admin-only Goose access; no agent start, workspace mount or network.

goose_maintenance_lock() {
    local mode="$1" result_name="$2" lock_fd
    mkdir -p -- "$CONFIG_DIR"
    chmod 700 -- "$CONFIG_DIR"
    (umask 077; : >> "$CONFIG_DIR/goose-maintenance.lock")
    chmod 600 -- "$CONFIG_DIR/goose-maintenance.lock"
    exec {lock_fd}>"$CONFIG_DIR/goose-maintenance.lock"
    if [[ "$mode" == shared ]]; then
        flock --shared --nonblock "$lock_fd" ||
            fail 'Goose configuration is being edited.'
    else
        flock --exclusive --nonblock "$lock_fd" ||
            fail 'A Goose session or another editor is active.'
    fi
    printf -v "$result_name" '%s' "$lock_fd"
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
