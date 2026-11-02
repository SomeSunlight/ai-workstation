# Native services and named Dispatcher clients — operator guide

> Review PR #37: opt-in preparation and authenticated client onboarding, **not**
> a cutover of the currently running Speedy services. Host acceptance follows.

## One architecture on all hosts

| Host | Supervisor for native processes | Operator entry |
| --- | --- | --- |
| Speedy Windows | Native Process Compose Windows executable | PowerShell 7: bootstrap/windows/Services.ps1 (numbered menu) |
| Laptop WSL | Native Linux Process Compose inside WSL | aiw → Native services; or aiw services COMMAND |
| Future native Linux | Same Linux binary and AIW command | aiw → Native services; or aiw services COMMAND |

There is no Windows/WSL process bridging. Windows manages native Windows
programs, WSL manages its own Linux processes, and native Linux runs the
same Linux code. The actual native Ubuntu installer remains unproven (#33).

Docker Compose stays the sole owner of Goose, containerized Open WebUI
and a future separately containerized Hermes Agent. Their existing
AI Workstation entrypoints remain native. No combined TUI, no double owner.

## One private host configuration directory

* Speedy Windows: %LOCALAPPDATA%\AIWorkstation\services\
* WSL / native Linux: ~/.config/ai-workstation/services/

Only two human-editable files, **without duplicated process definitions**:

* services.yaml: AI Workstation's named inference client identities, S02 policies
  and the Process Compose project filename/management port.
* process-compose.yaml: the **native, sole** process definitions including commands,
  readiness, dependencies and shutdown. Add a new native service **only here**.

Other files are generated/private, not edited independently:

* secrets/: Windows client keys protected with per-user DPAPI; Linux keys
  mode 0600. A local-only Process Compose management token is also here.
* clients.json: generated **hash-only** Dispatcher S02 schema. Point
  DISPATCHER_CLIENT_CONFIG here during an explicitly approved host migration.

Initialization creates a **disabled harmless smoke process** and never starts
Strata, Caddy, Dispatcher, Open WebUI or any background service.

## Operator commands

On Windows run the numbered menu with:

    pwsh -File .\bootstrap\windows\Services.ps1

Or use the same verbs as on Linux/WSL via its arguments. On Laptop/WSL:

    aiw services init             # once per host
    aiw services install          # opt-in native download, pinned SHA-256
    aiw services where            # locate editable private files
    aiw services check            # Process Compose dry-run, NO start
    aiw services up               # explicit detached native start
    aiw services status           # direct CLI, local API
    aiw services tui              # native Process Compose UI
    aiw services logs
    aiw services restart NAME
    aiw services down

The first project contains ONLY a disabled fixture. Because the current
release was built with a vulnerable Go toolchain (see below),
AIW **refuses to start production service definitions**; only the harmless
aiw-smoke pilot may be started. A later patched binary and real host gate
must verify Process Compose child ownership, unknown port owners,
graceful stop, health probes and safe restart before any cutover.

Process Compose CLI works with loopback management on **127.0.0.1:19011**,
not Strata port 8080. The management API uses a local protected token file.
MCP process control is not enabled; no public management endpoint or
unrestricted LLM tool access. Up disables automatic .env loading. Installing
Process Compose does not configure host autostart, Caddy or Windows services.

## Named inference clients

On the host where the Dispatcher operates (Speedy Windows) add clients via
the numbered menu, or call:

    pwsh -File .\bootstrap\windows\Services.ps1 client add goose-laptop --policy passthrough
    pwsh -File .\bootstrap\windows\Services.ps1 client add webui-laptop --policy passthrough
    pwsh -File .\bootstrap\windows\Services.ps1 client add goose-speedy --policy passthrough
    pwsh -File .\bootstrap\windows\Services.ps1 client add webui-speedy --policy passthrough
    pwsh -File .\bootstrap\windows\Services.ps1 client add hermes-speedy --policy passthrough
    pwsh -File .\bootstrap\windows\Services.ps1 client list
    pwsh -File .\bootstrap\windows\Services.ps1 client render

**Before migrating the currently working clients**, choose option 13 in the
native Windows services menu, or explicitly import the existing DPAPI
credential as home-gateway (use your *actual* protected key file path):

    pwsh -File .\bootstrap\windows\Services.ps1 client import-dpapi home-gateway --from-file C:\Caddy\speedy-api-key.dpapi --policy passthrough

This reads and reuses the original encrypted key under the same Windows
account, without revealing plaintext, modifying the original DPAPI file
or restarting any service. Its SHA-256 digest is included in clients.json
alongside the new independent client credentials. **Do not map the same
secret under two different client IDs**; S02 deliberately rejects
duplicate digests, because that would make attribution ambiguous.

Each name is the actual S02 ID, later visible in the Dispatcher
metrics_proxy_requests.client_id column. These are **technical applications**,
not human users. Your friend needs only an ordinary Open WebUI user account,
not another server or a personal Dispatcher identity.

The private credential never appears in YAML or clients.json; Windows
stores a DPAPI-encrypted value, and Linux uses strict filesystem permissions.
For a one-time secure transfer to a specific client, explicitly use
the **client reveal NAME** operation, which DOES display the token on the
terminal. Store it directly in that client app's protected provider settings
through a trusted credential manager; never paste it in Git, screenshots,
logs or this chat. S02 loads all identities at startup: after onboarding,
render the JSON and **explicitly restart Dispatcher** at the accepted
operational handoff. Merely adding a manifest entry does not modify a live
server.

Revocation is similarly explicit: client remove NAME, render, and restart.
An old encrypted secret is retained locally until reviewed deletion, so
no accidental irreversible credential deletion is performed.

## One-time Caddy / multi-client migration (not executed by this PR)

The existing Caddy matcher expects the **one** legacy SPEEDY_API_KEY for
both /v1 and /strata/v1. Before independent client tokens can work:

1. Keep that exact gateway-key check on the **direct /strata/v1** fallback.
2. For **/v1**, forward the Authorization header exclusively to the S02
   Dispatcher on loopback 8001, and let S02 authenticate **all** clients.
   Do **not** route an anonymous /v1 request to legacy Dispatcher or Strata.
3. Preserve the current home-gateway entry and key during the migration,
   until Goose/Open WebUI have moved to their new identities. The new
   hash generator does not import the existing key automatically.
4. Verify unauthorized 401, separately authenticated client 200, wrong
   key 401, direct fallback, SSE, Goose tools, UI functionality and the
   new exact SQLite client names before accepting a cutover.
5. Keep the owner's already working Start-SpeedyAI.ps1 as fallback and
   do not make Process Compose compete for any of its running services.

This is a **separately owner-reviewed, once-only gateway trust-boundary
change**, not a side effect of running client add/render or services init.
The generated private S02 file and DPAPI secrets are never committed.

## Choice and security of Process Compose

**Decision:** Process Compose is the native-host supervisor (not an
AI Workstation homegrown manager). Version pinned **v1.124.0, published
2026-10-27**, installed only on demand with official release archive SHA-256
verification. No PATH-wide replacement. AIW reuses its native CLI/TUI.
**Security hold (confirmed in CI on 2026-11-02):** The official
Linux AMD64 v1.124.0 binary reports **go1.27.0** in its Go build metadata.
Two October 2026 html/template advisories (CVE-2026-94448,
CVE-2026-97030) affect this Go version and were patched in **Go 1.27.2**.
This is a **toolchain exposure**, not proof that Process Compose has a
reachable exploit. The Windows binary's Go build was not independently
inspected. Until a patched release/rebuild and reachability review are
accepted, the AIW CLI **fails closed on production native process starts**
and permits only its disabled/harmless aiw-smoke fixture for runtime
experiments. Non-mutating config validation and S02 client onboarding
remain available. Update the centrally pinned manifest **only after**
actual binary Go build/version proof; keep the production hold until then.
Go build metadata can be inspected with 'go version -m PATH_TO_BINARY'
when Go is installed.

## Scope boundaries and new applications

* New native service: edit the single **process-compose.yaml** and validate.
* New containerized app: native Docker Compose and its AIW entrypoint.
  Hermes runs in its **own Docker container** with dedicated permissions.
* New Open WebUI human account: use Open WebUI user/role management,
  no additional backend container or personal model server required.
* Multiple directories for one Goose session: not yet supported.
  [Issue #38](https://github.com/SomeSunlight/ai-workstation/issues/38)
  tracks explicit extra directory mounts (read-only by default).

For corporate-managed laptops, personal VPN or altered routing requires
authorization from the employer's IT/security policy; a phone hotspot is
not a workaround for that policy, nor does tethering automatically forward
the phone's VPN. Running lengthy agent work on Speedy itself and accessing
its UI remotely avoids dependence on a travelling laptop staying awake.
