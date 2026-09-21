# Local-inference backend tuning notes

This document records **observed backend behavior and controlled tuning evidence** for AI Workstation local inference. It is intentionally not a permanent architecture rule. Issue #8 established a working Intel SYCL / Level Zero baseline. Issue #9 proved hardware Vulkan through Mesa DZN under WSL, but also established correctness/performance boundaries that currently keep DZN experimental. Issue #14 aligns normal AI Workstation SYCL provisioning with the proven current Intel runtime generation.

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

The source-version experiment is complete: v0.4.1 was built without disturbing the working NEO 26.31 guest stack and successfully exercised full-offload inference.

Issue #14 updates the normal AI Workstation provisioning path to match that proven generation:

- Intel's Ubuntu 24.04 `intel-graphics` PPA supplies the guest GPU runtime;
- `libze-intel-gpu1` replaces the historical `intel-level-zero-gpu` package;
- NEO older than 26.31 and Level Zero loader/development packages older than 1.32 are rejected;
- oneAPI 2025.3 provisioning remains a separate toolchain step;
- the effective GPU-runtime and oneAPI package versions are printed and stored with new SYCL build provenance.

The Issue #14 review candidate should make `aiw local-inference setup sycl` the intended reproducible path again after it is validated on the real ThinkPad.

The later native-WSL model tests also reached stable 16K and 32K contexts. During 32K model loading, observed host memory temporarily approached 99% before falling back to roughly 58% steady state. That is consistent with reclaimable file-backed pages coexisting temporarily with backend buffers, but it remains an operational observation rather than a precise allocation trace.

## WSL Vulkan / DZN findings from Issue #9

Issue #9 answered the first architectural question positively: **hardware Vulkan under WSL is possible on this ThinkPad through Mesa DZN**. It did not establish DZN as the preferred inference backend.

### Hardware Vulkan enablement succeeded

The pre-test Ubuntu 24.04 system Mesa exposed only `llvmpipe`; the packaged stack did not provide a usable DZN Vulkan ICD.

Mesa 26.2.3 was therefore built side-by-side under the user's AI Workstation experiment directory with an intentionally minimal DZN configuration:

```bash
meson setup build-dzn \
  -Dvulkan-drivers=microsoft-experimental \
  -Dgallium-drivers= \
  -Dplatforms= \
  -Dbuildtype=release \
  -Dllvm=disabled

ninja -C build-dzn
```

Nothing was installed over system Mesa. The build-tree development ICD was selected explicitly.

DZN exposed both physical adapters through WSL/D3D12:

- NVIDIA RTX 500 Ada — vendor/device `0x10de:0x28ba`;
- Intel Arc Pro integrated graphics — vendor/device `0x8086:0x7d55`.

The Intel test path was then forced explicitly:

```bash
export LD_LIBRARY_PATH=/usr/lib/wsl/lib:${LD_LIBRARY_PATH:-}
export VK_DRIVER_FILES="$HOME/.local/share/ai-workstation/experiments/mesa-26.2.3/build-dzn/src/microsoft/vulkan/dzn_devenv_icd.x86_64.json"
export MESA_VK_DEVICE_SELECT=8086:7d55!
```

With that environment, `vulkaninfo --summary` exposed only the intended Intel hardware device and `llama-server --list-devices` from the independent Vulkan build reported the Intel Arc Pro device. The DZN warning that the implementation is not conformant is expected and is itself a reason not to treat this as a production-ready system Vulkan stack.

Two immutable llama.cpp Vulkan slots were exercised:

- v0.4.1 / build 10964 / commit `b29c606e2`;
- build 11064 / commit `a894dae9`, 100 upstream commits newer than the first DZN test build.

The later build did not remove the Gemma correctness problem described below.

### Native WSL model storage materially changed loading behavior

The first Gemma 4 26B-A4B load used a GGUF under `/mnt/c` and failed during model loading with:

```text
llama_model_load: error loading model: read error: Bad address
```

Setting `GGML_VK_DISABLE_HOST_VISIBLE_VIDMEM=1` did not remove that loading failure.

The same GGUF was copied into the native WSL filesystem. After that change:

- Vulkan/DZN loaded the model successfully;
- loading was visibly much faster;
- the same native-WSL model location also made SYCL model loading visibly faster in the later control run.

This is an observed platform boundary, not yet a complete root-cause proof. The exact interaction between DrvFS/`/mnt/c`, llama.cpp model I/O and DZN buffer upload was not isolated further. For this machine, large host-local GGUF files should nevertheless be kept on the native WSL filesystem when testing WSL inference.

### Gemma 4 correctness fails on the Vulkan Flash-Attention path

With Gemma 4 26B-A4B QAT, Q4 KV cache and Flash Attention enabled, the model loads and starts inference but immediately produces repeated invalid special tokens such as:

```text
Hello<unused49><unused49><unused49>...
```

Reasoning was disabled for the reproduction. The same corruption occurred on both tested llama.cpp revisions, including build 11064.

The critical A/B tests were:

| Gemma configuration | Result |
|---|---|
| `cache-type-v=q4_0`, FA on | repeated `<unused49>` corruption |
| `cache-type-v=f16`, FA on | repeated `<unused49>` corruption |
| `cache-type-v=f16`, FA off | coherent answer |

This isolates the observed failure much more strongly to the current Gemma/Vulkan Flash-Attention execution path than to V-cache quantization itself.

FA-off is not a useful workaround on this laptop. Quantized V cache requires Flash Attention in current llama.cpp, so disabling FA forces an unquantized V cache. During the F16-V control run llama.cpp warned that Gemma's V embeddings have different sizes across layers and padded the V cache to 2048. System memory pressure became severe enough that the Windows desktop briefly lost/rearranged external displays. The configuration answered correctly, but it is operationally unacceptable.

Similar upstream llama.cpp reports exist for Gemma 4 Vulkan corruption, including Issue #21516 (`<unused>` loops) and the still-open Issue #27007 (Gemma 4 26B-A4B full-GPU Vulkan corruption). Those reports are useful corroborating context, but this ThinkPad/DZN experiment does not claim the same low-level root cause.

### Qwen proves Vulkan/DZN + Flash Attention is not globally broken

Qwen 3.6 35B-A3B Q4_K_M was used as a control with Vulkan/DZN and Flash Attention enabled.

Unlike Gemma, Qwen produced coherent output. This proves that neither DZN/Vulkan nor Flash Attention is generically unusable on the machine.

The current Qwen profile keeps KV offload enabled by overriding the laptop Vulkan engine default with `no-kv-offload: false`. That exception is intentional: upstream llama.cpp Issue #23321 documents gibberish output on Qwen3.6-35B-A3B when Vulkan `no-kv-offload` is enabled, and the local test configuration is aligned with the working path.

Performance, however, was unexpectedly low. Representative Dispatcher measurements were:

| Backend / model | Context | Prompt tokens | Prompt tok/s | Generated tokens | Generation tok/s |
|---|---:|---:|---:|---:|---:|
| SYCL / Gemma 4 26B-A4B / v0.4.1 | 16K | 13,715 | 53.48 | 924 | 3.79 |
| Vulkan-DZN / Qwen 3.6 35B-A3B | 16K | 67 | 7.15 | 74 | 1.34 |
| Vulkan-DZN / Qwen 3.6 35B-A3B | 8K | 3,641 | 17.63 | 568 | 2.45 |
| Vulkan-DZN / Qwen 3.6 35B-A3B | 8K | 340 | 17.19 | 18 | 2.68 |
| Vulkan-DZN / Gemma 4 26B-A4B, FA off, F16 V | 16K | 102 | 6.33 | 10 | 3.05 |

These rows are **not an apples-to-apples backend benchmark**. The models differ, and prompt-evaluation throughput depends strongly on prompt length. They are preserved as observed evidence showing that the Qwen control path is functional but not yet fast enough to make DZN attractive.

A later SYCL control using the same Gemma GGUF from native WSL storage remained correct and reached roughly 4.4-4.9 tok/s generation on short requests. Its visibly faster model load is operational evidence for native WSL storage, but the short prompt measurements should not be compared directly with the earlier 13.7k-token prompt throughput row.

### UMA does not eliminate memory pressure

The Intel iGPU is physically UMA/shared-memory, but the experiment again showed that backend buffers and file-backed pages can coexist and create large transient or steady pressure.

Operator observations:

- the Qwen Q4_K_M GGUF is roughly 22 GiB versus roughly 14 GiB for the tested Gemma Q4_K_XL;
- during Qwen loading, Windows Task Manager rose from roughly 32 GiB used to about 92% of the 64 GiB machine;
- the Gemma FA-off/F16-V control saturated memory much more severely.

These are operator-visible observations rather than precise backend allocation telemetry. Dispatcher Issue #4 remains the right place for automatic startup-memory/load-time telemetry.

### Issue #9 conclusion

The Vulkan investigation is therefore a **successful hardware-enablement experiment with a negative backend-selection result**:

- hardware DZN/Vulkan under WSL: **proven**;
- explicit Intel device selection: **proven**;
- real llama.cpp inference through DZN: **proven**;
- native WSL model storage: **strongly preferred on this machine**;
- Gemma 4 26B-A4B with required Flash Attention: **incorrect output**;
- FA-off Gemma workaround: **correct but memory-prohibitive**;
- Qwen 3.6 control with FA: **correct but unexpectedly slow and memory-heavy**;
- DZN installation/provisioning in normal AI Workstation setup: **deferred**;
- accepted day-to-day Intel backend: **remain on the known-good SYCL / Level Zero baseline for now**.

Do not weaken Vulkan verification or remove the side-by-side DZN evidence. The experiment proved that WSL hardware Vulkan is real. The remaining blockers are now inference correctness/performance, not device visibility.

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
- llama.cpp issue #21516 — Gemma 4 Vulkan `<unused>` token loop:
  https://github.com/ggml-org/llama.cpp/issues/21516
- llama.cpp issue #27007 — open Gemma 4 26B-A4B Vulkan corruption report:
  https://github.com/ggml-org/llama.cpp/issues/27007
- llama.cpp issue #23321 — Qwen3.6 Vulkan corruption with `no-kv-offload`:
  https://github.com/ggml-org/llama.cpp/issues/23321
- Intel Ubuntu client-GPU package instructions:
  https://dgpu-docs.intel.com/installation-guides/installing-packages-from-the-intel-ppa.html
