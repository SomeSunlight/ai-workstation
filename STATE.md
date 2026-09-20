# AI Workstation Current State

## Accepted repository baseline

PR #2 was squash-merged to `main` as `db65575c415f18a8c81db6e1bfcb32a50a56fb32`. Issue #1 is complete.

This baseline contains nine authored ContextCanon Nodes: the root plus eight nested Nodes. Canonical Node names use explicit `ctx:node name` metadata.

PR #6 was squash-merged to `main` as `76ebf7675188d3159bc6e1cea4146fdf0ee8dcb9`. It establishes the accepted host-local inference **infrastructure checkpoint**. Llama Dispatcher PR #6 subsequently added explicit effective llama.cpp runtime provenance and was squash-merged as `84efaa41684ff11a0fcb7266edf5cbf35efb7bad`; AI Workstation now pins that accepted Dispatcher checkpoint.

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
- WSL Vulkan still requires independent hardware enablement/validation in Issue #9; software-only `llvmpipe` remains unacceptable.

Issue #8 is complete as a successful but performance-limited SYCL/Level Zero acceptance result. Issue #14 tracks the remaining stale AI Workstation SYCL package provisioning, and Issue #9 owns the Vulkan comparison.

## Accepted ContextCanon maintenance state

The root `ai-workstation` Node uses Development Workflow `0.3.0-draft`. The Source update was reviewed and accepted with ContextCanon 0.7.3, then all eight semantic Parent/Child relationships were reviewed and propagated top-down.

The resulting Context was rebuilt, and the project owner verified `contextcanon check --all .` as `ok` for the root and all eight Child Nodes. Repeating the completed maintenance flow is idempotent.

`contextcanon.yaml` is the visible project-level Source discovery configuration; accepted Source and Parent package identities remain pinned locally in the consuming Nodes.

## Scope of this State file

This file records accepted checkpoints only. Broader operational state for Goose, Open WebUI, provider recovery and still-unresolved backend/placement decisions remains in `PLAN.md` or the linked Issues until separately reviewed and accepted.

## Next planned work

Continue from `PLAN.md` with an explicit issue-backed block. For laptop inference, treat Issue #8 as the accepted SYCL/Level Zero baseline, use Issue #9 for WSL Vulkan comparison, and use Issue #14 for SYCL provisioning cleanup; do not reconstruct those investigations from chat history.
