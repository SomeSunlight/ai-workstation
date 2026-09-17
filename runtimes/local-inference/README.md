# Host-local inference

This runtime integrates `llama.cpp` and Llama Dispatcher directly on the WSL/Linux host. It deliberately does **not** containerize either component.

AI Workstation owns reproducible installation, pinned code revisions, host prerequisites and the operator entry point. Llama Dispatcher remains responsible for model profiles, engine configuration, ensembles, benchmark/eval execution and its metrics database.

Local inference is optional. A remote-only AI Workstation does not need to configure or install this runtime.

## Laptop Vulkan first run

From an already installed AI Workstation:

```bash
aiw local-inference setup laptop-vulkan
```

This one command:

1. writes machine-local configuration to `~/.config/ai-workstation/local-inference.env`;
2. installs the Ubuntu build prerequisites for the selected backend;
3. clones `llama.cpp` at the pinned AI Workstation revision and builds it with Vulkan;
4. clones Llama Dispatcher at its pinned AI Workstation revision and runs `uv sync --frozen`;
5. clones `SomeSunlight/Llama_Dispatcher_Laptop` into the Dispatcher's existing `instances/Laptop` location;
6. enumerates llama.cpp devices and runs the Dispatcher's compile-only check for `thinkpad`.

The runtime code lives below:

```text
~/.local/share/ai-workstation/local-inference/
├── llama.cpp/
└── Llama_Dispatcher/
    └── instances/
        └── Laptop/
```

The instance repository is intentionally *not* reset or updated by AI Workstation after it is attached. It is machine-owned configuration and may contain deliberate local/committed changes. The public Dispatcher and llama.cpp code checkouts, in contrast, are pinned by `config/versions.json`.

## Commands

```bash
aiw local-inference status
aiw local-inference verify
aiw local-inference config
aiw local-inference serve
```

For direct access to existing Dispatcher modes without inventing a second benchmark interface:

```bash
aiw local-inference dispatcher bench PROFILE [DISPATCHER/LLAMA OVERRIDES...]
aiw local-inference dispatcher eval PROFILE DATASET [DISPATCHER/LLAMA OVERRIDES...]
aiw local-inference dispatcher serve --ensemble thinkpad
```

AI Workstation injects only the WSL `llama.cpp` binary directory and configured instance. All model and performance parameters continue to come from Llama Dispatcher.

## Important boundary: model paths

The existing Laptop instance was authored for Windows and its model profiles currently contain Windows paths. AI Workstation does not rewrite those profiles behind the Dispatcher's back. Before real inference under WSL, the selected instance profile must point to a model path visible from WSL.

The binary path is different: AI Workstation supplies `--bin-dir` as the Dispatcher's highest-priority CLI override, so the instance engine can retain its historical Windows binary path without being mutated merely for installation testing.

## Backends

The first implemented backend is Vulkan because it is the selected ThinkPad path. CUDA is already a build extension point when an appropriate WSL CUDA toolkit (`nvcc`) is present. Automatic CUDA toolkit provisioning and SYCL/oneAPI provisioning are intentionally deferred until those paths are tested as their own coherent blocks.

For Vulkan, the runtime uses the upstream llama.cpp build switch `GGML_VULKAN=ON` and installs the Ubuntu packages documented by upstream, including `libvulkan-dev`, `glslc` and `spirv-headers`.
