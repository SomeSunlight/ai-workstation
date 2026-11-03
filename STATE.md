# AI Workstation Current State

## Accepted PR #42 baseline (2026-11-03)

[AI Workstation PR #42](https://github.com/SomeSunlight/ai-workstation/pull/42)
was owner-tested ("tested successfully") and merged into `main` on
2026-11-03 as `49e8d67246763b83502f58fb4f6628e0801c76fb`
(final PR head `a02eb558d333a1695ecdfdec64ae31b76daedadf`).
It carries the accepted post-#37 PLAN/STATE/README/CHANGELOG checkpoint,
two concise project-specific rules in authored `CONTEXT.src.md`, and
compiler-generated root and child Official Context packages
(compiler metadata `0.8.0`). Those rules require general-purpose,
English-language behavior and a compact, self-explaining operator UX.
It also accepts the bounded Windows installer staging retry/fresh-root
fix (#43), with owner testing and successful Ubuntu/Windows CI
[run #41637116958](https://github.com/SomeSunlight/ai-workstation/actions/runs/41637116958).

Independent post-merge verification under issue #40 used the matching
ContextCanon **CLI 0.10.0** (internal compiler **0.8.0**, SHA
`786c50957c4c06f9209ebacfa021609b592c0b07`). In Linux
[workflow #41641727621](https://github.com/SomeSunlight/ai-workstation/actions/runs/41641727621),
`contextcanon build --all .` made **no changes** across all nine Nodes;
`contextcanon check --all .` reported **nine OK** and all eight
Parent/Child relationships current. The first attempted check with an older
CLI 0.8.0/internal compiler 0.6.0 falsely reported nine-node drift.
That incompatible generated candidate was rejected and removed from the
current review tree; inherited Development Workflow rules are intact.
A correctly pinned read-only CI gate and this closure are proposed in
[PR #44](https://github.com/SomeSunlight/ai-workstation/pull/44), not yet
merged. No production Caddy/Dispatcher/Strata or container service
was migrated by PR #42.

**Next priority:** issue [#39](https://github.com/SomeSunlight/ai-workstation/issues/39)
(usable, separately isolated Goose/Hermes Docker Workbench after host
prerequisite review), then issue
[#41](https://github.com/SomeSunlight/ai-workstation/issues/41)
(generic Caddy management and owner-approved per-client authentication
cutover with the working gateway preserved). The Process Compose
production hold remains active.

## Accepted repository baseline

PR #2 was squash-merged to `main` as `db65575c415f18a8c81db6e1bfcb32a50a56fb32`. Issue #1 is complete.

This baseline contains nine authored ContextCanon Nodes: the root plus eight nested Nodes. Canonical Node names use explicit `ctx:node name` metadata.

PR #6 was squash-merged to `main` as `76ebf7675188d3159bc6e1cea4146fdf0ee8dcb9`. It establishes the accepted host-local inference **infrastructure checkpoint**. Llama Dispatcher PR #6 subsequently added explicit effective llama.cpp runtime provenance and was squash-merged as `84efaa41684ff11a0fcb7266edf5cbf35efb7bad`; AI Workstation now pins that accepted Dispatcher checkpoint.

The earlier accepted PR #20 checkpoint is `f72973e764560a4102b7291495fa0fb93effe434`. PR #13 (`1505a8dcce7b5bc94489913b20a5371ba7357d9a`) accepts deleted-review-branch update recovery. PR #18 (`420fe61d2cd98d7e438169ea629cb1581b6d676d`) accepts current Intel NEO provisioning after the real ThinkPad setup/idempotence test. PR #20 removes the legacy repository permission normalizer; tracked executable modes remain Git-owned.

PR #22 remains an accepted baseline, squash-merged as `e4f6ee86e746241ea6630bb759b971b7e47012b7` on 2026-10-07 after the owner reported installation testing complete and approved merging. Exact review head `f4c5ca304a2ccaf98934befa1f8662a7f0c3071a` passed Validate run `37532821370` and the repeated release check. Goose/Open WebUI application updates are menu-accessible and select stable image versions independently from workstation updates. Open WebUI updates include a stopped-volume backup.

PR #24 (merged as `9bd87860571b972cf33a41a49e213a55ee22dfae`) removed forced OpenRouter injection for Goose in favor of native provider/model configuration and protected Goose-only environment settings.

PR #28 was owner-tested successfully on Windows/WSL and squash-merged on 2026-10-09 as `f0a8b553d22b903c3431fa36aea433e7f5654dbc`. It accepts recovery-first onboarding, dual Linux launcher names, and an opt-in YAML-backed menu command preview.

**Accepted host-platform checkpoint:** PR #36 was owner-accepted and squash-merged on 2026-11-01 as `13eb053becde1a66de9d275e25cbe1fb716062ab`. It adds the WSL/native-Ubuntu 24.04 host-mode first slice and shared Linux host preflight without a full real native-host acceptance. The previous accepted Windows/WSL launcher checkpoint was PR #32 (`b33949ccd72352a26c305d46f60b643d6a60adad`, 2026-10-14). The normal supported production path remains Windows 11 + WSL2; native Ubuntu 24.04 remains experimental until a real dedicated systemd host test.

## Accepted native-services and client-identity checkpoint (2026-11-03)

[AI Workstation PR #37](https://github.com/SomeSunlight/ai-workstation/pull/37)
was **owner-tested and squash-merged** into `main` on 2026-11-03 as
`da108899518d261a960edae9ff8867a6e57bb459`.
The owner exercised the native Windows Process Compose CLI lifecycle:
private initialization, pinned checksum-verified binary install,
configuration validation, named client/DPAPI key registration,
harmless `aiw-smoke` **start → status → logs → TUI → stop**, all
successful. Independent Ubuntu/Windows CI also exercised real native
Process Compose `up/status/logs/down` and double-start/unknown-stop
refusal. This is acceptance of **the first safe operator tooling slice**,
not acceptance of real production process ownership.

**Architectural responsibilities:** AI Workstation installs/configures
software and offers platform entrypoints; Process Compose owns only
native host processes (Windows binary on Windows, Linux binary inside
WSL or on native Linux); Docker Compose independently owns agent and
container lifecycles. Client IDs and credentials are operator-selected,
host-local; generated `clients.json` holds only S02 token hashes.
Native Windows Process Compose requires AIW's headless OS launcher
because upstream v1.124.0 has **no `--detached`** on Windows.
Native Linux full installation remains **experimental** until #33 real
host acceptance; CLI compatibility tests do not imply full host support.

**Production hold:** official Process Compose v1.124.0 Linux AMD64 build
reports Go 1.27.0, before the Go 1.27.2 `html/template` fixes.
This alone does not prove exploitable Process Compose code paths.
AIW's explicit launch guard remains
`production_adoption_blocked: true`; native *production* service
takeover must wait for a verified patched build and separate review.

**Not yet adopted:** the existing native Caddy, Strata, Dispatcher
and Open WebUI host services remain controlled by their current owner
setup. AI Workstation does **not yet** install or manage the live Caddy
gateway. The legacy shared `home-gateway` bearer still exists until
the owner-approved S02/Caddy trust boundary change; generating new
per-client secrets does **not** activate them in the running services.
Next gateway work is tracked in
[#41](https://github.com/SomeSunlight/ai-workstation/issues/41)
(alongside #34); the independent Docker agent Workbench is
[#39](https://github.com/SomeSunlight/ai-workstation/issues/39).
Multiple explicit Goose mounts remain [#38](https://github.com/SomeSunlight/ai-workstation/issues/38).
No manual Caddy cutover or secret redistribution is implied by this merge.

## Accepted local-inference infrastructure

Local inference is optional. When enabled, `llama.cpp` and Llama Dispatcher run directly on the WSL/Linux host rather than in containers; remote-only AI Workstations remain valid.

AI Workstation now owns reproducible llama.cpp source/build slots, exact build provenance and selection, the generic pinned Dispatcher checkout, machine-local model/instance/ensemble selection, and managed systemd lifecycle. Dispatcher instances under `instances/<name>` remain user-owned independent Git repositories and keep their runtime databases/generated router state local.

The real ThinkPad acceptance run completed the managed path end-to-end:

`AI Workstation service → Dispatcher → llama.cpp router → child llama-server → real model response`.

This checkpoint accepts the infrastructure, **not a final GPU backend or placement decision**. Current backend evidence is:

- Intel SYCL/Level Zero under WSL is now functionally stable with the current Intel guest runtime generation: NEO 26.31 plus oneAPI 2025.3.3 runs the Meteor Lake iGPU at full model offload.
- The decisive fix was the guest-runtime migration from the old 24.39 generation to 26.31; updating only the Windows host driver improved the OpenCL control path but did not remove the earlier Level Zero allocation failure.
- Both the pinned llama.cpp baseline and v0.4.1 completed real Level Zero inference. On the Gemma 4 26B-A4B MoE profile, a representative v0.4.1 run reached about 3.79 tok/s generation; performance remains modest but backend stability is no longer the blocking question.
- The earlier multi-minute first-request observation was not representative of the later 26B-A4B experience; subsequent first responses can arrive quickly.
- SYCL through OpenCL remains a diagnostic control rather than the preferred architecture.
- WSL hardware Vulkan is now proven through a side-by-side user-local Mesa 26.2.3 DZN build. DZN exposes the Intel Arc Pro iGPU explicitly under WSL and real llama.cpp inference runs through it.
- DZN is not accepted as the normal laptop backend yet. Gemma 4 26B-A4B with Flash Attention produces repeated `<unused49>` corruption on both tested llama.cpp revisions; the FA-off/F16-V workaround is correct but memory-prohibitive.
- Qwen 3.6 35B-A3B produces coherent output through DZN + Flash Attention, proving the backend is not generically broken, but current throughput is unexpectedly low and memory pressure is high.
- Large GGUF loading from `/mnt/c` failed on the DZN path with `read error: Bad address`; moving the same model to the native WSL filesystem fixed loading and made model startup visibly faster. SYCL loading also benefited from native WSL model storage.

Issue #8 is complete as a successful but performance-limited SYCL/Level Zero acceptance result. Issue #9 is complete as a successful hardware-Vulkan enablement experiment with a negative backend-selection result for now. Issue #14 provisioning is implemented and accepted through PR #18.

## Accepted ContextCanon maintenance state

The root `ai-workstation` Node uses Development Workflow `0.3.0-draft`. The Source update was reviewed and accepted with ContextCanon 0.7.3, then all eight semantic Parent/Child relationships were reviewed and propagated top-down.

The resulting Context was rebuilt, and the project owner verified `contextcanon check --all .` as `ok` for the root and all eight Child Nodes. Repeating the completed maintenance flow is idempotent.

`contextcanon.yaml` is the visible project-level Source discovery configuration; accepted Source and Parent package identities remain pinned locally in the consuming Nodes.

## Scope of this State file

This file records accepted checkpoints only. Broader operational state for Goose, Open WebUI, provider recovery and still-unresolved backend/placement decisions remains in `PLAN.md` or the linked Issues until separately reviewed and accepted.

## Native Linux status (not yet accepted)

Issue [#33](https://github.com/SomeSunlight/ai-workstation/issues/33) is **partially implemented**: [PR #36](https://github.com/SomeSunlight/ai-workstation/pull/36) merged the shared host-mode and preflight improvements into `main` on 2026-11-01. A complete Ubuntu 24.04 native systemd installation, idempotent rerun, Goose/Open WebUI operation and rollback have **not** been tested on real native Linux, so this platform is **not yet accepted as supported**. No rental/cloud setup is needed for current Speedy/Dispatcher work.

## Next planned work

Issue [#40](https://github.com/SomeSunlight/ai-workstation/issues/40)
now concerns only post-#42 independent ContextCanon verification and
documentation closure. The next **product work** is
[#39](https://github.com/SomeSunlight/ai-workstation/issues/39):
isolated Goose/Hermes containers and a usable host-local Workbench,
starting with an explicit Windows Docker/prerequisite and secret review.
Only subsequently address [#41](https://github.com/SomeSunlight/ai-workstation/issues/41):
reproducible Caddy installation, safe native process ownership and
independently authenticated S02 gateway clients. A patched Process Compose build, reversible process
ownership handoff, real-host tests and owner approval are required
**before any live Caddy/Strata/Dispatcher migration**. The current
working Caddy → authenticated Dispatcher → native Strata gateway is
the operational baseline and rollback. Real native Ubuntu host
validation remains deferred (#33). Reusable operator UX guidance
is proposed independently in
[ContextCanon #126](https://github.com/SomeSunlight/context-canon/issues/126);
its pinned parent Context is unchanged.

For laptop inference, treat Issue #8 as the accepted SYCL/Level Zero baseline and Issue #9 as the completed DZN/Vulkan evidence package; treat Issue #14 / PR #18 as the accepted provisioning checkpoint. The detailed backend findings and representative measurements are preserved in `runtimes/local-inference/TUNING.md`.
