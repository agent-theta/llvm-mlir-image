#!/usr/bin/env bash
set -euo pipefail

image="${1:-llvm-mlir:test}"

docker run --rm "$image" llvm-config --version
docker run --rm "$image" mlir-opt --version
docker run --rm "$image" mlir-tblgen --version
docker run --rm "$image" test -f /opt/llvm-mlir/lib/cmake/mlir/MLIRConfig.cmake
docker run --rm "$image" test -f /opt/llvm-mlir/lib/cmake/llvm/LLVMConfig.cmake
