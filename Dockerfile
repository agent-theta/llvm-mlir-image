# syntax=docker/dockerfile:1.7

ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION} AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG LLVM_PROJECT_SHA
ARG LLVM_INSTALL_PREFIX=/opt/llvm-mlir
ARG LLVM_PARALLEL_LINK_JOBS=2
ARG RUN_MLIR_TESTS=ON
ARG LLVM_BUILD_JOBS=2
ARG LLVM_LIT_WORKERS=2

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    clang \
    cmake \
    git \
    lld \
    ninja-build \
    python3 \
    python3-pip \
    build-essential \
  && rm -rf /var/lib/apt/lists/*

RUN set -eu; \
    test -n "${LLVM_PROJECT_SHA}"; \
    test "${LLVM_PROJECT_SHA}" != "<exact-llvm-project-commit-sha>"; \
    printf '%s' "${LLVM_PROJECT_SHA}" | grep -Eq '^[0-9a-f]{40}$'

WORKDIR /src
RUN set -eux; \
    git init llvm-project; \
    cd llvm-project; \
    git remote add origin https://github.com/llvm/llvm-project.git; \
    git fetch --depth=1 origin "${LLVM_PROJECT_SHA}"; \
    git checkout --detach FETCH_HEAD; \
    test "$(git rev-parse HEAD)" = "${LLVM_PROJECT_SHA}"

WORKDIR /build/llvm
RUN cmake -G Ninja /src/llvm-project/llvm \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${LLVM_INSTALL_PREFIX}" \
    -DLLVM_ENABLE_PROJECTS=mlir \
    -DLLVM_TARGETS_TO_BUILD=X86 \
    -DLLVM_ENABLE_ASSERTIONS=ON \
    -DLLVM_ENABLE_LLD=ON \
    -DLLVM_INCLUDE_BENCHMARKS=OFF \
    -DLLVM_INCLUDE_EXAMPLES=OFF \
    -DLLVM_INCLUDE_TESTS=ON \
    -DLLVM_INCLUDE_DOCS=OFF \
    -DLLVM_INSTALL_UTILS=ON \
    -DMLIR_INCLUDE_INTEGRATION_TESTS=OFF \
    -DLLVM_LIT_ARGS="-sv --workers=${LLVM_LIT_WORKERS}" \
    -DLLVM_PARALLEL_LINK_JOBS="${LLVM_PARALLEL_LINK_JOBS}"

RUN set -eu; \
    test "$(pwd)" = /build/llvm; \
    case "${RUN_MLIR_TESTS}" in \
      ON) \
        cmake --build . --target check-mlir --parallel "${LLVM_BUILD_JOBS}" ;; \
      OFF) \
        echo "Skipping upstream MLIR check-mlir because RUN_MLIR_TESTS=${RUN_MLIR_TESTS}" ;; \
      *) \
        echo "RUN_MLIR_TESTS must be ON or OFF (got '${RUN_MLIR_TESTS}')" >&2; \
        exit 1 ;; \
    esac

RUN cmake --build . --target install --parallel "${LLVM_BUILD_JOBS}" \
  && cd / \
  && rm -rf /build/llvm /src/llvm-project

FROM ubuntu:${UBUNTU_VERSION} AS runtime

ARG DEBIAN_FRONTEND=noninteractive
ARG LLVM_PROJECT_SHA
ARG LLVM_INSTALL_PREFIX=/opt/llvm-mlir
ARG IMAGE_SOURCE_URL="https://github.com/agent-theta/llvm-mlir-image"

LABEL org.opencontainers.image.title="LLVM/MLIR Toolchain" \
      org.opencontainers.image.description="Prebuilt LLVM/MLIR toolchain for downstream MLIR-based projects" \
      org.opencontainers.image.source="${IMAGE_SOURCE_URL}" \
      org.opencontainers.image.licenses="Apache-2.0 WITH LLVM-exception" \
      org.opencontainers.image.revision="${LLVM_PROJECT_SHA}"

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    clang \
    cmake \
    git \
    lld \
    ninja-build \
    python3 \
    build-essential \
  && rm -rf /var/lib/apt/lists/*

COPY --from=builder ${LLVM_INSTALL_PREFIX} ${LLVM_INSTALL_PREFIX}

ENV PATH="${LLVM_INSTALL_PREFIX}/bin:${PATH}" \
    MLIR_DIR="${LLVM_INSTALL_PREFIX}/lib/cmake/mlir" \
    LLVM_DIR="${LLVM_INSTALL_PREFIX}/lib/cmake/llvm"

RUN llvm-config --version \
  && mlir-opt --version \
  && mlir-tblgen --version \
  && FileCheck --version \
  && llvm-lit --version \
  && test -f "${MLIR_DIR}/MLIRConfig.cmake" \
  && test -f "${LLVM_DIR}/LLVMConfig.cmake"

WORKDIR /workspace
