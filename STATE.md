# AI Workstation Current State

## Accepted repository baseline

PR #2 was squash-merged to `main` as `db65575c415f18a8c81db6e1bfcb32a50a56fb32`. Issue #1 is complete.

This baseline contains nine authored ContextCanon Nodes: the root plus eight nested Nodes. Canonical Node names use explicit `ctx:node name` metadata.

PR #6 was squash-merged to `main` as `76ebf7675188d3159bc6e1cea4146fdf0ee8dcb9`. It establishes the accepted host-local inference **infrastructure checkpoint**. The pinned Llama Dispatcher checkpoint was merged separately in `SomeSunlight/Llama_Dispatcher` PR #3 as merge commit `2f401efa75f8c9fcde939049868202d338a3366e`; AI Workstation pins the tested Dispatcher head `19e5798e2c7cc7bcf962f9c72c118c98560e042b`.

## Accepted local-inference infrastructure

Local inference is optional. When enabled, `llama.cpp` and Llama Dispatcher run directly on the WSL/Linux host rather than in containers; remote-only AI Workstations remain valid.

AI Workstation now owns reproducible llama.cpp source/build slots, exact build provenance and selection, the generic pinned Dispatcher checkout, machine-local model/instance/ensemble selection, and managed systemd lifecycle. Dispatcher instances under `instances/<name>` remain user-owned independent Git repositories and keep their runtime databases/generated router state local.

The real ThinkPad acceptance run completed the managed path end-to-end:

`AI Workstation service → Dispatcher → llama.cpp router → child llama-server → real model response`.

This checkpoint accepts the infrastructure, **not a final GPU backend or placement decision**. Current backend evidence is:

- Intel SYCL/Level Zero under WSL can run with minimal GPU offload, but higher offload currently fails during SYCL matrix compute with a memory-object allocation error.
- A current llama.cpp build exposed an additional direct Level Zero/Sysman startup crash; disabling llama.cpp's direct Level Zero API removes that startup crash but not the higher-offload compute failure.
- SYCL through OpenCL is a stable diagnostic control and has run the 12B Gemma model fully offloaded at `ngl=99`, `ctx=16384`; it is not the target architecture.
- WSL Vulkan currently exposes only Mesa `llvmpipe` even though separate D3D12/OpenGL tests prove hardware-accelerated Intel GPU access.

Intel SYCL/Level Zero acceptance, current driver/runtime provenance, unified-memory requirements and same-commit Windows↔WSL comparison are tracked in Issue #8. Hardware Vulkan/DZN work is tracked separately in Issue #9.

## Accepted ContextCanon maintenance state

The root `ai-workstation` Node uses Development Workflow `0.3.0-draft`. The Source update was reviewed and accepted with ContextCanon 0.7.3, then all eight semantic Parent/Child relationships were reviewed and propagated top-down.

The resulting Context was rebuilt, and the project owner verified `contextcanon check --all .` as `ok` for the root and all eight Child Nodes. Repeating the completed maintenance flow is idempotent.

`contextcanon.yaml` is the visible project-level Source discovery configuration; accepted Source and Parent package identities remain pinned locally in the consuming Nodes.

## Scope of this State file

This file records accepted checkpoints only. Broader operational state for Goose, Open WebUI, provider recovery and still-unresolved backend/placement decisions remains in `PLAN.md` or the linked Issues until separately reviewed and accepted.

## Next planned work

Continue from `PLAN.md` with an explicit issue-backed block. For laptop inference, use Issue #8 for Intel SYCL/Level Zero and Issue #9 for WSL Vulkan; do not reconstruct those investigations from chat history.
