# Application updates

## The normal route

Open **AI Workstation** or **AI Workstation Terminal** from Windows and run:

```bash
aiw
```

The command works from **any directory inside the installed WSL distribution**.
It follows the installed symlink to the workstation checkout and supplies the
correct Compose file, environment file and project name itself.

Choose **Standard tools**, then **Open WebUI** or **Goose**, then **Update
application**. The update chooser offers:

1. **Latest stable official release** — discover the current non-prerelease on
   the application's official GitHub repository.
2. **Enter a specific stable version** — use a release such as `v0.11.4`.
3. **Use the repository default version** — select the exact image recorded in
   this checkout's `config/versions.json`.

`aiw` shows the existing image selection, target image and release-notes URL. It
only proceeds after you answer **y**. Cancellation or a failed release check
does not change the application. If the release exists but its Docker image has
not been published yet, the pull fails before changing any running container.

The Open WebUI update notification is useful as a notification and link to
release information. The workstation's `aiw` command performs the container
update; the browser application does not control the Docker Engine.

## What gets updated

| Operation | Effect |
| --- | --- |
| `aiw update` / Update installation | Fast-forward the workstation Git checkout and rerun its host installer. |
| Update application | Select an exact application release and download its image. Recreate Open WebUI, or use the selection for future Goose sessions. |
| Pull pinned image | Download the currently configured image. Its version selection stays the same. |
| Restart service | Recreate Open WebUI using its existing image selection. No newer release is discovered. |

Fresh installations keep the repository's tested defaults. Application updates
save exact tags in `GOOSE_IMAGE` or `OPEN_WEBUI_IMAGE` in the existing Git-ignored
`.env` file, with permissions `600`. API keys, provider settings, the browser
port and other entries are preserved. No tracked file is edited, so later
`aiw update` runs still work. Your application selections survive repository
updates until you explicitly choose another version.

The updater accepts stable version numbers, not floating `main`, `latest` or
development image tags. It does not claim that a newly published upstream
release has already been owner-tested with AI Workstation. The repository
default remains the explicit choice for that baseline.

If you previously exported `GOOSE_IMAGE` or `OPEN_WEBUI_IMAGE` in your shell,
unset that variable before updating. Compose shell overrides otherwise take
precedence over the persisted selection, so the updater reports this conflict.

## Open WebUI data and startup

The updater downloads the new image first, then stops Open WebUI and
backs up its entire `ai-workstation_open-webui-data` volume. Accounts, chats,
settings, uploads and knowledge data are retained in that same named volume
when the new container starts. Authentication, localhost binding and the
existing isolation settings come from the unchanged Compose definition.

A private backup directory is printed, for example:

```text
~/.local/state/ai-workstation/backups/open-webui/20261006T210000Z.ABC123/
```

It contains `data.tar.gz`, the protected pre-update `runtime.env`, and
`previous-image.txt` (the actual previous container image when one exists).
The environment snapshot can contain API keys; keep the directory private.
Backups are retained until you deliberately remove obsolete ones. Ensure there
is room for another copy of your data before a large update.

If backup creation fails, the new image selection is not saved. A previously
running service is restarted using its old container. After a successful
backup, `aiw` recreates Open WebUI and checks `/health`. It reports success only
when that endpoint responds. A fresh installation without an existing volume
has nothing to back up.

Refresh the Windows browser with **Ctrl+F5** after a successful update. You may
need to sign in again after container recreation.

## Goose sessions

Goose already uses a new isolated container for each session. Its update pulls
and saves the image for the **next** session. Active sessions keep their existing
container and are not stopped. Registered workspaces and the persistent
`ai-workstation_goose-home` volume remain in place. No workspace is mounted and
no Goose process is started by the updater.

Finish old sessions before starting sessions with a new release: both versions
would otherwise share the same persistent Goose state. Back up important
session history before a major Goose version change.

## Direct commands

These commands also work from any WSL directory and ask before applying updates:

```bash
aiw open-webui update
aiw goose update
```

For an exact release or the repository default:

```bash
aiw open-webui update v0.11.4
aiw goose update 1.53.0
aiw open-webui update --repository
aiw goose update --repository
```

`--yes` skips the interactive confirmation for scripts. Use `aiw open-webui
update --help` or `aiw goose update --help` to rediscover the syntax.

## If an update does not start

Read the reported error and open **Open WebUI -> Follow logs**, or run:

```bash
aiw open-webui logs
```

For an ordinary startup problem, correct the cause and use **Start service**.
The selected new image and pre-update backup are retained. The updater does
not automatically downgrade against a potentially migrated database.

Open WebUI database migrations can be one-way. Choosing an older image or the
repository default **does not restore the old database**. If the new database
is incompatible with the old release, restore a pre-update backup together
with its previous image. Keep the failed-upgrade volume until recovery is
verified.

For advanced recovery, the following recipe restores into a **new** volume,
leaving the original data intact. Run it from `~/ai-workstation` (the checkout
that owns `.env`), replace the backup path with the directory printed by `aiw`,
and use a new recovery-volume name if one already exists:

```bash
cd ~/ai-workstation
aiw open-webui down
aiw_backup_dir="$HOME/.local/state/ai-workstation/backups/open-webui/REPLACE-WITH-BACKUP"
aiw_previous_image="$(cat "$aiw_backup_dir/previous-image.txt")"
aiw_recovery_volume=ai-workstation_open-webui-recovery
docker volume create "$aiw_recovery_volume"
docker run --rm -i --network none --read-only --user 0 \
  --security-opt no-new-privileges:true \
  --mount "type=volume,src=$aiw_recovery_volume,dst=/data" \
  --entrypoint python "$aiw_previous_image" -c \
  'import sys, tarfile; tarfile.open(fileobj=sys.stdin.buffer, mode="r|gz").extractall("/data", filter="data")' \
  < "$aiw_backup_dir/data.tar.gz"
```

Create a local `compose/open-webui-recovery.override.yml` containing:

```yaml
volumes:
  open-webui-data:
    name: ai-workstation_open-webui-recovery
    external: true
```

Start the previous image with the restored volume:

```bash
OPEN_WEBUI_IMAGE="$aiw_previous_image" docker compose \
  --project-name ai-workstation-open-webui --env-file .env \
  --file compose/open-webui.yml \
  --file compose/open-webui-recovery.override.yml \
  up --detach --force-recreate open-webui
```

This is a temporary recovery service: normal `aiw` lifecycle commands use the
original volume, and the updater deliberately refuses an unexpected data mount.
Verify the recovered accounts/chats before deciding how to replace the original
volume. Do not delete either volume while diagnosing the failure. The snapshot
`runtime.env` is available to recover lost settings, but does not need to replace
later unrelated configuration changes.

## Docker working directories

`docker pull IMAGE` does not depend on a directory. Raw `docker compose`
commands need the right Compose files, `.env` and project identity. This
repository has separate Compose files rather than a default root
`compose.yml`. For example, the existing configured Open WebUI image can be
pulled and applied manually from the checkout root with:

```bash
cd ~/ai-workstation
docker compose --project-name ai-workstation-open-webui \
  --env-file .env --file compose/open-webui.yml pull open-webui
docker compose --project-name ai-workstation-open-webui \
  --env-file .env --file compose/open-webui.yml up --detach open-webui
```

That pair keeps the existing image selection and does not make the pre-update
backup described above. The **Update application** menu handles version
selection, backup and recreation as one operation.

Upstream references: [Open WebUI updates](https://docs.openwebui.com/getting-started/updating/),
[Open WebUI releases](https://github.com/open-webui/open-webui/releases),
[Goose releases](https://github.com/aaif-goose/goose/releases), and
[Docker Compose up](https://docs.docker.com/reference/cli/docker/compose/up/).
