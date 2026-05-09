#!/usr/bin/env bash
set -euo pipefail

image="${1:-llvm-mlir:test}"

docker run --rm "$image" bash -euxo pipefail -s <<'CONTAINER_SCRIPT'
: "${LLVM_DIR:=/opt/llvm-mlir/lib/cmake/llvm}"
: "${MLIR_DIR:=/opt/llvm-mlir/lib/cmake/mlir}"

llvm-config --version
mlir-opt --version
mlir-tblgen --version

test -f "${MLIR_DIR}/MLIRConfig.cmake"
test -f "${LLVM_DIR}/LLVMConfig.cmake"

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

cat > "${tmpdir}/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.20)
project(LLVMMLIRSmoke LANGUAGES CXX)

find_package(LLVM REQUIRED CONFIG)
find_package(MLIR REQUIRED CONFIG)

message(STATUS "Found LLVM ${LLVM_PACKAGE_VERSION}")
message(STATUS "Found MLIR at ${MLIR_DIR}")
CMAKE

cmake -S "${tmpdir}" -B "${tmpdir}/build" -G Ninja \
  -DLLVM_DIR="${LLVM_DIR}" \
  -DMLIR_DIR="${MLIR_DIR}"
CONTAINER_SCRIPT
