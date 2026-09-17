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
│       │   ├── build/bin/
│       │   └── manifest.json
│       ├── sycl-9e3b928f/
│       │   ├── source/
│       │   ├── build/bin/
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
- build timestamp;
- for SYCL, the observed Intel compiler/package version as additional toolchain provenance.

By default the generated name is `<backend>-<short-commit>`. A descriptive suffix can be added with `--label`; an explicit `--name` is also possible. Two materially different build specifications should use two different build names.

Build names are human-oriented; the manifest is the source of truth.

## Controlled ThinkPad baseline

The first ThinkPad comparison deliberately pins llama.cpp commit `9e3b928fd8c9d14dbf15a8768b9fdd7e5c721d66` (Windows build 9553), matching the source revision already validated with the existing Dispatcher setup under Windows/Vulkan. Backend experiments therefore change the hardware/runtime path without also changing llama.cpp source.

The first WSL/Vulkan run successfully built that revision but `vulkaninfo` exposed only Mesa `llvmpipe`, so AI Workstation correctly rejects it as hardware-valid. Separate WSL testing showed the Intel Arc Pro GPU is available and accelerated through the WSL D3D12 path; the missing piece for the Vulkan experiment is a usable Vulkan-over-D3D12/DZN path. The Vulkan build is retained as a parallel baseline rather than deleted.

## Vulkan setup

```bash
aiw local-inference setup vulkan
```

This writes generic machine-local configuration, creates/selects the pinned Vulkan build slot, synchronizes the pinned Dispatcher checkout, enumerates Vulkan devices and verifies the Dispatcher core. It does **not** clone a Dispatcher instance.

A Vulkan setup is not considered hardware-valid when `vulkaninfo` exposes only a CPU/software renderer such as `llvmpipe`.

## Intel SYCL / oneAPI setup on WSL

The first automatic SYCL path is deliberately narrow: **WSL2 + Ubuntu 24.04 (noble) + Intel GPU**. It does not attempt to be a universal oneAPI installer.

```bash
aiw local-inference setup sycl
```

For the controlled ThinkPad test this command:

1. keeps existing Vulkan/build slots untouched;
2. verifies Ubuntu 24.04 under WSL and `/dev/dxg`;
3. configures Intel's Ubuntu 24.04 client-GPU APT repository;
4. installs the Intel user-mode Level Zero/OpenCL compute runtime inside WSL (the Windows host remains the owner of the actual GPU driver);
5. configures Intel's oneAPI APT repository;
6. installs the pinned `intel-deep-learning-essentials-2025.3` package series. The pinned llama.cpp SYCL documentation verifies oneAPI 2025.3.3 for Ubuntu 24.04;
7. sources `/opt/intel/oneapi/setvars.sh` and requires `sycl-ls` to expose a Level Zero GPU;
8. builds the same pinned llama.cpp commit as `sycl-9e3b928f` with `GGML_SYCL=ON`, `icx`, and `icpx` (FP32/default SYCL build);
9. selects the new SYCL slot and verifies both `llama-server --list-devices` and `llama-ls-sycl-device`;
10. verifies the pinned Dispatcher core without touching any user-owned instance.

The runtime exports `UR_L0_ENABLE_RELAXED_ALLOCATION_LIMITS=1` for SYCL commands because the pinned llama.cpp SYCL launcher uses that setting for Level Zero allocations larger than 4 GiB. AI Workstation intentionally does **not** set `ONEAPI_DEVICE_SELECTOR`: choosing a specific Intel device remains explicit user/Dispatcher instance policy.

`setup sycl` selects the pinned SYCL slot even when a Vulkan slot was already active. The old Vulkan build remains installed and can be selected again at any time.

## Attach your own Dispatcher instance

Only after the generic runtime/backend is healthy, clone or create the appropriate instance yourself in the Dispatcher's expected directory. Example only:

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

Build the pinned revision explicitly with a backend:

```bash
aiw local-inference llama build --backend vulkan
aiw local-inference llama build --backend sycl
```

Build another revision without touching existing builds:

```bash
aiw local-inference llama build \
  --backend sycl \
  --commit <commit-or-ref>
```

Give a special compile variant a recognizable suffix:

```bash
aiw local-inference llama build \
  --backend sycl \
  --commit <commit-or-ref> \
  --label experiment-a \
  --cmake-arg -DGGML_SYCL_F16=ON
```

Select and inspect builds:

```bash
aiw local-inference llama select vulkan-9e3b928f
aiw local-inference llama select sycl-9e3b928f
aiw local-inference llama show sycl-9e3b928f
```

Rebuilding the same slot name is allowed only when commit, backend, and extra CMake arguments still match; otherwise a new name is required. This prevents historical benchmark labels from silently changing meaning.

## Dispatcher use

AI Workstation injects only the selected llama.cpp binary directory through the Dispatcher's `--bin-dir` override and loads the backend environment required by that selected build. The user supplies the Dispatcher command and instance semantics explicitly.

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
  --llama-build vulkan-9e3b928f \
  bench PROFILE \
  --instance Laptop
```

Model/profile/ensemble semantics and benchmark rows remain produced by the existing Dispatcher/database machinery rather than by a second AI Workstation test harness.

## Important boundary: model paths

An instance may contain paths authored for another operating environment. AI Workstation does not translate Windows model paths into WSL paths or otherwise mutate profile configuration. Before real inference, the user-owned instance must contain paths valid for the environment being tested.

The llama.cpp binary path is intentionally different: AI Workstation supplies `--bin-dir` at invocation time, so the selected build can change without rewriting the instance engine configuration.

## Backend status

- **Vulkan**: implemented. On the first ThinkPad WSL run the build worked, but only `llvmpipe` was visible; hardware Vulkan under WSL remains unresolved and is retained for a later DZN investigation.
- **SYCL**: implemented for the first WSL2/Ubuntu 24.04 Intel-GPU acceptance path using pinned oneAPI 2025.3-series tooling and Level Zero device verification.
- **CUDA**: explicit extension point when a WSL CUDA toolkit (`nvcc`) already exists; automatic CUDA toolkit provisioning is not part of this block.
- **CPU**: supported as a build backend.
