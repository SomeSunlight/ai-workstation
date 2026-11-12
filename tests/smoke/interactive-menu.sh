#!/usr/bin/env bash
set -Eeuo pipefail
# Preserve the failing command/line when nested menu input changes unexpectedly.
trap 'printf "Interactive menu regression failed at line %s: %s\\n" "$LINENO" "$BASH_COMMAND" >&2' ERR
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cli="${ROOT}/bin/aiw"
temp_home="$(mktemp -d)"
trap 'rm -rf "$temp_home"' EXIT

menu_output="$(printf 'q\n' | HOME="$temp_home" "$cli")"
grep -Fq 'AI Workstation' <<< "$menu_output"
grep -Fq 'Goose' <<< "$menu_output"
grep -Fq 'Open WebUI' <<< "$menu_output"
grep -Fq 'Local inference' <<< "$menu_output"
grep -Fq 'llama.cpp / Llama Dispatcher' <<< "$menu_output"

local_menu_output="$(printf '2\nb\nq\n' | HOME="$temp_home" "$cli")"
grep -Fq 'Local inference' <<< "$local_menu_output"
grep -Fq 'List llama.cpp builds' <<< "$local_menu_output"
grep -Fq 'Setup generic Vulkan runtime' <<< "$local_menu_output"
grep -Fq 'Setup Intel SYCL runtime (WSL / Ubuntu 24.04)' <<< "$local_menu_output"

# Safe sandbox cockpit is the default entry; legacy direct-workspace Goose stays
# accessible on purpose, behind an explicit advanced choice.
cockpit_output="$(printf '1\n1\nb\nb\nq\n' | HOME="$temp_home" "$cli")"
assert_menu_has() {
    local actual="$1" needle="$2" stage="$3"
    if ! grep -Fq -- "$needle" <<< "$actual"; then
        printf 'Missing %s in %s menu. Actual output:\n%s\n' "$needle" "$stage" "$actual" >&2
        return 1
    fi
}
assert_menu_has "$cockpit_output" 'Goose sandbox cockpit' cockpit
assert_menu_has "$cockpit_output" 'Your projects (' cockpit
assert_menu_has "$cockpit_output" 'Your sessions (' cockpit
assert_menu_has "$cockpit_output" 'Your environments (' cockpit
assert_menu_has "$cockpit_output" 'Start a NEW safe Goose session' cockpit
goose_menu_output="$(printf '1\n2\n8\nb\n\nb\nb\nq\n' | "$cli")"
assert_menu_has "$goose_menu_output" 'Update application' legacy-Goose
assert_menu_has "$goose_menu_output" 'Latest stable official release' legacy-Goose
assert_menu_has "$goose_menu_output" 'Enter a specific stable version' legacy-Goose

webui_menu_output="$(printf '1\n2\n10\nb\n\nb\nq\nq\n' | "$cli")"
grep -Fq 'Update application (includes data backup)' <<< "$webui_menu_output"
grep -Fq 'Use the repository default version' <<< "$webui_menu_output"

# Native Process Compose submenu is a one-time menu, with explicit '?' redisplay.
services_output="$(printf '7\n14\n?\nb\nq\n' | HOME="$temp_home" "$cli")"
headers="$(grep -cx 'Native services (Process Compose)' <<< "$services_output")"
[[ "$headers" == "2" ]] || { echo "Native services menu repeated unexpectedly: $headers" >&2; exit 1; }
grep -Fq -- '--- End of action 14' <<< "$services_output" || {
    echo 'Native services menu lost action-boundary output.' >&2
    exit 1
}

welcome_output="$(HOME="$temp_home" "$cli" welcome --force)"
grep -Fq 'AI Workstation ready' <<< "$welcome_output"
grep -Fq 'aiw              Open the interactive tool menu' <<< "$welcome_output"

second_welcome="$(HOME="$temp_home" "$cli" welcome)"
[[ -z "$second_welcome" ]] || { echo 'Welcome hint was shown twice in one boot.' >&2; exit 1; }

printf 'Interactive menu and startup hint are valid.\n'
