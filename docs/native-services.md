# Native services and client identities

**Audience:** operators of AI Workstation on native Windows, WSL or Linux.
**Status:** PR #37 accepted (2026-11-03); existing real host services are **not** yet migrated.
**Key principle:** use the menu for everyday operation, native CLI for automation.

For the first native Windows **Strata + Dispatcher + Caddy + existing Open WebUI** supervised start and reboot-acceptance procedure, see [Native Windows host operations](native-host-operations.md) (#41). The old private PowerShell launcher is a rollback only after a separate ownership gate; this first pilot must not depend on it to start services.

For the three independent remote/local applications (Goose in WSL, Open WebUI in WSL, and an existing native-host Open WebUI), see the staged [gateway client migration and rollback runbook](gateway-client-migration.md) (#41). This guide separates **registering a new original key** from **activating S02 in Dispatcher and forwarding the key through Caddy**; neither happens automatically.

## Start

| Host | Entry point | Native supervisor |
| --- | --- | --- |
| Windows | `pwsh -File .\bootstrap\windows\Services.ps1` | Process Compose for Windows |
| WSL | `aiw` → Native services, or `aiw services ...` | Process Compose for Linux *inside WSL* |
| Linux | `aiw` → Native services, or `aiw services ...` | Process Compose for Linux |

The Windows menu is printed **once**. Subsequent actions have clear
`--- Action N ---` and `--- End of action N ---` boundaries, so the
console keeps a readable history without continually repeating the menu.
Enter **`?`** whenever you want to see it again; **`q`** exits.

Process Compose owns only **native host processes**. Docker Compose remains
the independent manager for containerized applications, including agents.
AI Workstation offers entry points; it does not invent another dashboard,
second process registry, or MCP process-control dependency.

## Concepts (four different things)

| Term | Meaning |
| --- | --- |
| **Client ID** | Operator-chosen, unique **label for one application/provider connection**. Not a computer, OS, or human user |
| **Original API key** | The secret that an application sends to the Dispatcher to authenticate |
| **Protected secret** | Original key stored locally (Windows DPAPI, Linux permissions 0600) |
| **S02 digest** | SHA-256 hash of the key, used by the Dispatcher to verify incoming requests |

**Names are not preconfigured.** Examples such as `agent-project` and
`chat-client` are only suggestions. The same installation can run on
any combination of machines; choose identifiers that make sense to you.
The exact labels appear in the Dispatcher's
`metrics_proxy_requests.client_id` column after S02 is activated.

## Where does each thing live?

The first initialization creates a **private, host-local directory**:

| Host | Default path |
| --- | --- |
| Windows | `%LOCALAPPDATA%\AIWorkstation\services\` |
| Linux / WSL | `~/.config/ai-workstation/services/` |

| File | Purpose |
| --- | --- |
| `services.yaml` | Editable client IDs and policies; points to the native project |
| `process-compose.yaml` | **Sole definition** of native processes, commands and dependencies |
| `secrets/ID.dpapi` or `secrets/ID.token` | Encrypted/protected **original** client credentials |
| `clients.json` | Generated S02 client list containing **hashes only** |
| `secrets/process-compose.api-token` | Private local supervisor management credential |

**`clients.json` is NOT a backup of usable API keys.** Copying it into
a password manager does not let you recover client secrets.

### Register a client and save the original key

1. Use **menu 10**, enter a name of your choice. A new independent key
   is generated automatically and protected locally; it is **not printed**.
2. Use **menu 11** to see the registered names and their purposes.
3. Use **menu 14** to select the correct client **by number**, not by
   remembering or retyping a byte-exact name. Confirm clipboard access.
4. Paste the key into the **password/secret field of your preferred
   password manager** as a separate credential entry with the client ID
   as its title. Repeat once for each independent client. Afterwards,
   clear the clipboard and its history if enabled; Windows clipboard
   history and synchronization are potential secret exposure paths.
5. Use **menu 12** to generate `clients.json`. This is the file the
   Dispatcher will later load on explicit activation; it is not deployed
   automatically. Configure each application with **its own original
   key** retrieved from your password manager.

For Windows, menu **16** renames an identity after **numbered selection**
and preserves the encrypted original key; regenerate `clients.json` with
12 afterwards. For Linux/WSL, the corresponding CLI is
`aiw services client rename OLD NEW`.

### Existing/shared credentials: why are they listed?

**Menu 13** imports an existing DPAPI credential under an operator-chosen
ID. It is retained **only to keep existing application access working
during an authentication migration**. It is **not** a newly generated
individual key, and it should **not** be distributed to additional apps.
Menu 11 distinguishes imported shared keys from fresh client keys.

Earlier registrations made before this distinction was introduced
show **`older key / origin unknown`** rather than being guessed.
Menu 14 warns before copying such a key: confirm it is truly an
individual client credential. Newly imported keys are not offered for
transfer; create new independent clients via menu 10 instead.

Importing or creating a key, renaming an ID, and generating hashes
**does not change the running Dispatcher or reverse proxy**.
Activation and restart are separate, explicitly reviewed operations.

## Platform-specific supervisor lifetime (not two supervisors)

The Process Compose v1.124.0 source **intentionally omits** the
`--detached` / `-D` flags on Windows, although the generic upstream CLI
documentation displays them. [Upstream Windows source](https://github.com/F1bonacc1/process-compose/blob/v1.124.0/src/cmd/project_runner_windows.go)
explicitly rejects detached operation; its
[CLI initialization](https://github.com/F1bonacc1/process-compose/blob/v1.124.0/src/cmd/up.go)
only registers the flag on non-Windows systems.

AI Workstation therefore starts **native Windows Process Compose in its
own headless OS process** with `up --keep-project --tui=false`. The
supervisor, **not AI Workstation**, manages the configured native child
processes. The host-private runtime directory contains a PID, executable
path and Windows process creation-time ownership record, plus a startup
diagnostic log. Restart/start/stop/down and interactive attach refuse
to control unknown/replaced Windows processes. A occupied management port
without a matching owned instance is **not adopted**.

Under WSL/native Linux, Process Compose's own `up --detached` mode is
used. Both platforms keep the same YAML, port and commands. Menu **6
(TUI)** connects to the *existing* supervisor with `attach`; it never
starts a second supervisor. Menu **8 (Stop)** shuts down only the
AI Workstation-owned test project on Windows.

The isolated `aiw-smoke` fixture ends quickly, so `--keep-project`
keeps the management API running until you explicitly choose Stop.
Status/logs will still be accessible after the harmless `echo` exits.

The upstream `PROC_COMP_CONFIG` variable points at the existing private
AI Workstation configuration directory, suppressing its otherwise
misleading debug messages about missing global config directories.

## Quick operator test (no production takeover)

In your Windows **review-branch checkout**, run the native menu; an
existing checkout can be refreshed with `git pull --ff-only`.
The menu is not itself the Process Compose project; selecting numbers
operates the native CLI.

| Step | Menu | Expected result |
| --- | --- | --- |
| Prepare | 2 | Initializes only if not already initialized; refuses overwrites |
| Install | 3 | Installs pinned, SHA-256-verified native Process Compose |
| Verify | 4 | Prints `Validated 1 configured processes from 2 files` and clear success confirmation |
| Inspect | 1 | Reports the actual private host-local paths |
| Register | 10, 11, 14, 12 | Add one test identity, select by **number**, save original key, render hash list |

**Optional isolated process smoke:** The initial
`process-compose.yaml` has a harmless `aiw-smoke` command initially
set to `disabled: true`. Change **only that setting** to `false`,
then choose **4 (validate) → 7 (start) → 5 (status) → 9 (logs) →
8 (stop)**. The command is a short `echo`; a completed process is expected
but the **supervisor remains available** for status and logs until Stop.
Look for `aiw-process-compose-smoke` in the logs. Restore
`disabled: true` afterwards. The existing processes on the host
are **never** adopted or stopped by this test.

The published v1.124.0 Linux binary reports a Go 1.27.0 build, below
the Go 1.27.2 patch level for October 2026 `html/template` issues.
**This is not proof of an exploitable Process Compose code path.**
AI Workstation therefore prevents production native-service starts
until a reviewed patched binary is adopted. The isolated test fixture
and non-mutating validation remain available. Keep the management API
on loopback and do not enable its MCP control endpoint for agents.

## Reference CLI (optional)

Windows native CLI:

```powershell
.\bootstrap\windows\Services.ps1 client list
.\bootstrap\windows\Services.ps1 client add agent-project --policy passthrough
.\bootstrap\windows\Services.ps1 client rename agent-project agent-development
.\bootstrap\windows\Services.ps1 client render
.\bootstrap\windows\Services.ps1 check
```

WSL or native Linux:

```bash
aiw services client list
aiw services client add agent-project --policy passthrough
aiw services check
```

Windows menu 14 is preferred for transferring individual keys; the
direct `client reveal ID` CLI displays a raw secret in the terminal,
so use it only with deliberate safeguards.

The current reverse proxy may still check one existing gateway key.
Before **new client credentials** are activated, configure the proxy
to preserve the Authorization header exclusively to the S02-authenticated
Dispatcher; maintain authorization on any separate direct inference
fallback. Keep an existing shared key **only for migration**, and verify
per-client 200/401, actual agent tool calls, and
`metrics_proxy_requests.client_id` before removing the shared key.
Do not let Process Compose and an existing script or systemd unit
manage the same service at once.

**Other tasks:** multi-directory agent workspace mounts are tracked
in [Issue #38](https://github.com/SomeSunlight/ai-workstation/issues/38);
optional additional native-host agent containers are deferred and tracked in
[Issue #39](https://github.com/SomeSunlight/ai-workstation/issues/39).
