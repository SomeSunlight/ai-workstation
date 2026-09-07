# AI Workstation Plan

This file is the durable recovery map for active and upcoming development work. Keep completed checkpoints checked as soon as they are genuinely complete. Use `STATE.md` for accepted current facts and this file for work that is still in progress or intentionally deferred.

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
- [ ] Record any resulting ContextCanon guidance or implementation change that AI Workstation should consume before its repository restructuring PR is finalized.
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

Purpose: decide empirically whether llama.cpp and the Llama Dispatcher should move from Windows into WSL/Linux before making Linux-first local inference an architectural rule.

### Desktop validation

- [ ] Establish a comparable Windows baseline for the existing llama.cpp setup on the RTX 3090 workstation.
- [ ] Install/build an equivalent llama.cpp runtime directly on the WSL Linux host with the appropriate NVIDIA/CUDA backend.
- [ ] Compare model loading, usable VRAM/RAM, prompt processing, token throughput, context behavior, startup/operation, and stability.
- [ ] Verify access from Open WebUI/containerized tools to the WSL-hosted llama.cpp service without the Windows-host firewall bridge.

### Laptop validation

- [ ] Establish a comparable Windows baseline on the 64 GB laptop with its Intel GPU/shared-memory constraints.
- [ ] Test the appropriate llama.cpp Intel/Linux backend under WSL before assuming parity with the Windows runtime.
- [ ] Measure the largest practical model, effective shared-memory availability, throughput, context behavior, and stability.
- [ ] Test whether the default WSL memory ceiling is a material limitation and, if necessary, evaluate an explicit WSL memory configuration without starving Windows.

### Placement decision

- [ ] Decide llama.cpp placement only after both machines have comparable measurements.
- [ ] Decide Llama Dispatcher placement; current preference is Linux/WSL unless testing reveals a concrete Windows-only advantage.
- [ ] If Linux/WSL wins, define local inference as a first-class non-containerized or deliberately containerized runtime based on measured operational simplicity and hardware access rather than forcing everything into Compose.
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

Issue #1 implementation checkpoint: all nine authored Nodes now carry explicit canonical `ctx:node name` metadata, generated ContextCanon output was rebuilt with the exact PR #18 head `fbca8b2f5a6bfcf2aa040917e201674562d5c983`, and `contextcanon check --all .` plus diff hygiene passed. Draft PR #2 now presents the migration for owner review; no merge is authorized.
