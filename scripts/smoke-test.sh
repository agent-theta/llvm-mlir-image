#!/usr/bin/env bash
set -euo pipefail

image="${1:-llvm-mlir:test}"

docker run --rm -i "$image" bash -euxo pipefail -s <<'CONTAINER_SCRIPT'
: "${LLVM_DIR:=/opt/llvm-mlir/lib/cmake/llvm}"
: "${MLIR_DIR:=/opt/llvm-mlir/lib/cmake/mlir}"

llvm-config --version
mlir-opt --version
mlir-tblgen --version
FileCheck --version
llvm-lit --version

test -f "${MLIR_DIR}/MLIRConfig.cmake"
test -f "${LLVM_DIR}/LLVMConfig.cmake"

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

mkdir -p "${tmpdir}/lit"
cat > "${tmpdir}/lit/lit.cfg.py" <<'PY'
import os
import lit.formats

config.name = "MLIRSmoke"
config.test_format = lit.formats.ShTest(True)
config.suffixes = [".mlir"]
config.test_source_root = os.path.dirname(__file__)
config.test_exec_root = config.test_source_root
PY

cat > "${tmpdir}/lit/basic.mlir" <<'MLIR'
// RUN: mlir-opt %s | FileCheck %s
module {}
// CHECK: module
MLIR

llvm-lit -sv "${tmpdir}/lit"

cat > "${tmpdir}/main.cpp" <<'CPP'
#include "mlir/IR/MLIRContext.h"

int main() {
  mlir::MLIRContext context;
  context.allowUnregisteredDialects();
  return 0;
}
CPP

cat > "${tmpdir}/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.20)
project(LLVMMLIRSmoke LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED YES)
set(CMAKE_CXX_EXTENSIONS NO)

find_package(LLVM REQUIRED CONFIG)
find_package(MLIR REQUIRED CONFIG)

message(STATUS "Found LLVM ${LLVM_PACKAGE_VERSION}")
message(STATUS "Found MLIR at ${MLIR_DIR}")

add_definitions(${LLVM_DEFINITIONS})
add_executable(mlir-smoke main.cpp)
target_include_directories(mlir-smoke PRIVATE ${LLVM_INCLUDE_DIRS} ${MLIR_INCLUDE_DIRS})
target_link_libraries(mlir-smoke PRIVATE MLIRIR)
CMAKE

cmake -S "${tmpdir}" -B "${tmpdir}/build" -G Ninja \
  -DLLVM_DIR="${LLVM_DIR}" \
  -DMLIR_DIR="${MLIR_DIR}"
cmake --build "${tmpdir}/build" --target mlir-smoke --parallel 2
"${tmpdir}/build/mlir-smoke"
CONTAINER_SCRIPT
