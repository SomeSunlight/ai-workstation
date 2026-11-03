# Gateway and client-identity migration — operator runbook (#41)

**Status: proposed and unactivated.** This is a review guide, **not** a command to change running services. Follow [native services and client identities](native-services.md) for the current AI Workstation menu. Keep the existing, working gateway and private starter script until every owner acceptance gate passes. No secrets, personal host names, private gateway URLs or real instance paths belong in the public repository.

## The small deployment we are building

| Location | Already-existing application/service | Owner and intended connection |
| --- | --- | --- |
| Native service host (Windows) | Caddy HTTPS ingress | Private host configuration now; Process Compose **only after an approved handoff** |
| Native service host (Windows) | Llama Dispatcher (S02 + S03 attached Strata) | Caddy routes `/v1` to loopback Dispatcher; independent bearer identities |
| Native service host (Windows) | Strata | Native loopback inference, independently owned until approved; Dispatcher alone supplies Strata's separate native credential |
| Native service host (Windows) | Open WebUI | **Preserve its executable, venv and data directory**; optionally have the native AIW/Process Compose supervisor start it as a fourth process; point its OpenAI-compatible API connection at Dispatcher with its own S02 key |
| Laptop/WSL | Goose (Docker Compose) | Existing AIW Goose; connect to **HTTPS Caddy `/v1`**, its own S02 key |
| Laptop/WSL | Open WebUI (Docker Compose) | Existing AIW Open WebUI; connect to **HTTPS Caddy `/v1`**, another S02 key |

No native-host Goose/Hermes containers, no replacement Open WebUI instance and no remote Process Compose control API are required. The existing Windows WebUI may be supervised as a **fourth** native process, with unchanged persistent DATA_DIR. This is a reusable Windows/WSL/Linux product: actual device names, domains, credential-provider choices and paths are private operator settings.

## Important: the keys are distinct

An **S02 original key** is the random token issued to one application/provider connection. The AIW Windows service menu stores it protected with DPAPI. AIW **menu 14 (Copy key)** retrieves that *exact original*, which the application sends in `Authorization: Bearer <original-token>` when calling Dispatcher. **Menu 12 (Render S02)** creates `clients.json` containing only SHA-256 digests: that file is for the Dispatcher, **never** the API Key field in Open WebUI. Do not print, paste into Git, share in tickets, or put the key in a URL or command argument.

Example operator-chosen client IDs (no defaults are preinstalled):

| Example ID | One connection | Suggested policy |
| --- | --- | --- |
| `goose-wsl` | WSL Goose | `passthrough` (the current AIW menu 10 default) |
| `webui-wsl` | WSL Open WebUI | `passthrough` (the current menu 10 default) |
| `webui-host` | Native host Open WebUI | `passthrough` (the current menu 10 default) |
| `home-gateway` | Existing shared legacy key, temporary | Preserve until all real clients and fallback are verified; **do not issue it to new applications** |

A client ID identifies the **application connection**, not the user sitting in front of Open WebUI. Multiple human users of one Open WebUI instance share that instance's Dispatcher client ID; WebUI's own user/audit system is responsible for finer attribution.

## Fresh-install contract (versus existing installation adoption)

AI Workstation must ultimately support **both** paths under #41. This draft documents the migration but does **not yet implement** this contract:

- **Fresh supported Windows host:** guided, repeatable provisioning of pinned/verified Caddy, native Llama Dispatcher, Strata and Process Compose, plus private configuration, readiness validation and controlled service lifecycle. Verify the actual Strata distribution/install route and any separate licensing or GPU prerequisites before promising automated binary installation.
- **Existing Windows host:** discover exact installed program/configuration and process ownership, then attach/adopt safely without uninstalling, overwriting private files, changing ports or launching duplicate processes.
- **Both:** no personal domains, native keys, models or user databases in Git; explain required operator-provided TLS/DNS configuration, model weights, native GPU drivers and secrets. Have a safe rollback and explicit approval before re-owning running processes.

Installing AI Workstation should remain the **operator's primary entry point** on a new host; installing Caddy/Dispatcher/Strata by hand must not silently be treated as the generic prerequisite.
## Phase A — preparation that can be done **without changing live traffic**

1. Confirm the existing native Caddy → Dispatcher → Strata path and the existing WSL Goose/Open WebUI route still work. Record current process owner, executable path, PID + creation time, ports, private Caddy configuration path, Dispatcher instance/config + SQLite location, Strata endpoint, WebUI data directories, old shared credential reference and the direct-Strata fallback. **Keep those details private**; a redacted checklist is sufficient for review. Do not stop, reload or replace any process during inventory.
2. On the Windows service host, open `pwsh -File .\bootstrap\windows\Services.ps1`. Select **11** to inspect existing registrations; **10** three times to add three uniquely named clients. This changes only the private AIW identity registry; it does **not** configure Caddy, restart Dispatcher or activate a token.
3. For each individual client, select **14**, choose its **number**, and explicitly confirm copy. Put the *original* key in a protected password manager entry identified by that client's ID; convey only the relevant original to the laptop using a trusted channel. Handle Windows clipboard history/sync appropriately; avoid screenshots and terminal transcripts containing tokens.
4. Choose **12** to render the private, hash-only `clients.json`. Check the names/policies with **11**. Preserve any imported `home-gateway` key as a **transitional** identity, not as the common key for new clients.
5. **Stop here if the running Dispatcher does not yet load this exact file**, or if the current Caddy `/v1` route still consumes/replaces the legacy bearer instead of forwarding the client's original bearer to Dispatcher. The new keys must not be installed into active clients prematurely.

The native service manager is already capable of creating/copying keys. The missing piece is a separately approved **activation** and verified Caddy trust boundary, not another password generator.

## Phase B — reviewed, reversible S02 gateway activation (not yet performed)

1. Back up the **private configuration sources** and describe their owners and restoration procedure; do not copy sensitive settings into Git. Preserve the current working `home-gateway` credential, native Strata fallback and the running WebUI databases. Coordinate any Dispatcher restart with the operator; do not copy a live SQLite database while ignoring WAL state.
2. Stage a private Dispatcher S02 client file by referencing the generated `clients.json`, and verify that the **process that launches Dispatcher** supplies `DISPATCHER_CLIENT_CONFIG` pointing to it. Its separate Strata credential still comes from the private Strata attach environment; do not treat S02 client tokens as native Strata credentials.
3. Privately stage and validate Caddy's `/v1` reverse proxy to the S02-authenticated loopback Dispatcher, retaining the incoming bearer **unchanged**. Do not have Caddy substitute an upstream shared token, accept untrusted `X-Client-Id` headers as identity, or send those application tokens directly to Strata. Keep the independent `/strata/v1` fallback protected by its **own** existing authorization rule. Preserve TLS and the existing Open WebUI route.
4. Verify configuration diff, process/port ownership, readiness and rollback before a controlled Caddy reload and Dispatcher restart. **Owner approval is required for this traffic-affecting step.** Neither installing AIW nor rendering clients automatically performs the cutover.
5. Verify the protected route rejects both **missing** and **incorrect** bearer tokens (HTTP 401), and that a valid individual token returns the expected model list and inference. Use private tools or password-manager-backed API client fields instead of secrets in shell history or `curl` arguments.

## Phase C — configure each application after Phase B passes

**Native host Open WebUI:** in its existing instance, go to **Settings → Admin → Connections → Manage OpenAI API Connections → Add Connection** (or edit the existing connection with a preserved rollback setting). Select **OpenAI-compatible / Chat Completions**, enter the gateway base URL ending in `/v1`, and paste the **original** for `webui-host` into **API Key**. If it truly runs as a **native process on the same Windows host**, `http://127.0.0.1:8001/v1` is also a possible *private* direct-Dispatcher base URL; first verify the actual loopback port and authorization. If Open WebUI is itself in Docker, its `localhost` is not the Windows host: use a verified host-reachable address instead. Keep the original connection available for rollback until the new one passes model discovery and streaming.

**Laptop/WSL Open WebUI:** follow the same OpenAI-compatible connection procedure but point to the existing protected HTTPS Caddy `/v1` route and use the **different original** for `webui-wsl`. Docker's `localhost` denotes its own container, so do not point it at the remote Windows service's loopback address.

**Laptop/WSL Goose:** use the existing `aiw goose configure` native provider/model menu (and optionally `aiw goose check`). Configure its OpenAI-compatible endpoint as the same **protected HTTPS Caddy `/v1`** route, with the **different original** for `goose-wsl`. Do not alter a project workspace mount merely to change the inference endpoint. Goose session and tool traces remain in Goose's own persistent state, not in Dispatcher SQLite.

The Open WebUI *provider* API key is different from a WebUI **user** API key (the latter grants API access *to* Open WebUI and is not used for Dispatcher).

## Phase D — prove the separation and preserve rollback

1. From **each** of the three application connections, request model discovery, make one tiny actual chat completion, and test streaming. With Goose, test a small approved tool call and inspect the real Goose session. Keep the model/Strata load small and do not force simultaneous model loading.
2. In **the active Dispatcher instance's SQLite database** (a read-only connection), inspect:

   ```sql
   SELECT client_id, policy_mode, COUNT(*) AS requests
   FROM metrics_proxy_requests
   WHERE client_id IS NOT NULL
   GROUP BY client_id, policy_mode
   ORDER BY client_id, policy_mode;
   ```

   Expect separately named requests from **all three clients**. Verify appropriate 401 responses for an unknown or absent key. The Dispatcher records client identity and safe request telemetry, **not** Goose's file-by-file actions or a WebUI user's personal identity.
3. If any application fails, restore **its previous connection** and the existing gateway configuration/old key while investigating; do not revoke `home-gateway` until the entire old path and new clients have passed. Dispatcher configuration is read at startup: changes to digests take effect only after a controlled restart.
4. Only in a **separate owner-approved service-management step**, after checking patched Process Compose artifact checksums/security and real Windows process-tree shutdown, hand ownership of Caddy, Dispatcher, Strata and optional existing native Open WebUI from the old private start script to a **single** AIW/Process Compose supervisor. Never let two managers start or stop the same process. Retain the old private script as documented rollback; supervisor commands must refuse unknown PIDs/port owners.
5. When owner verification is complete, explicitly decide whether to retire `home-gateway`. Do not silently revoke existing access or expose management/Strata endpoints publicly.

## Stop conditions

**Do not proceed with live cutover** if Caddy's current behavior is unknown; if the active Dispatcher does not read the S02 digest file; if the legacy shared key or fallback would fail; if a process/port owner cannot be identified; or if the Process Compose production guard is still active. Registry preparation and writing this runbook do not count as activation.
