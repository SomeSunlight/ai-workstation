# M00 — External process supervisor discovery (Issue #34)

> **Status:** review candidate, **now includes opt-in native installer and client/CLI scaffolding; still not a production migration**.
> Date: 2026-11-02. Owner-approved architectural direction: AI Workstation
> provisions/operates a single host-native supervisor; Dispatcher attaches to
> independently owned Strata. Process Compose is **selected by the owner**; its safe process-tree behavior
> still requires real Windows and Linux acceptance.

## Observed starting point

### Speedy native Windows (private owner startup reference)

The owner currently has a working, repeatable PowerShell 7.4 **start-only**
launcher for Caddy (HTTPS gateway), Strata (native loopback inference), and
Open WebUI (native loopback). The script was examined locally; its code,
machine-specific paths/domain and protected credentials are **not** included
in this public repository.

- Checks configured executables, Caddy/Strata configuration, existing Open
  WebUI data directory and DPAPI-protected key *before* any startup; validates
  native Strata JSON so an empty/partly written config does not launch.
- Serializes simultaneous starts using a Windows named mutex; avoids double
  launch when a valid service is already running; refuses ambiguous partial
  starts rather than blindly starting a second one.
- Checks that Strata and Open WebUI listen on **loopback only**. Inspects Caddy
  port ownership and Open WebUI process/child ancestry; rejects unknown
  listeners. A TCP port alone is not proof of process identity.
- Recovers a native AI gateway secret from a local **Windows DPAPI** file. The
  secret is supplied as process environment for Strata/Caddy; never via a
  public repository, command-line argument or metrics.
- Proves **application readiness, not merely process existence**: Strata must
  accept an authenticated `/v1/models` request and reject an unauthenticated
  one; Caddy's own unauthenticated gateway must return its expected 401,
  while its authorized native-Strata fallback works; Open WebUI must pass
  native HTTP health and its existing Caddy route.
- Preserves existing processes, configurations and native WebUI data; does
  **not** implement owned-process stop, restart, crash recovery or monitoring.

After accepted [Dispatcher S03 PR #27](https://github.com/SomeSunlight/Llama_Dispatcher/pull/27),
real Goose and Open WebUI traffic from Laptop/WSL reaches Speedy via the
existing Caddy `/v1` route, authenticated Dispatcher (loopback port 8001),
and existing Strata (loopback 8080). Actual user answers and per-request
SQLite records were owner-verified. The separate direct Strata route remains
available for fallback. **This working runtime is our regression reference.**

### Existing AI Workstation Linux/WSL service

`runtimes/local-inference/service.sh` installs a **systemd system unit**
(`ai-workstation-local-inference.service`) for an optional *legacy*
Dispatcher-managed `llama.cpp` runtime. The service launches the selected
instance/ensemble via `runtimes/local-inference/manage.sh`, and
`aiw local-inference start|stop|restart|status|logs` provides its existing
operator interface. It has no general multi-engine/Windows host supervisor
and must **not** be made to compete with a new supervisor for the same
process. Host-native Ubuntu 24.04 is still awaiting real-host validation
([#33](https://github.com/SomeSunlight/ai-workstation/issues/33)).

## Candidate capability and responsibility matrix

Source for candidate features:
[Process Compose documentation](https://f1bonacc1.github.io/process-compose/),
[health checks](https://f1bonacc1.github.io/process-compose/configuration/),
[CLI](https://f1bonacc1.github.io/process-compose/cli/process-compose/)
and [releases](https://github.com/F1bonacc1/process-compose/releases).
These are *documented upstream functions*, **not yet measured on Speedy**.
The official **v1.124.0 release (2026-10-27)** is now centrally pinned in
config/versions.json with per-platform SHA-256 checksums. Native Windows
binary execution, full Windows process-tree ownership and Go build security
metadata remain **unverified on Speedy**.

| Requirement | Process Compose candidate | AI Workstation responsibility / open proof |
| --- | --- | --- |
| Host process start/stop/restart and logs | Built-in lifecycle, log capture, CLI/TUI | Install a pinned verified binary; own host-specific service definitions and `aiw` interface. Verify real Windows child-tree shutdown before claiming ownership. |
| Service startup order | `depends_on` and readiness/liveness probes | Generate only explicit dependencies; no implicit model autoload or GPU job. Verify order after delayed/failed probes. |
| Readiness versus liveness | HTTP and exec probes | Native `/health` is **not enough**: gateway's exact unauthorized 401 and authenticated upstream 200 are application-level checks implemented by a secret-safe host adapter. |
| Restart policy / crash recovery | Configurable restart, backoff, project operations | Fail closed on persistent bad config/credentials; never repeatedly restart Strata into a RAM/VRAM overcommit. Resource admission remains a separately tested gate. |
| One owner, no double start | Supervisor can own launched processes | Before adopting a service, validate executable identity, PID **and creation time**, port ownership and existing unmanaged instances. Never adopt or stop a port owner merely because it listens. Compare against Windows PowerShell mutex behavior. |
| Windows secret handling | Environment and env-file mechanisms exist | AI Workstation resolves **DPAPI or Credential Manager references**, avoids YAML/plaintext env files, `argv`, logs, report/debug endpoints. Verify child and probe secret visibility and error redaction. |
| Linux secret handling | Environment/exec mechanisms exist | Use protected host-specific sources; no assumption that Windows DPAPI works on Linux; systemd credentials need separate design/test. |
| WebUI data / native config | Can launch a command with an explicit working directory | Preflight asserts existing paths and valid Strata JSON; never create a fresh Open WebUI data root on error. Native model configuration remains engine-owned. |
| Windows and Linux portability | Upstream supports both, with different default shells (`cmd` vs `bash`) | Render/test separate host adapters rather than substituting `bash` for a Windows executable or assuming WSL==native Ubuntu. |
| Managed process identity / operational API | CLI/TUI/REST status and operations | Authenticate/bind any manager API to loopback by default; **do not expose REST/MCP process control to remote LLM agents**. Independently verify PID/path/start identity and race behavior on Windows. |
| Model-engine config, aliases, client policy, SQLite inference requests | **Not** the supervisor's job | Preserve Dispatcher-owned alias/policy/proxy/audit and S07's future secret-free LaunchPlan v1; do **not** invent a competing AI Workstation plan schema. |
| Operational boot persistence | Detached/daemon mode exists | Explicit opt-in Windows Task Scheduler and later Linux systemd wrapper, with non-destructive rollback and idempotent updates. Do not switch on by installing. |

**Important:** Process Compose `project update` and live reload may restart
changed processes. A configuration preview is therefore **not** a reload;
AI Workstation must show side effects and require an explicit owner action.
The Process Compose REST/MCP control surface is a privilege boundary, not
an ordinary inference API. Do not give unrestricted LLMs control of it.

## Smallest acceptable pilot — after this discovery review

Scope: **one isolated disposable process on Speedy/Windows**, no GPU,
no Strata/Caddy/Dispatcher/Open WebUI, no engine/model download, no network
publication, no changes to Windows boot configuration. Prefer an echo/periodic
heartbeat test process with a deterministic readiness marker and a short
startup-failure option; only add a local HTTP listener in a separately
controlled test if checking unknown port ownership requires it.

1. AI Workstation downloads/installs a **pinned, checksum-verified**
   Process Compose Windows binary into a separate private tool slot, or uses
   an explicitly identified preinstalled binary during the experiment.
   Tool selection remains user-visible; no silent PATH-wide replacement.
2. Generate a **private** Process Compose project for this test alone,
   avoiding `process-compose.yaml` in the repository root. Disable
   implicit `.env` loading; no protected secret is necessary for the fixture.
3. Validate the generated configuration with upstream `--dry-run` before
   starting. Observe isolated status, readiness, buffered logs, safe
   stop/restart, forced child failure, recovery policy and exit reporting.
4. Independently start an **unrelated process** and confirm project stop/
   restart never touches it. Confirm refusing an unexpected port owner
   (only in the opt-in loopback fixture), and verify safe repeated start
   without orphans or stale PID confusion.
5. Keep the project API loopback-only, disable unnecessary MCP controls and
   require explicit operator approval for start/stop. Record observed
   version, config hash, executable identity, process PID/start and OS
   separately from *declared* configuration. Never claim engine runtime
   ownership from inference HTTP observations.
6. Demonstrate clean uninstall/rollback of **only** the isolated trial,
   leaving Speedy's proven original launcher and existing services untouched.

**Owner gate:** a separate PR with focused Windows regression tests, a
reproducible run instruction and a real Speedy test log. Once accepted,
expand incrementally: real service config generation from the existing
Speedy startup invariants, operator `aiw` commands and managed Strata/
Caddy/Open WebUI only by an **explicit, reversible** per-service handoff.
A WSL/Linux trial follows; do not advertise native Ubuntu production
support from WSL or CI results alone.

## Decisions and unresolved questions

- **Owner-selected supervisor:** Process Compose v1.124.0 is the chosen
  off-the-shelf native process manager. The opt-in binary downloader checks
  official SHA-256; adoption of actual Speedy processes remains gated. Build *adapters
  around it*, not a second supervisor in Python/Dispatcher.
- **Do not cut over now:** the proven Speedy PowerShell startup remains the
  working fallback; preserve the independent Caddy direct-Strata route.
- **No two process owners:** the existing Linux systemd local-inference
  service and a later Process Compose project may not supervise the same
  Dispatcher/llama.cpp instance simultaneously. Plan per-instance migration
  only after an independently accepted launch contract.
- **Secrets and authorization:** today the Speedy Caddy gateway and Strata
  share a DPAPI-backed native secret; the S03 trial's single
  `home-gateway` S02 identity does not distinguish Goose from WebUI.
  Distinct revocable client credentials remain future security hardening,
  not a retroactive claim about accepted S03.
- **Current PR #37:** delivers the first explicit native CLI/menu and
  private named-client onboarding, without modifying live services. See
  [operator guide](native-services.md). The next gate is the real Speedy
  disposable-process test, then per-service activation of multi-client
  S02, Caddy and Docker/Hermes without double ownership.
