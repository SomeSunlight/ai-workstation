# Host-local inference

This runtime integrates `llama.cpp` and Llama Dispatcher directly on the WSL/Linux host. It deliberately does **not** containerize either component.

AI Workstation owns reproducible host installation, pinned default revisions, a registry of locally built `llama.cpp` variants, and the operator entry point. Llama Dispatcher remains responsible for model profiles, engine configuration, ensembles, benchmark/eval execution, and its metrics database.

Local inference is optional. A remote-only AI Workstation does not need to configure or install this runtime.

## Why llama.cpp is a build registry, not one installation

Benchmarking different `llama.cpp` revisions and build configurations is a normal use case. AI Workstation therefore keeps multiple builds side by side instead of overwriting one `llama.cpp` directory.

The layout is:

```text
~/.local/share/ai-workstation/local-inference/
├── llama.cpp/
│   ├── repository/                 # shared Git object/source cache
│   └── builds/
│       ├── vulkan-05f2dcfd/
│       │   ├── source/             # detached worktree at the exact commit
│       │   ├── build/
│       │   │   └── bin/
│       │   └── manifest.json
│       └── sycl-<commit>-24-24/    # example future custom build
└── Llama_Dispatcher/
    └── instances/
        └── Laptop/
```

The build directory name is deliberately **human-oriented**, similar to the older `server_06_vulcan`, `server_07_SYCL`, `server_07_SYCL_24_24` convention. The difference is that the name is no longer the source of truth.

Each build gets `manifest.json`, which records at least:

- exact `llama.cpp` commit;
- backend;
- additional CMake arguments;
- binary path;
- first line of `llama-server --version`;
- build timestamp.

By default the generated name is `<backend>-<short-commit>`. A descriptive suffix can be added, for example `--label 24-24`. An explicit `--name` is also possible. Two materially different build specifications should use two different build names.

This gives the useful combination: **recognizable names for humans, exact provenance for measurements**.

## Laptop Vulkan first run

From an already installed AI Workstation:

```bash
aiw local-inference setup laptop-vulkan
```

This command:

1. writes machine-local configuration to `~/.config/ai-workstation/local-inference.env`;
2. builds the AI Workstation-pinned `llama.cpp` revision as a Vulkan build slot and selects it;
3. clones Llama Dispatcher at its pinned AI Workstation revision and runs `uv sync --frozen`;
4. clones `SomeSunlight/Llama_Dispatcher_Laptop` into the Dispatcher's existing `instances/Laptop` location;
5. enumerates llama.cpp devices and runs the Dispatcher's compile-only check for `thinkpad`.

The instance repository is intentionally *not* reset or updated by AI Workstation after it is attached. It is machine-owned configuration and may contain deliberate local or committed changes.

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

Select the default build used by Dispatcher commands:

```bash
aiw local-inference llama select vulkan-05f2dcfd
```

Inspect exact provenance:

```bash
aiw local-inference llama show vulkan-05f2dcfd
```

Build names are treated as stable identities. Rebuilding the same name is allowed only when commit, backend, and extra CMake arguments still match; otherwise a new name is required. This prevents historical benchmark labels from silently changing meaning.

## Dispatcher use

Normal commands use the selected llama.cpp build:

```bash
aiw local-inference status
aiw local-inference verify
aiw local-inference serve
```

The existing Dispatcher modes stay the benchmark/evaluation interface:

```bash
aiw local-inference dispatcher bench PROFILE [DISPATCHER/LLAMA OVERRIDES...]
aiw local-inference dispatcher eval PROFILE DATASET [DISPATCHER/LLAMA OVERRIDES...]
aiw local-inference dispatcher serve --ensemble thinkpad
```

A single run can select another installed llama.cpp build without changing the machine default:

```bash
aiw local-inference dispatcher \
  --llama-build vulkan-<other-commit> \
  bench PROFILE
```

AI Workstation injects only the chosen WSL `llama.cpp` binary directory and configured Dispatcher instance. Model and performance parameters continue to come from Llama Dispatcher. Therefore benchmark rows remain produced by the existing Dispatcher/database machinery rather than by a second AI Workstation test harness.

## Important boundary: model paths

The existing Laptop instance was authored for Windows and its model profiles currently contain Windows paths. AI Workstation does not rewrite those profiles behind the Dispatcher's back. Before real inference under WSL, the selected instance profile must point to a model path visible from WSL.

The binary path is different: AI Workstation supplies `--bin-dir` as the Dispatcher's highest-priority CLI override. Historical engine configuration can therefore remain intact while each benchmark run chooses one installed WSL build.

## Backends

The first implemented backend is Vulkan because it is the selected ThinkPad path. CUDA is an explicit extension point when an appropriate WSL CUDA toolkit (`nvcc`) is present. SYCL/oneAPI provisioning is deliberately deferred until that toolchain is tested under WSL, but the multi-build registry is designed for variants such as `sycl-<commit>` and `sycl-<commit>-24-24`.

For Vulkan, the runtime uses upstream llama.cpp's `GGML_VULKAN=ON` switch and the Ubuntu packages documented upstream, including `libvulkan-dev`, `glslc`, and `spirv-headers`.
