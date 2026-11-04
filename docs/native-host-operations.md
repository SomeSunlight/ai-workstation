# Native Windows AI service host — Strata + Dispatcher + Caddy + Open WebUI (#41)

**Review candidate; live adoption is blocked until the security/owner gates below pass.**

The **first useful host acceptance test** must run all four native services under **AI Workstation + one Process Compose supervisor**. After a Windows restart, opening AI Workstation and selecting **Start** must restore Caddy → Dispatcher → Strata, without executing the previous Caddy-folder PowerShell starter or manually launching any of those services. This is **operator-initiated after reboot**, not automatic Windows boot startup. The old script stays as a rollback only and must never start a second copy of the same processes.

AI Workstation installs/configures and presents the menu; Process Compose is the only live native process supervisor. The WSL Goose/Open WebUI containers remain Docker Compose-owned. The existing native-host Open WebUI instance is **also supervised by Process Compose**, using its existing executable and DATA_DIR without copying, resetting or duplicating its database. It receives a separate Dispatcher client key as described in the [identity runbook](gateway-client-migration.md).

## Before changing anything

Keep private backups of the working PowerShell script, Caddyfile, Strata and Dispatcher config, model locations, encrypted keys and the existing Open WebUI data. Privately inventory the exact executable paths, start argument arrays, working directories, ports and DPAPI credential references. **Do not copy personal details or tokens into GitHub**.

The central version manifest currently has **production_adoption_blocked: true** because the pinned Process Compose build requires a security/toolchain review. **Never bypass that guard.** A verified patched binary plus real Windows child-process termination tests are mandatory before starting these actual services. AIW can prepare and validate their private configuration before that release gate is cleared.

## One-time native Windows host setup

From the Windows checkout, open the **native** menu in PowerShell 7.4+:

    .\aiw

To enable just `aiw` from any native Windows directory, run
`.\aiw register` once, then open a **new PowerShell session**. This
user-scoped command is unrelated to the WSL/Linux `aiw` executable.
Registration does not start, stop or reconfigure any service.

1. Choose **2 Initialize**, and **3 Install** if Process Compose is not installed. This initializes the private service directory and installs the currently pinned verified Process Compose executable; it does not install the four applications yet.
2. Choose **17 Host setup**. This creates a private, initially disabled four-service JSON template under %LOCALAPPDATA%\AIWorkstation\services\native-host.json, refusing overwrite. The JSON is the private input for rendering a Process Compose project.
3. Open this private file with an editor. For **strata**, **dispatcher**, **caddy** and optional **open-webui**, fill in the actual *absolute* executable path, working directory, and **arguments array** (one native argument per JSON element, same order as the existing working command). For Dispatcher, the executable may be a local uv.exe with arguments selecting the existing Python checkout and Strata attach config, or a reviewed S03 attach launcher. **Do not assume a Caddy/Strata/WebUI startup script also starts Dispatcher**. A legacy S03 launcher might regenerate only the shared `home-gateway` client identity; individual S02 activation is a separate migration. Use real values from the working startup, not generic guesses.
4. Declare each service's **listen_ports** (Strata commonly 8080, Dispatcher commonly 8001, Caddy's actual HTTPS and optional HTTP redirect port, native WebUI commonly 3000). Keep secrets out of arguments. The **environment** mapping is for *nonsecret* values such as a path to the S02 client digest file. Use **secret_environment** to map credential environment variable names to existing absolute Windows **.dpapi** encrypted files; they are decrypted only by the native child under the correct Windows user. Optional **required_paths** lists important input files and persistent directories (such as the existing WebUI data root) which must exist before a real start.
5. Set a **readiness** HTTP(S) URL, expected HTTP status and optional protected bearer reference. Strata and Dispatcher model endpoints normally return **200 with authorized credentials**; a deliberately unauthorized request to protected Caddy may correctly return **401**. AIW never disables certificate checks. A real response check is stronger than PID/port alone.
6. Keep **enabled: false** until the approved live test. Choose **18 Render host**; AIW generates native Process Compose definitions and guarded PowerShell launch/health adapters with startup dependencies **Strata → Dispatcher → Caddy → Open WebUI**. Nothing is started. After changing JSON, render again while the supervisor is stopped; a source fingerprint blocks stale projects.
7. Choose **4 Validate** for the native Process Compose configuration dry-run. Choose **19 Host preflight** to check declared loopback ports are free; while the old services run, collision refusal is an *expected* safe result, not a reason to kill unknown processes.

The rendered YAML does not contain raw tokens. Only one Process Compose instance can own all four selected services. Direct edits to generated commands are unsupported; change the private host input and render again while stopped. The upstream product's AIW native service CLI remains available for scripting.

## Owner-approved first full-stack test and reboot check

1. Review the actual private launch commands and process/port ownership, preserve a tested rollback, and clear the Process Compose release-security gate only after a patched and checksum-verified build plus Windows child-tree tests.
2. At an explicitly agreed service-cutover moment, stop the *existing owner-controlled* Strata/Dispatcher/Caddy/Open WebUI processes using the verified previous procedure. **Do not blindly stop processes based only on their port numbers.** Never run the previous script concurrently.
3. In the private native-host JSON set the four **enabled** flags to true, choose **18 Render host**, then **4 Validate** and **19 Host preflight**. All declared ports must be free.
4. Choose **7 Start**. AI Workstation starts one headless supervisor; Process Compose launches Strata, waits for its authorized HTTP readiness, then Dispatcher, then Caddy, then native Open WebUI. The old script is not invoked. Native Open WebUI must keep its existing data directory and loopback-only port.
5. Choose **5 Status**, **9 Logs** and **6 TUI** to inspect and monitor the four individually. Verify negative 401 requests, authorized model discovery, one small real inference, streaming, Caddy's direct-Strata protected fallback, and SQLite request/client identity audit.
6. Choose **8 Stop** and verify all *owned* child processes exited and relinquished their ports. A Windows child that survives Stop is a stop condition: do not start the old script until the orphaned child ownership is safely resolved.
7. Reboot Windows normally. Open AI Workstation, choose **7 Start** and **5 Status**. The full native inference chain should return with no dependency on the previous script. Automatic boot-time service startup is optional future work, not assumed.
8. Independently migrate the three application client keys (WSL Goose, WSL Open WebUI, native-host Open WebUI) with the [client identity runbook](gateway-client-migration.md), preserving the old shared identity until all three are proven in Dispatcher SQLite.

## Current limitations

This review branch can render and dry-run a four-service project but has **not** installed Caddy/Strata/Dispatcher on a clean native host, imported the owner's private existing process commands, qualified the Process Compose patched binary, or passed a real Speedy run/stop/reboot test. **No production service startup is yet authorized.** The original private starter remains the working fallback until the owner explicitly approves the completed migration.
