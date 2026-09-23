# Ollama Vega / gfx900

Experimental Ollama build for older AMD GPUs based on the **Vega 56 / Vega 64** architecture (`gfx900`).

This repository contains the changes and build configuration required to run Ollama's ROCm/HIP backend on AMD Vega GPUs that are no longer handled correctly by current stock Ollama ROCm builds.

> **Status:** Experimental
> Tested hardware: **2× AMD Radeon RX Vega 56 8 GB**

---

## Hardware

Tested with:

* 2× ASRock Phantom Gaming X Radeon RX Vega 56
* 8 GB VRAM per GPU
* AMD GPU architecture: `gfx900`
* Linux
* AMDGPU kernel driver
* ROCm 6.1

The setup is capable of using both GPUs for a single model.

Example:

```text
GPU 0: Radeon RX Vega
GPU 1: Radeon RX Vega
Architecture: gfx900
VRAM: ~8176 MiB per GPU
```

---

## Why this fork?

Recent Ollama releases use newer ROCm versions and GPU detection mechanisms that do not work correctly with older Vega GPUs in some configurations.

On the tested system, stock Ollama detects the Vega GPUs but reports zero usable VRAM:

```text
skipping pseudo-device with zero memory
initial_count=0
inference compute id=cpu library=cpu
vram-based default context total_vram="0 B"
```

As a result, Ollama falls back to CPU inference.

This fork adds a compatibility workaround for the Vega/gfx900 platform.

---

# Vega VRAM workaround

The main compatibility problem is related to VRAM reporting.

On the tested Vega/ROCm combination:

```text
hipMemGetInfo()
```

does not reliably return usable VRAM information and can fail with:

```text
invalid argument
```

The workaround therefore uses:

* HIP/CUDA device properties to determine total VRAM
* Linux DRM sysfs to determine currently used VRAM

The used VRAM is obtained from:

```text
/sys/class/drm/cardX/device/mem_info_vram_used
```

The available VRAM is then calculated as:

```text
free VRAM = total VRAM - used VRAM
```

The compatibility patch is located at:

```text
llama/compat/002-llama-cpp-vega-vram.patch
```

Ollama's CMake build automatically applies patches from `llama/compat/`.

---

# Requirements

The tested build environment uses:

* Ubuntu 20.04
* Linux kernel 5.4
* ROCm 6.1
* Go 1.26
* CMake 3.31+
* AMDGPU
* AMD Vega GPU with `gfx900`

The important ROCm paths in the tested environment are:

```text
/opt/rocm-6.1.0
/usr/local/go
/opt/cmake
```

---

# Verify the GPU

Check that the GPUs are visible:

```bash
rocminfo
```

You should see something similar to:

```text
Name:                    gfx900
```

Check the DRM devices:

```bash
ls -l /dev/dri/
```

and:

```bash
ls -l /dev/kfd
```

The Ollama service/user needs access to the appropriate `render` and `video` groups.

For example:

```bash
groups
```

---

# Build

Clone the repository:

```bash
git clone https://github.com/Sayrin/ollama-vega.git
cd ollama-vega
```

The build script is:

```text
build-ollama.sh
```

Make it executable:

```bash
chmod +x build-ollama.sh
```

Then build:

```bash
./build-ollama.sh
```

The script configures:

```text
ROCm:       /opt/rocm-6.1.0
Backend:    rocm_v7_2
GPU target: gfx900
```

The build uses the AMD HIP compiler and explicitly targets:

```text
gfx900
```

---

# Build output

After a successful build:

```text
build/lib/ollama/llama-server
```

and:

```text
build/lib/ollama/rocm_v7_2/libggml-hip.so
```

are available.

The custom `llama-server` can be started directly without replacing the system Ollama installation.

---

# Running llama-server

Example for one Vega GPU:

```bash
cd build/lib/ollama

GGML_BACKEND_PATH=$PWD/rocm_v7_2/libggml-hip.so \
LD_LIBRARY_PATH=$PWD:$PWD/rocm_v7_2 \
./llama-server \
  -m /path/to/model.gguf \
  --host 127.0.0.1 \
  --port 8080 \
  -c 2048 \
  -ngl all \
  -dev ROCm0 \
  -sm none
```

For two Vega GPUs:

```bash
cd build/lib/ollama

GGML_BACKEND_PATH=$PWD/rocm_v7_2/libggml-hip.so \
LD_LIBRARY_PATH=$PWD:$PWD/rocm_v7_2 \
./llama-server \
  -m /path/to/model.gguf \
  --host 127.0.0.1 \
  --port 8080 \
  -c 2048 \
  -ngl all \
  -dev ROCm0,ROCm1 \
  -sm layer \
  -ts 1,1
```

`-ts` controls the tensor split between the GPUs.

For example:

```text
-ts 1,1
```

splits the model approximately evenly.

Other ratios can be tested:

```text
-ts 3,2
```

---

# Multi-GPU support

Two Vega 56 GPUs can be used simultaneously.

The tested configuration:

```text
ROCm0 + ROCm1
```

with:

```text
-sm layer
```

successfully performs layer splitting across both GPUs.

This makes models possible that cannot fit into a single 8 GB Vega GPU.

---

# Tested models

## Qwen2.5-Coder 7B

The Q4_K_M version runs successfully on a single Vega 56.

Test result:

```text
Prompt:     ~84.6 tokens/s
Generation: ~39.4 tokens/s
```

Using both GPUs:

```text
Prompt:     ~47.9 tokens/s
Generation: ~21.5 tokens/s
```

The dual-GPU configuration is therefore not necessarily faster for models that already fit on one GPU.

The main advantage is increased available VRAM.

---

## Qwen2.5-Coder 14B

The 14B Q4_K_M model does not fit on a single 8 GB Vega 56.

Single GPU:

```text
cudaMalloc failed: out of memory
```

Using both GPUs:

```text
-ts 1,1
```

successfully loads and runs the model.

Test result:

```text
Prompt:     ~37.6 tokens/s
Generation: ~14.2 tokens/s
```

A different split was also tested:

```text
-ts 3,2
```

with approximately:

```text
Prompt:     ~37.1 tokens/s
Generation: ~14.3 tokens/s
```

---

## Qwen 27B

A Qwen 27B Q4_K_M model can be loaded across both Vega 56 GPUs.

However, the current configuration is extremely close to the available VRAM limit.

The model can reach:

```text
model loaded
listening on http://127.0.0.1:8080
```

with approximately:

```text
GPU 0: ~8011 MiB / 8176 MiB
GPU 1: ~8131 MiB / 8176 MiB
```

At this point there is almost no free VRAM remaining.

The first inference currently fails with:

```text
ROCm error: out of memory
```

Therefore:

> **27B loading works, but 27B inference is currently not working with the present full-GPU configuration.**

The next area of investigation is reducing the number of GPU-resident layers and/or optimizing temporary VRAM usage.

---

# VRAM monitoring

Linux DRM provides useful VRAM information for the Vega GPUs.

Check current usage:

```bash
for c in /sys/class/drm/card0 /sys/class/drm/card1; do
    used=$(cat $c/device/mem_info_vram_used)
    total=$(cat $c/device/mem_info_vram_total)

    echo "$(basename $c): Used $((used/1024/1024)) MiB / Total $((total/1024/1024)) MiB"
done
```

Example:

```text
card0: Used 2500 MiB / Total 8176 MiB
card1: Used 2670 MiB / Total 8176 MiB
```

For continuous monitoring:

```bash
watch -n 1 '
for c in /sys/class/drm/card0 /sys/class/drm/card1; do
    used=$(cat $c/device/mem_info_vram_used)
    total=$(cat $c/device/mem_info_vram_total)

    echo "$(basename $c): Used $((used/1024/1024)) MiB / $((total/1024/1024)) MiB"
done
'
```

---

# Important: do not replace the system Ollama

This project can be tested independently of an existing Ollama installation.

The recommended approach is to leave the production installation untouched and run the custom `llama-server` directly.

For example:

```text
/usr/local/bin/ollama
```

can remain unchanged while the custom build is tested from:

```text
build/lib/ollama/llama-server
```

This makes it possible to compare the custom Vega build with the standard Ollama installation.

---

# Architecture

The Vega 56 is based on AMD's Vega 10 architecture:

```text
GPU
└── Vega 10
    └── gfx900
```

The build therefore explicitly targets:

```text
AMDGPU_TARGETS=gfx900
```

---

# Current limitations

This project is experimental.

Known limitations include:

* Vega/gfx900 is an older architecture.
* Modern ROCm versions have reduced support for older GPUs.
* `hipMemGetInfo()` is unreliable on the tested Vega/ROCm configuration.
* The custom VRAM detection uses Linux DRM sysfs.
* 8 GB VRAM per GPU is a significant limitation for larger models.
* Multi-GPU inference increases usable model capacity but does not necessarily increase performance.
* Large models may fail during inference because temporary buffers require additional VRAM.
* The current 27B configuration can load the model but still runs out of VRAM during inference.

---

# Tested configuration

The primary test system:

```text
CPU:
    Intel Core i5-7600K

GPU:
    2× ASRock Phantom Gaming X Radeon RX Vega 56
    8 GB VRAM each
    gfx900

OS:
    Ubuntu 20.04.6 LTS

Kernel:
    5.4.0-216-generic

ROCm:
    6.1.0

HIP:
    6.1.40091

Clang:
    AMD clang 17

Go:
    1.26.0

CMake:
    3.31.10

Ollama:
    v0.34.2
```

---

# Project status

Current status:

```text
Vega gfx900 detection        ✓
ROCm/HIP backend              ✓
Vega VRAM workaround          ✓
Single Vega GPU inference     ✓
Dual Vega GPU inference       ✓
7B models                     ✓
14B models                    ✓
27B model loading             ✓
27B inference                 ✗ VRAM limit
```

The goal of this project is to keep older AMD Vega hardware useful for local AI workloads despite its limited support in newer ROCm/Ollama releases.

---

# Disclaimer

This is an experimental compatibility project.

Performance, stability and compatibility may vary depending on:

* ROCm version
* Linux kernel
* AMDGPU driver
* GPU firmware
* model architecture
* quantization
* context size
* number of GPUs
* available VRAM

Use the standard Ollama project for officially supported hardware and configurations.

---

## License

This project is based on Ollama.

See the upstream project for the applicable license and notices.
