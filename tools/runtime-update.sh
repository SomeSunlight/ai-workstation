#!/usr/bin/env bash
# Shared application-update workflow, sourced by bin/aiw-core.

runtime_default_image() {
    python3 - "${ROOT}/config/versions.json" "$1" <<'PYTHON'
import json
import sys
from pathlib import Path

key = {"goose": "goose", "open-webui": "open_webui"}[sys.argv[2]]
print(json.loads(Path(sys.argv[1]).read_text())["versions"][key]["image"])
PYTHON
}

runtime_selected_image() {
    local image key="$2"
    image="$(env_value "$key" "$(runtime_env_file)")"
    printf '%s\n' "${image:-$(runtime_default_image "$1")}"
}

runtime_release_tag() {
    local repository="$1" release
    command -v curl >/dev/null 2>&1 || fail "curl is missing. Run ./install.sh first."
    release="$(curl --fail --silent --show-error --location \
        --connect-timeout 10 --max-time 30 \
        --header 'Accept: application/vnd.github+json' \
        "https://api.github.com/repos/${repository}/releases/latest")" || \
        fail "Cannot check the latest stable release. Retry later or specify a version."
    printf '%s' "$release" | python3 -c '
import json, re, sys
try:
    release = json.load(sys.stdin)
    tag = release["tag_name"]
    if release.get("draft") is not False or release.get("prerelease") is not False:
        raise ValueError("release is not stable")
    if not isinstance(tag, str) or not re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+", tag):
        raise ValueError("release has no supported stable version tag")
    print(tag)
except (ValueError, KeyError, TypeError) as exc:
    sys.exit(f"Invalid stable release metadata: {exc}")
' || fail "No supported stable release found. Specify an exact version instead."
}

runtime_write_image() {
    # Replace duplicate entries as well; preserve every unrelated byte and secret.
    python3 - "$RUNTIME_ENV_FILE" "$1" "$2" <<'PYTHON'
import os
import re
import sys
import tempfile
from pathlib import Path

path, key, value = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
lines = path.read_bytes().splitlines(keepends=True)
pattern = re.compile(rb"^[ \t]*" + key.encode() + rb"[ \t]*=")
result, found = [], False
for line in lines:
    if pattern.match(line):
        if not found:
            result.append(f"{key}={value}\n".encode())
            found = True
    else:
        result.append(line)
if not found:
    if result and not result[-1].endswith(b"\n"):
        result.append(b"\n")
    result.append(f"{key}={value}\n".encode())
fd, temp = tempfile.mkstemp(prefix=".aiw-image-", dir=path.parent)
try:
    with os.fdopen(fd, "wb") as stream:
        stream.write(b"".join(result))
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temp, path)
finally:
    if os.path.exists(temp):
        os.unlink(temp)
PYTHON
}

runtime_update_usage() {
    cat <<EOF_USAGE
Usage: aiw $1 update [VERSION|--repository] [--yes]

With no version, check the latest stable official release and ask before updating.
VERSION accepts a stable version such as 1.2.3 or v1.2.3.
--repository selects the default from this checkout's config/versions.json.
--yes applies the displayed choice without an interactive confirmation.
Selections are saved in the protected, Git-ignored .env; tracked pins stay intact.
EOF_USAGE
}

runtime_update() (
    local tool="$1"
    shift
    local selection="latest" assume_yes=false selected=false arg
    for arg in "$@"; do
        case "$arg" in
            --yes) assume_yes=true ;;
            --help|-h) runtime_update_usage "$tool"; return 0 ;;
            *)
                [[ "$selected" == false ]] || fail "Specify only one update version."
                selection="$arg"
                selected=true
                ;;
        esac
    done
    [[ "$selection" == latest || "$selection" == --repository || \
        "$selection" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]] || \
        fail "Use a stable version, --repository, or no version for latest stable."

    command -v python3 >/dev/null 2>&1 || fail "Python 3 is missing. Run ./install.sh first."
    local key repository image_base volume
    case "$tool" in
        goose)
            key=GOOSE_IMAGE repository=aaif-goose/goose
            image_base=ghcr.io/aaif-goose/goose
            ;;
        open-webui)
            key=OPEN_WEBUI_IMAGE repository=open-webui/open-webui
            image_base=ghcr.io/open-webui/open-webui
            volume=ai-workstation_open-webui-data
            ;;
        *) fail "Unknown application: $tool" ;;
    esac
    [[ ! -v "$key" ]] || fail "Unset exported $key first; updates use the persisted .env selection."
    if [[ "$tool" == open-webui ]]; then
        command -v curl >/dev/null 2>&1 || fail "curl is required to verify Open WebUI health."
    fi

    local current target tag
    current="$(runtime_selected_image "$tool" "$key")" || fail "Cannot read the current image."
    case "$selection" in
        latest)
            printf '[..] Checking the latest stable %s release.\n' "$tool"
            tag="$(runtime_release_tag "$repository")" || exit 1
            target="${image_base}:${tag}"
            ;;
        --repository) target="$(runtime_default_image "$tool")" || exit 1 ;;
        *) target="${image_base}:v${selection#v}" ;;
    esac
    printf '\nApplication update: %s\n  Current selection: %s\n  Target:            %s\n' "$tool" "$current" "$target"
    printf '  Release notes:     https://github.com/%s/releases/tag/%s\n' "$repository" "${target##*:}"
    if python3 - "$current" "$target" <<'PYTHON'
import re, sys

def version(image):
    match = re.search(r":v([0-9]+)\.([0-9]+)\.([0-9]+)$", image)
    return tuple(map(int, match.groups())) if match else None

current, target = map(version, sys.argv[1:])
sys.exit(0 if current is not None and target is not None and target < current else 1)
PYTHON
    then
        warn "This selects an older release; persistent state may require a matching older backup."
        [[ "$tool" != open-webui ]] || warn "A backup of today's database does not undo earlier migrations."
    fi
    if [[ "$tool" == open-webui ]]; then
        printf 'Open WebUI will stop for a data backup, then restart with the selected image.\n'
    else
        printf 'New Goose sessions will use the selected image. Existing sessions keep running.\n'
    fi
    if [[ "$assume_yes" == false ]]; then
        local reply
        read -r -p 'Apply this application update? [y/N] ' reply || reply=""
        [[ "$reply" =~ ^[Yy]$ ]] || { printf '[..] Update cancelled.\n'; return 0; }
    fi

    mkdir -p "$STATE_DIR" || fail "Cannot create the runtime state directory."
    command -v flock >/dev/null 2>&1 || fail "flock is missing. Run ./install.sh first."
    exec 9> "${STATE_DIR}/runtime-update.lock"
    flock --nonblock 9 || fail "Another application update is running; retry after it finishes."
    require_docker
    printf '[..] Downloading %s before changing configuration.\n' "$target"
    docker pull "$target" || fail "Image download failed; configuration and running containers were kept."
    runtime_init || fail "Cannot prepare the runtime configuration."

    if [[ "$tool" == goose ]]; then
        runtime_write_image "$key" "$target" || fail "Cannot save the Goose image selection."
        printf '[OK] Goose image ready for the next session: %s\n' "$target"
        return 0
    fi

    local backup_dir="" was_running=false container_id data_mounts volume_name previous_image="$current"
    # Inspect the actual container mount rather than backing up an unrelated volume.
    container_id="$(open_webui_compose ps --all --quiet open-webui)" || fail "Cannot inspect Open WebUI."
    if [[ -n "$container_id" ]]; then
        data_mounts="$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/app/backend/data"}}{{.Name}}{{end}}{{end}}' "$container_id")" || \
            fail "Cannot inspect the Open WebUI data volume."
        [[ "$data_mounts" == "$volume" ]] || fail "Unexpected Open WebUI data mount; update stopped before changing the service."
        previous_image="$(docker inspect --format '{{.Config.Image}}' "$container_id")" || fail "Cannot read the previous container image."
        was_running="$(docker inspect --format '{{.State.Running}}' "$container_id")" || fail "Cannot inspect the previous container state."
    fi
    volume_name="$(docker volume ls --filter "name=^${volume}$" --format '{{.Name}}')" || \
        fail "Cannot inspect Docker volumes; update aborted."
    if [[ "$volume_name" == "$volume" ]]; then
        umask 077
        mkdir -p "${STATE_DIR}/backups/open-webui" || fail "Cannot create the backup directory."
        backup_dir="$(mktemp -d "${STATE_DIR}/backups/open-webui/$(date -u +%Y%m%dT%H%M%SZ).XXXXXX")" || exit 1
        cp -- "$RUNTIME_ENV_FILE" "${backup_dir}/runtime.env" || fail "Cannot save the pre-update configuration."
        printf '%s\n' "$previous_image" > "${backup_dir}/previous-image.txt"
        printf '[..] Stopping Open WebUI for a consistent data backup.\n'
        open_webui_compose stop open-webui || fail "Cannot stop Open WebUI; update aborted."
        printf '[..] Backing up Open WebUI data to %s\n' "$backup_dir"
        if ! docker run --rm --network none --read-only --cap-drop ALL \
            --security-opt no-new-privileges:true --user 0 \
            --mount "type=volume,src=${volume},dst=/data,readonly" \
            --entrypoint python "$target" -c \
            'import sys, tarfile; archive = tarfile.open(fileobj=sys.stdout.buffer, mode="w|gz"); archive.add("/data", arcname="."); archive.close()' \
            > "${backup_dir}/data.tar.gz"; then
            rm -f -- "${backup_dir}/data.tar.gz"
            if [[ "$was_running" == true ]]; then
                open_webui_compose start open-webui || warn "Could not restart the previous service; run: aiw open-webui up"
            fi
            fail "Data backup failed; the image selection was kept and no update was applied."
        fi
        printf '[OK] Pre-update backup: %s\n' "$backup_dir"
    elif [[ -n "$container_id" ]]; then
        fail "Cannot inspect the existing Open WebUI volume; update aborted."
    fi

    if ! runtime_write_image "$key" "$target"; then
        if [[ "$was_running" == true ]]; then
            open_webui_compose start open-webui || warn "Could not restart the previous service."
        fi
        fail "Cannot save the image selection; no updated container was started."
    fi
    if ! open_webui_compose up --detach --force-recreate --pull never open-webui; then
        fail "Open WebUI could not start with $target. Backup: ${backup_dir:-none (new installation)}. Check: aiw open-webui logs"
    fi
    if ! wait_for_open_webui "$(open_webui_url)"; then
        fail "Open WebUI did not become healthy. Backup: ${backup_dir:-none (new installation)}. Check: aiw open-webui logs. Database migrations may require restoring the backup; see docs/container-updates.md."
    fi
    printf '[OK] Open WebUI updated and healthy: %s\n' "$target"
    printf '[OK] Browser URL: %s (refresh with Ctrl+F5)\n' "$(open_webui_url)"
)
