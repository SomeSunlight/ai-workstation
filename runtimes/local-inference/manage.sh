#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

readonly ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
readonly VERSIONS_FILE="${ROOT}/config/versions.json"
readonly CONFIG_DIR="${HOME}/.config/ai-workstation"
readonly CONFIG_FILE="${AIW_LOCAL_INFERENCE_CONFIG:-${CONFIG_DIR}/local-inference.env}"
readonly RUNTIME_ROOT="${AIW_LOCAL_INFERENCE_ROOT:-${HOME}/.local/share/ai-workstation/local-inference}"
readonly LLAMA_DIR="${RUNTIME_ROOT}/llama.cpp"
readonly LLAMA_BUILD_DIR="${LLAMA_DIR}/build-aiw"
readonly LLAMA_BIN_DIR="${LLAMA_BUILD_DIR}/bin"
readonly DISPATCHER_DIR="${RUNTIME_ROOT}/Llama_Dispatcher"
readonly UV_BIN="${HOME}/.local/bin/uv"

usage() {
    cat <<'EOF'
Host-local inference

Usage:
  aiw local-inference configure laptop-vulkan
  aiw local-inference setup laptop-vulkan
  aiw local-inference install
  aiw local-inference status
  aiw local-inference verify
  aiw local-inference serve [DISPATCHER ARGUMENTS...]
  aiw local-inference dispatcher DISPATCHER ARGUMENTS...
  aiw local-inference config
  aiw local-inference help

The laptop-vulkan preset configures the existing Laptop instance repository and
thinkpad ensemble. Model/profile/ensemble semantics remain owned by Llama
Dispatcher and its instance repository.
EOF
}

fail() {
    printf '[XX] %s\n' "$*" >&2
    exit 1
}

warn() {
    printf '[!!] %s\n' "$*" >&2
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

config_value() {
    local key="$1"
    [[ -f "$CONFIG_FILE" ]] || return 0
    awk -F= -v key="$key" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' "$CONFIG_FILE"
}

require_config() {
    [[ -f "$CONFIG_FILE" ]] || fail "Local inference is not configured. Run: aiw local-inference configure laptop-vulkan"
    [[ "$(config_value AIW_LOCAL_INFERENCE_ENABLED)" == "true" ]] || \
        fail "Local inference is disabled in $CONFIG_FILE"
}

write_laptop_vulkan_config() {
    mkdir -p "$CONFIG_DIR"
    chmod 0700 "$CONFIG_DIR" 2>/dev/null || true
    cat > "$CONFIG_FILE" <<'EOF'
AIW_LOCAL_INFERENCE_ENABLED=true
AIW_LLAMA_CPP_BACKEND=vulkan
AIW_DISPATCHER_INSTANCE=Laptop
AIW_DISPATCHER_INSTANCE_REPOSITORY=https://github.com/SomeSunlight/Llama_Dispatcher_Laptop.git
AIW_DISPATCHER_ENSEMBLE=thinkpad
EOF
    chmod 0600 "$CONFIG_FILE"
    printf '[OK] Local inference preset written: %s\n' "$CONFIG_FILE"
}

configure() {
    local preset="${1:-}"
    case "$preset" in
        laptop-vulkan|laptop|thinkpad)
            write_laptop_vulkan_config
            ;;
        *)
            fail "Unknown preset '${preset:-}'. Supported now: laptop-vulkan"
            ;;
    esac
}

install_system_dependencies() {
    local backend="$1"
    local packages=(
        build-essential
        cmake
        git
        libcurl4-openssl-dev
        libssl-dev
        ninja-build
        pkg-config
    )

    case "$backend" in
        vulkan)
            packages+=(glslc libvulkan-dev spirv-headers vulkan-tools)
            ;;
        cuda)
            command -v nvcc >/dev/null 2>&1 || \
                fail "CUDA backend requires an existing WSL CUDA toolkit (nvcc). Automatic CUDA toolkit installation is intentionally not part of this first block."
            ;;
        sycl)
            fail "SYCL provisioning is not implemented in this first block. Keep the backend explicit and add the oneAPI/Level Zero toolchain as a dedicated tested extension."
            ;;
        *)
            fail "Unsupported llama.cpp backend: $backend"
            ;;
    esac

    printf '[..] Installing host build prerequisites for backend: %s\n' "$backend"
    sudo apt-get update
    sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${packages[@]}"
}

sync_pinned_checkout() {
    local url="$1"
    local ref="$2"
    local directory="$3"
    local label="$4"

    if [[ ! -d "${directory}/.git" ]]; then
        mkdir -p "$(dirname -- "$directory")"
        git clone --filter=blob:none "$url" "$directory"
    fi

    local origin
    origin="$(git -C "$directory" remote get-url origin 2>/dev/null || true)"
    [[ "$origin" == "$url" ]] || fail "$label checkout has unexpected origin: ${origin:-missing}"

    git -C "$directory" diff --quiet && git -C "$directory" diff --cached --quiet || \
        fail "$label checkout has local changes. Commit/stash them before AI Workstation changes its pinned code revision."

    git -C "$directory" fetch --prune origin
    git -C "$directory" checkout --detach "$ref"
    [[ "$(git -C "$directory" rev-parse HEAD)" == "$ref" ]] || fail "$label did not reach pinned revision $ref"
    printf '[OK] %s revision: %s\n' "$label" "$ref"
}

install_llama_cpp() {
    local backend="$1"
    local repository commit
    repository="$(json_value versions.llama_cpp.repository)"
    commit="$(json_value versions.llama_cpp.commit)"

    sync_pinned_checkout "$repository" "$commit" "$LLAMA_DIR" "llama.cpp"

    local cmake_args=(-S "$LLAMA_DIR" -B "$LLAMA_BUILD_DIR" -G Ninja -DCMAKE_BUILD_TYPE=Release)
    case "$backend" in
        vulkan) cmake_args+=(-DGGML_VULKAN=ON) ;;
        cuda) cmake_args+=(-DGGML_CUDA=ON) ;;
        *) fail "Unsupported build backend: $backend" ;;
    esac

    cmake "${cmake_args[@]}"
    cmake --build "$LLAMA_BUILD_DIR" --config Release -j "$(nproc)"
    [[ -x "${LLAMA_BIN_DIR}/llama-server" ]] || fail "llama-server was not produced in $LLAMA_BIN_DIR"
    printf '[OK] llama.cpp built with %s backend.\n' "$backend"
}

install_dispatcher() {
    local repository commit
    repository="$(json_value versions.llama_dispatcher.repository)"
    commit="$(json_value versions.llama_dispatcher.commit)"

    sync_pinned_checkout "$repository" "$commit" "$DISPATCHER_DIR" "Llama Dispatcher"
    [[ -x "$UV_BIN" ]] || fail "uv is missing. Run the normal AI Workstation installer first."
    (cd "$DISPATCHER_DIR" && "$UV_BIN" sync --frozen --python /usr/bin/python3)
    printf '[OK] Llama Dispatcher environment synchronized.\n'
}

attach_instance() {
    local instance repository target
    instance="$(config_value AIW_DISPATCHER_INSTANCE)"
    repository="$(config_value AIW_DISPATCHER_INSTANCE_REPOSITORY)"
    [[ -n "$instance" ]] || fail "AIW_DISPATCHER_INSTANCE is missing from $CONFIG_FILE"
    [[ -n "$repository" ]] || fail "AIW_DISPATCHER_INSTANCE_REPOSITORY is missing from $CONFIG_FILE"
    target="${DISPATCHER_DIR}/instances/${instance}"

    if [[ ! -d "${target}/.git" ]]; then
        mkdir -p "${DISPATCHER_DIR}/instances"
        git clone "$repository" "$target"
        printf '[OK] Dispatcher instance attached: %s\n' "$target"
        return
    fi

    local origin
    origin="$(git -C "$target" remote get-url origin 2>/dev/null || true)"
    [[ "$origin" == "$repository" ]] || fail "Instance '$instance' has unexpected origin: ${origin:-missing}"
    printf '[OK] Dispatcher instance already attached; its working tree was left untouched.\n'
}

install_all() {
    require_config
    local backend
    backend="$(config_value AIW_LLAMA_CPP_BACKEND)"
    [[ -n "$backend" ]] || fail "AIW_LLAMA_CPP_BACKEND is missing from $CONFIG_FILE"

    install_system_dependencies "$backend"
    mkdir -p "$RUNTIME_ROOT"
    install_llama_cpp "$backend"
    install_dispatcher
    attach_instance
}

show_status() {
    local enabled="false"
    local backend="not configured"
    local instance="not configured"
    local ensemble="not configured"
    if [[ -f "$CONFIG_FILE" ]]; then
        enabled="$(config_value AIW_LOCAL_INFERENCE_ENABLED)"
        backend="$(config_value AIW_LLAMA_CPP_BACKEND)"
        instance="$(config_value AIW_DISPATCHER_INSTANCE)"
        ensemble="$(config_value AIW_DISPATCHER_ENSEMBLE)"
    fi

    printf 'Local inference       : %s\n' "${enabled:-false}"
    printf 'llama.cpp backend     : %s\n' "${backend:-not configured}"
    printf 'llama.cpp checkout    : %s\n' "$([[ -d "${LLAMA_DIR}/.git" ]] && git -C "$LLAMA_DIR" rev-parse --short HEAD 2>/dev/null || printf 'not installed')"
    printf 'llama-server          : %s\n' "$([[ -x "${LLAMA_BIN_DIR}/llama-server" ]] && printf '%s' "$LLAMA_BIN_DIR/llama-server" || printf 'not installed')"
    printf 'Dispatcher checkout   : %s\n' "$([[ -d "${DISPATCHER_DIR}/.git" ]] && git -C "$DISPATCHER_DIR" rev-parse --short HEAD 2>/dev/null || printf 'not installed')"
    printf 'Dispatcher instance   : %s\n' "${instance:-not configured}"
    printf 'Dispatcher ensemble   : %s\n' "${ensemble:-not configured}"
}

verify() {
    require_config
    local backend instance ensemble
    backend="$(config_value AIW_LLAMA_CPP_BACKEND)"
    instance="$(config_value AIW_DISPATCHER_INSTANCE)"
    ensemble="$(config_value AIW_DISPATCHER_ENSEMBLE)"

    [[ -x "${LLAMA_BIN_DIR}/llama-server" ]] || fail "llama-server is missing. Run: aiw local-inference install"
    [[ -d "${DISPATCHER_DIR}/.git" ]] || fail "Llama Dispatcher is missing. Run: aiw local-inference install"
    [[ -d "${DISPATCHER_DIR}/instances/${instance}/.git" ]] || fail "Dispatcher instance '$instance' is missing."
    [[ -x "$UV_BIN" ]] || fail "uv is missing."

    printf '[..] llama.cpp devices\n'
    "${LLAMA_BIN_DIR}/llama-server" --list-devices

    if [[ "$backend" == "vulkan" ]]; then
        if command -v vulkaninfo >/dev/null 2>&1; then
            vulkaninfo --summary || warn "vulkaninfo could not enumerate a usable Vulkan device. The build is installed, but WSL graphics support still needs attention."
        else
            warn "vulkaninfo is unavailable."
        fi
    fi

    printf '[..] Dispatcher compile-only check for instance=%s ensemble=%s\n' "$instance" "$ensemble"
    (
        cd "$DISPATCHER_DIR"
        "$UV_BIN" run --frozen python src/dispatcher.py serve \
            --instance "$instance" \
            --ensemble "$ensemble" \
            --compile-only \
            --bin-dir "$LLAMA_BIN_DIR"
    )
    printf '[OK] Host-local inference installation is structurally usable.\n'
}

run_dispatcher() {
    require_config
    (($# > 0)) || fail "Dispatcher arguments are required."
    local instance
    instance="$(config_value AIW_DISPATCHER_INSTANCE)"
    [[ -d "$DISPATCHER_DIR" ]] || fail "Llama Dispatcher is not installed."
    (
        cd "$DISPATCHER_DIR"
        exec "$UV_BIN" run --frozen python src/dispatcher.py "$@" \
            --instance "$instance" \
            --bin-dir "$LLAMA_BIN_DIR"
    )
}

serve() {
    require_config
    local ensemble
    ensemble="$(config_value AIW_DISPATCHER_ENSEMBLE)"
    [[ -n "$ensemble" ]] || fail "AIW_DISPATCHER_ENSEMBLE is missing from $CONFIG_FILE"
    run_dispatcher serve --ensemble "$ensemble" "$@"
}

setup() {
    local preset="${1:-}"
    configure "$preset"
    install_all
    verify
}

show_config() {
    printf 'Configuration file: %s\n' "$CONFIG_FILE"
    if [[ -f "$CONFIG_FILE" ]]; then
        cat "$CONFIG_FILE"
    else
        printf '(not configured)\n'
    fi
    printf 'Runtime root      : %s\n' "$RUNTIME_ROOT"
    printf 'llama.cpp bin dir : %s\n' "$LLAMA_BIN_DIR"
}

command_name="${1:-help}"
shift || true
case "$command_name" in
    configure) configure "$@" ;;
    setup) setup "$@" ;;
    install) install_all ;;
    status) show_status ;;
    verify) verify ;;
    serve) serve "$@" ;;
    dispatcher) run_dispatcher "$@" ;;
    config) show_config ;;
    help|-h|--help) usage ;;
    *) usage >&2; exit 2 ;;
esac
