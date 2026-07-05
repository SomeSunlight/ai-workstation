#!/usr/bin/env bash
# Public Linux entry point for AI Workstation.
set -Eeuo pipefail
IFS=$'\n\t'

readonly ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
exec "${ROOT}/bootstrap/linux/install.sh" "$@"
