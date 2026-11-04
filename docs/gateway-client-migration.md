# Gateway and individual application identities — staged migration (#41)

**Audience:** Operators of AI Workstation on Windows, WSL and Linux.
**Goal:** three independent client API keys, one native Strata credential, and a
reversible transition away from the old shared gateway key — **before the first
real native service start**. General-purpose examples below are not device
defaults. Never commit operator paths, domain names, raw API keys, Caddyfiles
or database contents.

## What the keys actually do

| Connection | Suggested client ID | Secret goes to | URL |
| --- | --- | --- | --- |
| WSL Goose | `goose-wsl` | Goose's native OpenAI-compatible provider key | Existing protected Caddy HTTPS `/v1` |
| WSL Open WebUI | `webui-wsl` | Existing Open WebUI **Admin → Connections → OpenAI-compatible API Key** | Same protected Caddy HTTPS `/v1` |
| Native Windows Open WebUI | `webui-host` | Existing native WebUI **Admin → Connections → OpenAI-compatible API Key** | `http://127.0.0.1:8001/v1` (native host only) |
| Existing gateway token | `home-gateway` | **Transitional only**; preserve for working clients/rollback | Historical routes only |
| Native Strata API token | Not an S02 client | Dispatcher-to-Strata; existing protected direct fallback | `http://127.0.0.1:8080` only |

Every application gets one original random credential; Dispatcher receives the
**SHA-256 digest**, not the original. The three IDs identify application
connections — *not human users* of an Open WebUI instance. The native Strata token is **distinct from the three new S02
application tokens**. During migration, however, the imported transitional
`home-gateway` identity deliberately reuses the **old** Strata/Caddy
shared token, as the previous startup scripts did. Never issue that shared
token to a new client. The old key remains necessary for S03 attached
Strata and the protected `/strata/v1/*` fallback until independently
rotated in a future operation.

## Phase 1 — generate three independent tokens on the Windows host

Do this while Caddy, Dispatcher, Strata and native Open WebUI are stopped.
Open `aiw` → **Manage application access keys**. First choose **List
applications**. Create only missing IDs; creating an existing name fails
rather than rotating a working key.

Use **Create a separate API key for an application** three times, with
operator-chosen names for Goose in WSL, WebUI in WSL, and WebUI on the native
host (suggested names above). Use `passthrough` policy initially so the
Dispatcher does not silently override Strata's reasoning/model settings.

**Import the current shared gateway key for migration only:** use **Import
an OLD shared gateway key (migration only)**, supply a new registry ID
such as `home-gateway` and the absolute path to the **existing native
gateway *.dpapi file**. This imports a protected copy; it does not
create another independent key or rotate Strata's token. Skip it if that
registry ID is already present. Never distribute the imported shared key
to new applications.

For automation, the equivalent native Windows CLI is:

```powershell
aiw client list
# Execute each add only if this identity does not already exist:
aiw client add goose-wsl --policy passthrough
aiw client add webui-wsl --policy passthrough
aiw client add webui-host --policy passthrough
# Import legacy only if still absent, using the operator's actual DPAPI path:
aiw client import-dpapi home-gateway --from-file '<existing-gateway.dpapi>' --policy passthrough
aiw client render
```

Select **Prepare the Dispatcher key-verification file** (CLI:
`aiw client render`) after creating/importing. The resulting
`%LOCALAPPDATA%\AIWorkstation\services\clients.json` contains **only
one-way token hashes**, without the original credentials.

Use **Copy an application API key to the clipboard** for each *generated*
client, one at a time, and save each **original** in a separate password
manager entry or the correct application's protected provider settings. The
menu deliberately blocks copying imported shared credentials to new apps.
Do not screenshot or paste keys into chats, tickets, project YAML or shell
commands. Windows clipboard history/synchronization must be considered;
clear history if enabled after moving a key. Secrets must be transported
to other machines through a trusted, private channel; Git/AIW does not
silently sync DPAPI values to WSL.

**Stop condition:** the generated file must have the three unique client
IDs and (if preserving existing access) the transitional legacy ID. If
one is missing, do not proceed. A hash is never the API key for Goose/WebUI.

## Phase 2 — stage Dispatcher and Caddy while both are STOPPED

### Dispatcher: prevent replacement of the multi-client digest file

The normal S03 attached-Strata trial remains a separate instance from any
earlier managed-llama.cpp `serve --ensemble … --model-root …` setup.

The new standalone S03 starter from
[Dispatcher's S03 multi-client review PR](https://github.com/SomeSunlight/Llama_Dispatcher/pull/30)
accepts an explicit `-ClientConfig` or inherited
`DISPATCHER_CLIENT_CONFIG` environment variable. If provided, it
**validates and preserves** the external S02 digest registry. If it is
missing or invalid, startup fails; **it will not recreate a one-client
`home-gateway` file**. The historical one-client generator remains
only for invocations which specify no external config.

In native Windows `native-host.json`, edit the **dispatcher** service's
non-secret `environment` mapping:

```json
"environment": {
  "DISPATCHER_CLIENT_CONFIG": "C:\\Path\\To\\Private\\AIWorkstation\\services\\clients.json"
}
```

Use the actual full filename on **your** computer; no bearer token goes
into this mapping. Keep the existing S03 starter invocation/Strata
credential and real working directory. The approved native readiness
probe may still use the old imported key for the first HTTP 200 check.

**Avoid Windows JSON backslash mistakes:** optional local PowerShell
to update this property without manually escaping any path. Back up
your private file first and run only after verifying which AIW
installation/Windows account owns it:

```powershell
$dir = Join-Path $env:LOCALAPPDATA 'AIWorkstation\services'
$path = Join-Path $dir 'native-host.json'
$backup = Join-Path $dir 'native-host.before-S02.json'
if (Test-Path -LiteralPath $backup) { throw 'Backup already exists; inspect it first.' }
Copy-Item -LiteralPath $path -Destination $backup -ErrorAction Stop
$hostConfig = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
$hostConfig.services.dispatcher.environment.DISPATCHER_CLIENT_CONFIG =
    (Join-Path $dir 'clients.json')
$hostConfig | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $path -Encoding utf8
```

Under native AIW **Set up or change this computer**, use **View service
configuration summary → Check edited settings → Apply edited settings
for the next startup**. No application is started by those operations.
Do not run the old standalone S03 launcher concurrently with Process Compose.

### Caddy: let S02 authenticate /v1, preserve Strata's independent key

**Critical:** the *old* Caddy authentication matcher checks a single
gateway token for both `/v1/*` and `/strata/v1/*`. It would reject the
new Goose/WebUI keys before Dispatcher ever sees them. Simply adding
entries to `clients.json` does **not** fix this.

The new
[offline Caddy staging helper in Dispatcher PR #30](https://github.com/SomeSunlight/Llama_Dispatcher/pull/30)
strictly recognizes the reviewed S03 Caddy topology. It changes **only**:

- the old Caddy bearer matcher so it still protects `/strata/v1/*`,
  **not** Dispatcher `/v1/*`;
- the Dispatcher reverse proxy so it forwards the client's original
  `Authorization` header to Dispatcher S02 rather than stripping it.

Dispatcher must **independently return 401** to missing/invalid S02 keys;
this must be confirmed after the first Start. The direct-Strata fallback
retains the old Caddy bearer check. TLS, domain, WebUI routes, other
Caddy handlers and native Strata credential are not intentionally changed.

From the **reviewed Dispatcher checkout** on Windows, perform a
read-only preview first:

```powershell
./scripts/s03_caddy_s02_stage.ps1 -Caddyfile '<private-Caddyfile>'
```

If it recognizes your topology, stage while Caddy is stopped:

```powershell
./scripts/s03_caddy_s02_stage.ps1 -Caddyfile '<private-Caddyfile>' `
  -CaddyExe '<actual-caddy.exe>' -DpapiKeyFile '<existing-gateway.dpapi>' -Stage
```

This saves the untouched original as
`<private-Caddyfile>.s02-before-multiclient`, invokes the real Caddy
**offline config validator**, and **does not reload or start Caddy**.
On a failed validation the old file is restored. If it reports an
unknown topology, **do not bypass it or improvise an authorization
rule**: review that private Caddyfile first.

When still stopped, a reviewed rollback is:

```powershell
./scripts/s03_caddy_s02_stage.ps1 -Caddyfile '<private-Caddyfile>' `
  -CaddyExe '<actual-caddy.exe>' -DpapiKeyFile '<existing-gateway.dpapi>' `
  -Revert -Stage
```

This refuses to overwrite later operator edits that differ from the
exact expected staging result.

## Phase 3 — Start once, then configure and verify the actual applications

Some Open WebUI connections are saved **in their existing databases** and
take precedence over environment settings on subsequent starts. Therefore
there is no safe claim that setting a native `OPENAI_API_KEY` environment
variable alone will migrate an existing WebUI. **Do not reset persistent
configuration or edit the WebUI SQLite databases directly.**

1. With old script **not** running, verify native ports are free.
   In AIW **Run and monitor AI services → Start all enabled services**,
   request the live status/log monitor, and require Strata → S03 Dispatcher
   → Caddy → existing native Open WebUI readiness. If startup fails,
   inspect the owned logs; never run a second launcher.
2. Verify **locally** that Dispatcher `/v1/models` returns HTTP **401**
   without an S02 token and HTTP **200** with one of the new original
   keys. On Caddy HTTPS `/v1/models`, separately verify no key/invalid
   key receive **401**, and at least one new key receives **200**.
   The direct `/strata/v1/models` must still require the *old
   independent* bearer credential. Do not put tokens in URLs or scripts.
3. Open **existing native Windows Open WebUI**: **Admin → Connections
   → OpenAI-compatible**. Edit the existing provider rather than
   recreating the database. Use native loopback
   `http://127.0.0.1:8001/v1` and the **original** `webui-host` key.
   Save, discover the model alias, test one tiny completion. The key
   is an **OpenAI provider credential**, not a WebUI user API key.
4. In **existing WSL Open WebUI**, configure the OpenAI-compatible
   connection through its **Admin → Connections** settings using the
   Caddy **HTTPS /v1** endpoint and the different `webui-wsl`
   original key. Inside Docker, `localhost` does **not** mean the
   Windows native host. Preserve the WSL WebUI data volume.
5. On WSL, run `aiw goose configure` (native Goose configure
   inside its existing persistent volume). Select the same
   OpenAI-compatible Caddy HTTPS `/v1` endpoint and the separate
   `goose-wsl` original key; select a real Dispatcher model alias.
   Use `aiw goose check` and then an approved small Goose tool request.
   Do not overwrite a saved provider with unrelated cloud defaults.
6. For all three, request model discovery, one short chat completion,
   and verify streaming as appropriate. The active S03 Dispatcher
   SQLite database should record each separately:

   ```sql
   SELECT client_id, policy_mode, COUNT(*) AS requests
   FROM metrics_proxy_requests
   WHERE client_id IS NOT NULL
   GROUP BY client_id, policy_mode
   ORDER BY client_id, policy_mode;
   ```

   You should see three different IDs once requests from all
   three applications have arrived. No false attribution from
   headers, URL, User-Agent or Open WebUI human usernames.
7. Keep `home-gateway` until the old path and all new clients pass.
   Only remove a client or rotate a key in a separate deliberate
   step followed by a controlled Dispatcher restart. To roll back:
   stop only AIW-owned processes, verify all child ports/PIDs are
   released; restore the Caddyfile with the reviewed helper, restore
   previous WebUI/Goose connections, and then start the old launcher
   only when AIW no longer owns any process.

## Related: what this does not do automatically

- It **does not** transmit Windows DPAPI secrets to WSL/Linux, install
  or configure applications on an unavailable other computer, or modify
  a user's password manager; transfer the individual original keys
  securely and intentionally.
- It **does not** substitute application tokens for Strata's native API
  key, or remove the protected Caddy direct-Strata fallback.
- It **does not** make a globally approved production Process Compose
  release. The reviewed Windows-only pilot and full process-tree stop,
  reboot and rollback tests remain separately owner-gated under #41.
