# Native Windows AI service host: setup, operation and first test (#41)

AI Workstation is the entry point for native Windows inference services. You should
not have to know PowerShell script names, Process Compose syntax or internal
configuration-generator commands to use it.

**Current status:** General production adoption remains **blocked** for
the official pinned Process Compose build. For the first Windows-only test,
AI Workstation offers a deliberately enabled **reviewed pilot binary** from
the immutable upstream source `v1.124.0`, rebuilt with **Go 1.27.3**.
Windows CI verified both embedded Go version and the real nested
parent/child `down` behavior on an isolated runner. The operator must
download and explicitly install the **exact checksum-approved artifact**.
Other/unverified builds remain blocked. This is NOT a general production release.
Never change `production_adoption_blocked` manually to make a test pass.

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

### What to expect during a slow first model load

An HTTP readiness probe checks whether an application can **actually serve
requests**. This is not the same thing as "its executable has started".
Native Strata may need **one or two minutes or more** to load a large model
on its first launch. The old 2-second initial delay plus three checks
five seconds apart incorrectly marked a cold Strata startup failed after
about 16 seconds and skipped every dependent service.

AI Workstation now uses these **default startup grace windows**:

| Service | Initial load grace |
| --- | ---: |
| Strata | approx. 300 seconds |
| S03 Dispatcher | approx. 120 seconds |
| Caddy | approx. 90 seconds |
| Existing native Open WebUI | approx. 180 seconds |

The original HTTP readiness URL and required status still determine actual
success. A longer grace does **not** turn an unhealthy service into a healthy
one, inject credentials or restart failed applications automatically.
If a specific machine legitimately needs longer, add
`"startup_grace_seconds": 420` **inside that service's `readiness`
object** in the machine-local `native-host.json` (valid range: 30–1800
seconds), then validate and apply the source again while stopped.

Process Compose now retains **per-service** startup/STDOUT/STDERR logs under
`%LOCALAPPDATA%\AIWorkstation\services\runtime\logs\`, with limited
rotation. In **Run and monitor → Read saved service logs**, select the
service and inspect the last lines **even after failure**. Direct native
CLI: `aiw logs-file strata` or `aiw logs-file --lines 200`.
The live Process Compose monitor provides the real-time view while
supervision is running; the saved files survive exit and reboot.

**Windows console behavior:** Windows AIW launches the supervisor in an
independent **hidden console**, so the four foreground child applications
can inherit one console instead of opening four separate terminal windows.
This launch mode is exercised in Windows CI but its visual behavior under
the owner's Windows Terminal settings still needs a real-host check.
The native AIW menu and attached live Process Compose TUI remain the
interactive interface.

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
     - **`.bat` / `.cmd`:** legacy transitional wrappers only, not permitted
       for the hardened Strata launch; inspect and replace Strata's batch
       with its equivalent already-installed direct Python/native entrypoint.
       For other legacy services only, scripts may be launched through
       `C:\Windows\System32\cmd.exe`,
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

## Obtain and install the reviewed Windows test supervisor

The official pinned Process Compose version and ordinary production hold
remain unchanged. For this first controlled native Windows pilot only:

1. Open the successful [Windows qualification run](https://github.com/SomeSunlight/ai-workstation/actions/runs/41834867823).
   Download its artifact **`process-compose-windows-review-go1273`**
   from the workflow **Artifacts** section. It is a ZIP containing
   `process-compose.exe`. This short-lived GitHub Actions artifact is
   not an official upstream release and may require GitHub sign-in.
2. In `aiw` select **Set up or change this computer →
   Install the independently reviewed Windows supervisor (pilot)**.
   Enter the full path to the **downloaded artifact ZIP** and confirm
   the one-time opt-in. AI Workstation extracts it *privately* as
   `process-compose-pilot.exe`, preserving the previously installed
   official `process-compose.exe`. It verifies the exact reviewed
   binary SHA-256 before accepting it.
3. Select **Show reviewed supervisor pilot status**. It must report
   **enabled**. If the ZIP has the wrong contents or digest, installation
   fails closed. This installation does **not** start, stop or take over
   any current host service.
4. The initial pilot is for a **single owner-approved host validation**,
   not a general Windows production release. The general pinned
   security hold remains active for unrelated native projects. After
   an accepted test, a separately reviewed, permanent pinned release
   and clean-machine installation path must replace this provisional
   Actions artifact.

The pilot source is fixed at
`f471d83a5dfa4779d589d0a73182b6d6e22736b2`,
Go toolchain `1.27.3`, binary SHA-256
`7b966884a41987173ab6d342947376b799ea633492122f624f18f5328475b701`.
For provenance and the isolated nested-process shutdown result, see
[workflow #41833439667](https://github.com/SomeSunlight/ai-workstation/actions/runs/41834867823).
No private Windows machine names, model paths or credentials are part
of this build.

## Before the first real Start: three S02 application keys

**Do not start the native stack with the old single-key configuration.**
The [individual gateway client migration guide](gateway-client-migration.md)
now covers the exact offline work: generate three separate originals with
AI Workstation, import the original key as a transitional fourth identity,
render the hash-only `clients.json`, ensure the S03 Dispatcher uses that
file **without regenerating a shared-only registry**, and stage the Caddy
`/v1/*` forwarding change while preserving the old `/strata/v1/*`
authentication rule. The S03 starter and offline Caddy stage helper are in
[Dispatcher draft PR #30](https://github.com/SomeSunlight/Llama_Dispatcher/pull/30).

Both Open WebUI installations **persist provider connections**. They must
be configured with their different original keys in the **existing
Admin → Connections** screens after WebUI has started; setting one
environment variable is not proof that an existing saved connection
changed. Goose in WSL uses its existing `aiw goose configure` operation.
Do not touch the WebUI databases or clear their persistent volumes.

## First live cutover test — separate owner approval required

Only after the exact reviewed Windows pilot binary is installed,
its checksum is accepted, private configuration and data are backed up,
the existing owners/ports are known and the operator explicitly authorizes
the takeover. The isolated Windows CI test supports this pilot but the
**real-host tree-shutdown behavior remains unverified** until the stop test:

1. **Complete the S02/Caddy/Dispatcher staging described above.**
   All three new original keys should be generated and stored safely before
   starting. No client should be switched to the new gateway yet.
2. If the old starter is still running, stop only its known processes using
   the existing verified procedure. If the machine has just rebooted and
   no old services are running, **do not start the old script**.
   Verify the required ports have no unrelated owners.
3. In AIW, select **Set up or change this computer → Check the edited
   settings → Apply edited settings for the next startup → Check whether
   old services still occupy the ports**. Require a successful dry-run
   and free declared service ports.
4. Choose **Run and monitor AI services → Start all enabled services**
   and opt in to the live status/logs monitor. Inspect each service's
   HTTP readiness as Strata, Dispatcher, Caddy and native WebUI start.
5. Before adding the new provider connections, verify S02 with private
   token-backed HTTP requests: missing and invalid keys get **401**,
   each generated key gets **200** on its intended Dispatcher/Caddy
   route, and the independent old-key Strata fallback still requires its
   existing credential. Do not include secrets in reports/URLs.
6. Configure the two existing Open WebUI instances through their
   **Admin → Connections** screens, and Goose through
   `aiw goose configure`, with three different original credentials.
   Execute model discovery, a tiny completion and an optional short
   stream in each. Confirm three distinct client IDs in the active
   Dispatcher SQLite audit data.
7. Choose **Stop all AIW-managed services**. The generated native project
   uses `ordered_shutdown: true`, so Process Compose requests stops in
   reverse dependency order (**Open WebUI → Caddy → Dispatcher → Strata**),
   then the supervisor itself exits. A separately attached TUI can show the
   progression while the supervisor is available; it disconnects when the
   supervisor exits. The normal menu command prints periodic waiting status.
   Unlike the old six-second PID-only check, AIW now confirms both the
   supervisor's exit and freedom of **all declared TCP listening ports**
   (plus its management port), allowing up to three minutes for slow
   shutdown. Only then does it remove the private ownership record and print
   `[OK]`. An orphaned Strata/listener, unverifiable port state or timed-out
   supervisor causes a failure, **retains the ownership record** and blocks
   another launch until manually investigated. No unknown process is killed.
8. Reboot Windows, reopen AIW and choose **Start all enabled services**.
   Verify the same individual keys and persistent WebUI data still work.
   Automatic startup at login is not assumed.
9. Retain the old shared identity until all prior clients and routes
   pass. Its removal is an independent, explicitly approved operation.

**Rollback:** stop only AIW-owned processes, verify that the entire
native process tree is gone, then use the preserved private old starter.
Never allow both managers to control the same services.

## Quiet readiness: monitoring without fictitious user activity

The native supervisor still checks service health on its five-second interval,
but **normal checks should not appear as Dispatcher user activity or repeated
401/200 access logs**. Real client requests, invalid keys and failed health
checks remain observable.

The reviewed implementation uses three independent lightweight checks:

| Service | Normal health check | Audit/log behavior |
| --- | --- | --- |
| Strata | Authenticated local `GET /health` | No repeated model discovery |
| Dispatcher | Local `GET /health` (no client credential) | Only successful exact-path health access lines are omitted from Uvicorn access logs; real `/v1/*`, 401s and 503s remain visible |
| Caddy | Certificate-validated TLS handshake to existing configured HTTPS host | **No HTTP request** is sent through Caddy, so no synthetic 401 gets proxied to Dispatcher; TLS failure still fails readiness |
| Open WebUI | Existing `GET /health` | Existing behavior unchanged |

The TLS handshake checks the certificate/HTTPS listener, **not application
routing or individual client authentication**. Those are still covered by the
explicit S02 acceptance tests: unauthorized 401, each valid client 200, and
one small inference request from each actual client.

### One-time migration of existing private host settings

This changes only private `readiness` entries, not source credentials, client
registrations, Caddyfile, process commands or WebUI databases. **Do not run the
mutation while an AIW-owned supervisor is running.**

1. On the review branch, pull the reviewed changes and first show the preview:
   `aiw host quiet-probes`. No private file is changed.
2. When a controlled restart is acceptable, exit the monitor and run
   `aiw down`. Ensure the AIW supervisor has stopped and no conflicting
   processes are listening.
3. Apply explicitly: `aiw host quiet-probes --apply`. A byte-for-byte private
   backup `native-host.before-quiet-probes.json` is created first; existing
   backups are never silently replaced.
4. Prepare the updated supervisor process definition: `aiw host validate`,
   `aiw host render`, `aiw check`. Inspect success before `aiw up`
   followed by `aiw tui`.
5. Verify in the TUI: all four healthy, no recurring 401/200
   `/v1/models` pairs in Dispatcher logs. Send a real Goose/WSL/WebUI request
   and verify that **it still appears** under its correct individual
   client identity. In case of any failed certificate/health check, read
   `aiw logs-file caddy` and the error on the Process Compose monitor.

The migration refuses custom or unexpected probe URLs instead of guessing.
If the Caddy URL uses an IP address with a certificate for a DNS hostname,
use a genuine certificate-valid hostname before opting in; **TLS verification
is not disabled**. Restoring the original `native-host.json` requires
stopping AIW, restoring its backup, re-rendering and validating before start.

## Failure diagnosis and retry — first native host start

If the TUI says `Processes: 0/4`, `strata: Failed` and
`dispatcher`, `caddy` and `open-webui` are all `Skipped`, inspect
the **Strata log first**. Upstream readiness failure can cause a cascade
of skipped dependencies. Logs such as `loading the vision encoder` and
`starting the engine: reading the model's weights` immediately before
`readiness check fail` indicate a likely premature health-check
deadline; they do **not** by themselves prove that the model is corrupt.
A separate problem is possible if the configured readiness URL or
expected response status is incorrect.

For a **controlled retry** after receiving the cold-start fix:

1. Leave the Process Compose TUI. Then use `aiw down` to stop **only
   the AIW-owned supervisor**; do not kill unknown PIDs. Check its
   exit result. If the supervisor ownership record does not match, stop
   and inspect rather than force-removing it.
2. Use **Set up → Check whether old services still occupy the ports**.
   If any old/foreign service is listening, investigate ownership.
   A failed supervisor can leave a child process briefly busy;
   don't start a second copy of Strata on the same port.
3. `git pull --ff-only` on the AIW review branch. Run **Set up →
   Check edited settings → Apply edited settings for the next startup**.
   The process definition must contain the increased Strata grace
   and per-service rotated log files. This does not start an application.
4. Use `aiw check` as an optional dry-run, then **Run and monitor →
   Start all enabled services**, choosing the live monitor if desired.
   Watch Strata loading; its readiness is checked regularly for up
   to roughly five minutes by default. If all four become healthy,
   carry on with the **S02 client connection** checks.
5. If Strata still fails, do **not** immediately increase the timeout
   again. Inspect `aiw logs-file strata` and the configured
   `readiness.url`/`expected_status` in your private JSON. Also
   check the separate supervisor log
   `%LOCALAPPDATA%\AIWorkstation\services\runtime\process-compose-stdout.log`.
   Share redacted diagnostics, not credentials or private config values.

The separate child windows observed with the previous Process Compose
`DETACHED_PROCESS` launcher are **not intended**. Their stdout/stderr
was not persisted by the previous native-host renderer. The corrected
hidden-console mode plus per-service persistent log files require
re-rendering **and a new supervisor start**; a currently running
supervisor cannot adopt those changes in place.

The official guide is the source of truth for the workflow. The Windows
runner proves the **synthetic** setup and lifecycle contracts; successful
real Strata loading, actual window behavior and all three distinct
application connections require the owner's host acceptance test.

## What this PR does not yet provide

This review branch implements the workbench, private configuration
generator, a specifically reviewed Go 1.27.3 Windows pilot and safe CI tests.
It does not yet install all four programs on a clean native Windows system,
remove the general Process Compose security hold, supply private launch
parameters from Git, or prove actual four-child Speedy startup/shutdown/reboot. Those remain open acceptance criteria
under issue #41.


## Review-only #53: locally approved Strata and direct Process Compose launch

**Existing working installations are not migrated by a repository update.**
AIW renders the private Process Compose project only while stopped. No download,
installation, hash reapproval or service restart occurs merely by reading this
document, performing Check or running a normal managed service start.

### Why the launcher changes

An observed Kaspersky `HEUR:Trojan.Multi.Powecod.b` detection reported a
`cmd.exe` process. Native Process Compose v1.124.0 defaults to `cmd /C`,
while the previous AIW renderer produced a UTF-16LE/Base64 PowerShell
`-EncodedCommand` for every service and recurring health probe. The operator
confirmed that `process-compose-pilot.exe` was the parent of five such
`cmd.exe` processes. This explains the suspicious process pattern but does
**not prove** a false-positive malware verdict. Do not add antivirus
exceptions or suppress the event.

The revised generated project uses native `entrypoint` **argument arrays**
for all four service starters: Process Compose launches `pwsh -NoProfile
-NonInteractive -File aiw-native-child.ps1 ...` directly, without `cmd.exe`.
For executable health probes, the project explicitly sets
`shell_command: pwsh`, `shell_argument: -Command` and uses normal
PowerShell single-quoted literal arguments (including doubled apostrophes).
Both use only private JSON paths; neither embeds DPAPI secret values in
command lines. Other AIW entrypoint scripts such as `aiw.cmd` are outside
this supervisor-level change. **Limitation:** Process Compose's exec-probe
shell accepts only one shell argument; `pwsh -Command` may load the
operator's PowerShell profile. Keep that user profile trusted and avoid
altering it during testing. Verify the profile has no undesirable side
effects before approving this change on a live host.

### One-time migration or deliberate update (Windows, stopped services)

1. Preserve the currently running, known-good AIW checkout, its private
   `native-host.json`, and the prior local Strata installation as rollback.
   In **Run and monitor AI services**, choose **Stop all managed services**.
   Do not kill unknown processes or start an additional inference engine.
2. In **Set up or change this computer → Edit service startup settings**,
   keep `services.strata.executable` as the verified direct installed
   Python interpreter or native binary; preserve exact `arguments` (one
   item per parameter) and `working_directory`. Remove the obsolete Strata
   batch file from `required_paths` only if no longer needed. All other
   private service fields, credentials and readiness settings remain intact.
3. Add the mandatory **`services.strata.integrity_files`** list to your
   *private* `native-host.json`. Include absolute paths to the actual
   code-bearing start files, such as the Python `serve/server.py` entrypoint,
   the inspected Strata configuration/launch control and appropriate
   installed native engine executable. Do **not** list the interpreter
   twice; it is automatically hashed from `executable`. Do not list large
   model weight files or private credentials. Confirm these are the
   actual files used by your installation, not example paths.
4. Choose **Check the edited settings**. Then choose **Review Strata
   launch-chain file hashes** (option 13) to inspect the exact paths and
   SHA-256 values. Confirm the installation provenance and argv digest
   against the expected known-good version. This action writes nothing.
5. Choose **Approve reviewed Strata launch** (option 14). Read the
   displayed hashes again and confirm deliberately. AIW writes the
   machine-local `strata-launch-approved.json` next to `native-host.json`;
   it does not overwrite previous approvals without saving a dated
   `.before-*.bak`. Approval is refused if a supervisor ownership record
   indicates the host is running.
6. Choose **Apply edited settings for the next startup** (regenerates
   `process-compose.yaml`, with an actual syntax/dry-run check), then
   **Check whether old services still occupy the ports**.
7. Choose **Run and monitor AI services → Start all enabled services**.
   Inspect the live monitor and per-service saved logs, then confirm
   authenticating Goose/Open WebUI and seeing both model aliases through
   the existing Dispatcher. Inspect `cmd.exe` children of the Process
   Compose supervisor and Kaspersky's detailed event history; do not
   declare the alert permanently resolved from one successful start.

### What fails closed; rollback

The native Strata child and AIW preflight independently verify the
approved direct executable, path, working directory, hashed argument
array and each declared launch-chain code file. A missing manifest,
changed file or path, shell/batch/package-manager wrapper or unapproved
arguments **blocks Strata before process creation**. The other three
services and existing S02 client registry/metrics are not modified.
No automatic installation, downloads or approval is performed on `up`.

For an explicit Strata update, stop services, stage verified new code
outside the normal launcher, review it, approve the new local hashes,
apply the same private JSON and start only once. For a rollback, restore
the previous **matching** reviewed files, private host JSON if changed,
and prior `strata-launch-approved.json.before-*.bak` manifest while
stopped; reapply the private definition before restarting. This is
operator-controlled, not automatic recovery. A local hash demonstrates
consistency with the locally approved bytes, not that those bytes are
free of malware. Avoid globally whitelisting any antivirus alert.
