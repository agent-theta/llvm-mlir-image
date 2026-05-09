# syntax=docker/dockerfile:1.7

ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION} AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG LLVM_PROJECT_SHA
ARG LLVM_INSTALL_PREFIX=/opt/llvm-mlir
ARG LLVM_PARALLEL_LINK_JOBS=2

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
    git clone --filter=blob:none --no-checkout https://github.com/llvm/llvm-project.git llvm-project; \
    cd llvm-project; \
    git checkout "${LLVM_PROJECT_SHA}"

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
    -DLLVM_INCLUDE_TESTS=OFF \
    -DLLVM_INCLUDE_DOCS=OFF \
    -DMLIR_INCLUDE_INTEGRATION_TESTS=OFF \
    -DLLVM_PARALLEL_LINK_JOBS="${LLVM_PARALLEL_LINK_JOBS}"

RUN ninja install

FROM ubuntu:${UBUNTU_VERSION} AS runtime

ARG DEBIAN_FRONTEND=noninteractive
ARG LLVM_PROJECT_SHA
ARG LLVM_INSTALL_PREFIX=/opt/llvm-mlir

LABEL org.opencontainers.image.title="LLVM/MLIR Toolchain" \
      org.opencontainers.image.description="Prebuilt LLVM/MLIR toolchain for downstream MLIR-based projects" \
      org.opencontainers.image.source="https://github.com/agent-theta/llvm-mlir-image" \
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
  && mlir-tblgen --version

WORKDIR /workspace
