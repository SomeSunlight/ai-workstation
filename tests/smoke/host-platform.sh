#!/usr/bin/env bash
# Pure classification + isolated fake-browser behavior. No system changes or GPU.
set -Eeuo pipefail
IFS=$'\n\t'
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
source "$ROOT/tools/host-platform.sh"

fail() { printf '[XX] %s\n' "$*" >&2; exit 1; }
assert_mode() {
    local value="$1" expected="$2"
    [[ "$(aiw_host_mode_from_release "$value")" == "$expected" ]] || \
        fail "Host mode for '$value' was not '$expected'"
}

assert_mode '6.6.87.2-microsoft-standard-WSL2' wsl
assert_mode '4.4.0-Microsoft' wsl
assert_mode '6.8.0-52-generic' native-linux
assert_mode '6.8.0-1018-aws' native-linux

aiw_checkout_is_blocked '/mnt/c/ai-workstation' wsl || fail 'WSL /mnt guard not enforced'
aiw_checkout_is_blocked '/mnt/workspace/ai-workstation' wsl || fail 'Existing WSL /mnt guard weakened'
if aiw_checkout_is_blocked '/mnt/data/ai-workstation' native-linux; then
    fail 'Native Linux /mnt mount was incorrectly blocked'
fi
if aiw_checkout_is_blocked '/home/user/ai-workstation' wsl; then
    fail 'Normal WSL Linux checkout was incorrectly blocked'
fi

temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT
mkdir -p "$temp_dir/bin"
export AIW_BROWSER_TEST_LOG="$temp_dir/browser.log"
cat > "$temp_dir/bin/powershell.exe" <<'EOF_FAKE'
#!/usr/bin/env bash
printf 'powershell %s\n' "$*" >> "$AIW_BROWSER_TEST_LOG"
EOF_FAKE
cat > "$temp_dir/bin/xdg-open" <<'EOF_FAKE'
#!/usr/bin/env bash
printf 'xdg-open %s\n' "$*" >> "$AIW_BROWSER_TEST_LOG"
EOF_FAKE
chmod +x "$temp_dir/bin/powershell.exe" "$temp_dir/bin/xdg-open"
export PATH="$temp_dir/bin:$PATH"

output="$(DISPLAY=:0 aiw_open_browser_url 'http://localhost:3000' wsl)"
grep -Fq '[OK] Opened Windows browser' <<< "$output" || fail 'WSL browser adapter failed'
grep -Fq 'powershell ' "$AIW_BROWSER_TEST_LOG" || fail 'WSL did not invoke PowerShell'

: > "$AIW_BROWSER_TEST_LOG"
output="$(DISPLAY=:0 aiw_open_browser_url 'http://localhost:3000' native-linux)"
grep -Fq '[OK] Opened Linux browser' <<< "$output" || fail 'Native desktop adapter failed'
grep -Fq 'xdg-open http://localhost:3000' "$AIW_BROWSER_TEST_LOG" || fail 'Native desktop did not invoke xdg-open'
if grep -Fq 'powershell' "$AIW_BROWSER_TEST_LOG"; then
    fail 'Native Linux unexpectedly invoked Windows browser'
fi

: > "$AIW_BROWSER_TEST_LOG"
output="$(DISPLAY= WAYLAND_DISPLAY= aiw_open_browser_url 'http://localhost:3000' native-linux)"
grep -Fq 'Open this URL on the Linux host' <<< "$output" || fail 'Headless host missing URL'
grep -Fq 'SSH tunnel' <<< "$output" || fail 'Headless host missing private access hint'
[[ ! -s "$AIW_BROWSER_TEST_LOG" ]] || fail 'Headless mode attempted to open a browser'

printf 'Native Linux / WSL host adapter checks passed.\n'
