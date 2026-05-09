# LLVM/MLIR GHCR Image

This repository builds `ghcr.io/agent-theta/llvm-mlir`, a GHCR image containing a pinned upstream LLVM/MLIR toolchain installed at `/opt/llvm-mlir`.

It is intended for downstream MLIR-based projects that want fast CI without rebuilding LLVM/MLIR on every pull request.

## Image tags

Use an exact LLVM commit tag:

```text
ghcr.io/agent-theta/llvm-mlir:<llvm-sha>-ubuntu24.04
```

The publishing workflow also creates a short-SHA tag and `latest-ubuntu24.04` on the default branch. Treat `latest-ubuntu24.04` as a convenience tag only.

For production CI, prefer digest pinning:

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
3. Commit and push to `main`, or run the workflow manually.
4. Wait for `ghcr.io/agent-theta/llvm-mlir` to publish.
5. Update downstream consumers to the new exact tag or digest.

GHCR packages may default to private after the first publish. If needed, set the `ghcr.io/agent-theta/llvm-mlir` package visibility to public in GitHub package settings.

## Local build and smoke test

Building LLVM/MLIR is expensive and can take significant CPU, memory, disk, and time.

```bash
docker build \
  --build-arg LLVM_PROJECT_SHA="$(tr -d '[:space:]' < llvm-project.sha)" \
  -t llvm-mlir:test .

scripts/smoke-test.sh llvm-mlir:test
```

The smoke test checks `llvm-config`, `mlir-opt`, `mlir-tblgen`, and the LLVM/MLIR CMake package files inside the image.
