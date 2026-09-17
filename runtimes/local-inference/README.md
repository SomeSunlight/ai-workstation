# Host-local inference

This runtime integrates `llama.cpp` and Llama Dispatcher directly on the WSL/Linux host. It deliberately does **not** containerize either component.

AI Workstation owns reproducible host installation, pinned default revisions, a registry of locally built `llama.cpp` variants, and the operator entry point. Llama Dispatcher remains responsible for model profiles, engine configuration, ensembles, benchmark/eval execution, and metrics. Dispatcher instances under `instances/<name>` are explicitly **user-owned** and are not cloned or rewritten by AI Workstation.

Local inference is optional. A remote-only AI Workstation does not need to configure or install this runtime.

## Ownership boundary

The generic runtime layout is:

```text
~/.local/share/ai-workstation/local-inference/
├── llama.cpp/
│   ├── repository/                 # shared Git object/source cache
│   └── builds/
│       ├── vulkan-9e3b928f/
│       │   ├── source/             # detached worktree at the exact commit
│       │   ├── build/
│       │   │   └── bin/
│       │   └── manifest.json
│       └── <other-build>/
└── Llama_Dispatcher/
    ├── src/                         # AI Workstation-pinned Dispatcher checkout
    ├── defaults/
    └── instances/                   # user-owned; AI Workstation never populates this
        └── <name>/
```

This boundary is intentional: AI Workstation can reproduce the generic runtime, but only the user knows the hardware-specific profiles, model paths, ensembles, identity and whether historical metrics should be reused.

## Why llama.cpp is a build registry, not one installation

Benchmarking different `llama.cpp` revisions and build configurations is a normal use case. AI Workstation therefore keeps multiple builds side by side instead of overwriting one `llama.cpp` directory.

Each build gets `manifest.json`, which records at least:

- exact `llama.cpp` commit;
- backend;
- additional CMake arguments;
- binary path;
- first line of `llama-server --version`;
- build timestamp.

By default the generated name is `<backend>-<short-commit>`. A descriptive suffix can be added with `--label`; an explicit `--name` is also possible. Two materially different build specifications should use two different build names.

Build names are human-oriented; the manifest is the source of truth.

## First Vulkan run

For the first ThinkPad WSL/Vulkan acceptance run, the default pin is deliberately `9e3b928fd8c9d14dbf15a8768b9fdd7e5c721d66` (llama.cpp build 9553). This is the same source revision already validated with the existing Dispatcher setup under Windows/Vulkan. Keeping the llama.cpp source revision constant makes the WSL/Vulkan migration the primary changed variable.

From an already installed AI Workstation:

```bash
aiw local-inference setup vulkan
```

This command:

1. writes generic machine-local configuration to `~/.config/ai-workstation/local-inference.env`;
2. builds the AI Workstation-pinned `llama.cpp` revision as a Vulkan build slot and selects it;
3. clones Llama Dispatcher at its pinned AI Workstation revision and runs `uv sync --frozen`;
4. enumerates llama.cpp/Vulkan devices;
5. verifies the Dispatcher core CLI/imports.

It does **not** clone a Dispatcher instance.

A Vulkan setup is not considered hardware-valid when `vulkaninfo` exposes only a CPU/software renderer such as `llvmpipe`. In that case `verify` fails with an explicit diagnostic instead of claiming that the selected Vulkan runtime is usable on the GPU.

## Attach your own Dispatcher instance

After the generic runtime is installed, clone or create the appropriate instance yourself in the Dispatcher's expected directory. Example only:

```bash
cd ~/.local/share/ai-workstation/local-inference/Llama_Dispatcher
git clone <your-instance-repository> instances/<name>
```

The instance repository should own profiles, engines, ensembles and machine identity. Runtime-generated data such as a metrics database or generated llama.cpp router preset should normally remain environment-local unless the user intentionally chooses otherwise.

AI Workstation does not pull, reset or rewrite anything under `instances/<name>`.

## Managing parallel llama.cpp builds

List installed builds; `*` marks the selected default:

```bash
aiw local-inference llama list
```

Build the pinned revision with Vulkan:

```bash
aiw local-inference llama build --backend vulkan
```

Build another revision without touching existing builds:

```bash
aiw local-inference llama build \
  --backend vulkan \
  --commit <commit-or-ref>
```

Give a special compile variant a recognizable suffix:

```bash
aiw local-inference llama build \
  --backend vulkan \
  --commit <commit-or-ref> \
  --label experiment-a \
  --cmake-arg -DGGML_SOME_OPTION=VALUE
```

Select and inspect the baseline build:

```bash
aiw local-inference llama select vulkan-9e3b928f
aiw local-inference llama show vulkan-9e3b928f
```

Rebuilding the same slot name is allowed only when commit, backend, and extra CMake arguments still match; otherwise a new name is required. This prevents historical benchmark labels from silently changing meaning.

## Dispatcher use

AI Workstation injects only the selected llama.cpp binary directory through the Dispatcher's `--bin-dir` override. The user supplies the Dispatcher command and instance semantics explicitly.

Examples:

```bash
aiw local-inference serve \
  --instance Laptop \
  --ensemble thinkpad

aiw local-inference dispatcher \
  bench PROFILE \
  --instance Laptop
```

A single run can select another installed llama.cpp build without changing the machine default:

```bash
aiw local-inference dispatcher \
  --llama-build vulkan-<other-commit> \
  bench PROFILE \
  --instance Laptop
```

Model/profile/ensemble semantics and benchmark rows remain produced by the existing Dispatcher/database machinery rather than by a second AI Workstation test harness.

## Important boundary: model paths

An instance may contain paths authored for another operating environment. AI Workstation does not translate Windows model paths into WSL paths or otherwise mutate profile configuration. Before real inference, the user-owned instance must contain paths valid for the environment being tested.

The llama.cpp binary path is intentionally different: AI Workstation supplies `--bin-dir` at invocation time, so the selected build can change without rewriting the instance engine configuration.

## Backends

The first implemented backend is Vulkan. CUDA is an explicit extension point when an appropriate WSL CUDA toolkit (`nvcc`) is present. SYCL/oneAPI provisioning is deliberately deferred until that toolchain is tested under WSL, but the multi-build registry is designed for parallel backend/build variants.

For Vulkan, the runtime uses upstream llama.cpp's `GGML_VULKAN=ON` switch and installs the Ubuntu build/runtime prerequisites including `libvulkan-dev`, `glslc`, `spirv-headers`, `mesa-vulkan-drivers`, and `vulkan-tools`.
