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

# The supported SYCL provisioning path must use Intel's current Ubuntu PPA and
# the modern libze-intel-gpu1 package family. The legacy package may appear only
# in migration/removal checks, never in an apt install package list.
versions_file="${ROOT}/config/versions.json"
grep -Fq '"ubuntu_ppa": "ppa:kobuk-team/intel-graphics"' "$versions_file" || {
    echo 'Intel GPU provisioning must use the current intel-graphics PPA.' >&2
    exit 1
}
grep -Fq 'libze-intel-gpu1 libze1 intel-opencl-icd clinfo libze-dev intel-ocloc' "$manager" || {
    echo 'SYCL provisioning is missing the current Intel NEO / Level Zero package set.' >&2
    exit 1
}
grep -Fq 'apt-get remove -y intel-level-zero-gpu' "$manager" || {
    echo 'SYCL provisioning must explicitly migrate away from intel-level-zero-gpu.' >&2
    exit 1
}
if grep -Eq 'apt-get install[^[:cntrl:]]*intel-level-zero-gpu' "$manager"; then
    echo 'SYCL provisioning still installs obsolete intel-level-zero-gpu.' >&2
    exit 1
fi
grep -Fq 'verify_minimum_package_version libze-intel-gpu1' "$manager" || {
    echo 'SYCL verification must reject Intel NEO generations older than the proven minimum.' >&2
    exit 1
}

grep -Fq 'install_system_dependencies "$backend"' "$manager" || {
    echo 'Backend setup must reprovision prerequisites even when a pinned build already exists.' >&2
    exit 1
}

# Intel's setvars.sh owns ONEAPI_ROOT. AI Workstation must not declare that
# vendor environment variable readonly before sourcing the Intel environment.
if grep -Eq '^[[:space:]]*readonly[[:space:]]+ONEAPI_ROOT=' "$manager"; then
    echo 'AI Workstation must not declare Intel-owned ONEAPI_ROOT readonly.' >&2
    exit 1
fi

# Intel setvars.sh marks a completed environment with SETVARS_COMPLETED. The
# manager may enter the SYCL environment loader several times in one command,
# so repeated sourcing must be guarded rather than relying on --force.
grep -Fq 'if [[ "${SETVARS_COMPLETED:-}" != "1" ]]; then' "$manager" || {
    echo 'SYCL environment loading is not guarded against repeated Intel setvars.sh sourcing.' >&2
    exit 1
}

# llama-ls-sycl-device currently prints "Found N SYCL devices" with a capital F.
# Keep the verifier case-insensitive so a valid real device is not rejected.
grep -Fq "grep -Eiq 'found [1-9][0-9]* SYCL devices'" "$manager" || {
    echo 'SYCL device verification must accept llama.cpp output capitalization.' >&2
    exit 1
}
printf 'Found 1 SYCL devices:\n' | grep -Eiq 'found [1-9][0-9]* SYCL devices'

# Dispatcher instances are user-owned. A modified instance/submodule must not make
# the AI Workstation-owned Dispatcher core appear dirty, while real core edits must.
dirty_repo="${temp_home}/dispatcher-dirty-check"
mkdir -p "${dirty_repo}/instances/Laptop"
git -C "$dirty_repo" init -q
git -C "$dirty_repo" config user.email smoke@example.invalid
git -C "$dirty_repo" config user.name smoke
printf 'core\n' > "${dirty_repo}/core.txt"
printf 'instance\n' > "${dirty_repo}/instances/Laptop/config.txt"
git -C "$dirty_repo" add .
git -C "$dirty_repo" commit -qm initial
printf 'instance changed\n' >> "${dirty_repo}/instances/Laptop/config.txt"
git -C "$dirty_repo" diff --quiet -- . ':(exclude)instances' ':(exclude)instances/**'
printf 'core changed\n' >> "${dirty_repo}/core.txt"
if git -C "$dirty_repo" diff --quiet -- . ':(exclude)instances' ':(exclude)instances/**'; then
    echo 'Dispatcher core dirty check unexpectedly ignored a core edit.' >&2
    exit 1
fi

# Remote-only is a valid state and must not require any local runtime artifacts.
remote_status="$(bash "$manager" status)"
grep -Fq 'Local inference       : false' <<< "$remote_status"
grep -Fq 'llama.cpp builds      : 0' <<< "$remote_status"
grep -Fq 'Dispatcher instances  : 0 user-owned' <<< "$remote_status"

# Generic configuration is machine-local and must not inject an instance repo.
bash "$manager" configure vulkan
[[ -f "$config_file" ]]
grep -Fxq 'AIW_LOCAL_INFERENCE_ENABLED=true' "$config_file"
grep -Fxq 'AIW_LLAMA_CPP_BOOTSTRAP_BACKEND=vulkan' "$config_file"
if grep -Fq 'AIW_DISPATCHER_INSTANCE' "$config_file"; then
    echo 'Generic local-inference config unexpectedly contains a Dispatcher instance.' >&2
    exit 1
fi
if grep -Fq 'Llama_Dispatcher_Laptop' "$config_file"; then
    echo 'Generic local-inference config unexpectedly contains a user-specific repository.' >&2
    exit 1
fi

# Create a synthetic completed build slot. Smoke tests exercise registry semantics,
# not compilers, GPU drivers, network access or real model execution.
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

# Re-applying a backend preset must preserve the explicitly selected build.
bash "$manager" configure vulkan
grep -Fxq "AIW_LLAMA_CPP_ACTIVE_BUILD=${name}" "$config_file"

# SYCL is another explicit generic backend. Merely configuring it must not
# provision hardware in CI and must not destroy/change the selected Vulkan slot.
bash "$manager" configure sycl
grep -Fxq 'AIW_LLAMA_CPP_BOOTSTRAP_BACKEND=sycl' "$config_file"
grep -Fxq "AIW_LLAMA_CPP_ACTIVE_BUILD=${name}" "$config_file"
sycl_status="$(bash "$manager" status)"
grep -Fq 'llama.cpp bootstrap   : sycl' <<< "$sycl_status"
grep -Fq "llama.cpp active      : ${name}" <<< "$sycl_status"
grep -Fq 'llama.cpp backend     : vulkan' <<< "$sycl_status"

# The stable aiw front controller must expose the same optional runtime.
router_status="$("$cli" local-inference status)"
grep -Fq 'Local inference       : true' <<< "$router_status"
grep -Fq "llama.cpp active      : ${name}" <<< "$router_status"

if bash "$manager" llama select does-not-exist >/dev/null 2>&1; then
    echo 'Selecting an unknown llama.cpp build unexpectedly succeeded.' >&2
    exit 1
fi

printf 'Local-inference registry, Vulkan/SYCL backend configuration, ownership boundary and routing are valid.\n'
