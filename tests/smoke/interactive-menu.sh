#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cli="${ROOT}/bin/aiw"
temp_home="$(mktemp -d)"
trap 'rm -rf "$temp_home"' EXIT

menu_output="$(printf 'q\n' | HOME="$temp_home" "$cli")"
grep -Fq 'AI Workstation' <<< "$menu_output"
grep -Fq 'Goose' <<< "$menu_output"
grep -Fq 'Open WebUI' <<< "$menu_output"

welcome_output="$(HOME="$temp_home" "$cli" welcome --force)"
grep -Fq 'AI Workstation ready' <<< "$welcome_output"
grep -Fq 'aiw              Open the interactive tool menu' <<< "$welcome_output"

second_welcome="$(HOME="$temp_home" "$cli" welcome)"
[[ -z "$second_welcome" ]] || { echo 'Welcome hint was shown twice in one boot.' >&2; exit 1; }

printf 'Interactive menu and startup hint are valid.\n'
