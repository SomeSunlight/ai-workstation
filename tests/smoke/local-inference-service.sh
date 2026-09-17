#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
service="${ROOT}/runtimes/local-inference/service.sh"
temp="$(mktemp -d)"
trap 'rm -rf "$temp"' EXIT

export HOME="${temp}/home"
mkdir -p "$HOME"
models="${temp}/models"
dispatcher="${temp}/dispatcher"
mkdir -p "$models" "${dispatcher}/instances/Laptop/ensembles"
printf 'nickname: Laptop\nmachine_guid: test-guid\n' > "${dispatcher}/instances/Laptop/instance.yaml"
printf 'defaults:\n  engine: sycl\n' > "${dispatcher}/instances/Laptop/ensembles/thinkpad-sycl.yaml"

runtime_config="${temp}/runtime.env"
manager_args="${temp}/manager-args.txt"
fake_manager="${temp}/manager.sh"
cat > "$fake_manager" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$AIW_TEST_MANAGER_ARGS"
EOF
chmod +x "$fake_manager"

systemctl_log="${temp}/systemctl.txt"
fake_systemctl="${temp}/systemctl"
cat > "$fake_systemctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$AIW_TEST_SYSTEMCTL_LOG"
if [[ "$*" == 'show-environment' ]]; then
    exit 0
fi
if [[ "$*" == 'is-enabled '* || "$*" == 'is-active '* ]]; then
    exit 1
fi
EOF
chmod +x "$fake_systemctl"

export AIW_LOCAL_INFERENCE_RUNTIME_CONFIG="$runtime_config"
export AIW_LOCAL_INFERENCE_DISPATCHER_DIR="$dispatcher"
export AIW_LOCAL_INFERENCE_MANAGER="$fake_manager"
export AIW_SYSTEMCTL_BIN="$fake_systemctl"
export AIW_SUDO_BIN=""
export AIW_TEST_MANAGER_ARGS="$manager_args"
export AIW_TEST_SYSTEMCTL_LOG="$systemctl_log"
export AIW_LOCAL_INFERENCE_SYSTEMD_DIR="${temp}/systemd"

bash "$service" runtime configure \
    --model-root "$models" \
    --instance Laptop \
    --ensemble thinkpad-sycl

grep -Fxq "AIW_LLAMA_MODEL_ROOT=${models}" "$runtime_config"
grep -Fxq 'AIW_DISPATCHER_INSTANCE=Laptop' "$runtime_config"
grep -Fxq 'AIW_DISPATCHER_ENSEMBLE=thinkpad-sycl' "$runtime_config"
if grep -Eq '^LLAMA_MODEL_ROOT=' "$runtime_config"; then
    echo 'Runtime config must not create a shell-level LLAMA_MODEL_ROOT variable.' >&2
    exit 1
fi

bash "$service" service-run
grep -Fxq 'serve' "$manager_args"
grep -Fxq -- '--instance' "$manager_args"
grep -Fxq 'Laptop' "$manager_args"
grep -Fxq -- '--ensemble' "$manager_args"
grep -Fxq 'thinkpad-sycl' "$manager_args"
grep -Fxq -- '--model-root' "$manager_args"
grep -Fxq "$models" "$manager_args"

unit="$(bash "$service" render-service)"
grep -Fq 'local-inference service-run' <<< "$unit"
grep -Fq 'Restart=on-failure' <<< "$unit"
grep -Fq "User=$(id -un)" <<< "$unit"
grep -Fq 'WantedBy=multi-user.target' <<< "$unit"

bash "$service" start
grep -Fxq 'daemon-reload' "$systemctl_log"
grep -Fxq 'start ai-workstation-local-inference.service' "$systemctl_log"
[[ -f "${temp}/systemd/ai-workstation-local-inference.service" ]]

bash "$service" autostart enable
grep -Fxq 'enable --now ai-workstation-local-inference.service' "$systemctl_log"

printf 'Local-inference runtime configuration, explicit model-root injection and system-level service lifecycle are valid.\n'
