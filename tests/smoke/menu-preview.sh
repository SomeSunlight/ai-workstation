#!/usr/bin/env bash
# Behavioral tests for the optional aiw menu learning mode.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
CLI="${ROOT}/bin/aiw"
temp_home="$(mktemp -d)"
trap 'rm -rf -- "$temp_home"' EXIT
export HOME="$temp_home"
export AIW_MENU_CONFIG_FILE="$HOME/.config/ai-workstation/config.yaml"

assert_contains() {
    local output="$1" needle="$2"
    if [[ "$output" != *"$needle"* ]]; then
        printf 'Missing expected output: %s\n%s\n' "$needle" "$output" >&2
        exit 1
    fi
}
assert_absent() {
    local output="$1" needle="$2"
    if [[ "$output" == *"$needle"* ]]; then
        printf 'Unexpected output: %s\n%s\n' "$needle" "$output" >&2
        exit 1
    fi
}

# Disabled by default, existing menus keep working without creating a config file.
output="$(printf '5\n\nq\n' | "$CLI" 2>&1)"
assert_contains "$output" 'AI Workstation command line'
assert_absent "$output" 'Command to run:'
[[ ! -e "$AIW_MENU_CONFIG_FILE" ]]

# The editor entry creates documented and protected YAML and uses the chosen editor.
editor="$temp_home/my-editor"
cat > "$editor" <<'EOF_EDITOR'
#!/usr/bin/env bash
printf '%s\n' "$1" > "$HOME/editor-opened"
EOF_EDITOR
chmod +x "$editor"
output="$(printf '6\n\nq\n' | VISUAL="$editor" "$CLI" 2>&1)"
[[ -f "$AIW_MENU_CONFIG_FILE" ]]
[[ "$(stat -c '%a' "$AIW_MENU_CONFIG_FILE")" == 600 ]]
[[ "$(cat "$HOME/editor-opened")" == "$AIW_MENU_CONFIG_FILE" ]]
grep -Fq 'menu_command_preview: false' "$AIW_MENU_CONFIG_FILE"
grep -Fq 'Only "y" or "Y" executes it' "$AIW_MENU_CONFIG_FILE"

# Turn mode on and start a separate process (reopening WSL/aiw is equivalent).
sed -i 's/menu_command_preview: false/menu_command_preview: true/' "$AIW_MENU_CONFIG_FILE"
output="$(printf '5\nn\nq\n' | "$CLI" 2>&1)"
assert_contains "$output" 'Command to run: aiw help'
assert_contains "$output" 'Continue? [y/N]'
assert_absent "$output" 'AI Workstation command line'

output="$(printf '5\n\nq\n' | "$CLI" 2>&1)"
assert_contains "$output" 'Command to run: aiw help'
assert_absent "$output" 'AI Workstation command line'

output="$(printf '5\ny\n\nq\n' | "$CLI" 2>&1)"
assert_contains "$output" 'AI Workstation command line'

# Direct CLI invocation is never intercepted.
output="$("$CLI" help 2>&1)"
assert_contains "$output" 'AI Workstation command line'
assert_absent "$output" 'Command to run:'

# Nested standard menu: cancellation must not call Docker or require it.
output="$(printf '1\n1\n7\nn\nb\nq\nq\n' | "$CLI" 2>&1)"
assert_contains "$output" 'Command to run: aiw goose pull'
assert_absent "$output" 'Docker is not installed'

# Informational actions have public CLI equivalents too.
output="$(printf '1\n1\n6\ny\n\nb\nq\nq\n' | "$CLI" 2>&1)"
assert_contains "$output" 'Command to run: aiw goose quick-help'
assert_contains "$output" 'Goose quick help'
output="$("$CLI" goose quick-help 2>&1)"
assert_contains "$output" 'Goose quick help'
assert_absent "$output" 'Command to run:'

# Nested local-inference menu: dynamically entered arguments are shell-quoted.
output="$(printf '2\n10\nmodel with spaces\nn\nb\nq\n' | "$CLI" 2>&1)"
assert_contains "$output" 'Command to run: aiw local-inference llama select model\ with\ spaces'

# Invalid or duplicate setting must refuse execution (fail closed), not become false.
printf 'menu_command_preview: maybe\n' > "$AIW_MENU_CONFIG_FILE"
output="$(printf '5\nq\n' | "$CLI" 2>&1)"
assert_contains "$output" 'Invalid menu_command_preview'
assert_absent "$output" 'AI Workstation command line'

printf 'menu_command_preview: true\nmenu_command_preview: false\n' > "$AIW_MENU_CONFIG_FILE"
output="$(printf '5\nq\n' | "$CLI" 2>&1)"
assert_contains "$output" 'Duplicate menu_command_preview'
assert_absent "$output" 'AI Workstation command line'

# Disabled mode stays off for the next process, and inline comments are supported.
printf 'menu_command_preview: false # Disable previews\n' > "$AIW_MENU_CONFIG_FILE"
output="$(printf '5\n\nq\n' | "$CLI" 2>&1)"
assert_absent "$output" 'Command to run:'
assert_contains "$output" 'AI Workstation command line'

printf 'Menu preview/configuration smoke checks passed.\n'
