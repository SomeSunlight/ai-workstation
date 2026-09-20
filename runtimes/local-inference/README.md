# Host-local inference

This runtime integrates `llama.cpp` and Llama Dispatcher directly on the WSL/Linux host. It deliberately does **not** containerize either component.

AI Workstation owns reproducible host installation, pinned default revisions, the local `llama.cpp` build registry, machine-local runtime paths, and the normal start/stop lifecycle. Llama Dispatcher remains responsible for profiles, engine/backend policy, ensembles, benchmark/eval execution, and metrics. Dispatcher instances under `instances/<name>` are **user-owned** and are not cloned, reset, or rewritten by AI Workstation.

Local inference is optional. A remote-only AI Workstation does not need to configure or install this runtime.

Backend acceptance and tuning evidence is kept separately in [TUNING.md](TUNING.md). The Intel SYCL/Level Zero investigation is now complete: NEO 26.31 plus oneAPI 2025.3.3 runs the ThinkPad iGPU stably at full offload, including with llama.cpp v0.4.1. The remaining caveat is installer-owned: `setup sycl` and the current `llama build --backend sycl` dependency-provisioning path still reference the older Intel guest-runtime packaging. Issue #14 owns that provisioning cleanup; until it is complete, do not use those commands in a way that could replace the working NEO 26.31 stack.

## Ownership boundary

The generic runtime layout is:

```text
~/.local/share/ai-workstation/local-inference/
├── llama.cpp/
│   ├── repository/
│   └── builds/
│       ├── vulkan-9e3b928f/
│       │   ├── source/
│       │   ├── build/bin/
│       │   └── manifest.json
│       └── sycl-9e3b928f/
│           ├── source/
│           ├── build/bin/
│           └── manifest.json
└── Llama_Dispatcher/
    ├── src/                         # AI Workstation-pinned Dispatcher checkout
    ├── defaults/
    └── instances/                   # user-owned; AI Workstation never populates this
        └── <name>/
```

Machine-local AI Workstation state is intentionally separate from the versioned Dispatcher instance:

```text
~/.config/ai-workstation/
├── local-inference.env             # backend/bootstrap + selected llama.cpp build
└── local-inference-runtime.env     # model root + normal instance + ensemble
```

The second file stores `AIW_LLAMA_MODEL_ROOT`, `AIW_DISPATCHER_INSTANCE`, and `AIW_DISPATCHER_ENSEMBLE`. AI Workstation does **not** create a global `LLAMA_MODEL_ROOT` in `.bashrc`, `.profile`, or the WSL environment. It passes the configured root explicitly to Dispatcher as `--model-root`.

## Normal operator workflow

Once the backend and user-owned Dispatcher instance exist, configure the normal start once:

```bash
aiw local-inference runtime configure
```

The interactive menu asks for:

- the machine-local model root;
- the Dispatcher instance name;
- the normal ensemble.

Afterwards ordinary operation is intentionally short:

```bash
aiw local-inference start
aiw local-inference stop
aiw local-inference restart
aiw local-inference status
aiw local-inference logs
```

The same actions are available from the `aiw` interactive menu, so remembering these commands is optional.

`start` installs/refreshes the `ai-workstation-local-inference.service` systemd unit and starts it. The service runs under the Linux user who configured AI Workstation, not as root. The concrete selected llama.cpp build and model root are injected at runtime; they are not copied into profiles.

## Autostart

Autostart is deliberately **off** while a backend is still being validated. Once the runtime is known to work:

```bash
aiw local-inference autostart enable
```

This enables and starts the system-level WSL service. It is tied to the WSL distribution/systemd lifecycle rather than to a particular interactive shell session. Disable it with:

```bash
aiw local-inference autostart disable
```

This service is intended to become the dependency anchor for later local tools that require an LLM. Process ordering alone is not sufficient for those consumers because llama.cpp still has to load the model; dependent services should additionally wait for the Dispatcher HTTP endpoint/model readiness before beginning LLM work.

## Why llama.cpp is a build registry, not one installation

Benchmarking different `llama.cpp` revisions and build configurations is a normal use case. AI Workstation therefore keeps multiple builds side by side instead of overwriting one directory.

Each build gets `manifest.json`, which records at least:

- exact `llama.cpp` commit;
- backend;
- additional CMake arguments;
- binary path;
- first line of `llama-server --version`;
- build timestamp;
- for SYCL, observed Intel compiler/package provenance.

By default the generated name is `<backend>-<short-commit>`. A descriptive suffix can be added with `--label`; an explicit `--name` is also possible. Two materially different build specifications should use two different build names. The manifest, not the human-oriented name, is the source of truth.

## Controlled ThinkPad baseline

The first ThinkPad comparison pins llama.cpp commit `9e3b928fd8c9d14dbf15a8768b9fdd7e5c721d66` (Windows build 9553), matching the source revision already validated with the existing Dispatcher setup under Windows/Vulkan. Backend experiments therefore change the hardware/runtime path without also changing llama.cpp source.

The first WSL/Vulkan run successfully built that revision but `vulkaninfo` exposed only Mesa `llvmpipe`, so AI Workstation correctly rejects it as hardware-valid. Separate WSL testing showed the Intel GPU is accelerated through the WSL D3D12 path; the missing piece for the Vulkan experiment is a usable Vulkan-over-D3D12/DZN path. The Vulkan build remains installed as a parallel baseline.

## Vulkan setup

```bash
aiw local-inference setup vulkan
```

This writes generic machine-local configuration, creates/selects the pinned Vulkan build slot, synchronizes the pinned Dispatcher checkout, enumerates Vulkan devices, and verifies the Dispatcher core. It does **not** clone a Dispatcher instance.

A Vulkan setup is not considered hardware-valid when `vulkaninfo` exposes only a CPU/software renderer such as `llvmpipe`.

GPU selection such as `GGML_VK_VISIBLE_DEVICES` is not an AI Workstation setting. It belongs to the user-owned Dispatcher engine, for example:

```yaml
environment:
  GGML_VK_VISIBLE_DEVICES: "0"
```

Dispatcher applies that engine environment when it launches llama.cpp, so the operator does not have to remember a shell export before every start.

## Intel SYCL / oneAPI setup on WSL

The first automatic SYCL path is deliberately narrow: **WSL2 + Ubuntu 24.04 (noble) + Intel GPU**.

```bash
aiw local-inference setup sycl
```

For the controlled ThinkPad test this command:

1. keeps existing Vulkan/build slots untouched;
2. verifies Ubuntu 24.04 under WSL and `/dev/dxg`;
3. configures Intel's Ubuntu 24.04 client-GPU APT repository;
4. installs the Intel user-mode Level Zero/OpenCL compute runtime inside WSL;
5. configures Intel's oneAPI APT repository;
6. installs the pinned `intel-deep-learning-essentials-2025.3` package series;
7. sources `/opt/intel/oneapi/setvars.sh` once per AI Workstation process and requires `sycl-ls` to expose a Level Zero GPU;
8. builds the pinned llama.cpp commit as `sycl-9e3b928f` with `GGML_SYCL=ON`, `icx`, and `icpx`;
9. selects the SYCL slot and verifies the llama.cpp SYCL device tools;
10. verifies the pinned Dispatcher core without touching any user-owned instance.

AI Workstation exports `UR_L0_ENABLE_RELAXED_ALLOCATION_LIMITS=1` for the SYCL runtime because the pinned llama.cpp launcher uses it for larger Level Zero allocations. Device choice remains Dispatcher engine policy; for example an Intel engine may declare `ONEAPI_DEVICE_SELECTOR: "level_zero:0"` under its `environment:` mapping.

## Attach your own Dispatcher instance

Only after the generic runtime/backend is healthy, clone or create the appropriate instance in the Dispatcher's expected directory. Example:

```bash
cd ~/.local/share/ai-workstation/local-inference/Llama_Dispatcher
git clone <your-instance-repository> instances/<name>
```

The instance repository owns profiles, engines, ensembles, and machine identity. Runtime-generated data such as a metrics database or generated llama.cpp router preset should normally remain environment-local unless historical data is intentionally migrated.

AI Workstation does not pull, reset, or rewrite anything under `instances/<name>`.

## Portable model paths

Shared profiles should use `${LLAMA_MODEL_ROOT}` for the common model directory instead of storing Windows and WSL roots separately:

```yaml
common:
  model: "${LLAMA_MODEL_ROOT}/model.gguf"
```

AI Workstation stores the concrete machine-local root once in `local-inference-runtime.env` and passes it as `--model-root` whenever it starts Dispatcher. Dispatcher expands the placeholder. AI Workstation never guesses or translates `C:` to `/mnt/c`.

This gives each machine its own local path value without creating separate versions of the profile configuration.

## Managing parallel llama.cpp builds

List installed builds; `*` marks the selected default:

```bash
aiw local-inference llama list
```

Build or select variants explicitly:

```bash
aiw local-inference llama build --backend vulkan
aiw local-inference llama build --backend sycl
aiw local-inference llama select vulkan-9e3b928f
aiw local-inference llama select sycl-9e3b928f
aiw local-inference llama show sycl-9e3b928f
```

Another revision or compile variant gets its own slot rather than silently replacing an existing benchmark target.

## Direct Dispatcher/benchmark use

The managed service is the normal serve path. Direct Dispatcher operations remain available for experiments and benchmarks:

```bash
aiw local-inference dispatcher \
  bench PROFILE \
  --instance Laptop
```

A single run can choose another installed llama.cpp build without changing the machine default:

```bash
aiw local-inference dispatcher \
  --llama-build vulkan-9e3b928f \
  bench PROFILE \
  --instance Laptop
```

Model/profile/ensemble semantics and benchmark rows remain produced by the existing Dispatcher/database machinery rather than by a second AI Workstation test harness.

## Backend status

- **Vulkan**: build path implemented. On the first ThinkPad WSL run only `llvmpipe` was visible; hardware Vulkan under WSL remains a later DZN investigation.
- **SYCL**: implemented for the WSL2/Ubuntu 24.04 Intel-GPU acceptance path using pinned oneAPI 2025.3-series tooling and verified Level Zero visibility.
- **CUDA**: extension point when a WSL CUDA toolkit (`nvcc`) already exists; automatic CUDA toolkit provisioning is not part of this block.
- **CPU**: supported as a build backend.
