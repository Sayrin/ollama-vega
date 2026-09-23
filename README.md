# Ollama Vega / gfx900

Experimental Ollama build for older AMD GPUs based on the **Vega 56 / Vega 64** architecture (`gfx900`).

This repository contains the changes and build configuration required to run Ollama's ROCm/HIP backend on AMD Vega GPUs that are no longer handled correctly by current stock Ollama ROCm builds.

> **Status:** Experimental
> **Tested hardware:** 2× AMD Radeon RX Vega 56 8 GB

---

## Hardware

The project targets AMD Vega GPUs using the `gfx900` architecture.

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

> **Note:** Vega 56 has been tested with this project.

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

* Ubuntu 20.04.6 LTS
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
git clon
```
