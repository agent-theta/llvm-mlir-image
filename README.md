# LLVM/MLIR GHCR Image

This repository builds `ghcr.io/agent-theta/llvm-mlir`, a GHCR image containing a pinned upstream LLVM/MLIR toolchain installed at `/opt/llvm-mlir`.

It is intended for downstream MLIR-based projects that want fast CI without rebuilding LLVM/MLIR on every pull request.

## Image tags

Use an LLVM commit tag when you want the image built for a specific pinned LLVM revision:

```text
ghcr.io/agent-theta/llvm-mlir:<llvm-sha>-ubuntu24.04
```

The publishing workflow also creates a short-SHA tag and `latest-ubuntu24.04` on the default branch. Treat `latest-ubuntu24.04` as a convenience tag only.

Scheduled weekly rebuilds use `--pull` and `no-cache` to refresh Ubuntu package contents. Those rebuilds may republish the same LLVM SHA tags with a different image digest, so treat all tags as mutable. For production CI, prefer digest pinning:

```text
ghcr.io/agent-theta/llvm-mlir@sha256:<digest>
```

The digest is printed in the GitHub Actions workflow summary after each publish.

## Toolchain paths

LLVM/MLIR is installed under:

```text
/opt/llvm-mlir
/opt/llvm-mlir/bin
/opt/llvm-mlir/lib/cmake/llvm
/opt/llvm-mlir/lib/cmake/mlir
```

The image also includes upstream test utilities such as `FileCheck` and `llvm-lit`.

The image sets:

```text
LLVM_DIR=/opt/llvm-mlir/lib/cmake/llvm
MLIR_DIR=/opt/llvm-mlir/lib/cmake/mlir
```

## Downstream GitHub Actions example

```yaml
jobs:
  linux:
    runs-on: ubuntu-24.04
    container:
      image: ghcr.io/agent-theta/llvm-mlir:<llvm-sha>-ubuntu24.04

    permissions:
      contents: read
      packages: read

    steps:
      - uses: actions/checkout@v4

      - name: Configure
        run: |
          cmake -S . -B build -G Ninja \
            -DCMAKE_BUILD_TYPE=Release \
            -DMLIR_DIR=/opt/llvm-mlir/lib/cmake/mlir \
            -DLLVM_DIR=/opt/llvm-mlir/lib/cmake/llvm

      - name: Build
        run: cmake --build build --parallel

      - name: Test
        run: ctest --test-dir build --output-on-failure --parallel 2
```

## Updating LLVM/MLIR

1. Resolve the current upstream LLVM commit:

   ```bash
   git ls-remote https://github.com/llvm/llvm-project.git refs/heads/main
   ```

2. Copy the first field into `llvm-project.sha`. The file must contain exactly one lowercase 40-character SHA plus a newline.
3. Commit and push to `main`, or run the workflow manually from the `main` branch. Manual runs from other refs build only and do not publish.
4. Wait for `ghcr.io/agent-theta/llvm-mlir` to publish.
5. Update downstream consumers to the new tag or digest.

GHCR packages may default to private after the first publish. If needed, set the `ghcr.io/agent-theta/llvm-mlir` package visibility to public in GitHub package settings.

## Build-time MLIR verification

The Docker build configures upstream LLVM/MLIR tests and runs `cmake --build . --target check-mlir` in the builder stage before installing the toolchain. This provides build-time verification of the pinned upstream MLIR checkout while keeping integration tests disabled and limiting targets to X86 for CI cost control.

The final runtime image contains the installed toolchain under `/opt/llvm-mlir`, but it does not retain `/build/llvm` or `/src/llvm-project`. As a result, upstream `check-mlir` is build-time verification only and cannot be rerun from the runtime image.

## Local build and smoke test

Building LLVM/MLIR is expensive and can take significant CPU, memory, disk, and time.

```bash
docker build \
  --build-arg LLVM_PROJECT_SHA="$(tr -d '[:space:]' < llvm-project.sha)" \
  --build-arg IMAGE_SOURCE_URL="https://github.com/agent-theta/llvm-mlir-image" \
  --build-arg RUN_MLIR_TESTS=ON \
  --build-arg LLVM_BUILD_JOBS=2 \
  --build-arg LLVM_LIT_WORKERS=2 \
  -t llvm-mlir:test .

scripts/smoke-test.sh llvm-mlir:test
```

For faster iterative local builds only, you can skip upstream `check-mlir` with `--build-arg RUN_MLIR_TESTS=OFF`.

The smoke test checks `llvm-config`, `mlir-opt`, `mlir-tblgen`, `FileCheck`, `llvm-lit`, the LLVM/MLIR CMake package files, a tiny lit/FileCheck MLIR test, and a minimal downstream C++ executable that includes `mlir/IR/MLIRContext.h`, links `MLIRIR`, builds with CMake/Ninja, and runs inside the image.

## Reproducibility notes

- The base image is tag-pinned as `ubuntu:24.04` and the workflow builds with `--pull`; it is not digest-pinned. Pin the base digest or record the resolved base digest in release notes if strict reproducibility matters.
- Runtime `clang` and `lld` come from Ubuntu packages. The pinned upstream LLVM install provides LLVM/MLIR libraries, tools, and CMake packages under `/opt/llvm-mlir`; build `clang`/`lld` from the same LLVM SHA if consumers need a fully version-matched compiler toolchain.
