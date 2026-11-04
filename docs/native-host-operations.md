# Native Windows AI service host: setup, operation and first test (#41)

AI Workstation is the entry point for native Windows inference services. You should
not have to know PowerShell script names, Process Compose syntax or internal
configuration-generator commands to use it.

**Current status:** This is a review candidate. Preparing, inspecting and
validating settings is supported. **The real four-service startup is still
blocked** by the Process Compose production-security gate until the patched
binary and Windows child-process shutdown are approved. Never disable that gate
merely to make a test pass.

## What does this installation run?

| Service | Role | Typical private listening port |
| --- | --- | --- |
| Strata | Loads the local model and answers inference requests | 8080 |
| Llama Dispatcher | Attaches to Strata; provides model aliases and application attribution | 8001 |
| Caddy | HTTPS gateway and access rules | 443 (possibly also 80) |
| Open WebUI | Existing native Windows chat web app, preserving its own data | 3000 |

Under AI Workstation, one Process Compose supervisor starts them in this order:
**Strata → Dispatcher → Caddy → Open WebUI**. It tracks status, logs and
readiness. This does **not** create a second WebUI installation or a new database.
WSL/Linux Goose and WebUI remain managed separately with Docker Compose.

The previous native PowerShell launcher stays as a rollback, **not** a second
concurrent process manager. After Windows reboots, the goal is to open AI
Workstation and select **Start all enabled services** — no old script required.
Automatic startup at Windows sign-in/boot is a different, optional feature.

## Open the Windows workbench

From the AI Workstation checkout, enter `.\aiw`. After one-time
`.\aiw register` and opening a new terminal, simply enter `aiw` from any
directory.

The workbench is divided into user tasks:

- **Run and monitor AI services:** start, see status, read logs, attach a
  full-screen monitor or stop. Start asks *beforehand* if the live monitor
  should open immediately afterward. The monitor attaches to the existing
  supervisor, rather than launching a duplicate.
- **Set up or change this computer:** first-time preparation; inspect,
  edit, check and apply the machine-local startup settings; check whether the
  old services still occupy the ports.
- **Manage application access keys:** create an original per-app key, copy it
  to the clipboard, list/rename registrations or prepare Dispatcher key hashes.
  These actions do not automatically activate the new keys in a running
  Dispatcher.
- **Help and explanations:** how the services connect, the key terminology,
  this guide and optional direct CLI commands.

The commands themselves remain English and host-neutral. No secret or personal
machine configuration is committed to Git.

## First-time setup

1. In `aiw` choose **Set up or change this computer → First-time preparation**.
   AI Workstation creates the private user configuration (if missing) and
   offers to install a checksum-verified Process Compose binary. Existing
   configuration and secret files are not overwritten.
2. Choose **View service configuration summary** to see which services are
   configured and whether they are intended to start.
3. **Now edit the private `native-host.json` file.** Select **Edit service
   startup settings**; it opens in Notepad, or open it in your preferred editor
   from `%LOCALAPPDATA%\AIWorkstation\services\native-host.json`.

   This file describes **how to start each service**; you edit it once for
   your machine, not on every start. Inside the `services` object there is
   one section for Strata, Dispatcher, Caddy and (optionally) native Open WebUI:

   - **`executable` and `working_directory`:** full Windows path to the program
     that must run, and the directory in which it starts. The executable
     must be a real file, not an unqualified name such as `run-model.bat`.

     - **`.exe`:** executable directly (for example `C:\Apps\caddy\caddy.exe`).
     - **`.bat` / `.cmd`:** launch through `C:\Windows\System32\cmd.exe`,
       with `"/d", "/c", "C:\\Apps\\models\\run-model.bat"` in `arguments`.
       `/c` executes the batch file and waits; it allows supervision to
       observe when that process exits. Avoid `/k`, which leaves an
       unrelated interactive command prompt running.
     - **`.ps1`:** use the full path to `pwsh.exe` (PowerShell 7) as executable,
       with `-NoProfile`, `-NonInteractive`, `-File` and the script path
       as **separate items** in `arguments`.
     - **Python/uv:** use the actual `uv.exe` and an argument array matching
       the approved working invocation. No shell is necessary to run `uv`.
   - **`arguments`:** a JSON list of strings; **one argument per element**.
     There is no need to add shell quoting around each element. Flags and
     their values are separate entries. Never copy a whole command line
     into one array item.
   - **`listen_ports`:** Windows TCP ports the process owns. The preflight
     rejects occupied listening ports (including non-loopback/IPv6 listeners)
     before a new supervisor starts. Include every actual Caddy listener.
   - **`environment`:** ordinary environment variables such as WebUI's
     existing `DATA_DIR`. **`secret_environment`:** secret environment
     variables mapped to **existing absolute Windows `.dpapi` files**,
     rather than plaintext tokens. The native child decrypts these only
     at launch using the Windows account that originally protected them.
   - **`required_paths`:** important startup inputs that must already
     exist — for example the Caddyfile, Strata configuration and existing
     WebUI data directory. AI Workstation refuses to start an enabled
     Open WebUI if its original `DATA_DIR` is missing.
   - **`readiness`:** HTTP(S) endpoint, exact expected status and optionally
     a local DPAPI-backed authorization token. An authenticated
     `/v1/models` should typically return **200**. A deliberately
     unauthenticated request to a protected Caddy path may correctly
     return **401**. No TLS verification is disabled.
   - **`enabled`:** choose **`true`** for services AI Workstation should
     start; `false` only for a service intentionally excluded. The untouched
     first-time template uses `false` to prevent accidental startup before
     paths have been configured. For a correctly prepared four-service
     host, all four entries may be `true`. This setting does **not**
     override the independent Process Compose production security gate.

   **Windows path rule:** in JSON, a single backslash must be escaped:
   `"C:\\Apps\\models\\run-model.bat"`. After parsing JSON, Windows receives
   `C:\Apps\models\run-model.bat`. In an ordinary PowerShell string in
   single quotes, write that same Windows path with **single** backslashes.
   Do **not** prefix paths with PowerShell's escape backtick.

   Example of just the startup-related fields for a batch file:

   ```json
   {
     "enabled": true,
     "executable": "C:\\Windows\\System32\\cmd.exe",
     "working_directory": "C:\\Apps\\models",
     "arguments": ["/d", "/c", "C:\\Apps\\models\\run-model.bat"],
     "required_paths": ["C:\\Apps\\models\\run-model.bat"]
   }
   ```

   The actual service object contains additional fields; **edit the
   generated private file**, do not replace it with this partial example.

4. Choose **Check the edited settings (without starting services)**. This
   checks paths, enabled dependencies, missing WebUI data and readiness
   URLs. Errors identify the service rather than exposing secrets.
5. Choose **Apply edited settings for the next startup**. This takes your
   private JSON and prepares the Process Compose definition, then performs a
   real **dry-run validation**. The internal *render* step is automatic:
   there is no YAML to edit and no running process is changed.
6. Choose **Check whether old services still occupy the ports**. If your
   original launcher is still running, **conflicts are expected**. This
   read-only check must refuse the conflicting ports; do not try to kill
   a foreign PID or run both launchers.

If you later change startup parameters, repeat **Edit → Check → Apply**
while the AIW supervisor is stopped. Your private JSON stays the source of
truth; AI Workstation refuses to run a stale generated configuration.

### Choosing the correct Dispatcher

The same Dispatcher source checkout can have **two different configurations**:

- **Existing, model-loading Dispatcher:** a previous command using
  `serve --ensemble ... --instance ... --model-root ...`. This may load
  and manage inference itself.
- **S03 trial Dispatcher:** the reviewed `s03_speedy_gateway.ps1` in the
  Dispatcher repository. It connects to the **already-running native
  Strata** and publishes the trial alias. For the gateway acceptance test,
  **use this S03 configuration**, not the original `--ensemble` command.
  The legacy S03 helper currently regenerates the transitional
  `home-gateway` key registry, so independently named Goose/WebUI S02 keys
  require their own staged migration.

Never start both instances against the same port 8001. Keep the previous
configuration intact until the test and identity migration are accepted.

## Exactly what can you test now, without stopping existing services?

These actions may be performed while the old launcher still manages the
working Windows stack:

1. `git pull --ff-only` on your review branch, then `aiw`.
2. Open **Set up or change this computer → View service configuration
   summary**. Expect four services listed; their setup and enabled flags
   should match your private file. No process starts.
3. Choose **Edit service startup settings** and verify the file. For an
   S03 trial, check the actual Dispatcher checkout and script path,
   instance name, Caddyfile, Strata batch/config and existing WebUI data.
   Keep `enabled: true` for the four services you intend to supervise.
4. Choose **Check the edited settings**. Expect a validation success if
   all files, directories, dependencies and health settings exist.
5. Choose **Apply edited settings for the next startup** and confirm.
   Expect a successful Process Compose configuration **dry-run** for
   four processes. This does not start, stop or reload the live stack.
6. Choose **Check whether old services still occupy the ports**. While
   the previous starter's Strata/Caddy/WebUI instances run, expect
   **occupied-port refusal**. This is a successful *safety test*, not
   a reason to stop unknown processes.
7. Under **Run and monitor AI services**, inspect the actions and return
   without starting anything. The menu now explicitly distinguishes
   Start, Status, Logs, the live monitor and Stop.
8. Optionally inspect **Manage application access keys → List
   applications**. Do not issue or activate new client keys as part
   of a process-manager-only acceptance test.

**Stop here.** Do not choose **Start all enabled services** while the old
launcher owns the processes or the production security gate remains active.

## First live cutover test — separate owner approval required

Only after the pinned Process Compose binary is security-qualified,
Windows child-process termination is tested, private configuration is
backed up and the operator explicitly authorizes the takeover:

1. Stop the old script-owned processes using their known, verified
   owner procedure. Confirm none of their listed ports is occupied.
   Do not stop a process just because its port is 8080, 8001, 443 or 3000.
2. In AIW, choose **Setup → Check edited settings → Apply settings →
   Check occupied ports**. All these steps must pass.
3. Choose **Run and monitor → Start all enabled services**. The workbench
   asks **before starting** whether you want the live monitor open
   immediately afterward (default: Yes). Inspect all four processes
   as they pass their individual HTTP readiness checks.
4. In **Run and monitor → Show current status** and **Read service logs**,
   check all four and their startup order. Verify unauthorized 401,
   authorized model discovery 200, one tiny inference request, streaming,
   the protected direct-Strata fallback, the WebUI health endpoint,
   persistent WebUI data and the existing gateway routes.
5. Choose **Stop all AIW-managed services**, then verify that every
   **owned** child process stopped and its ports are released. Windows
   process-tree termination must be proven; a surviving child prevents
   restarting the old launcher until that child is safely resolved.
6. Reboot Windows normally. Open AI Workstation and choose
   **Start all enabled services** again; the old starter must not be
   necessary. Automatic boot startup is not part of this test.
7. After separately validating the gateway and client registry, migrate
   the three distinct application identities as described in
   [gateway-client-migration.md](gateway-client-migration.md).

**Rollback:** stop only AIW-owned processes, verify that the entire
native process tree is gone, then use the preserved private old starter.
Never allow both managers to control the same services.

## What this PR does not yet provide

This review branch implements the workbench, private configuration
generator and safe tests; it does not yet install all four programs on a
clean native Windows system, clear the Process Compose security hold,
supply your private launch parameters from Git, or prove real four-child
Windows startup/shutdown/reboot. Those remain open acceptance criteria
under issue #41.
