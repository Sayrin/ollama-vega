#!/bin/bash

set -e

echo "========================================"
echo " Ollama custom Vega build"
echo "========================================"

# --------------------------------------------------
# Build target
# --------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OLLAMA_SRC="$SCRIPT_DIR"
BUILD_DIR=$OLLAMA_SRC/build

# AMD Vega 56 / Vega 64
AMDGPU_TARGET=gfx900

# Ollama ROCm backend
OLLAMA_BACKEND=rocm_v7_2

# --------------------------------------------------
# ROCm / HIP
# --------------------------------------------------

export ROCM_PATH=/opt/rocm-6.1.0
export HIP_PATH=/opt/rocm-6.1.0
export CMAKE_PREFIX_PATH=$ROCM_PATH

# --------------------------------------------------
# Tools
# --------------------------------------------------

export PATH=/opt/cmake/bin:/usr/local/go/bin:$ROCM_PATH/bin:$ROCM_PATH/llvm/bin:$PATH

export CC=$ROCM_PATH/llvm/bin/clang
export CXX=$ROCM_PATH/llvm/bin/clang++
export CMAKE_HIP_COMPILER=$ROCM_PATH/bin/hipcc

# --------------------------------------------------
# Configuration
# --------------------------------------------------

echo
echo "Configuration:"
echo "  Source:       $OLLAMA_SRC"
echo "  Build:        $BUILD_DIR"
echo "  ROCm:         $ROCM_PATH"
echo "  Backend:      $OLLAMA_BACKEND"
echo "  GPU target:   $AMDGPU_TARGET"

echo
echo "ROCm:"
hipcc --version | head -2

echo
echo "Go:"
go version

echo
echo "CMake:"
cmake --version | head -1

echo
echo "========================================"
echo " Environment ready"
echo "========================================"

# --------------------------------------------------
# Ollama source
# --------------------------------------------------

cd "$OLLAMA_SRC"

# --------------------------------------------------
# CMake configuration
#
# llama/compat/*.patch is automatically applied
# by Ollama's llama.cpp compatibility mechanism.
# --------------------------------------------------

echo
echo "========================================"
echo " CMake configuration"
echo "========================================"

cmake -S . -B "$BUILD_DIR" \
  -DOLLAMA_LLAMA_BACKENDS="$OLLAMA_BACKEND" \
  -DAMDGPU_TARGETS="$AMDGPU_TARGET" \
  -DCMAKE_PREFIX_PATH="$ROCM_PATH" \
  -DCMAKE_HIP_COMPILER="$ROCM_PATH/bin/hipcc" \
  -DCMAKE_BUILD_TYPE=Release \
  -DGO_EXECUTABLE=/usr/local/go/bin/go

echo
echo "========================================"
echo " CMake configuration complete"
echo "========================================"

# --------------------------------------------------
# Build Ollama GPU backends
# --------------------------------------------------

echo
echo "========================================"
echo " Building Ollama GPU backends"
echo "========================================"

cmake --build "$BUILD_DIR" \
  --target ollama-llama-server-backends \
  -j"$(nproc)"

# --------------------------------------------------
# Build llama-server
# --------------------------------------------------

echo
echo "========================================"
echo " Building llama-server"
echo "========================================"

cmake --build "$BUILD_DIR" \
  --target ollama-llama-server-local \
  -j"$(nproc)"

echo
echo "========================================"
echo " Build complete"
echo "========================================"

echo
echo "llama-server:"
echo "  $BUILD_DIR/lib/ollama/llama-server"

echo
echo "GPU backend:"
echo "  $BUILD_DIR/lib/ollama/$OLLAMA_BACKEND/libggml-hip.so"

echo
echo "========================================"
