#!/usr/bin/env bash
# Small, dependency-free host integration helpers shared by Linux entry points.
# Native Ubuntu and Ubuntu under WSL use the same installation implementation.

aiw_host_mode_from_release() {
    local release="${1,,}"
    case "$release" in
        *microsoft*|*wsl*) printf '%s\n' 'wsl' ;;
        *) printf '%s\n' 'native-linux' ;;
    esac
}

aiw_host_mode() {
    local release
    release="$(cat /proc/sys/kernel/osrelease 2>/dev/null || uname -r)"
    aiw_host_mode_from_release "$release"
}

# Deliberately keep the existing WSL /mnt guard, but do not prohibit legitimate
# native Linux mounts such as /mnt/models or /mnt/workstation.
aiw_checkout_is_blocked() {
    local path="$1" mode="${2:-$(aiw_host_mode)}"
    [[ "$mode" == 'wsl' && "$path" == /mnt/* ]]
}

# $2 is an optional explicit mode for isolated tests; production uses host mode.
aiw_open_browser_url() {
    local url="$1" mode="${2:-$(aiw_host_mode)}"
    if [[ "$mode" == 'wsl' ]]; then
        if command -v powershell.exe >/dev/null 2>&1 && \
            powershell.exe -NoLogo -NoProfile -NonInteractive \
                -Command "Start-Process '$url'" >/dev/null 2>&1; then
            printf '[OK] Opened Windows browser: %s\n' "$url"
            return 0
        fi
        if command -v cmd.exe >/dev/null 2>&1 && \
            cmd.exe /C start "" "$url" >/dev/null 2>&1; then
            printf '[OK] Opened Windows browser: %s\n' "$url"
            return 0
        fi
        printf '[..] Open this URL in your Windows browser: %s\n' "$url"
        return 0
    fi

    if [[ "$mode" == 'native-linux' && -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] && \
        command -v xdg-open >/dev/null 2>&1 && xdg-open "$url" >/dev/null 2>&1; then
        printf '[OK] Opened Linux browser: %s\n' "$url"
        return 0
    fi

    printf '[..] Open this URL on the Linux host: %s\n' "$url"
    printf '[..] On a remote host, use an SSH tunnel to the loopback port; do not expose Open WebUI publicly.\n'
}
