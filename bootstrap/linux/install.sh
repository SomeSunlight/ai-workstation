#!/usr/bin/env bash
# Minimal Linux bootstrap and full host installer.
set -Eeuo pipefail
IFS=$'\n\t'

readonly ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
readonly VERSIONS_FILE="${ROOT}/config/versions.json"
readonly UV_BIN="${HOME}/.local/bin/uv"
readonly COLLECTIONS_DIR="${ROOT}/.ansible/collections"
readonly STATE_DIR="${HOME}/.local/state/ai-workstation"
readonly LOG_DIR="${STATE_DIR}/logs"
readonly RUN_ID="$(date '+%Y%m%d-%H%M%S')"
readonly LOG_FILE="${LOG_DIR}/install-${RUN_ID}.log"

BECOME_PASSWORD_FILE=""

ACTION="install"
ASSUME_YES="false"

usage() {
    cat <<'EOF'
Usage:
  ./install.sh [install|status|verify] [--yes]

Commands:
  install  Bootstrap dependencies and configure the host.
  status   Show current state without changing anything.
  verify   Verify bootstrap and configured host.
EOF
}

parse_arguments() {
    while (($# > 0)); do
        case "$1" in
            install|status|verify) ACTION="$1" ;;
            --yes|-y) ASSUME_YES="true" ;;
            --help|-h) usage; exit 0 ;;
            *) printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
        esac
        shift
    done
}

section() {
    printf '\n%s\n%s\n%s\n' \
        '==============================================================================' \
        "$1" \
        '=============================================================================='
}

info() { printf '[..] %s\n' "$*"; }
ok()   { printf '[OK] %s\n' "$*"; }
fail() { printf '[XX] %s\n' "$*" >&2; exit 1; }

on_error() {
    local code=$?
    {
        printf '\n[XX] Installation failed.\n'
        printf '     Exit code : %s\n' "$code"
        printf '     Line      : %s\n' "${BASH_LINENO[0]:-unknown}"
        printf '     Command   : %s\n' "${BASH_COMMAND:-unknown}"
        printf '     Log       : %s\n' "$LOG_FILE"
    } >&2
    exit "$code"
}

cleanup_secrets() {
    if [[ -n "${BECOME_PASSWORD_FILE:-}" && -f "$BECOME_PASSWORD_FILE" ]]; then
        rm -f "$BECOME_PASSWORD_FILE"
    fi
}

setup_logging() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
    chmod 0600 "$LOG_FILE"
    exec > >(tee -a "$LOG_FILE") 2>&1
    trap on_error ERR
    trap cleanup_secrets EXIT
}

json_value() {
    local path="$1"
    python3 -c '
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    value = json.load(handle)
for key in sys.argv[2].split("."):
    value = value[key]
print(value)
' "$VERSIONS_FILE" "$path"
}

normalize_permissions() {
    find "$ROOT" \
        \( -path "$ROOT/.git" -o -path "$ROOT/.venv" -o -path "$ROOT/.ansible" \) -prune -o \
        -type d -exec chmod 0755 {} +

    find "$ROOT" \
        \( -path "$ROOT/.git" -o -path "$ROOT/.venv" -o -path "$ROOT/.ansible" \) -prune -o \
        -type f -exec chmod 0644 {} +

    chmod 0755 \
        "$ROOT/install.sh" \
        "$ROOT/bin/aiw" \
        "$ROOT/bootstrap/linux/install.sh" \
        "$ROOT/tools/normalize-permissions.sh" \
        "$ROOT/tools/release-check.sh" \
        "$ROOT/tools/adopt-prototype-lock.sh" \
        "$ROOT/tests/smoke/repository-layout.sh"
}

preflight() {
    section 'Bootstrap preflight'

    [[ "$(id -u)" -ne 0 ]] || fail "Run this installer as a normal user, not root."
    [[ "$ROOT" != /mnt/* ]] || fail "The repository must live in the Linux filesystem, not under /mnt."
    [[ -f "$VERSIONS_FILE" ]] || fail "Missing $VERSIONS_FILE"
    command -v python3 >/dev/null 2>&1 || fail "python3 is required by the pinned Ubuntu image."
    [[ -r /etc/os-release ]] || fail "/etc/os-release is missing."
    # shellcheck disable=SC1091
    source /etc/os-release

    [[ "${ID:-}" == "ubuntu" ]] || fail "Ubuntu is required; found ${ID:-unknown}."
    [[ "${VERSION_ID:-}" == "$(json_value versions.ubuntu.release)" ]] || \
        fail "Ubuntu $(json_value versions.ubuntu.release) is required; found ${VERSION_ID:-unknown}."
    [[ "$(ps -p 1 -o comm= | xargs)" == "systemd" ]] || fail "systemd must run as PID 1."
    [[ -f "${ROOT}/pyproject.toml" ]] || fail "pyproject.toml is missing."
    if find "$ROOT" -maxdepth 0 -perm -0002 -print -quit | grep -q .; then
        fail "Repository is world-writable. Run tools/normalize-permissions.sh first."
    fi

    info "Repository : $ROOT"
    info "User       : $(id -un)"
    info "Ubuntu     : ${PRETTY_NAME:-unknown}"
    info "Python     : $(python3 --version 2>&1)"
    info "systemd    : active as PID 1"
    ok "Bootstrap prerequisites are satisfied."
}

show_status() {
    preflight
    "${ROOT}/bin/aiw" status
}

confirm_install() {
    [[ "$ASSUME_YES" == "true" ]] && return 0
    cat <<'EOF'

This installer may:
  - install minimal Ubuntu packages;
  - install the pinned uv release in ~/.local/bin;
  - create the repository-local Python environment;
  - install repository-local Ansible collections;
  - configure directories and Docker Engine through Ansible.
EOF
    read -r -p 'Continue? [y/N]: ' answer
    case "${answer,,}" in y|yes) ;; *) fail "Installation cancelled." ;; esac
}

prepare_become_password() {
    section 'Linux sudo authentication'

    BECOME_PASSWORD_FILE="$(mktemp)"
    chmod 0600 "$BECOME_PASSWORD_FILE"

    local password
    read -r -s -p "Linux sudo password for $(id -un): " password
    printf '\n'
    printf '%s\n' "$password" > "$BECOME_PASSWORD_FILE"
    unset password

    if ! sudo -S -v < "$BECOME_PASSWORD_FILE"; then
        fail "Linux sudo authentication failed."
    fi

    export AIW_BECOME_PASSWORD_FILE="$BECOME_PASSWORD_FILE"
    ok "Linux sudo password accepted."
}

install_base_packages() {
    section 'Install bootstrap packages'
    sudo apt-get update
    sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates curl git python3 python3-apt python3-venv
    [[ "$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')" == \
       "$(json_value versions.ubuntu.python)" ]] || fail "Unexpected Python version."
    ok "Bootstrap packages are installed."
}

installed_uv_version() {
    [[ -x "$UV_BIN" ]] || return 1
    "$UV_BIN" --version 2>/dev/null | awk 'NR == 1 && $1 == "uv" {print $2; exit}'
}

install_uv() {
    section 'Install uv'
    local expected installer
    expected="$(json_value versions.uv)"

    if [[ "$(installed_uv_version || true)" == "$expected" ]]; then
        ok "uv $expected is already installed."
        return
    fi

    mkdir -p "${HOME}/.local/bin"
    installer="$(mktemp)"
    if ! curl --proto '=https' --tlsv1.2 --fail --silent --show-error --location \
        "https://astral.sh/uv/${expected}/install.sh" --output "$installer"; then
        rm -f "$installer"
        fail "Could not download the uv installer."
    fi

    if ! env UV_INSTALL_DIR="${HOME}/.local/bin" UV_NO_MODIFY_PATH=1 sh "$installer"; then
        rm -f "$installer"
        fail "uv installation failed."
    fi
    rm -f "$installer"

    [[ "$(installed_uv_version || true)" == "$expected" ]] || fail "Unexpected uv version."
    ok "$($UV_BIN --version) is installed."
}

sync_automation_runtime() {
    section 'Synchronize automation runtime'
    [[ -f "${ROOT}/uv.lock" ]] || fail \
        "uv.lock is missing. Copy the tested lockfile before publishing or installing. See docs/repository-setup.md."

    cd "$ROOT"
    "$UV_BIN" lock --check --python /usr/bin/python3
    "$UV_BIN" sync --frozen --python /usr/bin/python3
    ok "The repository-local Python environment is synchronized."
}

install_collections() {
    section 'Install Ansible collections'
    mkdir -p "$COLLECTIONS_DIR"
    cd "$ROOT"

    export ANSIBLE_CONFIG="${ROOT}/ansible/ansible.cfg"
    export ANSIBLE_COLLECTIONS_PATH="$COLLECTIONS_DIR"

    "$UV_BIN" run --frozen ansible-galaxy collection install \
        --requirements-file "${ROOT}/ansible/requirements.yml" \
        --collections-path "$COLLECTIONS_DIR"

    local expected installed
    expected="$(json_value versions.ansible.community_docker)"
    installed="$(
        "$UV_BIN" run --frozen ansible-galaxy collection list community.docker 2>/dev/null |
            awk '$1 == "community.docker" {print $2; exit}'
    )"
    [[ "$installed" == "$expected" ]] || \
        fail "Expected community.docker $expected, found ${installed:-nothing}."
    ok "Ansible collections are installed."
}

bootstrap_verify() {
    section 'Verify automation bootstrap'
    [[ -x "$UV_BIN" ]] || fail "uv is missing."
    [[ -f "${ROOT}/uv.lock" ]] || fail "uv.lock is missing."
    [[ -x "${ROOT}/.venv/bin/ansible-playbook" ]] || fail "Ansible environment is missing."

    cd "$ROOT"
    "$UV_BIN" lock --check --python /usr/bin/python3
    "$UV_BIN" sync --check --frozen --python /usr/bin/python3

    export ANSIBLE_CONFIG="${ROOT}/ansible/ansible.cfg"
    export ANSIBLE_INVENTORY="${ROOT}/ansible/inventory/localhost.yml"
    export ANSIBLE_ROLES_PATH="${ROOT}/ansible/roles"
    export ANSIBLE_COLLECTIONS_PATH="$COLLECTIONS_DIR"
    export AIW_REPOSITORY_ROOT="$ROOT"
    export AIW_USER="$(id -un)"
    export AIW_HOME="$HOME"
    export AIW_PRIMARY_GROUP="$(id -gn)"

    "$UV_BIN" run --frozen ansible-playbook "${ROOT}/ansible/playbooks/bootstrap-verify.yml"
    "$UV_BIN" run --frozen ansible-lint --config-file "${ROOT}/ansible/.ansible-lint" \
        "${ROOT}/ansible/playbooks"
    ok "Automation bootstrap is valid."
}

main() {
    parse_arguments "$@"
    setup_logging

    section 'AI Workstation installer'
    info "Action : $ACTION"
    info "Log    : $LOG_FILE"

    case "$ACTION" in
        status)
            show_status
            ;;
        install)
            normalize_permissions
            preflight
            confirm_install
            prepare_become_password
            install_base_packages
            install_uv
            sync_automation_runtime
            install_collections
            bootstrap_verify
            "${ROOT}/bin/aiw" install
            ;;
        verify)
            preflight
            bootstrap_verify
            prepare_become_password
            "${ROOT}/bin/aiw" verify
            ;;
    esac
}

main "$@"
