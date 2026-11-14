## Issue #71 — OpenShell workstations: first thin integration (Draft PR)

**Baseline:** current `main` after merged docs PR #72. This independent review branch changes no host, Docker runtime, existing Goose sessions, or data. OpenShell v0.1.8 is operator-tested on one WSL2 + in-WSL Docker host, not generally security-qualified. Owner explicitly approves any host test and any merge.

- [x] Read #71, closed research gates #68/#69, merged PR #72 runbook, source context and Development Workflow; decide responsibility split first.
- [x] Write short ADR describing upstream ownership, typed user actions, trust boundary, state/export policy and unchanged #65 fallback.
- [x] Add one opt-in Goose-first `aiw workstations` entry and standalone stdlib adapter: title-first list/selection, create with reviewed policy + pinned OCI reference, status/start/stop, interactive Goose/shell, full registered-project copy and targeted export.
- [x] Add offline mocks for strict no-overwrite/no-delete and command/approval contracts; integrate into CI without accessing OpenShell, Docker or a user host. (8 tests; GitHub Ubuntu `Verify repository files` passed on head `e0a6884`.)
- [x] Review focused tests and six-file diff; open independent [Draft PR #73](https://github.com/SomeSunlight/ai-workstation/pull/73). Ubuntu validation and disposable legacy Docker job passed on prior head `e0a6884`; remaining Windows/updated-head CI is checked separately. No ContextCanon source changes in this first slice: update authorized source and regenerate only after owner reviews the ADR.
- [x] Operator feedback: rename top-level entry to plain English "Goose work areas" (not "Workstations / WSL"), explain persistent sandbox vs Goose conversation, offer bundled strict policy by default and site/flexible-web choices without local YAML management.
- [x] Implement source-linked OpenShell v0.1.8 restrictive preset and minimal read-only HTTPS host rule, plus opt-in upstream policy-advisor mode (not fully unrestricted). Security boundary and support caveats documented in docs/openshell-network-profiles.md; **runtime policy effects still need operator flight**.
- [x] Extend offline mocked contract suite to 14 tests: first-run title/profile (no YAML prompt), strict default, URL/IP validation, site-policy temporary 0600 file, no overwrite, explicit flexible-mode approval, unchanged legacy operations.
- [ ] Exact current-head CI checkpoint (all jobs) after owner UX corrections; user must separately authorize any real OpenShell/WSL smoke test. Latest successful Linux validation and disposable Docker regression: [Validate #43573762887](https://github.com/SomeSunlight/ai-workstation/actions/runs/43573762887); Windows job may still be running when this checklist was last edited.
- [x] Kaspersky / Windows-WSL/Linux support and scan-on-export integration: opened separate [Issue #74](https://github.com/SomeSunlight/ai-workstation/issues/74) with vendor-source feasibility questions and trusted scan-on-transfer criteria; no antivirus installed or implied protection.
- [ ] Owner reviews and authorizes any real WSL test / exact-head merge. Unresolved: interactive extension hang, pinned offline tools, provider convenience, full backup/restore and broader negative security tests.

---

## Issue #71 — OpenShell first-flight reproduction and #69 research handoff (2026-11-14)

**Scope of this documentation-only PR:** capture the operator-proven OpenShell v0.1.8 / Goose 1.59.0 WSL journey in a sanitized, repeatable runbook; update no runtime, source context, provider credentials, Docker/WSL configuration, or host. Integration architecture, security qualification, legacy migration and new features belong in #71's later scoped PRs. Owner squash-merges only after review.

- [x] Inspect latest #68/#69, owner-observed results, current main and the new #71 architecture/implementation hub.
- [x] Write a version-pinned hands-on runbook separating **actually tested** commands and expected output from **not yet qualified** security/backup/host cases; show safe key-injection and tested interactive Goose/export.
- [x] Verify document contains no user/host-specific identifiers, private Dispatcher hostname, original key, generated sandbox IDs or unrestricted security advice.
- [x] Open independent [draft docs-only PR #72](https://github.com/SomeSunlight/ai-workstation/pull/72); record successful research-gate handoff and links; do not merge or change running sandboxes.
- [x] Close #69 explicitly as **successful bounded functional research, not completed P0–P6 security certification**; carry gaps into #71 and annotate superseded older issues.
- [ ] Run read-only review/CI on the exact PR head, leave owner approval and squash-merge to operator.

Checkpoint: research gate #69 operator reports working default/hardened OpenShell sandboxes,
nonroot Goose, persistent Git history, effective policy, denied direct TCP with OCSF
attribution, isolated provider and successful model-backed Goose output, interactive
artwork creation/export. Pending: toolchain, extension hang, deeper network/FS negatives,
lifecycle/backup, broader autonomy release approval.

---

## Issue #68 — OpenShell existing-WSL research gate 1 (review branch)

Scope: upstream v0.1.8 theory, **passive-only** reusable preflight, mocked tests and a public sanitized decision memo. No host rollout, service/config changes, Issue #69 work, or PR #65 modification. Owner review is required before merge or any host execution.

- [x] Read Issue #68, current main context, and current upstream support/security/runtime documentation.
- [x] Implement standard-library-only passive WSL/Linux preflight with offline example, conservative statuses and redacted text/JSON.
- [x] Add mocked offline tests proving no subprocess/network/write operations and correct uncertainty/redaction behavior.
- [x] Publish version-linked evidence, non-goals, explicit open questions and CONDITIONAL decision in Issue #68 and branch documentation.
- [x] Execute focused tests in an isolated disposable development environment and inspect branch diff / CI.
- [x] Open an independent review PR; keep #69 blocked and #65 unchanged; await operator approval before any laptop execution.
Checkpoint (2026-11-13): CONDITIONAL decision in Issue #68; independent Draft PR #70.
Upstream baseline pinned to NVIDIA OpenShell v0.1.8. The new 10-test
standard-library suite ran in GitHub-hosted Ubuntu validation, whose
"Verify repository files" step passed (run #43420360480). No owner WSL
script execution or host data collection. Branch diff reviewed: only
PLAN, documentation, test/CI wiring and stand-alone preflight. This is
review-ready, **not** owner-approved or merge-ready. Gate #69 stays blocked
and merged PR #65 stays as-is.


# AI Workstation Plan

## Issue #64 — operator-facing agent sandbox UX (2026-11-12, draft first slice)

**Baseline:** PR #60 was squash-merged into `main` before this work; this branch
`feat/64-sandbox-operator-ux` starts from `a8b4e55ea9a0614cafe7edd1d18b236ec1ec0a50`.
Preserve the established isolation, approved image pins, typed approvals,
private Goose homes and currently running services. Git-powered project merge
must not be mixed with environment recipe promotion.

- [x] Confirm #60 merged and inspect #64, current source, operator menu and Docker CI.
- [x] First independent slice: human-readable session titles and stable IDs,
  an integrated project/session/environment **cockpit** (not duplicate menus),
  immediate safe takeoff with recommended `standard`, contextual revision management,
  project-folder registration reusing the existing Bash authority, and approval-
  guarded cleanup of empty test sessions. Existing legacy Goose entrypoints remain
  available but are labelled direct-project/advanced.
- [x] Add focused offline and disposable Docker regression checks plus operator guide.
- [x] **Revised cockpit functional head:** Linux/ContextCanon, Windows and disposable
  real Docker (including the guided empty-session cleanup) all passed
  [Validate #43253533626](https://github.com/SomeSunlight/ai-workstation/actions/runs/43253533626).
  Menu navigation tests were updated for the default safe cockpit and explicitly
  nested legacy Goose commands.
- [x] Pinned ContextCanon read-only `check --all` passed in CI. Existing general/English
  operator-UX and agent-isolation rules in `CONTEXT.src.md` already cover this
  slice; no authored rule or generated Parent/Child package needed modification.
- [x] Owner WSL cockpit acceptance (2026-11-12): recovered the earlier archived empty
  `python-tools` update (archive-name validator bug fixed and regression tested),
  cleaned up old test sessions, and successfully created and started a newly titled
  private Goose session. Operator reports the project/session/environment cockpit
  is understandable and the guided takeoff works. File review / next independent
  batch merge and resumed Hermes adapter are separate #64 scopes; no claim that
  the owner ran every advanced environment or original-file transfer path again.
- [x] Owner approved completing PR #65 after the successful WSL operator flight.
  Exact-head CI must remain green; owner performs the usual squash merge.
- [ ] After #65 merges, centrally codify the expanded **agent-neutral autonomy
  philosophy** into authored `compose/CONTEXT.src.md` (and refine root rules only
  if needed), propagate packages with pinned ContextCanon and zero generated drift.
  Requirements are captured in #64; do not disrupt the accepted #65 runtime.
- [ ] **Second independent #64 PR:** Git-powered batch changeset review, select all/files/hunks,
  baseline/current/proposal conflict handling and non-Git project coverage; retain host-side
  approval, backups, safe paths and explicit operator merge, not agent writes.
- [ ] **Real Windows crash/restart follow-up (not yet tested):** verify recovery and stale
  supervisor state when a crash occurs naturally (occasionally after hardware changes).
  Do not deliberately crash Windows merely to close this checkbox.
- [ ] Owner reviews and explicitly approves each Draft PR before any squash-merge.

---

## Issue #59 — PR 1: disposable Goose agent sandbox (historical pre-merge plan; #60 now merged)

**Scope:** separate opt-in sandbox service + Goose adapter only. No live Docker migration, running Windows service change, GitHub merge or PR 2 security profile. Branch `feat/59-sandbox-lifecycle-pr1` from current `main`.

- [x] Read current #59 and inspect Goose Compose, native config/maintenance, context source and existing CI.
- [x] Stage isolated non-Git/Git-compatible file copies with private SHA-256 baselines, operator review and explicit selected-file apply. No original is mounted inside the sandbox.
- [x] Define opt-in backed-up migration, disposable session home, pinned standard image recipe and owner-only named recipe catalogue with explicit candidate/promotion/rollback.
- [x] Preserve all existing legacy Goose entrypoints and private volume unchanged in the repository and deployment.
- [x] Add offline synthetic source/Markdown, binary, conflict, path and session-mount tests; document limits and operation.
- [x] Run pinned ContextCanon source build, reviewed Parent-to-Child propagation and check --all . (nine OK); generated packages committed by the temporary branch CI helper, now removed. [Generation run #43030879288](https://github.com/SomeSunlight/ai-workstation/actions/runs/43030879288).
- [x] Pass real disposable Ubuntu Docker acceptance: synthetic legacy-home backup/verification, Goose/uv/Python standard image build, private session uv tool install, named promotion/rebuild, versioned upgrade/rollback and opt-out. Pass offline project conflict/binary/Markdown/path tests, ContextCanon gate and Windows regression tests. [Validate #43034717195](https://github.com/SomeSunlight/ai-workstation/actions/runs/43034717195), three green jobs on prior exact head `6d94094a` (closing fix CI tracked separately). No operator machine or production services touched.
- [x] **Owner WSL acceptance:** the existing `aiw` launcher resolved the checked-out PR; Goose connected to the selected Dispatcher model, created isolated project copies under `~/projects`, changed files subject to review/selected apply, installed `uv tool` packages, built named `python-tools` r1/r2, and rolled back to r1. No services changed by PR authoring.
- [x] Record operator usability gaps and safe next steps in [#64](https://github.com/SomeSunlight/ai-workstation/issues/64): human titles, selectable sessions/revisions, guided environment saving and Git-backed changeset review/merge.
- [x] Resolve closing operator warnings: mandatory base-image Dockerfile lint without unsafe fallback defaults, ephemeral writable Goose home in the read-only version probe, actionable invalid confirmation; gate warnings in real Docker CI.
- [ ] Nonstandard native extension/history continuity and cold-reboot package durability are not separately proven by the owner; do not present as verified.
- [x] Owner squash-merged PR #60 into `main` before #64 began; PR 2 remains separate.

**Known first-slice limits:** approved recipes capture version-pinned `uv tool` installs, not opaque `uvx` caches/arbitrary runtime installs; pre-migration Goose history is copied as a snapshot, newer histories stay with resumable sessions and are not silently merged. Direct legacy Goose sessions still have their historical RW workspace. Sandbox Docker bridge networking, tool permissions and unknown external extensions are not hardened against a malicious actor until PR 2. Native Windows launches this Linux adapter only via WSL. Multi-file apply keeps verified private backups but is not a transaction.

---


## Owner acceptance checkpoint — Issue #53: native Strata integrity and shell-free launch (2026-11-10)

**Review:** [Draft PR #54](https://github.com/SomeSunlight/ai-workstation/pull/54) is a clean, independent `main`-based #53 change; the obsolete #45-stacked ancestry was removed earlier. The owner has completed the primary **live Speedy** acceptance and intends to squash-merge after the final review. This plan records verified evidence, not an automated deployment or an already completed merge.

- [x] Confirm the unwanted native supervisor process chain (`process-compose-pilot.exe → cmd /C → pwsh -EncodedCommand`) and replace service startup with explicit PowerShell `entrypoint` argv plus plain, quoted PowerShell readiness probes; do not introduce an antivirus exclusion.
- [x] Require offline operator review and explicit SHA-256 approval of Strata's installed interpreter and the selected code-bearing launch files before execution. On the tested host the operator approved `serve/server.py` and `engine/strata.exe`. Leave tunable model/config parameters outside that strict code-file list; preserve stable native command arguments and local approval/rollback.
- [x] Preserve existing Dispatcher aliases, separate S02 keys, Caddy routes and existing Open WebUI/metrics. Four AIW-owned services **started successfully on Speedy** with the Strata integrity preflight active. Both `agent` and `sparringpartner` answered with/without reasoning from native and WSL Open WebUI; the four cases were distinguishable in Dispatcher metrics.
- [x] **Owner observation:** no further Kaspersky alerts during the reviewed live starts. The practical nuisance has disappeared in this acceptance trial. This does not prove earlier detections were false positives or rule out future detections.
- [x] Remove inherited `VIRTUAL_ENV` **only for the Dispatcher native child**, allowing its own project `.venv` to be selected by `uv run --frozen`; test that other services still inherit their intended environment.
- [x] Test synthetic Windows integrity refusal/tampering/reapproval/rollback, plain-probe invocation and native child-tree behavior. **Exact code head `5c6fc5c`: [Validate](https://github.com/SomeSunlight/ai-workstation/actions/runs/42723440856) (Ubuntu/Windows) and [Process Compose qualification](https://github.com/SomeSunlight/ai-workstation/actions/runs/42723440828) (Windows) both successful.**
- [x] Record live-host findings and CI evidence in the PR. Keep all personal host paths, credentials, Kaspersky logs and metrics outside the repository.
- [ ] Owner confirms PR #54 and performs the **squash-merge to `main`**; close #53 as completed only after that merge.
- [ ] After the accepted merge, update the independent [Goose maintenance draft PR #58](https://github.com/SomeSunlight/ai-workstation/pull/58) onto the new `main`, rerun CI and perform its separate WSL/Goose acceptance.

**Boundary:** This PR hardens the Strata launch path; it does not prove whole-stack offline provisioning, remove the broader Process Compose production/pilot qualification hold or eliminate every PowerShell probe caveat. Current-version Goose was **not retested in this final #53 session**; that is separate from the owner's successful Open WebUI/S02 checks and must not be silently marked as completed. Long-term antivirus behavior and a fresh manual rollback exercise can be checked during normal operations, without conflating those with the successful current trial.

---


## Integration checkpoint — live S03 dual roles and native host (2026-11-07)

**Review scope:** [AIW PR #45](https://github.com/SomeSunlight/ai-workstation/pull/45) and [Dispatcher PR #30](https://github.com/SomeSunlight/Llama_Dispatcher/pull/30) together provide an operator-tested *first operational slice*. Owner proposes squash-merging both into `main` to establish a stable baseline, while leaving remaining issue requirements open. The documented current reviews are not an instruction to merge them automatically.

**Verified on the operator's live native Windows + remote WSL clients:**
- One AIW-owned Process Compose stack successfully starts native Strata, attached Dispatcher, Caddy and the existing native Open WebUI; the existing remote WSL Open WebUI and Goose authenticate through the protected gateway.
- Separate S02 application keys and stable client identities appear in Dispatcher request metrics. Two public role aliases `sparringpartner` and `agent` target one native Strata model: `default` client policy injects `reasoning_effort=high` for the sparring partner and `reasoning_effort=none` plus sampling defaults for the agent. The operator observed the agent responding without visible reasoning in both Open WebUI deployments. No second inference engine is started.
- Actual Goose requests already show correct S02 attribution, alias `sparringpartner`, `reasoning_effort=high`, successful tool-call responses and streamed completions. **Delegation from Goose to a separately configured subagent is not yet verified** and belongs to Goose/provider/tool configuration, not an assumed Dispatcher fault.

**Review-branch operational improvements:** client policy editing without key rotation, role-registry generation separated from native Process Compose rendering, persistent TUI/service logs, and Windows shutdown waiting for both the managed supervisor to exit and declared ports to be free. The shutdown code and `ordered_shutdown` project setting have synthetic Windows/Linux CI, but the new full shutdown and reboot behavior still needs real-host acceptance. General pinned-official-Process-Compose production hold remains; the qualified Windows-only pilot stays an explicit opt-in.

**Current #53 outcome (2026-11-10):** [PR #54](https://github.com/SomeSunlight/ai-workstation/pull/54) was rebuilt cleanly on accepted `main`, has passed exact-head CI and the owner-reported live Strata/Dispatcher/WebUI/S02 checks; **no Kaspersky alerts were observed** in this trial. See the acceptance checkpoint above for remaining merge and Goose/PR #58 work. The original Kaspersky false-positive hypothesis remains unproven.

**Other open work:** [#41](https://github.com/SomeSunlight/ai-workstation/issues/41) remains open for genuinely reproducible fresh-host provisioning, permanent patched Process Compose release and outstanding real-host lifecycle gates; [#46](https://github.com/SomeSunlight/ai-workstation/issues/46) for consolidated configuration activation UX; [#55](https://github.com/SomeSunlight/ai-workstation/issues/55) for private instance configuration/backup/disaster recovery. Goose subagent/planner/web-search setup can proceed independently. Preserve private host paths, credentials and live metrics; no automatic service mutation on repository updates.

---

## Active implementation — Issue #41: protected gateway and three auditable clients (2026-11-03)

**Owner-clarified deployment:** Native Windows workstation runs Caddy → authenticated Dispatcher → native Strata and an existing native Open WebUI. A separate AI Workstation in laptop/WSL runs existing Docker Compose Goose and Open WebUI over the protected home gateway. Do **not** deploy additional host-side Goose/Hermes containers (#39 deferred). Each of the three application clients (`Goose` WSL, `Open WebUI` WSL, native-host `Open WebUI`) needs its **own S02 identity**; `home-gateway` remains transitional. Client labels in product documentation are examples, not machine-specific defaults. Native Open WebUI may connect to loopback Dispatcher, while network clients use Caddy.

**Review block A (this branch):** document the operator order and safety/rollback checkpoints, reconcile accepted PR #44/#40 state and clarify existing independent WebUI instance. No live secrets, Caddyfile, Windows host process, Process Compose production guard, upstream version pin or canonical Context nodes may be changed. A draft PR is for review, **not** approval for deployment or trust-boundary cutover.

- [x] Confirm accepted PR #44 (`0a54b6c9`) and close issue #40, preserve zero ContextCanon drift findings.
- [x] Record new scope and the required independent native Open WebUI client identity in issue #41.
- [x] Create [operator runbook](docs/gateway-client-migration.md) for client provisioning, DPAPI-original-key recovery, Dispatcher/Caddy S02 authorization boundary, WebUI connections, request audit, negative tests and rollback.
- [x] Link runbook from [native-services guide](docs/native-services.md); correct accepted STATE/PLAN checkpoint and owner-prioritized #41 after #44 merge.
- [x] Create [draft PR #45](https://github.com/SomeSunlight/ai-workstation/pull/45) for the runbook and reconciliation. No live host changes; keep draft until owner's review.
- [x] Reviewed the first four-document scope and the new renderer/PowerShell/CI changes in draft PR #45; initial Linux/Windows CI green on `efdf394...`, reconfirm at final exact-head merge gate.
- [ ] Require explicit owner acceptance of the complete migration before merge, and separately approve live production service takeover.

**Owner's first Speedy four-service start: readiness/UI incident (2026-11-05):**
The operator ran the first AIW pilot, and the Process Compose TUI showed **0/4** healthy: Strata was still loading vision encoder and model weights when the generic readiness `2s delay + 3 failures × 5s` exhausted at ~16 seconds; Strata transitioned to Failed and Dispatcher/Caddy/native WebUI were Skipped. Four transient console windows also opened under the old detached startup, hiding transient diagnostics. [Draft PR #45](https://github.com/SomeSunlight/ai-workstation/pull/45) now uses a **300-second default Strata readiness grace** (120/90/180 seconds for Dispatcher/Caddy/WebUI), optional bounded per-service `readiness.startup_grace_seconds`, persistent rotated per-service local logs, `aiw logs-file [service]` readable after failure, and a hidden independent Windows supervisor console instead of console-less detached child window proliferation. Synthetic Windows regression verifies default/custom readiness, rejects invalid grace, validates log output paths and exercises saved-log retrieval; pilot CI tests Windows supervisor startup/stop, but hidden-console behavior must be tested on the actual owner Windows Terminal. Official [native-host guide](docs/native-host-operations.md) now covers safe `down`/re-render/free-port/health-log/restart and distinguishes S02 key staging from the **later client-side configuration**. Original screenshot/host logs remain user-local; no private tokens or machine config are committed. Both PRs still draft; **owner acceptance still pending.**

**Individual S02 before first native Start (2026-11-04):** Owner clarified that the first four-service trial must NOT run the transitional shared-only gateway. Existing S03 starter would regenerate a single `home-gateway` registry on every start, and the existing Caddy matcher checks just that one token for both `/v1/*` and `/strata/v1/*`. [Dispatcher draft PR #30](https://github.com/SomeSunlight/Llama_Dispatcher/pull/30) now accepts a pre-generated multi-client S02 registry without overwriting it, and stages an offline Caddy change that sends original bearer credentials to Dispatcher while preserving the old independent direct-Strata fallback gate. The [rewritten S02 migration guide](docs/gateway-client-migration.md) covers three DPAPI-generated application keys, transitional legacy import, private Windows native-host environment mapping, offline Caddy validation, per-client Goose and both WebUI provider settings, negative HTTP checks and SQLite attribution. Windows AIW synthetic four-identity CI and Dispatcher Windows CI guard the separation. **No actual host secret copied into Git and no live service started.** UI polish (compact labels, outcome guidance, Check+Apply merging) is tracked separately in [issue #46](https://github.com/SomeSunlight/ai-workstation/issues/46), not bundled into live gateway work.

**Live three-client acceptance and silent health monitoring (2026-11-06):** Owner successfully started **all four native Windows services**, verified Caddy HTTPS and Dispatcher 401/200 with individual credentials, and completed real Goose on WSL, WSL Open WebUI, and native Windows Open WebUI tests. Dispatcher Stage metrics correctly identify all three different clients; full life-cycle acceptance not yet complete. Recurring 401/200 `GET /v1/models` lines every five seconds were **AIW readiness probes**, not requests from unknown users. Review PR #45 now has `aiw host quiet-probes` (read-only preview) / `--apply` (only while stopped; exact private JSON backup) to replace Strata & Dispatcher model-list probes with `/health` and Caddy HTTP probe with a certificate-validating TLS handshake that performs **no HTTP request**. Successful Uvicorn `GET /health 200` lines are selectively silenced in Dispatcher draft PR #30; 401/503 and genuine client traffic remain visible. CI covers the host migration and private files; real Speedy TLS behavior needs owner-run acceptance. Preserve the general Process Compose security gate and exact-hash pilot. 3090 ensemble and legacy `Speedy_Win` SQLite handoff are next, without making Dispatcher a second process manager; [draft PR #32](https://github.com/SomeSunlight/Llama_Dispatcher/pull/32) is a separate, offline-only staging tool. S07 remains under [Dispatcher issue #15](https://github.com/SomeSunlight/Llama_Dispatcher/issues/15) and requires the applicable S04 provenance contract. The original old code and live Stage DB are not overwritten.

**Owner refinement (2026-11-04):** Native Windows Open WebUI is now the **fourth** Process Compose-managed native process, reusing its existing executable/virtualenv and DATA_DIR. The uploaded private starter shows exact Strata/Caddy/WebUI commands but does **not** start Dispatcher; his separate native S03 launcher and S02 migration are reviewed independently. A private generated native-host.json exists only for operator use, not public Git. First-test acceptance is Strata → Dispatcher → Caddy → Open WebUI, with no legacy-script dependency. Four-service Process Compose dry-run and safety tests must be green; live host startup still requires the release-security gate and owner's separate cutover permission.

**Owner first-test gate (2026-11-03):** The first useful Speedy acceptance test must be an end-to-end AIW/Process Compose service host, **not** a mixture that still needs the private Caddy-folder PowerShell starter. After one-time guarded import of the existing program paths/configuration, AIW must independently start **Strata → attached Dispatcher → Caddy → existing native Open WebUI**, show readiness/status/logs/TUI and stop/restart owned processes; on Windows reboot the operator can open AIW and start the whole stack again. Preserve the original script only for rollback, never start both. Native Open WebUI retains its existing executable and data but is included as the optional fourth supervised native process; its Dispatcher client key remains separate from process supervision. This does **not** imply automatic OS boot start, which is an opt-in separate feature.

**Windows CLI usability checkpoint (2026-11-04):** Introduce a root native
`aiw.cmd` so `.\aiw` from a Windows checkout opens the existing native
services menu or forwards commands. Opt-in `.\aiw register` creates an
AIW-owned, per-user PATH shim so a new Windows shell can run `aiw` from
any directory, as WSL/Linux shells already do. No admin, Windows installer,
PowerShell-profile modification, WSL routing, or production process change.
Windows CI must verify registration/unregistration and passthrough.

**Review block B — reversible native Windows service host and task-based workbench:**

- [x] Document first operational acceptance: no former script during the test, operator-selected Start after reboot, and safe rollback in [native host guide](docs/native-host-operations.md).


- [x] Add private, machine-neutral Windows Strata/Dispatcher/Caddy with **optional existing native Open WebUI** configuration, ordered Process Compose dependency/health project, DPAPI-only child launcher, required existing data/config paths and drift/collision checks; private commands and keys stay outside Git.
- [x] Replace the old numbered 1–19 implementation-centric menu with four task areas (**Run and monitor**, **Set up**, **Application keys**, **Help**); descriptive submenus, first-time safe setup, read-only service summary, edit/check/apply without starting, port collision check, per-service logs, and optional immediate live monitor on Start.
- [x] Windows real pinned Process Compose dry-run, template/render, collision, stale-config and production-gate regressions passed; Ubuntu release/ContextCanon checks also passed on review head `efdf394b7abcac8f1db07611884a1a1109471ff3` ([run #41728615114](https://github.com/SomeSunlight/ai-workstation/actions/runs/41728615114)). This is **not** real native service/child-tree adoption.
- [x] Preserve strict production security gate without any new bypass; actual real-host Start remains blocked until a patched checksum-verified Process Compose binary and Windows child-tree stop proof.
- [x] Clarify first-time `enabled: false` as a safety template only; operational four-service configuration should use `enabled: true`. Add explicit `.bat/.cmd → cmd.exe /c`, `.ps1 → pwsh.exe -File` and JSON double-backslash examples in [beginner-friendly host guide](docs/native-host-operations.md).
- [x] Distinguish the existing Dispatcher ensemble invocation from the S03 attached-Strata test instance, retaining the old configuration unchanged. Update operator-only host config to the actual Dispatcher checkout path without committing private machine paths.
- [ ] Verify exact-head Windows/Ubuntu CI after the latest menu and documentation changes; review no user secrets and leave draft unmerged.


- [ ] Implement **clean native Windows host provisioning** for checksum/version-verified Caddy, native Llama Dispatcher and Strata + Process Compose with reproducible host-local config and run/readiness interfaces; distinguish a fresh install from guarded attach/adoption of an existing service. Check Strata distribution and user-owned model/license prerequisites rather than assuming they are auto-downloadable.


- [ ] Read-only inventory and diff for Caddy/Dispatcher/Strata process ownership and existing protected routes/config/secrets; never import private host data into Git.
- [x] Qualify the **isolated Windows reviewer pilot**: upstream immutable source commit `f471d83a5dfa4779d589d0a73182b6d6e22736b2` compiled with Go 1.27.3; binary SHA-256 `7b966884a41987173ab6d342947376b799ea633492122f624f18f5328475b701` repeated across builds. [Actions #41833439667](https://github.com/SomeSunlight/ai-workstation/actions/runs/41833439667) passed Process Compose → PowerShell parent → TCP child shutdown and listener release.
- [x] Add a **separate, reversible Windows reviewer pilot install** in user-facing setup. It verifies the exact pinned binary hash from a downloaded GitHub artifact, installs to a separate private executable, keeps official v1.124.0 untouched, opts in explicitly, and allows only AIW-generated native-host projects under the reviewed pilot while keeping the general `production_adoption_blocked` true. Preserve the original owner-managed services.
- [x] Windows reviewer pilot installer qualification **passed**: [Actions #41834867823](https://github.com/SomeSunlight/ai-workstation/actions/runs/41834867823) rebuilt fixed source with Go 1.27.3 and the same executable SHA-256, proved nested Windows parent/child shutdown, exact-hash private import, tampered-binary fail-closed, arbitrary YAML rejection, owned smoke lifecycle and removal. General production hold remains active; actual Speedy four-service takeover is not yet validated.
- [ ] Prepare a permanent, reproducibly installable checksum-pinned Go-patched Process Compose release (not an expiring CI artifact), requalify production security, and only then consider removing the general global production hold.
- [ ] Verify production-host child-tree shutdown on Speedy after guarded pilot; keep a rollback and do not stop or duplicate existing native services without operator control.
- [ ] Implement generic Caddy component / owned service definitions and a staged, reversible migration, retaining direct-Strata fallback and no-double-owner preflight.
- [ ] After separate owner approval activate each client's S02 key, verify Goose/WebUI requests + SQLite attribution and controlled gateway/restart rollback; then explicitly approve production process handoff.

---
## Accepted post-merge closure — Issue #40 (2026-11-03)

**Accepted baseline:** [PR #42](https://github.com/SomeSunlight/ai-workstation/pull/42) was owner-tested and merged at `49e8d67246763b83502f58fb4f6628e0801c76fb`. Its source, nine compiled ContextCanon Nodes and eight normative Parent/Child relationships are already consistent; the merged PR's ordinary CI did not invoke ContextCanon.

**Current scope:** `PLAN.md`, `STATE.md`, `CHANGELOG.md` and `.github/workflows/validate.yml`; the temporary `.github/workflows/contextcanon-rebuild.yml` is removed before final review. No authored Context Source, compiler-generated package or live runtime changes are necessary. No Process Compose production adoption or Caddy cutover. Never merge without owner approval.

- [x] Verify PR #42 merge and owner's acceptance, then update the durable post-merge status.
- [x] Identify and correct the **verification-tool mismatch**: early run [#41640517137](https://github.com/SomeSunlight/ai-workstation/actions/runs/41640517137) used CLI 0.8.0 (`d285ae...`), whose internal compiler was **0.6.0**. Its nine-node drift report was a false positive due to incompatible compiler versions.
- [x] Restore original PR #42 Context packages after rejecting the old compiler's candidate output, including all inherited CCW rules; use CLI **0.10.0**, internal compiler **0.8.0**, pinned at `786c50957c4c06f9209ebacfa021609b592c0b07`.
- [x] In isolated, one-time Linux workflow [#41641727621](https://github.com/SomeSunlight/ai-workstation/actions/runs/41641727621), run the **correct compiler**: `contextcanon build --all .` reports **no changes** across all nine Nodes, `contextcanon check --all .` reports **nine OK**, all **eight Parent/Child links current**, and full `tools/release-check.sh` passed.
- [x] Add the correctly pinned, **read-only** ContextCanon check to ordinary Ubuntu CI, with no implicit generation or Parent package upgrade.
- [x] Align accepted PLAN, STATE and CHANGELOG; keep product priority #39 before #41, with no changes to the live Caddy gateway.
- [x] Remove the temporary branch-only rebuild workflow; the final review diff must contain only the four intended files.
- [x] Review the final four-file diff (CI, PLAN, STATE, CHANGELOG) and verify Ubuntu/Windows CI green on review head `0d54f5cac74fe00dcbe6da16b1385d2b10c9bcb6` ([run #41642078845](https://github.com/SomeSunlight/ai-workstation/actions/runs/41642078845)). At the eventual owner-approved merge gate, check the *then-current* exact head again.
- [x] Present [PR #44](https://github.com/SomeSunlight/ai-workstation/pull/44) as the four-file draft for owner review; do not merge.
- [x] Owner merged [PR #44](https://github.com/SomeSunlight/ai-workstation/pull/44) into main as `0a54b6c9393b8f4b06c7deb20b473ad305af81e1` after exact-head green validation; [issue #40](https://github.com/SomeSunlight/ai-workstation/issues/40) closed. Subsequent scoped implementation is tracked under #41.


---

## Accepted PR #42 — Windows installer staging resilience (#43)

Purpose: under native Windows, temporarily locked prior staging folders must not block re-elevation or RunOnce setup. Reuse the Development Workflow method tracked in [ContextCanon #127](https://github.com/SomeSunlight/context-canon/issues/127), without disabling antivirus or changing Context pins.

- [x] Create [AI Workstation #43](https://github.com/SomeSunlight/ai-workstation/issues/43) and keep implementation inside existing draft PR #42.
- [x] Use bounded cleanup retry for the old tool-owned stage, fall back to a unique fresh stage when still locked, and verify the copied entry point.
- [x] Add isolated Windows regression tests for a transient failure, persistent lock, idempotence and refusing foreign directories; wire into Windows CI.
- [x] Exact-head Ubuntu/Windows CI completed successfully ([run #41637116958](https://github.com/SomeSunlight/ai-workstation/actions/runs/41637116958)); owner commented "tested successfully" and merged PR #42 on 2026-11-03. Generated ContextCanon packages were included in the accepted change; independent pinned build/check confirmed zero drift in the issue #40 closure above.



## Accepted baseline closure + generic operator guidance — Issues #34/#40 (2026-11-03)

**Verified accepted merge:** Owner completed the native Windows **7 → 5 → 9 → 6 (TUI) → 8** harmless Process Compose test successfully, approved [PR #37](https://github.com/SomeSunlight/ai-workstation/pull/37), and squash-merged it to `main` on **2026-11-03** as `da108899518d261a960edae9ff8867a6e57bb459`. The merged code provides opt-in native Process Compose entrypoints for Windows and Linux/WSL plus private named Dispatcher S02 client registration, **not** live production ownership or the Caddy multi-client cutover.

**Accepted documentation PR #42** (issue [#40](https://github.com/SomeSunlight/ai-workstation/issues/40)): close the post-merge accepted baseline, state the general-purpose/English/OS-neutral product scope in **authored** `CONTEXT.src.md` with minimal positive operator-UX guidance, and align README/STATE/CHANGELOG. This does **not** modify any runtime, product binaries, Caddy, Docker, customer-specific secrets or parent ContextCanon package.

**Original PR scope:** `PLAN.md`, `STATE.md`, `README.md`, `CHANGELOG.md`, root `CONTEXT.src.md`, plus **generated** root/child ContextCanon outputs **only** through the normal authenticated `contextcanon build --all .` step. The published/pinned inherited Development Workflow package is not silently updated. Additional reusable UX guidance is proposed in upstream [ContextCanon issue #126](https://github.com/SomeSunlight/context-canon/issues/126); do not edit its published package without the separate review/versioning workflow.

- [x] Confirm actual PR #37 squash merge and real owner Windows Process Compose/TUI acceptance; distinguish CI smoke from on-host validation.
- [x] Separate operational next work: [#41](https://github.com/SomeSunlight/ai-workstation/issues/41) generic Caddy installation/process ownership and multi-client gateway trust-boundary migration; [#39](https://github.com/SomeSunlight/ai-workstation/issues/39) containerized agent Workbench; [#38](https://github.com/SomeSunlight/ai-workstation/issues/38) additional Goose workspace directories; [#33](https://github.com/SomeSunlight/ai-workstation/issues/33) real native Ubuntu acceptance.
- [x] Update accepted PLAN/STATE/README/CHANGELOG and author two concise host-neutral, English-language, low-memory operator rules in `CONTEXT.src.md`; add no new personal machine/domain/password-manager defaults. At the original source-edit stage the generated Context was pending; PR #42 subsequently included it and the matching compiler confirmed zero drift.
- [x] Compiler-generated root and dependent ContextCanon packages were committed in the accepted PR #42, including two new root rules (compiler metadata `0.8.0`).
- [x] Pinned matching compiler (`contextcanon` CLI 0.10.0, package compiler 0.8.0) ran `build --all` with no changes and `check --all` with nine OK/eight current Parent/Child relations on the post-merge review branch (workflow #41641727621); no generated Context files were hand-edited.
- [x] PR [#42](https://github.com/SomeSunlight/ai-workstation/pull/42) was accepted by the owner ("tested successfully") and merged on 2026-11-03 at `49e8d67246763b83502f58fb4f6628e0801c76fb`; final review head was `a02eb558d333a1695ecdfdec64ae31b76daedadf`. Historical pre-merge verification caveats remain in PR discussion.

**Revised owner priority (2026-11-03):** managed native Caddy/Dispatcher/Strata and three distinct WSL/native WebUI/Goose identities (#41) are first. Native Windows Goose/Hermes containers (#39) are deferred and not required. Treat trust-boundary and service-ownership changes as separate approved steps. Preserve the existing working gateway and the Process Compose production hold until verified patched binaries and owner approval. The current live gateway does **not** automatically consume the keys created by PR #37.

---

## Current review block — Issue #34: native Process Compose and named clients (2026-11-02)

**Accepted base:** AI Workstation PR #36 was squash-merged on 2026-11-01
as 13eb053becde1a66de9d275e25cbe1fb716062ab; real native Ubuntu
still awaits validation (#33). Llama Dispatcher S03 PR #27 was
owner-tested with real Laptop/WSL Goose and Open WebUI via Speedy's
authenticated Caddy → Dispatcher → native Strata, SQLite verified,
and squash-merged on 2026-11-02 as 2f076e2f1c6f95b1921cafcb6921cf365b2d1ae4.

**Owner-approved change of scope:** The original documentation-only
[draft PR #37](https://github.com/SomeSunlight/ai-workstation/pull/37)
is expanded at the owner's request, before review/merge, to the first
usable native Process Compose and named S02 client onboarding slice.

**Decision:** Process Compose is chosen (no further tool selection).
AI Workstation provides host-native entrypoints; native Process Compose
YAML is the **sole process registry**. Windows on Speedy and Linux
inside Laptop/WSL each run their **own** supervisor; native Linux
reuses the Linux code path. Docker Compose remains the owner of
containerized Goose/Open WebUI and future isolated Hermes. No merged
TUI or MCP process control. A native, operator-accessible CLI/TUI is enough.

**Writable scope:** PLAN.md, STATE.md, docs/process-manager-discovery.md,
docs/native-services.md, README.md, bin/aiw, bootstrap/windows/Services.ps1,
tools/aiw-services.py, tools/aiw-secret-windows.ps1,
config/versions.json, tests/smoke/services-registry.py,
tests/windows/, .github/workflows/validate.yml, tools/release-check.sh,
and PR #37 description. No Caddyfile, native Strata/Dispatcher process,
live DPAPI files, production Windows scheduled tasks, systemd units,
Goose containers or ContextCanon authored/generated packages are changed
on the user's hosts. Existing Speedy Start-SpeedyAI.ps1 remains the
working rollback. Multiple Goose workspace mounts are separate issue #38.

- [x] Verify accepted #36 and Dispatcher #27 and audit the private Speedy
  startup behavior versus existing Linux systemd local inference.
- [x] Select Process Compose as native supervisor; verify official v1.124.0
  (2026-10-27) release and Windows/Linux archive digests; document
  architecture/security and no-double-owner rule.
- [x] Design KISS host-local config: services.yaml for named client
  identities/policies and native Process Compose project reference,
  process-compose.yaml as the **only native process definitions**,
  protected local secret files and generated S02 hash-only clients.json.
- [x] Add opt-in version/checksum-pinned installation, native
  validation/start/status/logs/TUI entrypoints in AI Workstation under
  WSL/Linux and a native Windows PowerShell menu on Speedy.
- [x] Implement strongly named client credential generation, explicit
  revocation and S02 hash-only output. Windows DPAPI and Linux 0600;
  never silently replace live Caddy/S02 config.
- [x] Open separate multi-directory Goose mount issue #38 after confirming
  the current one-RW-workspace limit; capture the separately scoped
  usable containerized Speedy Goose/Hermes Workbench as issue #39.
- [x] Run the **actual official v1.124.0 Linux binary** with Go build
  metadata: the binary is Go **1.27.0**, below the 1.27.2 patch for
  two October html/template CVEs. This is a toolchain finding,
  **not proven exploitability**. Mark the production cutover blocked
  in config/versions.json and enforce an **actual code guard** that
  allows only the harmless aiw-smoke fixture for Process Compose
  native starts until a patched release/build is reviewed. Caddy,
  Strata, Dispatcher and containers remain outside this pilot.
- [x] Verify Linux focused security/CLI tests, Windows PowerShell
  syntax, real Windows DPAPI onboarding/import/revocation, checksum-pinned
  **actual** Process Compose binary/dry-run on Windows and Linux, and
  Go 1.27.0 production-block regression tests. Initial complete
  windows/ubuntu success at [run #41479217299](https://github.com/SomeSunlight/ai-workstation/actions/runs/41479217299);
  the security-guard exact-head Windows/Ubuntu run is
  [#41480747041](https://github.com/SomeSunlight/ai-workstation/actions/runs/41480747041).
  Final PLAN-only checkpoint requires fresh exact-head CI before merge.
- [x] Rework the operator UX after real owner feedback: the Windows and
  Linux native-services menus are **displayed once** (`?` redisplays),
  with clear result separators; existing clients can be selected by
  **number**, not by retyping an exact ID. Distinguish generated,
  imported shared and legacy unknown-origin keys. Avoid hardware names
  and password-manager brands in the general UI/guide. Preserve
  existing `services.yaml`/S02 compatibility and native Docker Compose
  ownership. Windows/Ubuntu CI green on review head
  `526870b9cd79f3b797649843c2e3fbe2b368031d`
  ([run #41540972843](https://github.com/SomeSunlight/ai-workstation/actions/runs/41540972843)).
  This PLAN-only checkpoint requires fresh exact-head CI.
- [x] Owner tested initialization/install/check/client management on real
  native Windows and reported the first real `aiw-smoke` Start attempt
  failed: `unknown flag: --detached`. Verified **upstream v1.124.0
  source**: Windows deliberately excludes `-D/--detached` while Unix
  supports it; the published cross-platform CLI documentation obscures
  the distinction. Replaced the Windows start path with an independent
  headless OS process (`--keep-project --tui=false`), bounded readiness,
  private log, and a PID/path/creation-time owner record for safe Stop.
  Linux/WSL keeps upstream detached mode; TUI now **attaches** instead
  of creating another supervisor. Native Process Compose logs now use
  an explicit project name (required by the upstream CLI).
  The upstream `PROC_COMP_CONFIG` setting binds its general config home
  to the existing private folder without spurious XDG debug messages.
  Native Windows and Ubuntu test-host **full up/status/logs/down**
  verified in [CI run #41546447273](https://github.com/SomeSunlight/ai-workstation/actions/runs/41546447273).
- [x] Owner completed the isolated native Windows `aiw-smoke` test,
  including start, status, logs, native TUI and stop; accepted PR #37 and
  squash-merged on 2026-11-03 as `da108899518d261a960edae9ff8867a6e57bb459`.
  The accepted merge is closed in the dedicated baseline block above.
- [x] Complete the **basic real Windows harmless-process acceptance**:
  owner validated actual start/status/log/TUI/stop, with no GPU or
  production service handoff. The CI additionally checked duplicate
  start and unknown-stop rejection.
- [ ] Later hardening gate: verify crash recovery, process-tree shutdown,
  unexpected listener ownership and restart semantics for real services.
  **Production adoption remains blocked** until the verified patched
  Process Compose build/security review. Track the gateway migration
  and process ownership within #41 and #34.
- [ ] Separate **real operational handoff** after pilot: implement
  DPAPI-aware native start adapters, preserve existing shared key
  during the one-time multi-client Caddy S02 trust boundary transition,
  activate separate Goose/WebUI/Hermes client IDs, move ownership
  per service with rollback. No Process Compose vs existing
  Windows-script/systemd simultaneous ownership. The owner explicitly
  controls activation.
- [ ] Separate Hermes container and Speedy Workbench deployment under
  Docker Compose (and ordinary Open WebUI user onboarding) with
  individually reviewed AIW entrypoints.

**Meaning of CI:** green source/command-contract tests and Windows
script parsing are not proof of working native Windows Process Compose
process-tree shutdown, secure token ACLs, DPAPI under the owner's
account, Caddy auth reconfiguration or full Linux host deployment.
Those remain genuine operator gates and must not be claimed completed.

---

## Accepted first slice — Issue #33: native Ubuntu host-mode foundations (real native host still deferred)

Purpose: make the existing Linux bootstrap behave correctly on WSL2 **and** native Ubuntu 24.04, without pretending that a full native install has yet been hardware-tested. First slice deliberately avoids cloud accounts, model downloads, GPU drivers, process-manager changes, secrets, and changing the Windows install path.

Historical implementation branch: `feature/issue-33-native-linux-first-slice`, based on accepted PR #35 merge `4b4c5f2f03bc092d1fb05c39851b365c5f00a795`; its review [PR #36](https://github.com/SomeSunlight/ai-workstation/pull/36) is now **merged**.

Writable scope: `PLAN.md`, `bootstrap/linux/install.sh`, `bin/aiw-core`, new `tools/host-platform.sh`, `tests/smoke/repository-layout.sh`, `tests/smoke/update-recovery.sh` (fixture now needs the shared host adapter), new `tests/smoke/host-platform.sh`, `tools/release-check.sh`, `.github/workflows/validate.yml`, `README.md`, new `docs/native-linux.md`, `docs/troubleshooting.md`. No ContextCanon source/generated changes in this first slice: official supported-platform statements remain accurate until an actual native installation is accepted.

- [x] Inspect accepted Linux bootstrap, Ansible/local host, Docker, browser, inference, source Context and workflow; record audit in Issue #33.
- [x] Confirm and reconcile the required accepted-baseline gate (PR #35, now merged).
- [x] Introduce pure, testable detection of WSL2 vs native Linux and apply it to mount-safety preflight and `aiw status`.
- [x] Make Open WebUI browser hints and Docker diagnostics truthful on native desktops and headless remote Linux, without breaking WSL Windows browser launch.
- [x] Add automated regression tests and concise native Ubuntu installation and validation guidance; initial standalone host-platform smoke passed in CI. The update-recovery fixture must include the shared helper.
- [x] Run focused host adapter checks, fix the isolated update-recovery fixture, and pass full Ubuntu/Windows Validate on code head `6802a1375cd3cf9af014a63ce5fc505ed004722d` ([run 41228326996](https://github.com/SomeSunlight/ai-workstation/actions/runs/41228326996)). Publish [draft review PR #36](https://github.com/SomeSunlight/ai-workstation/pull/36); this does not constitute native-host acceptance.
- [x] Owner reviewed and accepted the first Linux/WSL host-mode slice; [PR #36](https://github.com/SomeSunlight/ai-workstation/pull/36) passed its final CI gate and was squash-merged on 2026-11-01 as `13eb053becde1a66de9d275e25cbe1fb716062ab`.
- [ ] Separate later real-host gate: disposable native Ubuntu 24.04 x86-64 with systemd and Docker, installer rerun, Goose/Open WebUI functionality; only then update supported platform state and relevant ContextCanon packages.

Known intentional limits: Intel SYCL auto-setup remains restricted to WSL2 with /dev/dxg; optional inference can be disabled; native host systemd services are not a substitute for the future external manager (#34). Native Ubuntu may use a legitimate `/mnt` mount, while WSL continues to reject `/mnt/*` checkouts as before.

## Post-merge accepted baseline checkpoint — [PR #28](https://github.com/SomeSunlight/ai-workstation/pull/28) and [PR #32](https://github.com/SomeSunlight/ai-workstation/pull/32)

**Scope:** correct historical review/status wording after accepted squash merges; only `PLAN.md`, `STATE.md` and `CHANGELOG.md`. No new platform behavior, installer changes, ContextCanon source or generated file edits.

- [x] Verify the two actual accepted squash-merge commits, closed Issues and owner test comments.
- [x] Reconcile the previously open review/checklist status and accepted-state surfaces without deleting technical review history.
- [x] Owner accepted PR #35; exact-head CI was green and it was squash-merged on 2026-10-31 as `4b4c5f2f03bc092d1fb05c39851b365c5f00a795`. Native Linux #33 is now the separate implementation block.

**Next implementation after acceptance:** native Ubuntu 24.04 #33, beginning with a small WSL-safe host-mode/preflight review PR. Current `main` does **not** yet claim native Ubuntu is supported. Audit rationale is recorded in the comments on Issue #33.

## Accepted review block — Issue #29: reliable WSL launch and visual entrypoints

Purpose: ensure both Windows penguin shortcuts start an installed stopped WSL distro automatically, give immediate manual PowerShell commands, and make failures diagnosable. Provide a compact visual README illustration of the two launchers and central `aiw` menu. This takes precedence over Issue #30 (Intel SYCL regression).

Writable scope: `bootstrap/windows/Create-Shortcuts.ps1`, `bootstrap/windows/Launch-Wsl.ps1` (new), `tests/windows/shortcuts.ps1`, `README.md`, `docs/troubleshooting.md`, `CHANGELOG.md`, and this PLAN. No WSL distribution re-registration, removal, driver changes, runtime installation, ContextCanon source/package changes or inference changes. Work from accepted `main` on `agent/issue-29-wsl-cold-start`.

- [x] Record and expand Issue #29; read applicable Windows/bootstrap/Development Workflow Context and existing launcher code/tests.
- [x] Implement explicit WSL cold-start preflight for both launchers, bounded retry, visible manual commands and distinct failure paths.
- [x] Improve the README entrypoint visual and manual startup/recovery guidance.
- [x] Run new Windows mock tests for both links, custom distro names, successful cold startup and failure reporting; preserve ownership/migration/idempotency tests. GitHub Windows runner passed.
- [x] Run focused Windows smoke and complete repository release gate in GitHub Actions; disclose unavailable real Windows/WSL cold-start validation. GitHub Validate run [38552549675](https://github.com/SomeSunlight/ai-workstation/actions/runs/38552549675) passed both jobs on code head `66bc5eb6f3ae20886348d0841c6c88f522c28a4a`.
- [x] Publish [review PR #32](https://github.com/SomeSunlight/ai-workstation/pull/32); subsequently accepted by owner and squash-merged on 2026-10-14 as `b33949ccd72352a26c305d46f60b643d6a60adad`.
- [x] Owner accepted PR #32 after successful real launcher testing (PR review comment, 2026-10-14) and subsequently merged it. The original review checklist included the preferred full cold-boot replay; do not infer additional observations beyond the reported successful test.

Known diagnostic uncertainty: `wsl --distribution NAME --cd PATH` already ought to start a stopped distro. The contradictory `WSL_E_DISTRO_NOT_FOUND` alongside an installed distro list could be transient WSL startup/registration or launcher invocation, not a confirmed missing prestart command.

### Owner cold-boot result and follow-up — 2026-10-14

After a real Windows restart and ten minutes idle, the updated launcher printed `WSL_E_DISTRO_NOT_FOUND` during `--exec /bin/true` **and nevertheless printed `[OK] WSL distribution is running`**, then the same error when opening the target directory. Therefore the preflight's exit-code-only success test is **insufficient**, regardless of whether the root cause lies in WSL or `cmd.exe` / `call` return handling. A bounded retry alone is not a solution.

- [x] Reproduce the false-success class in a Windows fake-WSL test, including an error message with process exit code zero.
- [x] Require exact stdout sentinel from a real `/bin/echo` command inside Ubuntu *and* zero exit code before reporting WSL running; preserve error text and bounded retry.
- [x] Verify the additional Windows regression test and full release gate on revised PR code head `164c5a1066ade7ee5e9a556e0a0b334c6e86803b`. Both Windows and Linux validation jobs passed in [run 38561787523](https://github.com/SomeSunlight/ai-workstation/actions/runs/38561787523).
- [x] Owner PowerShell test (2026-10-14): `wsl -d Ubuntu-24.04 --exec /bin/echo WSL_OK` printed `WSL_OK`, `$LASTEXITCODE=0`, `wsl -l -v` lists the distro stopped, WSL 2.7.14.0 / kernel 6.18.33.2-2. PowerShell ran after failed penguin attempts, so the first-use effect is not excluded. Record in Issue #29.
- [x] Compare the literal full System32 wsl.exe invocation from PowerShell with `call` through ordinary cmd.exe and inspect the executable resolved by PowerShell: same account and absolute `System32/wsl.exe` returns `WSL_OK` and exit 0 from PowerShell 7.6.6, but prints `WSL_E_DISTRO_NOT_FOUND` and exits -1 from `cmd.exe` with `call`. **The CMD-vs-CALL distinction remains untested; do not attribute the bug to CALL alone.**
- [x] Replace the Windows shortcut's `cmd.exe /k` + `call wsl.exe` path with PowerShell 7 via a dedicated `bootstrap/windows/Launch-Wsl.ps1`, copied into standalone per-icon scripts under LocalAppData. Preserve manual commands, actual Linux readiness marker, bounded retry and distinct error paths.
- [x] Adapt Windows smoke tests for PowerShell shortcut targets, per-icon scripts, success/failure modes, custom distros, legacy cleanup and repeated installation. Both jobs succeeded on [run 38564510422](https://github.com/SomeSunlight/ai-workstation/actions/runs/38564510422).
- [x] Repeat Windows and complete release checks after the final documentation update; both GitHub jobs succeeded on code/documentation head `58f892d1e314bc417aa420bec46ac6276828c164` in [run 38564779999](https://github.com/SomeSunlight/ai-workstation/actions/runs/38564779999). The PLAN-only checkpoint after this validation does not change executable behavior.
- [x] Owner later reported successful real Linux startup with the updated launchers in PR #32 review and accepted the squash merge (2026-10-14). The preferred full cold-boot replay was not separately evidenced in that comment.
- [x] No additional registry/reinstall/service changes were needed for the accepted PR #32 launcher solution.




This file is the durable recovery map for active and upcoming development work. Keep completed checkpoints checked as soon as they are genuinely complete. Use `STATE.md` for accepted current facts and this file for work that is still in progress or intentionally deferred.


## Accepted review block — Issues #26 and #27 (post-PR #24 integration): recovery-first README and learnable aiw menu

Purpose: explain the full Windows-to-WSL-to-AI installation and its two shortcuts up front; make every actionable interactive menu operation teach its equivalent direct CLI invocation before optional execution.

Writable scope: `README.md`, `bin/aiw`, `bin/aiw-core`, shared `bin/aiw-menu-config.sh`, focused `tests/smoke/`, `tools/release-check.sh`, `PLAN.md`, `STATE.md`. Do not change bootstrap/WSL lifecycle, runtime isolation, central versions or generated ContextCanon files. This block is delegated for coherent implementation and owner review; no merge authorized.

- [x] Read ContextCanon workflow and inspect current command surface, launchers, existing tests and current main.
- [x] Create Issues #26 and #27 and a dedicated branch.
- [x] Implement persistent commented YAML configuration, editor entry and reusable command-preview/confirmation.
- [x] Cover top-level, Goose, Open WebUI, workspace, and local-inference actions, including dynamic parameters.
- [x] Put recovery-first value proposition and launcher distinction at the start of README.
- [x] Add behavioral tests for preview on/off, y/n/EOF, quoting, persistence, invalid config and editor.
- [x] Run available focused and release checks; inspect final change diff.
- [x] Publish a coherent review PR for the project owner; do not merge without approval.

### Owner follow-up — launcher naming/migration (Issue #26)

Extension to writable scope: `install.ps1`, `bootstrap/windows/Create-Shortcuts.ps1`, `bootstrap/windows/Install-AiWorkstation.ps1`, `docs/troubleshooting.md`, `docs/clean-room-test.md`, `tests/windows/`, `.github/workflows/validate.yml`, and related README/PLAN surfaces. No runtime/WSL provision changes. Preserve installer idempotency and avoid removing arbitrary user shortcuts.

- [x] Check existing installer + standalone shortcut implementations and status logic.
- [x] Keep the public `install.ps1` wrapper default consistent with its implementation (found in final cross-check).
- [x] Unify Windows shortcut creation and move to the explicit `Linux …` labels with distro suffixes.
- [x] Make legacy link migration owned-only, idempotent and safe for unrelated shortcuts.
- [x] Update user documentation and add actual Windows runner checks.
- [x] Pass complete CI on the shortcut-implementation review head and present for owner review (no merge).

Validation checkpoint: Windows GitHub Actions `windows-shortcuts` job passed on code head `b4a001eabb8fcd82256c516ba90b0b0212077337`, covering shortcut targets, legacy ownership checks, reruns and separate distro labels. Full GitHub Actions validation passed on `1622601e80649cf7e7e92312fd32d9dade8b05ed` in [run 37918181020](https://github.com/SomeSunlight/ai-workstation/actions/runs/37918181020): both Ubuntu verify/lint/syntax and Windows shortcut creation/migration tests are green. The final Windows-script smoke test now also covers the public `install.ps1` default. On the latest source head `46a87ea6cf0e7b7318b448baa1e3b802ab7c5030`, the Windows job passed; exact-head Ubuntu checks were running at this checkpoint. As usual, the latest PR head still needs green CI before owner merge. Because of the ContextCanon archive's very long paths, the Windows job uses a deliberately narrow sparse checkout.

Historical review checkpoint (before owner acceptance): [PR #28](https://github.com/SomeSunlight/ai-workstation/pull/28) was open against main; **later squash-merged on 2026-10-09** as `f0a8b553d22b903c3431fa36aea433e7f5654dbc` after the owner's successful Windows/WSL acceptance comment; accepted PR #24 was merged into the review branch, preserving native Goose configuration. Branch `agent/issues-26-27-readme-menu-preview` starts from accepted original main `e4f6ee86e746241ea6630bb759b971b7e47012b7`. The code-and-behavior review head `4b7a277017c026c28a951d2203e29daa9eba374e` passed the complete GitHub Validate workflow on Ubuntu 24.04, including the release checks and new menu-preview tests. The latest source/test changes and owner-requested Windows shortcut rename passed both Linux and Windows CI; the latest reviewed PR head must pass CI again after this planning checkpoint before owner merge. Full WSL/Docker hardware testing remains owner acceptance. Direct `aiw` CLI invocations remain unchanged; preview applies only to interactive selections.

Integration checkpoint: [GitHub Actions run 37951781424](https://github.com/SomeSunlight/ai-workstation/actions/runs/37951781424) passed on actual merge head `59e6901d096e2abc5a792597fa5ccf80adae4d8a` (Ubuntu full release/Goose tests + Windows shortcuts). At that earlier integration checkpoint, PR #28 was mergeable again with no commits behind `main`. Source `bin/aiw-core` retains PR #24 Goose native configuration and includes command previews for `goose configure`, `goose env`, and `goose check`; update-recovery fixture and release-check retain both PRs' tests. The owner subsequently reported successful Windows/WSL tests and approved/squash-merged PR #28 on 2026-10-09.

### Reconcile merged PR #24 before owner test

- [x] Confirm PR #24 was accepted on main, inspect Goose native provider settings and changed tests.
- [x] Integrate menu preview into the accepted Goose provider workflows without restoring obsolete OpenRouter assumptions.
- [x] Re-run Ubuntu + Windows CI and record review-ready conflict resolution; leave PR #28 open for owner acceptance.

## Owner-test follow-up — Issue #25: clean Goose Compose ownership

Purpose: address the owner's repeated volume ownership warning without permanent compatibility behavior for the old Compose project name.

Writable scope: the Goose lifecycle in `bin/aiw-core`, existing Goose smoke tests, `docs/goose-configuration.md`, project version/changelog, this recovery checkpoint and PR #24. Keep the current Compose project and stable home volume name. No Context semantics change is needed.

Decisions: the home stays a normal Compose-managed volume. The owner accepts reconfiguring after an explicit one-time home reset; deletion is an owner-run operation on WSL, not automatic launcher behavior. Remove routine cleanup of the old `ai-workstation` Compose project. Preserve Goose's optional environment file, workspace registry, project files, images and Open WebUI data.

- [x] Inspect the warning, current Compose ownership and old-project cleanup; record Issue #25 and the owner's reset preference.
- [x] Remove legacy project cleanup and verify routine Goose operations target only the current project.
- [x] Document the one-time reset and recreated ownership check; align release metadata.
- [x] Run focused behavior/Compose checks and the complete release gate.
- [x] Publish the follow-up in PR #24 without merging.

Recovery: continue on `agent/issue-23-goose-provider-freedom` after `da7b372ee3db3bf3ba5f4968da33102bff20939b`. Docker Engine and the owner's WSL are unavailable here; native volume deletion/recreation remains an explicit owner operation. At that historical review checkpoint, PR #24 was unmerged; it was later owner-accepted and squash-merged on 2026-10-09 as `9bd87860571b972cf33a41a49e213a55ee22dfae`.

Verification: focused lifecycle tests and real Compose 5.3.0 rendering pass. The complete release gate also passes with an unrelated host XDG path; ContextCanon 0.7.3 reports all nine Nodes `ok` with no generated drift. No authored Context or Ansible implementation changed in this follow-up. The recreated Docker volume's labels still require the documented real WSL check.

Publication: implementation commit `5611c6f8ed860f10f56446f1a7563cf7a58f9c4d` is on the existing PR #24 branch; its GitHub tree matches the locally verified `fe160367fd40fbb94aca7382bdf6b850cfb1892c` exactly. Next: current-head Validate and the owner's one-time reset/native reconfiguration/ownership test. Neither automatic deletion nor a merge has occurred.

## Current review block — Issue #23: unrestricted Goose provider configuration

Purpose: expose native Goose configuration through the operator menu, support local/self-hosted and public providers equally, and preserve one-project container isolation without forcing or falling back to a public LLM.

Writable scope: `bin/aiw-core`, Goose helpers and smoke tests, `compose/goose.yml`, `.env.example`, operator documentation, versions/changelog, and the authored Compose/Goose Contexts plus their generated dependent packages. The owner explicitly replaces the old Compose-only credential assumption with protected application-native storage and optional Goose-only environment configuration. Hardware inference provisioning and Open WebUI provider behavior are outside this block.

Decisions: native Goose settings in the existing `ai-workstation_goose-home` volume are authoritative; configuration runs without a project mount. OpenRouter is an optional first test. Existing `.env` provider/model/key entries are not silently imported. Advanced provider/subagent environment settings use a separately protected, explicitly edited Goose-only file. Preserve arbitrary native supported provider/model choices and CLI arguments; document release-dependent subagent behavior and recipe/session overrides rather than promising automatic optimal model selection or network isolation.

- [x] Read required Contexts and inspect pinned Goose CLI/source behavior; create Issue #23.
- [x] After owner approval and exact-head green Validate/release checks, squash-merge tested PR #22 as `e4f6ee86e746241ea6630bb759b971b7e47012b7` and start from that accepted baseline.
- [x] Implement configuration/menu access and protected Goose-only environment settings without a project mount or public-provider defaults.
- [x] Verify configuration before mounting a workspace; preserve the existing home volume, workspace boundaries and native CLI arguments.
- [x] Add meaningful regression tests for local/custom providers, missing/legacy configuration, secrets, menu routing and container boundaries.
- [x] Update migration/model-routing guidance, Context rules and generated dependent packages, release metadata and accepted baseline state.
- [x] Run focused checks, ContextCanon validation and the complete release gate; inspect the coherent diff.
- [x] Commit/publish the review candidate and open a PR against `main`; leave the new PR unmerged pending owner review.

Recovery: branch `agent/issue-23-goose-provider-freedom`, accepted base `e4f6ee86e746241ea6630bb759b971b7e47012b7`. Docker Engine is unavailable here; deterministic command tests cover launch semantics, while real interactive configuration/provider acceptance requires the owner's Docker installation. Baseline ContextCanon check also found stale root frozen setup/troubleshooting resources from earlier accepted edits; regenerate those resources and review all affected downstream package pins using the matching ContextCanon 0.7.3 compiler, without changing unrelated normative rules.

Verification checkpoint: complete release gate passes with actual Docker Compose 5.3.0 rendering, including provider-neutral launch/migration/menu behavior, primary/subagent overrides, literal environment values, missing/malformed configuration, empty overrides, failed reads/checks/configuration and one-workspace boundaries. Existing Open WebUI/local-inference service checks, locked `uv sync`/lock check, Ansible lint and both playbook syntax checks pass. ContextCanon 0.7.3 `check --all .` reports all nine Nodes `ok`; only generated Markdown's intentional hard-break whitespace is excluded from authored diff hygiene. Real Docker Engine/native-menu/LLM acceptance remains an owner test.

Historical review checkpoint: [PR #24](https://github.com/SomeSunlight/ai-workstation/pull/24) was open against `main` (subsequently merged on 2026-10-09). Implementation commit `deb9dbd1edd018057355d0f7a35bc9f5ab6a0602` has the exact locally tested tree `fcb2cec01a54ef5516a4f97e09df90e967717203`, verified when publishing through the GitHub connector. Next external gate: owner tests the native menu, intended main/subagent endpoints and persistent configuration on WSL/Docker, then explicitly approves before any merge. PR #24 has no merge authorization.

CI recovery: the first review run exposed host `XDG_CONFIG_HOME` leaking into the Docker test double. The mock now clears host routing/path variables like real Compose, and the regression gate passes with an intentionally unrelated host XDG path. Status also skips inspection if the selected image is absent, avoiding unintended Docker resource creation during a fresh-install status check. The follow-up stays in PR #24 and requires a green current-head Validate run.

## Completed review block — Issue #21: guided application container updates

Purpose: let an operator update Open WebUI and Goose from `aiw`, from any WSL directory, without remembering Docker commands or mistaking a pull of an old pinned tag for an application upgrade.

Writable scope: `bin/aiw-core`, a shared runtime-update helper under `tools/`, `tests/smoke/`, release/CI wiring, `README.md`, `docs/container-updates.md`, `CHANGELOG.md`, and project version metadata. ContextCanon sources/generated packages and runtime isolation definitions stay outside this block.

Decisions: resolve official latest stable GitHub releases to exact tags; persist per-machine selections through the existing protected Git-ignored `.env` overrides. Keep repository runtime defaults unchanged and expose them as an explicit choice. Open WebUI gets a stopped-volume backup before recreation; Goose updates affect future sessions only. Repository/host `aiw update` remains a separate operation.

- [x] Reconstruct required Contexts and reconcile accepted PR #13 / #18 / #20 baseline with exact-head green CI evidence.
- [x] Inspect runtime pins, Compose projects/volumes, existing menu and test contracts; create Issue #21 and a review branch.
- [x] Implement guided latest-stable / explicit-version / repository-default updates with download-first and failure handling.
- [x] Add real behavior smoke tests for directory independence, stable release validation, configuration persistence, backup/recreation, and failures.
- [x] Add menu actions and a short README route to the operating guide; align project version/changelog and CI.
- [x] Run focused tests and the complete release check; inspect the final diff.
- [x] Commit and publish the coherent review candidate on the review branch.
- [x] Open review PR #22 and record the owner test steps; do not merge without explicit owner approval.

Focused verification: `container-updates.sh`, `interactive-menu.sh`, `check-version-consistency.py`, Bash syntax and diff hygiene pass. The complete `./tools/release-check.sh` and existing Goose/Open WebUI/local-inference service smoke tests pass; new update checks also cover concurrent-update locking and unexpected recovery-volume mounts. Behavior tests cover download/API failures, duplicate image entries, backup failures for running/stopped services, startup/health failures, fresh installs, unreadable volumes, exported override conflicts and return-to-menu after errors.

Accepted checkpoint: the owner reported PR #22 tested and explicitly approved merging it. Exact review head `f4c5ca304a2ccaf98934befa1f8662a7f0c3071a` passed Validate run `37532821370` and the repeated release gate. PR #22 was squash-merged as `e4f6ee86e746241ea6630bb759b971b7e47012b7` on 2026-10-07.

Recovery checkpoint: working branch `agent/issue-21-container-updates`, accepted base `f72973e764560a4102b7291495fa0fb93effe434`. Latest stable release metadata observed on 2026-10-06: Open WebUI `v0.11.4`, Goose `v1.53.0`; implementation must discover releases at execution time rather than hard-code these observations. Docker Engine is unavailable in this development workspace, so container behavior is exercised with deterministic command mocks and real-volume acceptance remains an owner test.

## Completed review block — Issue #19: remove legacy permission normalization

Purpose: stop the Linux installer from rewriting Git-tracked executable bits on every install/update now that normal installations clone directly into the Linux filesystem.

- [x] Reproduce the cause: repository-wide `chmod 0644` followed by an incomplete hard-coded executable allowlist.
- [x] Remove automatic repository-wide permission normalization from the Linux installer.
- [x] Remove the obsolete `tools/normalize-permissions.sh` helper.
- [x] Keep the world-writable repository safety check without mutating tracked file modes.
- [x] Update setup/troubleshooting documentation to make Git/Linux modes authoritative.
- [x] Add regression coverage for tracked executable modes / absence of bulk normalization.
- [x] Run the complete release gate; exact review-head Validate checks passed before PR #20 merged.
- [x] Present the review PR; PR #20 was merged by the owner as `f72973e764560a4102b7291495fa0fb93effe434`.

## Completed review block — Issue #12: robust installation update

Purpose: make the installed checkout recover safely when a squash-merged review branch has been deleted remotely, and reconcile the accepted Llama Dispatcher provenance checkpoint.

- [x] Reproduce the deleted-upstream failure from the real WSL update attempt.
- [x] Preserve fast-forward-only and clean-working-tree safety.
- [x] Fetch/prune before update and fall back to `main` only when the current `origin` tracking branch no longer exists.
- [x] Preserve the old local review branch; do not reset or delete it.
- [x] Add a focused Git smoke test for the deleted-upstream recovery path.
- [x] Advance the pinned Llama Dispatcher revision to merged provenance checkpoint `84efaa41684ff11a0fcb7266edf5cbf35efb7bad`.
- [x] Update operator documentation/state/changelog together.
- [x] Complete the release gate and review PR; PR #13 was merged as `1505a8dcce7b5bc94489913b20a5371ba7357d9a`.

## Completed review block — Issue #14: reproduce the working Intel SYCL stack

Purpose: make a fresh supported WSL installation reproduce the Intel SYCL / Level Zero environment already proven on the ThinkPad, without reintroducing the obsolete NEO 24.39 package generation.

Accepted baseline:

- Ubuntu 24.04 under WSL2.
- Intel NEO 26.31 with `libze-intel-gpu1 26.31.39395.14`.
- Level Zero loader/development packages 1.32.
- oneAPI 2025.3.3.
- Full-offload Gemma 4 26B-A4B inference is stable; 16K and 32K smoke tests complete successfully, with high transient model-load memory pressure returning to substantially lower steady-state use.
- Vulkan/DZN is a separate Issue #9 path and must not be changed by this block.

Implementation checklist:

- [x] Replace the historical Intel Noble client repository/package path with Intel's current Ubuntu 24.04 `intel-graphics` PPA path.
- [x] Install the current compute/development package set required by the proven Level Zero/SYCL workflow, centered on `libze-intel-gpu1`, `libze1`, `libze-dev`, `intel-opencl-icd`, `intel-ocloc`, and `clinfo`.
- [x] Keep Intel GPU runtime provisioning and oneAPI compiler/toolchain provisioning logically separate in the installer.
- [x] Prevent `setup sycl` from reinstalling the obsolete `intel-level-zero-gpu` package or silently downgrading a working current NEO stack.
- [x] Record/verify the effective Intel GPU runtime and oneAPI versions after setup.
- [x] Add focused smoke coverage for the repository/package selection semantics without requiring Intel hardware in CI.
- [x] Update runtime documentation and version/provenance configuration together.
- [x] Run focused checks and the complete repository release gate.
- [x] On the real ThinkPad, run the updated SYCL setup against the existing NEO 26.31 installation, verify no downgrade/replacement occurs, repeat it for idempotence, and confirm full-offload inference still works.
- [x] Present the coherent review PR without merging; merge only after explicit owner approval.

Checkpoint: PR #18 was merged as `420fe61d2cd98d7e438169ea629cb1581b6d676d`; the real ThinkPad setup/idempotence validation is recorded complete above.

## Completed investigation block — Issue #9: WSL hardware Vulkan / DZN

Purpose: determine whether hardware Vulkan through Mesa DZN can improve ThinkPad local-inference performance and/or operational quality while preserving the stable Intel SYCL / Level Zero path as the known-good fallback and comparison baseline.

Accepted comparison baseline from Issue #8:

- NEO 26.31 + oneAPI 2025.3.3 is functionally stable with full Intel iGPU offload.
- llama.cpp v0.4.1 / commit `b29c606e2` is validated on the working stack.
- Gemma 4 26B-A4B QAT MoE is the preferred comparison model; a representative v0.4.1 Level Zero run measured 53.48 tok/s prompt throughput and 3.79 tok/s generation.
- Vulkan is therefore a performance/stability/operability comparison, not a recovery path for a broken SYCL backend.

Investigation checklist:

- [x] Capture the pre-test Windows/WSL/Vulkan provenance and software-only `llvmpipe` baseline.
- [x] Export the complete Ubuntu WSL distribution before the first Mesa/DZN mutation.
- [x] Preserve the working NEO 26.31 + oneAPI 2025.3.3 SYCL environment unchanged.
- [x] Build Mesa 26.2.3 DZN side-by-side in a user-local experiment directory without replacing system Mesa.
- [x] Select the experimental DZN ICD explicitly and prove the Intel Meteor Lake device `0x8086:0x7d55` is hardware-backed; `llvmpipe` alone remains failure.
- [x] Prove explicit Intel/NVIDIA device identity and selection; DZN exposes both Intel Arc Pro `0x8086:0x7d55` and RTX 500 Ada `0x10de:0x28ba`.
- [x] Build the same llama.cpp v0.4.1 source as an independent Vulkan slot and verify `llama-server --list-devices` through DZN.
- [x] Run real Intel Vulkan inference with Gemma 4 26B-A4B and preserve the correctness boundary: model loading succeeds from native WSL storage, but Flash Attention produces repeated `<unused49>` output.
- [x] Re-test the Gemma correctness boundary on current llama.cpp build 11064 / commit `a894dae9`; the Flash-Attention corruption remains.
- [x] Isolate Flash Attention from KV quantization: Gemma with FA off + F16 V cache answers correctly, while FA on + F16 V cache again produces `<unused49>`; the FA-off workaround is operationally unusable because of memory pressure.
- [x] Run Qwen 3.6 35B-A3B as a control: Vulkan/DZN + Flash Attention produces correct text, proving the DZN/Vulkan backend and FA are not globally broken, but measured throughput remains unexpectedly low.
- [x] Record the native-WSL-storage finding: the large GGUF failed to load from `/mnt/c` with `read error: Bad address`, while the same file loaded successfully and much faster from the WSL filesystem; SYCL model loading also improved visibly from native WSL storage.
- [x] Preserve representative Dispatcher measurements and qualitative memory/stability observations in `runtimes/local-inference/TUNING.md`; do not claim precise load-time/RAM accounting until startup-memory telemetry exists.
- [x] Decide provisioning: do not integrate experimental DZN into the normal AI Workstation installer yet; keep the proven side-by-side path as controlled evidence until correctness/performance is good enough to justify productizing it.
- [x] Compare the practical result with SYCL: hardware Vulkan enablement is successful, but the current Gemma FA correctness issue and Qwen performance prevent Vulkan/DZN from replacing the accepted SYCL baseline.
- [x] Document the Issue #9 result and upstream-related boundaries in the tuning guide.
- [x] Run the exact-head repository merge gate and squash-merge the owner-approved review PR.

Checkpoint: PR #16 passed the exact-head `Validate` workflow at `7af161d543c5f18e47509db12f1bdd191ee8b19a` and was squash-merged to `main` as `19be08a08f7b747daa954649dfc143a7b9e0e755`. Issue #9 concludes with hardware Vulkan/DZN proven under WSL but not selected as the normal laptop backend because Gemma 4 Flash-Attention correctness and Qwen 3.6 performance/memory remain limiting.

## Completed review block — Issue #5: host-local inference onboarding

Purpose: onboard optional `llama.cpp` and Llama Dispatcher operation on the WSL/Linux host without duplicating the Dispatcher's model, benchmark, evaluation, or metrics responsibilities.

Owner-approved decisions for this block:

- `llama.cpp` and Llama Dispatcher run directly on the WSL/Linux host, not in containers.
- Local inference is optional; remote-only AI Workstations remain valid.
- Llama Dispatcher continues to own profiles, ensembles, benchmark/eval execution, and metrics history.
- Dispatcher instances under `instances/<name>` are user-owned; AI Workstation installs the generic Dispatcher runtime but does not clone, rewrite, reset or update machine-specific instances.
- Hardware/backend choice is explicit configuration. AI Workstation verifies prerequisites but does not silently invent a backend.
- AI Workstation pins a tested default `llama.cpp` source revision, while multiple llama.cpp revisions/build configurations may coexist for controlled comparisons.
- llama.cpp builds use human-readable slot names plus machine-readable manifests; an existing slot name must never silently change meaning.
- One shared llama.cpp Git/object cache feeds independent detached worktrees/build directories so parallel test builds do not require full duplicate clones.

Implementation checklist:

- [x] Create Issue #5 and branch `agent/local-inference-onboarding` from current `main`.
- [x] Record the owner-approved placement and responsibility boundaries before implementation.
- [x] Add durable machine-local enablement/configuration for optional local inference.
- [x] Add a pinned host-local multi-build `llama.cpp` source/build/install workflow, starting with Vulkan and leaving clean backend extension points.
- [x] Add reproducible Llama Dispatcher checkout plus `uv` environment synchronization.
- [x] Keep Dispatcher instance repositories at the existing user-owned `instances/<name>` boundary without copying their configuration semantics into AI Workstation.
- [x] Expose install/status/verify/use and llama.cpp build selection through the AI Workstation operator surface.
- [x] Keep the default/remote-only path unchanged when local inference is not enabled.
- [x] Update central versions, local-inference documentation, smoke tests, CI and release checks together.
- [x] Run focused verification and the repository release gate in Ubuntu 24.04 CI on the coherent review candidate.
- [x] Present Draft PR #6 without merging; exact-head merge-gate verification remains after explicit owner approval.
- [x] Run the first real ThinkPad WSL/Vulkan installation: the pinned build succeeds, but WSL Vulkan exposes only Mesa `llvmpipe`; separate D3D12/OpenGL testing confirms the Intel Arc Pro itself is hardware-accelerated in WSL.
- [x] Add a parallel WSL2/Ubuntu 24.04 Intel SYCL provisioning/build path pinned to the oneAPI 2025.3 series, while retaining the Vulkan build as a controlled baseline.
- [x] Run real ThinkPad WSL/SYCL installation, device verification, managed-service startup and model inference. The pinned Level Zero path succeeds with minimal GPU offload but fails at higher offload; a current llama.cpp/OpenCL control path succeeds with full offload. Backend performance/stability acceptance is deliberately split into follow-up Issues #8 and #9.
- [x] Harden llama.cpp build validation so a freshly built `llama-server` must pass `--version` before a slot is reported ready.
- [x] Pin the Dispatcher runtime fixes found during hardware acceptance: tolerate non-object JSON logs from current llama.cpp and clean up child/router processes after orchestrator exceptions.

Checkpoint: PR #6 proved the **local-inference infrastructure** end-to-end on real hardware and was squash-merged to `main` as `76ebf7675188d3159bc6e1cea4146fdf0ee8dcb9`. Issue #5 is complete. The checkpoint accepts immutable parallel llama.cpp build slots, explicit selected build, machine-local model/instance/ensemble configuration, managed systemd lifecycle, pinned Dispatcher, and successful real model responses. Subsequent Issue #8 work established stable full-offload Intel SYCL/Level Zero under WSL with NEO 26.31 and oneAPI 2025.3.3; performance remains modest. Hardware Vulkan/DZN comparison continues separately in Issue #9, while Issue #14 owns the stale SYCL guest-runtime provisioning path. OpenCL full-offload remains a diagnostic control, not the target architecture.

## Current focus — align the repository after ContextCanon onboarding

Purpose: make the repository structure, ContextCanon Node structure, current project state, and next architectural decisions mutually consistent before adding further AI runtimes.

### 1. Establish the durable plan

- [x] Record the post-onboarding follow-up work in `PLAN.md` before implementation starts.
- [x] Keep the ContextCanon framework question separate from the AI Workstation implementation work.

### 2. Raise the ContextCanon framework question

The post-onboarding findings are now tracked in ContextCanon as two separate framework issues:

- `SomeSunlight/context-canon#14` — recommend filesystem alignment with Context Node boundaries without making filesystem layout semantic.
- `SomeSunlight/context-canon#15` — define Parent/Child change authority so inheritance does not implicitly grant upward write scope.

- [x] Document the proposed principle that filesystem layout should, where practical, align with Context Node structure even though ContextCanon itself must not depend on that layout.
- [x] Clarify Context inheritance versus modification authority: a Child must see and obey Parent/ancestor Contexts, but inheritance should not implicitly grant authority to modify those Parents.
- [x] Clarify the expected workflow when work in a Child discovers that a Parent rule or Parent-owned decision should change: propose/escalate the cross-Node change and deliberately expand the change scope rather than silently editing upward.
- [x] Record the resulting ContextCanon guidance consumed by AI Workstation: Development Workflow 0.3.0-draft is accepted at the root and all eight semantic Parent/Child relationships were reviewed and propagated with ContextCanon 0.7.3.
- [x] Add the resulting ContextCanon issue references here.

### 3. Implement the AI Workstation post-onboarding alignment in a review PR

Do this only after the ContextCanon issue exists and its immediate implications for this repository are understood. Keep the work on a review branch and do not merge without explicit project-owner approval.

#### 3.1 Align physical layout with Context Nodes

- [ ] Co-locate the existing Ansible implementation with the `Bootstrap -> Ansible host configuration` Node instead of keeping the Node under `bootstrap/ansible` while implementation lives separately under top-level `ansible/`.
- [ ] Co-locate Goose runtime implementation with `compose/goose/` instead of leaving Node context in the Child directory while the main Compose definition lives at the Parent level.
- [ ] Co-locate Open WebUI runtime implementation with `compose/open-webui/` for the same reason.
- [ ] Update every affected path reference in bootstrap/install scripts, `aiw`, tests, CI, documentation, configuration, and tooling.
- [ ] Preserve executable modes and Linux-native repository behavior during moves.
- [ ] Regenerate and validate ContextCanon-owned generated material after authored Node locations or references change; do not hand-edit generated Context files.
- [ ] Verify with concrete agent tasks that files inside the moved areas naturally resolve to the intended Child Contexts.

#### 3.2 Tighten the existing Context descriptions without redesigning the Node tree

- [ ] Add a short Bootstrap overview explaining that the Node groups the full host-foundation provisioning chain: Windows/WSL lifecycle, minimal Linux bootstrap, and idempotent Ansible host configuration.
- [ ] Expand the `aiw operator interface` overview to capture the stable UX contract: `aiw` is the discoverable/interactive operator surface while direct subcommands remain stable automation entry points.
- [ ] Reconcile stale Child Parent labels such as `Application runtimes` versus `Containerized application runtimes` if they remain after regeneration.
- [ ] Clean up the Development Workflow Source rationale wording without changing its intended meaning.
- [ ] Apply any relevant ContextCanon guidance from step 2 about filesystem alignment and Parent/Child modification scope.

#### 3.3 Create and populate durable current-state documentation

- [ ] Add root `STATE.md` as the compact accepted operational baseline.
- [ ] Record the currently supported host/guest platform and the verified foundation state without duplicating stable Context rules unnecessarily.
- [ ] Record Goose as an integrated sandboxed runtime and the verified workspace-isolation model.
- [ ] Record Open WebUI as an integrated persistent runtime with OpenRouter connectivity.
- [ ] Record the existing Open WebUI provider-recovery mechanism and its known limitation: full provider reset also removes/requires recreation of previously stored local provider connections.
- [ ] Record the current Windows-host local-model connectivity limitation: WSL NAT addressing can change across restarts, making address/subnet-specific firewall configuration fragile while llama.cpp remains on Windows.
- [ ] Distinguish accepted facts from proposed future architecture; do not promote untested llama.cpp/Dispatcher migration decisions into State.

#### 3.4 Verify the structural/documentation PR

- [ ] Run focused path/reference and smoke checks while restructuring.
- [ ] Run `./tools/release-check.sh` on the coherent review candidate.
- [ ] Confirm ContextCanon generated output has zero unintended drift at the merge gate.
- [ ] Review the final diff for accidental duplicate old/new paths and stale navigation text.
- [ ] Present the coherent PR for project-owner review.
- [ ] After explicit approval, require the exact merge head to pass the complete project verification before merging.
- [ ] After merge, update `STATE.md` and this plan with the actual accepted baseline before starting the next development block.

## Next architecture block — configurable installation scope

Purpose: make AI Workstation usable on machines that should not install every runtime while keeping one reproducible installation specification.

- [ ] Define which host-foundation components are mandatory on every AI Workstation.
- [ ] Define applications/runtimes as selectable modules rather than assuming all tools are installed everywhere.
- [ ] Decide the durable configuration model for module selection (for example explicit profiles and/or per-module enablement) before implementing it.
- [ ] Ensure reruns remain idempotent when a module is enabled, disabled, absent, or newly added.
- [ ] Define status output so `aiw` distinguishes not-installed-by-choice, installed/stopped, running, and broken states.
- [ ] Decide how clean removal/deactivation of an optional module differs from destructive data deletion.
- [ ] Cover at least the current Goose and Open WebUI runtimes and leave a clean extension point for future modules.
- [ ] Update documentation and automated tests together with the implementation.

## Next architecture block — local inference placement

Purpose: validate the selected WSL/Linux-host implementation on the real machines before promoting it from working direction to accepted architecture, and determine the best backend/runtime details per hardware class.

### Desktop validation

- [ ] Establish a comparable Windows baseline for the existing llama.cpp setup on the RTX 3090 workstation.
- [ ] Install/build an equivalent llama.cpp runtime directly on the WSL Linux host with the appropriate NVIDIA/CUDA backend.
- [ ] Compare model loading, usable VRAM/RAM, prompt processing, token throughput, context behavior, startup/operation, and stability.
- [ ] Verify access from Open WebUI/containerized tools to the WSL-hosted llama.cpp service without the Windows-host firewall bridge.

### Laptop validation

- [x] Establish a real managed-service smoke checkpoint on the ThinkPad and preserve both Vulkan and SYCL build paths without claiming backend acceptance.
- [x] Preserve the Issue #8 Intel SYCL/Level Zero findings in a runtime tuning guide, including the host-driver effect, NEO 24.39 -> 26.31 allocation fix, WSL/Sysman limitation, current performance caveat, and controlled-test method.
- [x] Link the tuning guide from the local-inference runtime documentation without promoting experimental backend findings into permanent Context rules.
- [x] Close Intel SYCL/Level Zero acceptance in Issue #8: NEO 26.31 removed the fatal allocation failure, full offload is stable with both the pinned and v0.4.1 llama.cpp paths, and performance is adequate for comparison but not compelling enough to stop backend evaluation.
- [x] Complete Issue #9 hardware Vulkan/DZN investigation: real Intel hardware Vulkan is proven through user-local Mesa 26.2.3 DZN, but Gemma 4 Flash Attention corrupts output and the Qwen control path is too slow/memory-heavy to replace SYCL today.
- [ ] Continue laptop placement comparison from the accepted SYCL baseline; retain DZN as controlled evidence and revisit it when upstream correctness/performance changes materially.
- [ ] Test the WSL memory ceiling only if measurements show it is a material constraint; avoid speculative host-memory tuning.
- [ ] Modernize the AI Workstation Intel guest-runtime provisioning in Issue #14 so normal SYCL setup/build commands preserve the proven NEO 26.31 package generation.

### Placement decision

- [ ] Confirm llama.cpp WSL/Linux-host placement after the real laptop and desktop measurements.
- [ ] Confirm Llama Dispatcher WSL/Linux-host placement unless testing reveals a concrete Windows-only advantage.
- [ ] Keep local inference non-containerized unless measured operational evidence justifies adding a container layer.
- [ ] If Windows-hosted inference remains supported, make Windows/WSL network discovery and firewall configuration dynamic, idempotent, and installer-owned instead of relying on manual chat instructions.
- [ ] Add the resulting stable architecture decision to the appropriate Context Node only after it is tested and accepted.

## Next runtime-quality block — Open WebUI provider handling

Purpose: replace the currently coarse recovery path with a less destructive operational workflow.

- [ ] Keep the existing full provider reset as an emergency recovery path until a safer replacement is verified.
- [ ] Investigate using the supported Open WebUI configuration/API surface to disable an unreachable provider while preserving its URL, credentials/options, and other stored connection settings.
- [ ] Add corresponding enable/disable operations to the operator workflow if the supported interface is stable enough.
- [ ] Ensure a temporarily unavailable local provider cannot make normal Open WebUI administration unusable.
- [ ] Preserve accounts, chats, uploads, persistent volumes, and unrelated provider configuration during routine recovery.

## Future runtimes

Do not create permanent Context Nodes solely from this list. Promote an item into repository architecture/Context when implementation becomes a real planned development block with sufficient repository evidence.

- [ ] Hermes Agent — design the sandbox and delegated-access model before integration.
- [ ] ComfyUI — rebuild as a reproducible Linux/WSL runtime, preferably with modern uv-based Python environment management where appropriate.
- [ ] Local service gateway / Caddy — introduce only when concrete routing/TLS/service-discovery requirements justify it.

## Architectural direction under evaluation

The current working hypothesis is intentionally not yet a permanent Rule:

- Windows remains the primary human desktop/workstation environment for applications such as IDEs, photography and device tooling.
- WSL/Linux becomes the reproducible AI runtime platform.
- Sandboxed/autonomous agents run in containers when that isolation boundary is useful.
- Hardware-heavy local runtimes may run directly on the WSL Linux host when that gives simpler and more reliable GPU access than adding a container layer.
- AI runtimes need not run continuously; it is acceptable for them to exist only while WSL/the AI Workstation is active.

Validate this direction through the local-inference and optional-module blocks above before turning it into durable Context rules.

## ContextCanon explicit Node-name migration — Issue #1

Purpose: keep this real-use ContextCanon project compatible with the explicit machine-metadata boundary introduced by ContextCanon PR #18 / Issue #25 without changing any project semantics.

- [x] Migrate all nine authored `CONTEXT.src.md` Nodes to explicit `ctx:node name="..."` metadata, preserving each existing H1-derived canonical name exactly.
- [x] Leave human Markdown H1 wording unchanged and do not hand-edit compiler-managed `.context/sources/` or generated `CONTEXT/references/` copies.
- [x] Rebuild generated ContextCanon output using exact tested ContextCanon head `fbca8b2f5a6bfcf2aa040917e201674562d5c983`.
- [x] Require `contextcanon check --all .` and diff hygiene on the coherent candidate.
- [x] Present the migration on a review PR; do not merge without explicit project-owner approval.

Checkpoint: Issue #1 records this bounded compatibility migration on branch `agent/explicit-context-node-names`. Repository inspection corrected the earlier informal count from eight to nine authored Nodes before implementation began.

Issue #1 implementation checkpoint: all nine authored Nodes now carry explicit canonical `ctx:node name` metadata. PR #2 was squash-merged to `main` as `db65575c415f18a8c81db6e1bfcb32a50a56fb32` and Issue #1 closed. Before that merge, the same review branch also completed the real ContextCanon 0.7.3 maintenance step: Development Workflow advanced to 0.3.0-draft, all eight Parent/Child relationships were reviewed and propagated, generated Context was rebuilt, `contextcanon check --all .` was clean across all nine Nodes, and the resulting maintenance flow was idempotent.


## Post-merge baseline — Issue #3

Purpose: close the inherited Development Workflow post-merge checkpoint after PR #2 without starting the larger repository-alignment block.

- [x] Record PR #2 squash merge `db65575c415f18a8c81db6e1bfcb32a50a56fb32` as the accepted ContextCanon migration/maintenance baseline.
- [x] Record the completed Development Workflow 0.3.0-draft Source update and all eight reviewed Parent/Child propagation steps.
- [x] Add a compact root `STATE.md` limited to facts proven by this maintenance run.
- [x] Leave the richer runtime/architecture State population and repository restructuring in their existing planned blocks.

Checkpoint: Issue #3 is documentation-only baseline reconciliation after PR #2; it does not change runtime or Context semantics.
