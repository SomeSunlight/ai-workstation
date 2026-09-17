#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cli="${ROOT}/bin/aiw"
manager="${ROOT}/runtimes/local-inference/manage.sh"
temp_home="$(mktemp -d)"
trap 'rm -rf "$temp_home"' EXIT

config_file="${temp_home}/.config/ai-workstation/local-inference.env"
runtime_root="${temp_home}/runtime"
export HOME="$temp_home"
export AIW_LOCAL_INFERENCE_CONFIG="$config_file"
export AIW_LOCAL_INFERENCE_ROOT="$runtime_root"

# Remote-only is a valid state and must not require any local runtime artifacts.
remote_status="$(bash "$manager" status)"
grep -Fq 'Local inference       : false' <<< "$remote_status"
grep -Fq 'llama.cpp builds      : 0' <<< "$remote_status"

# Configuration is machine-local and does not install/build anything by itself.
bash "$manager" configure laptop-vulkan
[[ -f "$config_file" ]]
grep -Fxq 'AIW_LOCAL_INFERENCE_ENABLED=true' "$config_file"
grep -Fxq 'AIW_LLAMA_CPP_BOOTSTRAP_BACKEND=vulkan' "$config_file"
grep -Fxq 'AIW_DISPATCHER_INSTANCE=Laptop' "$config_file"

# Create a synthetic completed build slot. Smoke tests exercise registry semantics,
# not compilers, Vulkan drivers, network access or real model execution.
name='vulkan-deadbeef-lab'
slot="${runtime_root}/llama.cpp/builds/${name}"
bin_dir="${slot}/build/bin"
mkdir -p "$bin_dir"
cat > "${bin_dir}/llama-server" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == '--version' ]]; then
    printf 'llama.cpp test build commit deadbeef\n'
fi
EOF
chmod +x "${bin_dir}/llama-server"
cat > "${slot}/manifest.json" <<EOF
{
  "schema": 1,
  "name": "${name}",
  "repository": "https://github.com/ggml-org/llama.cpp.git",
  "commit": "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef",
  "backend": "vulkan",
  "extra_cmake_args": ["-DTEST_ONLY=ON"],
  "source_dir": "${slot}/source",
  "build_dir": "${slot}/build",
  "bin_dir": "${bin_dir}",
  "llama_server_version": "llama.cpp test build commit deadbeef",
  "built_at_utc": "2026-09-17T00:00:00+00:00"
}
EOF

list_output="$(bash "$manager" llama list)"
grep -Fq "$name" <<< "$list_output"
grep -Fq 'vulkan' <<< "$list_output"
grep -Fq 'deadbeef' <<< "$list_output"

bash "$manager" llama select "$name"
grep -Fxq "AIW_LLAMA_CPP_ACTIVE_BUILD=${name}" "$config_file"

selected_status="$(bash "$manager" status)"
grep -Fq "llama.cpp active      : ${name}" <<< "$selected_status"
grep -Fq 'llama.cpp backend     : vulkan' <<< "$selected_status"
grep -Fq 'llama.cpp commit      : deadbeefdeadbeefdeadbeefdeadbeefdeadbeef' <<< "$selected_status"

manifest_output="$(bash "$manager" llama show "$name")"
grep -Fq '"extra_cmake_args": [' <<< "$manifest_output"
grep -Fq '"-DTEST_ONLY=ON"' <<< "$manifest_output"

# Re-applying a machine preset must preserve the explicitly selected build.
bash "$manager" configure laptop-vulkan
grep -Fxq "AIW_LLAMA_CPP_ACTIVE_BUILD=${name}" "$config_file"

# The stable aiw front controller must expose the same optional runtime.
router_status="$("$cli" local-inference status)"
grep -Fq 'Local inference       : true' <<< "$router_status"
grep -Fq "llama.cpp active      : ${name}" <<< "$router_status"

if bash "$manager" llama select does-not-exist >/dev/null 2>&1; then
    echo 'Selecting an unknown llama.cpp build unexpectedly succeeded.' >&2
    exit 1
fi

printf 'Local-inference registry and routing are valid.\n'
