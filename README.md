# LLVM/MLIR GHCR Image

This repository builds `ghcr.io/<owner>/llvm-mlir`, a GHCR image containing a pinned upstream LLVM/MLIR toolchain installed at `/opt/llvm-mlir`.

Replace `<owner>` with the lowercase GitHub user or organization that owns this repository. The publish workflow computes it from `github.repository_owner` and lowercases it for GHCR compatibility.

It is intended for downstream MLIR-based projects that want fast CI without rebuilding LLVM/MLIR on every pull request.

## Image tags

Use an LLVM commit tag when you want the image built for a specific pinned LLVM revision:

```text
ghcr.io/<owner>/llvm-mlir:<llvm-sha>-ubuntu24.04
```

The publishing workflow also creates a short-SHA tag and `latest-ubuntu24.04` on the default branch. Treat `latest-ubuntu24.04` as a convenience tag only.

Scheduled weekly rebuilds use `--pull` and `no-cache` to refresh Ubuntu package contents. Those rebuilds may republish the same LLVM SHA tags with a different image digest, so treat all tags as mutable. For production CI, prefer digest pinning:

```text
ghcr.io/<owner>/llvm-mlir@sha256:<digest>
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
      image: ghcr.io/<owner>/llvm-mlir:<llvm-sha>-ubuntu24.04

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
4. Wait for `ghcr.io/<owner>/llvm-mlir` to publish.
5. Update downstream consumers to the new tag or digest.

GHCR packages may default to private after the first publish. If needed, set the `ghcr.io/<owner>/llvm-mlir` package visibility to public in GitHub package settings.

## Local build and smoke test

Building LLVM/MLIR is expensive and can take significant CPU, memory, disk, and time.

```bash
docker build \
  --build-arg LLVM_PROJECT_SHA="$(tr -d '[:space:]' < llvm-project.sha)" \
  --build-arg IMAGE_SOURCE_URL="https://github.com/<owner>/llvm-mlir-image" \
  -t llvm-mlir:test .

scripts/smoke-test.sh llvm-mlir:test
```

The smoke test checks `llvm-config`, `mlir-opt`, `mlir-tblgen`, the LLVM/MLIR CMake package files, and a minimal downstream CMake configure against `LLVM_DIR`/`MLIR_DIR` inside the image.

## Reproducibility notes

- The base image is tag-pinned as `ubuntu:24.04` and the workflow builds with `--pull`; it is not digest-pinned. Pin the base digest or record the resolved base digest in release notes if strict reproducibility matters.
- Runtime `clang` and `lld` come from Ubuntu packages. The pinned upstream LLVM install provides LLVM/MLIR libraries, tools, and CMake packages under `/opt/llvm-mlir`; build `clang`/`lld` from the same LLVM SHA if consumers need a fully version-matched compiler toolchain.
