# Local-inference backend tuning notes

This document records **observed backend behavior and controlled tuning evidence** for AI Workstation local inference. It is intentionally not a permanent architecture rule. Issue #8 established a working Intel SYCL / Level Zero baseline; Issue #9 continues the WSL Vulkan comparison, while Issue #14 tracks the remaining AI Workstation SYCL provisioning cleanup.

The main purpose is to preserve enough detail that later work does not have to reconstruct hardware/runtime findings from chat history.

## Test platform

Primary laptop acceptance platform:

- Lenovo ThinkPad with Intel Core Ultra 7 165H (Meteor Lake-H)
- integrated Intel Arc Pro graphics, PCI ID `0x7d55`
- 64 GiB system RAM
- Windows 11 host
- WSL2 with Ubuntu 24.04
- host-local `llama.cpp` and Llama Dispatcher managed by AI Workstation

The laptop is an UMA/shared-memory system. GPU allocations ultimately consume system RAM, but the runtime may still create separate backend buffers rather than directly executing from the GGUF mmap pages.

## Keep the layers separate

Several independently versioned layers affect Intel GPU inference under WSL:

1. Windows host graphics driver.
2. WSL / kernel / DXG exposure.
3. Linux guest Intel compute runtime (NEO, Level Zero, OpenCL, IGC, GMM).
4. oneAPI / DPC++ compiler and SYCL runtime.
5. exact `llama.cpp` commit and build flags.
6. model, quantization and inference parameters.

Change one layer at a time during diagnosis. A successful or failed result is only comparable when the remaining layers are held fixed.

## Accepted observations from Issue #8

### Old guest runtime: Level Zero enumerated correctly but failed at first compute

The original WSL guest stack came from Intel's older Ubuntu Noble client repository and included approximately:

- `intel-level-zero-gpu 1.3.29735.27`
- `intel-opencl-icd 24.39.31294.20`
- `libigc1 1.0.17791.16`
- `libigdgmm12 22.5.2`
- `libze1/libze-dev 1.17.44`

With oneAPI 2025.3.3 and the pinned `llama.cpp` commit
`9e3b928fd8c9d14dbf15a8768b9fdd7e5c721d66`, the Intel GPU was visible through
`level_zero:0`.

Minimal offload worked, but higher/full offload could load the model and then fail on real compute with:

```text
could not create a memory object
...
ggml_sycl_op_mul_mat
```

This was not a generic WSL GPU-visibility failure. Device enumeration, model loading and OpenCL control tests all worked.

### Updating only the Windows host driver did not fix the Level Zero failure

The Arc Pro host driver was updated from 32.0.101.8517 to Intel's newer Arc Pro branch while the WSL guest stack, oneAPI and `llama.cpp` remained unchanged.

Observed effect:

- OpenCL inference performance improved by roughly 25% in the owner's comparison.
- The Level Zero first-compute failure remained.

This proves that the host driver materially affects WSL GPU performance, but the host-driver update alone was not the fix for the Level Zero allocation failure.

AI Workstation should not own Windows GPU-driver installation. Driver requirements and tested experience should be documented/diagnosed, while the actual host driver remains machine/OEM/operator responsibility.

### Updating the WSL Intel compute runtime fixed the allocation failure

The WSL guest stack was then migrated to Intel's current Ubuntu 24.04 client PPA generation while the newer Windows host driver, oneAPI 2025.3.3 and `llama.cpp 9e3b928f` remained fixed.

The package transition was coherent rather than an in-place mixed-generation upgrade:

- `intel-level-zero-gpu` removed
- `libze-intel-gpu1` installed
- `libigc1` / `libigdfcl1` replaced by `libigc2` / `libigdfcl2`
- OpenCL / ocloc moved from 24.39 to 26.31
- `libze1/libze-dev` moved from 1.17 to 1.32
- GMM moved to 22.10

Observed after restart:

- Level Zero still enumerated Intel `0x7d55` correctly.
- OpenCL reported NEO 26.31.
- The previous `could not create a memory object` crash disappeared.
- Full Level Zero inference completed.

This is the strongest current evidence that the old WSL NEO/user-mode compute stack, rather than WSL GPU exposure itself, caused or triggered the earlier allocation failure.

Do not generalize this into a claim that every `could not create a memory object` error has the same cause. It is the observed resolution on this platform.

### WSL Sysman/free-memory reporting remains limited

The Dispatcher engine uses:

```yaml
environment:
  ONEAPI_DEVICE_SELECTOR: "level_zero:0"
  ZES_ENABLE_SYSMAN: "1"
```

Even with `ZES_ENABLE_SYSMAN=1`, the pinned `llama.cpp` build can report that
`ext_intel_free_memory` is unavailable and fall back to treating total memory as free memory.

That warning is separate from the earlier fatal `mul_mat` allocation failure. Under WSL, Level Zero Sysman/free-memory reporting has known limitations, and later `llama.cpp` work added fallbacks for this case.

Do not use the reported Level Zero "free memory" value as authoritative host-RAM headroom on this platform.

### OpenCL is useful as a control, not the preferred architecture

SYCL through OpenCL has been a stable diagnostic control and can run the 12B Gemma test model fully offloaded.

It is valuable because it proves that:

- the Intel GPU is accessible from WSL;
- the model and broad SYCL toolchain can function;
- failures isolated to the Level Zero path are not necessarily generic model or Dispatcher failures.

However, OpenCL is not the target architecture for this laptop. The intended comparison remains Level Zero versus hardware Vulkan.

### Accepted Level Zero checkpoint: stable full offload, modest performance

After the NEO 26.31 migration, Level Zero inference became stable with full offload.

The early ~2.7 tok/s observation came from the first short checkpoint and should not be treated as the final result. Subsequent tests established a stronger baseline:

- `llama.cpp 9e3b928f` remained stable with full offload;
- `llama.cpp v0.4.1` / build 10964 / commit `b29c606e2` was built and tested against the same working NEO 26.31 + oneAPI 2025.3.3 stack;
- the Gemma 4 26B-A4B QAT MoE model completed real full-offload inference;
- in one representative long-request comparison, the older build measured about 59.47 tok/s prompt throughput and 3.08 tok/s generation, while v0.4.1 measured about 53.48 tok/s prompt throughput and 3.79 tok/s generation;
- the owner's later observation is that first response on the 26B-A4B model can arrive quickly, so the earlier multi-minute first-request behavior is not the normal current steady-state experience.

The larger 26B-A4B model is Mixture-of-Experts. Its larger parameter/file size does not imply proportionally more per-token compute because only a subset of experts is active for each token. Do not assume the dense 12B model should therefore be the faster or more representative performance baseline.

The accepted Issue #8 result is:

- **functional stability:** yes;
- **full offload:** yes;
- **current-source validation:** yes;
- **performance compelling enough to stop backend evaluation:** no.

The next performance question is comparative rather than diagnostic: hardware Vulkan under Issue #9 should be measured against this working SYCL/Level Zero baseline.

## Memory model: direct Level Zero is not the same as true zero-copy GGUF execution

On an integrated GPU, physical RAM is shared, but that does not mean the model exists only once in memory.

Typical model loading can involve:

1. GGUF file pages mapped through `mmap` / page cache;
2. separate SYCL/Level Zero backend buffers containing copied weights.

Clean mmap-backed pages are reclaimable by the OS, so a temporary loading peak can be substantially higher than the later steady state.

A direct Level Zero allocation path may reduce staging/copy overhead and improve backend memory behavior, but it is not automatically equivalent to the GPU executing directly from the original GGUF mmap pages.

For this laptop, measure at least:

- host available RAM before model start;
- minimum available RAM during loading;
- available RAM after model becomes ready;
- model-load duration;
- first-request latency;
- prompt-evaluation throughput;
- token-generation throughput.

Llama Dispatcher Issue #4 tracks adding startup-memory telemetry so this evidence can be captured automatically.

## Controlled comparison procedure

Before each meaningful comparison, record:

- Windows graphics-driver version;
- WSL version and kernel;
- NEO / Level Zero / OpenCL / IGC / GMM package versions;
- oneAPI compiler/runtime version;
- exact `llama.cpp` commit;
- CMake flags;
- model path/name and preferably file hash;
- context, batch, ubatch, GPU layers, KV-cache types, Flash Attention and thread count;
- relevant environment variables.

Useful commands:

```bash
dpkg-query -W -f='${Package}\t${Version}\n' \
  libze-intel-gpu1 libze1 libze-dev \
  intel-opencl-icd intel-ocloc \
  libigc2 libigdfcl2 libigdgmm12

source /opt/intel/oneapi/setvars.sh >/dev/null
icpx --version | head -n 2
sycl-ls
clinfo -l

aiw local-inference llama list
aiw local-inference status
```

AI Workstation keeps parallel immutable-spec `llama.cpp` build slots. Use them instead of overwriting a working baseline.

## SYCL provisioning follow-up

The source-version experiment described by the earlier version of this document is complete: v0.4.1 was built without disturbing the working NEO 26.31 guest stack and successfully exercised full-offload inference.

The remaining SYCL work is now **installer/reproducibility**, tracked in Issue #14.

**Do not currently run `aiw local-inference llama build --backend sycl` on the repaired ThinkPad environment if that command would invoke the historical dependency provisioning.** The current AI Workstation provisioning path still re-adds Intel's older Noble client repository and explicitly requests `intel-level-zero-gpu`, which can conflict with the proven current-PPA `libze-intel-gpu1` / NEO 26.31 stack.

Until Issue #14 is complete:

- preserve the working NEO 26.31 + oneAPI 2025.3.3 environment;
- keep existing immutable llama.cpp build slots intact;
- treat manual/source-only builds as controlled experiments rather than the preferred long-term operator workflow;
- do not interpret this installer limitation as a backend-stability failure.

Issue #14 should update the normal AI Workstation SYCL provisioning path so future builds are reproducible without risking a runtime downgrade.

## Vulkan handoff

Issue #9 owns WSL hardware Vulkan/DZN investigation.

The original WSL Vulkan baseline exposed only Mesa `llvmpipe`, despite separate D3D12/OpenGL tests proving hardware Intel GPU access. The next Vulkan block should determine whether a current Mesa DZN path can expose the Intel iGPU as a real Vulkan device under WSL and then compare it against the working SYCL baseline.

Do not mix Vulkan enablement changes into Issue #8.

## References

- AI Workstation Issue #8 — completed Intel SYCL / Level Zero acceptance
- AI Workstation Issue #9 — WSL hardware Vulkan/DZN
- AI Workstation Issue #14 — Intel SYCL guest-runtime provisioning
- Llama Dispatcher Issue #4 — model-start memory telemetry
- llama.cpp SYCL documentation:
  https://github.com/ggml-org/llama.cpp/blob/master/docs/backend/SYCL.md
- llama.cpp SYCL performance discussion:
  https://github.com/ggml-org/llama.cpp/discussions/23313
- llama.cpp issue #24045 — Gemma 4 26B performance with newer Intel runtime:
  https://github.com/ggml-org/llama.cpp/issues/24045
- llama.cpp issue #26010 — SYCL versus Vulkan generation throughput:
  https://github.com/ggml-org/llama.cpp/issues/26010
- Intel Ubuntu client-GPU package instructions:
  https://dgpu-docs.intel.com/installation-guides/installing-packages-from-the-intel-ppa.html
