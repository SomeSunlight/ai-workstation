#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

readonly ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
readonly VERSIONS_FILE="${ROOT}/config/versions.json"
readonly CONFIG_DIR="${HOME}/.config/ai-workstation"
readonly CONFIG_FILE="${AIW_LOCAL_INFERENCE_CONFIG:-${CONFIG_DIR}/local-inference.env}"
readonly RUNTIME_ROOT="${AIW_LOCAL_INFERENCE_ROOT:-${HOME}/.local/share/ai-workstation/local-inference}"
readonly LLAMA_ROOT="${RUNTIME_ROOT}/llama.cpp"
readonly LLAMA_REPOSITORY_DIR="${LLAMA_ROOT}/repository"
readonly LLAMA_BUILDS_DIR="${LLAMA_ROOT}/builds"
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
  aiw local-inference serve [--llama-build NAME] [DISPATCHER ARGUMENTS...]
  aiw local-inference dispatcher [--llama-build NAME] DISPATCHER ARGUMENTS...
  aiw local-inference llama build --backend BACKEND [--commit REF] [--name NAME]
                                  [--label LABEL] [--cmake-arg ARG]...
  aiw local-inference llama list
  aiw local-inference llama select NAME
  aiw local-inference llama show NAME
  aiw local-inference config
  aiw local-inference help

llama.cpp builds are parallel, immutable slots. A slot name is a convenient
human label; its manifest records the exact source commit, backend and CMake
arguments. The default generated name is BACKEND-SHORTCOMMIT, optionally with
a descriptive suffix from --label.

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

set_config_value() {
    local key="$1"
    local value="$2"
    mkdir -p "$CONFIG_DIR"
    chmod 0700 "$CONFIG_DIR" 2>/dev/null || true
    touch "$CONFIG_FILE"
    chmod 0600 "$CONFIG_FILE"

    python3 - "$CONFIG_FILE" "$key" "$value" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
key = sys.argv[2]
value = sys.argv[3]
lines = path.read_text(encoding="utf-8").splitlines()
prefix = f"{key}="
replaced = False
output = []
for line in lines:
    if line.startswith(prefix):
        if not replaced:
            output.append(prefix + value)
            replaced = True
    else:
        output.append(line)
if not replaced:
    output.append(prefix + value)
path.write_text("\n".join(output).rstrip() + "\n", encoding="utf-8")
PY
}

require_config() {
    [[ -f "$CONFIG_FILE" ]] || fail "Local inference is not configured. Run: aiw local-inference configure laptop-vulkan"
    [[ "$(config_value AIW_LOCAL_INFERENCE_ENABLED)" == "true" ]] || \
        fail "Local inference is disabled in $CONFIG_FILE"
}

write_laptop_vulkan_config() {
    mkdir -p "$CONFIG_DIR"
    chmod 0700 "$CONFIG_DIR" 2>/dev/null || true

    local existing_active=""
    existing_active="$(config_value AIW_LLAMA_CPP_ACTIVE_BUILD)"
    cat > "$CONFIG_FILE" <<EOF
AIW_LOCAL_INFERENCE_ENABLED=true
AIW_LLAMA_CPP_BOOTSTRAP_BACKEND=vulkan
AIW_LLAMA_CPP_ACTIVE_BUILD=${existing_active}
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

validate_build_name() {
    local name="$1"
    [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || \
        fail "Invalid llama.cpp build name '$name'. Use letters, numbers, dots, underscores or hyphens."
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
            fail "SYCL provisioning is not implemented in this first block. Keep it as a separate explicit build backend once the oneAPI/Level Zero toolchain is tested under WSL."
            ;;
        cpu)
            ;;
        *)
            fail "Unsupported llama.cpp backend: $backend"
            ;;
    esac

    printf '[..] Installing host build prerequisites for backend: %s\n' "$backend"
    sudo apt-get update
    sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${packages[@]}"
}

ensure_llama_repository() {
    local repository
    repository="$(json_value versions.llama_cpp.repository)"
    mkdir -p "$LLAMA_ROOT"

    if [[ ! -d "${LLAMA_REPOSITORY_DIR}/.git" ]]; then
        git clone --filter=blob:none "$repository" "$LLAMA_REPOSITORY_DIR"
    fi

    local origin
    origin="$(git -C "$LLAMA_REPOSITORY_DIR" remote get-url origin 2>/dev/null || true)"
    [[ "$origin" == "$repository" ]] || \
        fail "llama.cpp repository cache has unexpected origin: ${origin:-missing}"

    git -C "$LLAMA_REPOSITORY_DIR" diff --quiet &&
        git -C "$LLAMA_REPOSITORY_DIR" diff --cached --quiet || \
        fail "llama.cpp repository cache has local changes. It is AI Workstation-owned and must remain clean."

    git -C "$LLAMA_REPOSITORY_DIR" fetch --prune origin
    git -C "$LLAMA_REPOSITORY_DIR" worktree prune
}

resolve_llama_commit() {
    local requested_ref="${1:-}"
    local pinned
    pinned="$(json_value versions.llama_cpp.commit)"
    requested_ref="${requested_ref:-$pinned}"

    ensure_llama_repository

    local resolved=""
    resolved="$(git -C "$LLAMA_REPOSITORY_DIR" rev-parse --verify "${requested_ref}^{commit}" 2>/dev/null || true)"
    if [[ -z "$resolved" ]]; then
        git -C "$LLAMA_REPOSITORY_DIR" fetch origin "$requested_ref"
        resolved="$(git -C "$LLAMA_REPOSITORY_DIR" rev-parse --verify 'FETCH_HEAD^{commit}' 2>/dev/null || true)"
    fi
    [[ -n "$resolved" ]] || fail "Could not resolve llama.cpp ref: $requested_ref"
    printf '%s\n' "$resolved"
}

default_cmake_args() {
    local backend="$1"
    case "$backend" in
        vulkan) printf '%s\n' '-DGGML_VULKAN=ON' ;;
        cuda) printf '%s\n' '-DGGML_CUDA=ON' ;;
        cpu) ;;
        *) fail "Unsupported build backend: $backend" ;;
    esac
}

build_dir_for() {
    printf '%s/%s\n' "$LLAMA_BUILDS_DIR" "$1"
}

build_manifest_for() {
    printf '%s/manifest.json\n' "$(build_dir_for "$1")"
}

build_bin_dir_for() {
    printf '%s/build/bin\n' "$(build_dir_for "$1")"
}

build_source_dir_for() {
    printf '%s/source\n' "$(build_dir_for "$1")"
}

build_exists() {
    local name="$1"
    [[ -f "$(build_manifest_for "$name")" && -x "$(build_bin_dir_for "$name")/llama-server" ]]
}

manifest_value() {
    local name="$1"
    local key="$2"
    local manifest
    manifest="$(build_manifest_for "$name")"
    [[ -f "$manifest" ]] || return 1
    python3 - "$manifest" "$key" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
value = data[sys.argv[2]]
if isinstance(value, list):
    for item in value:
        print(item)
else:
    print(value)
PY
}

write_build_manifest() {
    local name="$1"
    local backend="$2"
    local commit="$3"
    shift 3
    local extra_args=("$@")
    local slot_dir source_dir build_dir bin_dir repository version_output
    slot_dir="$(build_dir_for "$name")"
    source_dir="${slot_dir}/source"
    build_dir="${slot_dir}/build"
    bin_dir="${build_dir}/bin"
    repository="$(json_value versions.llama_cpp.repository)"
    version_output="$("${bin_dir}/llama-server" --version 2>&1 | head -n 1 || true)"

    python3 - "$slot_dir/manifest.json" "$name" "$repository" "$commit" "$backend" \
        "$source_dir" "$build_dir" "$bin_dir" "$version_output" "${extra_args[@]}" <<'PY'
from datetime import datetime, timezone
import json
from pathlib import Path
import sys

path = Path(sys.argv[1])
name, repository, commit, backend = sys.argv[2:6]
source_dir, build_dir, bin_dir, version_output = sys.argv[6:10]
extra_args = sys.argv[10:]
payload = {
    "schema": 1,
    "name": name,
    "repository": repository,
    "commit": commit,
    "backend": backend,
    "extra_cmake_args": extra_args,
    "source_dir": source_dir,
    "build_dir": build_dir,
    "bin_dir": bin_dir,
    "llama_server_version": version_output,
    "built_at_utc": datetime.now(timezone.utc).isoformat(),
}
path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY
}

llama_build() {
    local backend=""
    local requested_ref=""
    local name=""
    local label=""
    local extra_args=()

    while (($# > 0)); do
        case "$1" in
            --backend)
                (($# >= 2)) || fail "--backend requires a value"
                backend="$2"
                shift 2
                ;;
            --commit|--ref)
                (($# >= 2)) || fail "$1 requires a value"
                requested_ref="$2"
                shift 2
                ;;
            --name)
                (($# >= 2)) || fail "--name requires a value"
                name="$2"
                shift 2
                ;;
            --label)
                (($# >= 2)) || fail "--label requires a value"
                label="$2"
                shift 2
                ;;
            --cmake-arg)
                (($# >= 2)) || fail "--cmake-arg requires a value"
                extra_args+=("$2")
                shift 2
                ;;
            -h|--help)
                usage
                return
                ;;
            *)
                fail "Unknown llama build argument: $1"
                ;;
        esac
    done

    [[ -n "$backend" ]] || fail "Usage: aiw local-inference llama build --backend BACKEND [...]"
    case "$backend" in vulkan|cuda|cpu) ;; *) fail "Unsupported llama.cpp backend: $backend" ;; esac

    install_system_dependencies "$backend"

    local commit short_commit
    commit="$(resolve_llama_commit "$requested_ref")"
    short_commit="${commit:0:8}"

    if [[ -z "$name" ]]; then
        name="${backend}-${short_commit}"
        if [[ -n "$label" ]]; then
            validate_build_name "$label"
            name="${name}-${label}"
        fi
    fi
    validate_build_name "$name"

    local slot_dir source_dir build_dir bin_dir manifest
    slot_dir="$(build_dir_for "$name")"
    source_dir="${slot_dir}/source"
    build_dir="${slot_dir}/build"
    bin_dir="${build_dir}/bin"
    manifest="${slot_dir}/manifest.json"

    if [[ -e "$slot_dir" ]]; then
        [[ -f "$manifest" ]] || fail "Build slot '$name' exists without a manifest: $slot_dir"
        local existing_commit existing_backend args_match
        existing_commit="$(manifest_value "$name" commit)"
        existing_backend="$(manifest_value "$name" backend)"
        args_match="$(python3 - "$manifest" "${extra_args[@]}" <<'PY'
import json, sys
manifest = json.load(open(sys.argv[1], encoding="utf-8"))
print("yes" if manifest.get("extra_cmake_args", []) == sys.argv[2:] else "no")
PY
)"
        [[ "$existing_commit" == "$commit" && "$existing_backend" == "$backend" && "$args_match" == "yes" ]] || \
            fail "Build slot '$name' already exists with a different commit/backend/CMake specification. Choose another name."
        printf '[..] Rebuilding existing immutable-spec slot: %s\n' "$name"
    else
        mkdir -p "$slot_dir"
        git -C "$LLAMA_REPOSITORY_DIR" worktree add --detach "$source_dir" "$commit"
    fi

    if [[ ! -d "$source_dir/.git" && ! -f "$source_dir/.git" ]]; then
        fail "llama.cpp source worktree is missing for build '$name': $source_dir"
    fi
    [[ "$(git -C "$source_dir" rev-parse HEAD)" == "$commit" ]] || \
        fail "Build '$name' source worktree is not at expected commit $commit"
    git -C "$source_dir" diff --quiet && git -C "$source_dir" diff --cached --quiet || \
        fail "Build '$name' source worktree has local changes."

    local cmake_args=(-S "$source_dir" -B "$build_dir" -G Ninja -DCMAKE_BUILD_TYPE=Release)
    local arg
    while IFS= read -r arg; do
        [[ -n "$arg" ]] && cmake_args+=("$arg")
    done < <(default_cmake_args "$backend")
    cmake_args+=("${extra_args[@]}")

    cmake "${cmake_args[@]}"
    cmake --build "$build_dir" --config Release -j "$(nproc)"
    [[ -x "${bin_dir}/llama-server" ]] || fail "llama-server was not produced in $bin_dir"

    write_build_manifest "$name" "$backend" "$commit" "${extra_args[@]}"
    printf '[OK] llama.cpp build ready: %s\n' "$name"
    printf '     backend : %s\n' "$backend"
    printf '     commit  : %s\n' "$commit"
    printf '     bin dir : %s\n' "$bin_dir"
    printf '%s\n' "$name"
}

llama_list() {
    mkdir -p "$LLAMA_BUILDS_DIR"
    local active
    active="$(config_value AIW_LLAMA_CPP_ACTIVE_BUILD)"
    printf '%-2s %-28s %-10s %-10s %s\n' '' 'NAME' 'BACKEND' 'COMMIT' 'LLAMA-SERVER'
    printf '%-2s %-28s %-10s %-10s %s\n' '--' '----------------------------' '----------' '----------' '------------'

    local manifest name backend commit version marker
    local found=false
    while IFS= read -r manifest; do
        found=true
        name="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["name"])' "$manifest")"
        backend="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["backend"])' "$manifest")"
        commit="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["commit"][:8])' "$manifest")"
        version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("llama_server_version",""))' "$manifest")"
        marker=' '
        [[ "$name" == "$active" ]] && marker='*'
        printf '%-2s %-28s %-10s %-10s %s\n' "$marker" "$name" "$backend" "$commit" "$version"
    done < <(find "$LLAMA_BUILDS_DIR" -mindepth 2 -maxdepth 2 -name manifest.json -type f | LC_ALL=C sort)

    if [[ "$found" == "false" ]]; then
        printf '(no llama.cpp builds installed)\n'
    fi
}

llama_select() {
    local name="${1:-}"
    [[ -n "$name" ]] || fail "Usage: aiw local-inference llama select NAME"
    validate_build_name "$name"
    build_exists "$name" || fail "Unknown or incomplete llama.cpp build: $name"
    set_config_value AIW_LLAMA_CPP_ACTIVE_BUILD "$name"
    printf '[OK] Active llama.cpp build: %s\n' "$name"
    printf '     bin dir: %s\n' "$(build_bin_dir_for "$name")"
}

llama_show() {
    local name="${1:-}"
    [[ -n "$name" ]] || fail "Usage: aiw local-inference llama show NAME"
    validate_build_name "$name"
    local manifest
    manifest="$(build_manifest_for "$name")"
    [[ -f "$manifest" ]] || fail "Unknown llama.cpp build: $name"
    cat "$manifest"
}

llama_command() {
    local subcommand="${1:-list}"
    shift || true
    case "$subcommand" in
        build) llama_build "$@" ;;
        list) llama_list ;;
        select|use) llama_select "$@" ;;
        show) llama_show "$@" ;;
        help|-h|--help) usage ;;
        *) fail "Unknown llama command: $subcommand" ;;
    esac
}

sync_pinned_dispatcher() {
    local repository commit
    repository="$(json_value versions.llama_dispatcher.repository)"
    commit="$(json_value versions.llama_dispatcher.commit)"

    if [[ ! -d "${DISPATCHER_DIR}/.git" ]]; then
        mkdir -p "$(dirname -- "$DISPATCHER_DIR")"
        git clone --filter=blob:none "$repository" "$DISPATCHER_DIR"
    fi

    local origin
    origin="$(git -C "$DISPATCHER_DIR" remote get-url origin 2>/dev/null || true)"
    [[ "$origin" == "$repository" ]] || fail "Llama Dispatcher checkout has unexpected origin: ${origin:-missing}"

    git -C "$DISPATCHER_DIR" diff --quiet && git -C "$DISPATCHER_DIR" diff --cached --quiet || \
        fail "Llama Dispatcher checkout has local changes. Commit/stash them before AI Workstation changes its pinned revision."

    git -C "$DISPATCHER_DIR" fetch --prune origin
    git -C "$DISPATCHER_DIR" checkout --detach "$commit"
    [[ "$(git -C "$DISPATCHER_DIR" rev-parse HEAD)" == "$commit" ]] || \
        fail "Llama Dispatcher did not reach pinned revision $commit"
    printf '[OK] Llama Dispatcher revision: %s\n' "$commit"
}

install_dispatcher() {
    sync_pinned_dispatcher
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

active_build_name() {
    local name
    name="$(config_value AIW_LLAMA_CPP_ACTIVE_BUILD)"
    [[ -n "$name" ]] || fail "No active llama.cpp build is selected. Run: aiw local-inference llama list / select NAME"
    build_exists "$name" || fail "Configured active llama.cpp build is missing or incomplete: $name"
    printf '%s\n' "$name"
}

resolve_requested_build() {
    local requested="${1:-}"
    if [[ -n "$requested" ]]; then
        validate_build_name "$requested"
        build_exists "$requested" || fail "Unknown or incomplete llama.cpp build: $requested"
        printf '%s\n' "$requested"
    else
        active_build_name
    fi
}

install_all() {
    require_config
    local active backend
    active="$(config_value AIW_LLAMA_CPP_ACTIVE_BUILD)"
    backend="$(config_value AIW_LLAMA_CPP_BOOTSTRAP_BACKEND)"
    backend="${backend:-vulkan}"

    if [[ -z "$active" ]]; then
        local pinned commit short name
        pinned="$(json_value versions.llama_cpp.commit)"
        commit="$(resolve_llama_commit "$pinned")"
        short="${commit:0:8}"
        name="${backend}-${short}"
        if ! build_exists "$name"; then
            llama_build --backend "$backend" --commit "$commit" --name "$name"
        fi
        llama_select "$name"
    elif ! build_exists "$active"; then
        fail "Configured active llama.cpp build '$active' does not exist. Build it explicitly or clear AIW_LLAMA_CPP_ACTIVE_BUILD."
    fi

    install_dispatcher
    attach_instance
}

show_status() {
    local enabled="false"
    local active="not configured"
    local instance="not configured"
    local ensemble="not configured"
    if [[ -f "$CONFIG_FILE" ]]; then
        enabled="$(config_value AIW_LOCAL_INFERENCE_ENABLED)"
        active="$(config_value AIW_LLAMA_CPP_ACTIVE_BUILD)"
        instance="$(config_value AIW_DISPATCHER_INSTANCE)"
        ensemble="$(config_value AIW_DISPATCHER_ENSEMBLE)"
    fi

    printf 'Local inference       : %s\n' "${enabled:-false}"
    printf 'llama.cpp active      : %s\n' "${active:-not configured}"
    if [[ -n "${active:-}" ]] && build_exists "$active"; then
        printf 'llama.cpp backend     : %s\n' "$(manifest_value "$active" backend)"
        printf 'llama.cpp commit      : %s\n' "$(manifest_value "$active" commit)"
        printf 'llama.cpp bin dir     : %s\n' "$(build_bin_dir_for "$active")"
    else
        printf 'llama.cpp backend     : not available\n'
        printf 'llama.cpp commit      : not available\n'
        printf 'llama.cpp bin dir     : not available\n'
    fi
    local build_count=0
    [[ -d "$LLAMA_BUILDS_DIR" ]] && build_count="$(find "$LLAMA_BUILDS_DIR" -mindepth 2 -maxdepth 2 -name manifest.json -type f | wc -l)"
    printf 'llama.cpp builds      : %s\n' "$build_count"
    printf 'Dispatcher checkout   : %s\n' "$([[ -d "${DISPATCHER_DIR}/.git" ]] && git -C "$DISPATCHER_DIR" rev-parse --short HEAD 2>/dev/null || printf 'not installed')"
    printf 'Dispatcher instance   : %s\n' "${instance:-not configured}"
    printf 'Dispatcher ensemble   : %s\n' "${ensemble:-not configured}"
}

verify() {
    require_config
    local backend instance ensemble build bin_dir
    build="$(active_build_name)"
    backend="$(manifest_value "$build" backend)"
    instance="$(config_value AIW_DISPATCHER_INSTANCE)"
    ensemble="$(config_value AIW_DISPATCHER_ENSEMBLE)"
    bin_dir="$(build_bin_dir_for "$build")"

    [[ -x "${bin_dir}/llama-server" ]] || fail "llama-server is missing for build '$build'."
    [[ -d "${DISPATCHER_DIR}/.git" ]] || fail "Llama Dispatcher is missing. Run: aiw local-inference install"
    [[ -d "${DISPATCHER_DIR}/instances/${instance}/.git" ]] || fail "Dispatcher instance '$instance' is missing."
    [[ -x "$UV_BIN" ]] || fail "uv is missing."

    printf '[..] llama.cpp build=%s devices\n' "$build"
    "${bin_dir}/llama-server" --list-devices

    if [[ "$backend" == "vulkan" ]]; then
        if command -v vulkaninfo >/dev/null 2>&1; then
            vulkaninfo --summary || warn "vulkaninfo could not enumerate a usable Vulkan device. The build is installed, but WSL graphics support still needs attention."
        else
            warn "vulkaninfo is unavailable."
        fi
    fi

    printf '[..] Dispatcher compile-only check for instance=%s ensemble=%s build=%s\n' "$instance" "$ensemble" "$build"
    (
        cd "$DISPATCHER_DIR"
        "$UV_BIN" run --frozen python src/dispatcher.py serve \
            --instance "$instance" \
            --ensemble "$ensemble" \
            --compile-only \
            --bin-dir "$bin_dir"
    )
    printf '[OK] Host-local inference installation is structurally usable.\n'
}

run_dispatcher() {
    require_config
    local requested_build=""
    if (($# >= 2)) && [[ "$1" == "--llama-build" ]]; then
        requested_build="$2"
        shift 2
    fi
    (($# > 0)) || fail "Dispatcher arguments are required."

    local instance build bin_dir
    instance="$(config_value AIW_DISPATCHER_INSTANCE)"
    build="$(resolve_requested_build "$requested_build")"
    bin_dir="$(build_bin_dir_for "$build")"
    [[ -d "$DISPATCHER_DIR" ]] || fail "Llama Dispatcher is not installed."

    printf '[..] Dispatcher using llama.cpp build: %s (%s)\n' "$build" "$bin_dir"
    (
        cd "$DISPATCHER_DIR"
        exec "$UV_BIN" run --frozen python src/dispatcher.py "$@" \
            --instance "$instance" \
            --bin-dir "$bin_dir"
    )
}

serve() {
    require_config
    local requested_build=""
    if (($# >= 2)) && [[ "$1" == "--llama-build" ]]; then
        requested_build="$2"
        shift 2
    fi
    local ensemble
    ensemble="$(config_value AIW_DISPATCHER_ENSEMBLE)"
    [[ -n "$ensemble" ]] || fail "AIW_DISPATCHER_ENSEMBLE is missing from $CONFIG_FILE"
    if [[ -n "$requested_build" ]]; then
        run_dispatcher --llama-build "$requested_build" serve --ensemble "$ensemble" "$@"
    else
        run_dispatcher serve --ensemble "$ensemble" "$@"
    fi
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
    printf 'Runtime root       : %s\n' "$RUNTIME_ROOT"
    printf 'llama.cpp root     : %s\n' "$LLAMA_ROOT"
    printf 'llama.cpp builds   : %s\n' "$LLAMA_BUILDS_DIR"
    printf 'Dispatcher checkout: %s\n' "$DISPATCHER_DIR"
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
    llama) llama_command "$@" ;;
    config) show_config ;;
    help|-h|--help) usage ;;
    *) usage >&2; exit 2 ;;
esac
