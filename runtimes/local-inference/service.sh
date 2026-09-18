#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

readonly ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
readonly MANAGER="${AIW_LOCAL_INFERENCE_MANAGER:-${ROOT}/runtimes/local-inference/manage.sh}"
readonly CONFIG_DIR="${HOME}/.config/ai-workstation"
readonly RUNTIME_CONFIG="${AIW_LOCAL_INFERENCE_RUNTIME_CONFIG:-${CONFIG_DIR}/local-inference-runtime.env}"
readonly DISPATCHER_DIR="${AIW_LOCAL_INFERENCE_DISPATCHER_DIR:-${HOME}/.local/share/ai-workstation/local-inference/Llama_Dispatcher}"
readonly SYSTEMD_SYSTEM_DIR="${AIW_LOCAL_INFERENCE_SYSTEMD_DIR:-/etc/systemd/system}"
readonly SERVICE_NAME="ai-workstation-local-inference.service"
readonly SERVICE_FILE="${SYSTEMD_SYSTEM_DIR}/${SERVICE_NAME}"
readonly SYSTEMCTL_BIN="${AIW_SYSTEMCTL_BIN:-systemctl}"
readonly JOURNALCTL_BIN="${AIW_JOURNALCTL_BIN:-journalctl}"
readonly SUDO_BIN="${AIW_SUDO_BIN-sudo}"
readonly SERVICE_USER="$(id -un)"
readonly SERVICE_GROUP="$(id -gn)"
readonly SERVICE_HOME="$HOME"

usage() {
    cat <<'EOF'
Managed local-inference runtime

Usage:
  aiw local-inference runtime configure [--model-root PATH] [--instance NAME] [--ensemble NAME]
  aiw local-inference runtime show
  aiw local-inference start
  aiw local-inference stop
  aiw local-inference restart
  aiw local-inference logs
  aiw local-inference autostart enable|disable|status

The model root is stored as machine-local AI Workstation configuration and passed
explicitly to Llama Dispatcher as --model-root. No LLAMA_MODEL_ROOT needs to be
placed in .bashrc, .profile or the global WSL environment.

The managed Dispatcher runs as a normal systemd system service under the current
Linux user. Autostart therefore follows the WSL distribution/systemd lifecycle and
can later be used as an explicit dependency of agent services.
EOF
}

fail() {
    printf '[XX] %s\n' "$*" >&2
    exit 1
}

privileged() {
    if [[ -n "$SUDO_BIN" ]]; then
        "$SUDO_BIN" "$@"
    else
        "$@"
    fi
}

config_value() {
    local key="$1"
    [[ -f "$RUNTIME_CONFIG" ]] || return 0
    awk -F= -v key="$key" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' "$RUNTIME_CONFIG"
}

set_config_value() {
    local key="$1"
    local value="$2"
    mkdir -p "$CONFIG_DIR"
    chmod 0700 "$CONFIG_DIR" 2>/dev/null || true
    touch "$RUNTIME_CONFIG"
    chmod 0600 "$RUNTIME_CONFIG"
    python3 - "$RUNTIME_CONFIG" "$key" "$value" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
key = sys.argv[2]
value = sys.argv[3]
prefix = f"{key}="
lines = path.read_text(encoding="utf-8").splitlines()
out = []
replaced = False
for line in lines:
    if line.startswith(prefix):
        if not replaced:
            out.append(prefix + value)
            replaced = True
    else:
        out.append(line)
if not replaced:
    out.append(prefix + value)
path.write_text("\n".join(out).rstrip() + "\n", encoding="utf-8")
PY
}

validate_simple_name() {
    local label="$1"
    local value="$2"
    [[ "$value" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || \
        fail "Invalid ${label} '${value}'. Use letters, numbers, dots, underscores or hyphens."
}

require_runtime_config() {
    local model_root instance ensemble
    model_root="$(config_value AIW_LLAMA_MODEL_ROOT)"
    instance="$(config_value AIW_DISPATCHER_INSTANCE)"
    ensemble="$(config_value AIW_DISPATCHER_ENSEMBLE)"
    [[ -n "$model_root" ]] || fail "Dispatcher runtime is not configured. Use the AI Workstation menu or: aiw local-inference runtime configure"
    [[ -n "$instance" ]] || fail "Dispatcher instance is not configured."
    [[ -n "$ensemble" ]] || fail "Dispatcher ensemble is not configured."
    [[ -d "$model_root" ]] || fail "Configured model root does not exist: $model_root"
    [[ -f "${DISPATCHER_DIR}/instances/${instance}/instance.yaml" ]] || \
        fail "Configured Dispatcher instance is not attached: ${DISPATCHER_DIR}/instances/${instance}"
    [[ -f "${DISPATCHER_DIR}/instances/${instance}/ensembles/${ensemble}.yaml" ]] || \
        fail "Configured Dispatcher ensemble does not exist: ${ensemble}"
}

runtime_configure() {
    local model_root=""
    local instance=""
    local ensemble=""

    while (($# > 0)); do
        case "$1" in
            --model-root)
                (($# >= 2)) || fail "--model-root requires a path"
                model_root="$2"
                shift 2
                ;;
            --instance)
                (($# >= 2)) || fail "--instance requires a name"
                instance="$2"
                shift 2
                ;;
            --ensemble)
                (($# >= 2)) || fail "--ensemble requires a name"
                ensemble="$2"
                shift 2
                ;;
            *) fail "Unknown runtime configure argument: $1" ;;
        esac
    done

    local current_model current_instance current_ensemble
    current_model="$(config_value AIW_LLAMA_MODEL_ROOT)"
    current_instance="$(config_value AIW_DISPATCHER_INSTANCE)"
    current_ensemble="$(config_value AIW_DISPATCHER_ENSEMBLE)"

    if [[ -z "$model_root" || -z "$instance" || -z "$ensemble" ]]; then
        [[ -t 0 ]] || fail "Non-interactive configuration requires --model-root, --instance and --ensemble."
        printf 'Configure the normal Dispatcher start used by AI Workstation.\n'
        printf 'These values are local to this machine and are not committed to Git.\n\n'
        read -r -e -p "Model root [${current_model:-/path/to/models}]: " model_root || true
        model_root="${model_root:-$current_model}"
        read -r -e -p "Dispatcher instance [${current_instance:-Laptop}]: " instance || true
        instance="${instance:-${current_instance:-Laptop}}"
        read -r -e -p "Ensemble [${current_ensemble:-thinkpad}]: " ensemble || true
        ensemble="${ensemble:-${current_ensemble:-thinkpad}}"
    fi

    [[ -n "$model_root" ]] || fail "Model root is required."
    [[ -d "$model_root" ]] || fail "Model root does not exist: $model_root"
    model_root="$(cd -- "$model_root" && pwd -P)"
    validate_simple_name instance "$instance"
    validate_simple_name ensemble "$ensemble"

    [[ -f "${DISPATCHER_DIR}/instances/${instance}/instance.yaml" ]] || \
        fail "Dispatcher instance is not attached: ${DISPATCHER_DIR}/instances/${instance}"
    [[ -f "${DISPATCHER_DIR}/instances/${instance}/ensembles/${ensemble}.yaml" ]] || \
        fail "Ensemble '${ensemble}' not found in instance '${instance}'."

    set_config_value AIW_LLAMA_MODEL_ROOT "$model_root"
    set_config_value AIW_DISPATCHER_INSTANCE "$instance"
    set_config_value AIW_DISPATCHER_ENSEMBLE "$ensemble"

    printf '[OK] Dispatcher runtime configuration saved: %s\n' "$RUNTIME_CONFIG"
    printf '     model root : %s\n' "$model_root"
    printf '     instance   : %s\n' "$instance"
    printf '     ensemble   : %s\n' "$ensemble"
    printf '[..] No global LLAMA_MODEL_ROOT environment variable was created.\n'
}

runtime_show() {
    printf 'Dispatcher runtime config : %s\n' "$RUNTIME_CONFIG"
    printf 'Model root                : %s\n' "$(config_value AIW_LLAMA_MODEL_ROOT || true)"
    printf 'Dispatcher instance       : %s\n' "$(config_value AIW_DISPATCHER_INSTANCE || true)"
    printf 'Dispatcher ensemble       : %s\n' "$(config_value AIW_DISPATCHER_ENSEMBLE || true)"
}

render_service_unit() {
    local aiw_bin
    aiw_bin="$(command -v aiw 2>/dev/null || true)"
    [[ -n "$aiw_bin" ]] || aiw_bin="${ROOT}/bin/aiw"
    cat <<EOF
[Unit]
Description=AI Workstation local inference (Llama Dispatcher)
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_GROUP}
Environment=HOME=${SERVICE_HOME}
Environment=PYTHONUNBUFFERED=1
ExecStart=${aiw_bin} local-inference service-run
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
}

install_service_unit() {
    local temp_unit
    temp_unit="$(mktemp)"
    render_service_unit > "$temp_unit"
    privileged mkdir -p "$SYSTEMD_SYSTEM_DIR"
    privileged install -m 0644 "$temp_unit" "$SERVICE_FILE"
    privileged "$SYSTEMCTL_BIN" daemon-reload
    rm -f "$temp_unit"
}

require_systemd() {
    command -v "$SYSTEMCTL_BIN" >/dev/null 2>&1 || fail "systemctl is unavailable."
    if ! "$SYSTEMCTL_BIN" show-environment >/dev/null 2>&1; then
        fail "The system systemd manager is unavailable. Ensure systemd is enabled in WSL and restart the distribution."
    fi
}

service_run() {
    require_runtime_config
    [[ -x "$MANAGER" || -f "$MANAGER" ]] || fail "Local-inference manager is missing: $MANAGER"
    local model_root instance ensemble
    model_root="$(config_value AIW_LLAMA_MODEL_ROOT)"
    instance="$(config_value AIW_DISPATCHER_INSTANCE)"
    ensemble="$(config_value AIW_DISPATCHER_ENSEMBLE)"
    printf '[..] Starting configured Dispatcher runtime: instance=%s ensemble=%s\n' "$instance" "$ensemble"
    exec bash "$MANAGER" serve \
        --instance "$instance" \
        --ensemble "$ensemble" \
        --model-root "$model_root"
}

service_status() {
    runtime_show
    printf 'Autostart                  : '
    if command -v "$SYSTEMCTL_BIN" >/dev/null 2>&1 && "$SYSTEMCTL_BIN" is-enabled "$SERVICE_NAME" >/dev/null 2>&1; then
        printf 'enabled\n'
    else
        printf 'disabled\n'
    fi
    printf 'Dispatcher service         : '
    if command -v "$SYSTEMCTL_BIN" >/dev/null 2>&1 && "$SYSTEMCTL_BIN" is-active "$SERVICE_NAME" >/dev/null 2>&1; then
        printf 'running\n'
    else
        printf 'stopped\n'
    fi
}

start_service() {
    require_runtime_config
    require_systemd
    install_service_unit
    privileged "$SYSTEMCTL_BIN" start "$SERVICE_NAME"
    printf '[OK] Local inference started.\n'
    printf '     Logs: aiw local-inference logs\n'
}

stop_service() {
    require_systemd
    privileged "$SYSTEMCTL_BIN" stop "$SERVICE_NAME"
    printf '[OK] Local inference stopped.\n'
}

restart_service() {
    require_runtime_config
    require_systemd
    install_service_unit
    privileged "$SYSTEMCTL_BIN" restart "$SERVICE_NAME"
    printf '[OK] Local inference restarted.\n'
}

autostart() {
    local action="${1:-status}"
    require_systemd
    case "$action" in
        enable)
            require_runtime_config
            install_service_unit
            privileged "$SYSTEMCTL_BIN" enable --now "$SERVICE_NAME"
            printf '[OK] Local inference autostart enabled and service started.\n'
            ;;
        disable)
            privileged "$SYSTEMCTL_BIN" disable --now "$SERVICE_NAME" 2>/dev/null || true
            printf '[OK] Local inference autostart disabled and service stopped.\n'
            ;;
        status)
            service_status
            ;;
        *) fail "Usage: aiw local-inference autostart enable|disable|status" ;;
    esac
}

logs() {
    require_systemd
    if [[ -n "$SUDO_BIN" ]]; then
        exec "$SUDO_BIN" "$JOURNALCTL_BIN" -u "$SERVICE_NAME" -f --no-hostname
    fi
    exec "$JOURNALCTL_BIN" -u "$SERVICE_NAME" -f --no-hostname
}

command_name="${1:-help}"
shift || true
case "$command_name" in
    runtime)
        subcommand="${1:-show}"
        shift || true
        case "$subcommand" in
            configure) runtime_configure "$@" ;;
            show|status) runtime_show ;;
            *) fail "Unknown runtime command: $subcommand" ;;
        esac
        ;;
    start) start_service ;;
    stop) stop_service ;;
    restart) restart_service ;;
    status) service_status ;;
    logs) logs ;;
    autostart) autostart "$@" ;;
    service-run) service_run ;;
    render-service) render_service_unit ;;
    help|-h|--help) usage ;;
    *) usage >&2; exit 2 ;;
esac
