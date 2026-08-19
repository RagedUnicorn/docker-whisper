# Testing Guide

This document describes how to test the whisper Docker images using Container Structure Tests.

## Quick Start

```bash
# Run all tests (both variants)
docker compose -f docker-compose.test.yml run test-all

# Run one variant's suite
docker compose -f docker-compose.test.yml run test-all-cpu
docker compose -f docker-compose.test.yml run test-all-cuda

# Run individual test suites
docker compose -f docker-compose.test.yml up container-test-cpu           # File structure tests (cpu)
docker compose -f docker-compose.test.yml up container-test-command-cpu   # Command execution tests (cpu)
docker compose -f docker-compose.test.yml up container-test-metadata-cpu  # Metadata validation tests (cpu)
docker compose -f docker-compose.test.yml up container-test-cuda          # File structure tests (cuda)
docker compose -f docker-compose.test.yml up container-test-command-cuda  # Command execution tests (cuda)
docker compose -f docker-compose.test.yml up container-test-metadata-cuda # Metadata validation tests (cuda)
```

## Test Structure

Each variant has its own set of three test files (`cpu_*` and `cuda_*`, mirroring the Dockerfile target names):

### 1. File Structure Tests (`test/cpu_test.yml`, `test/cuda_test.yml`)

Validates:

- The `whisper-ctranslate2` entry point and Python interpreter exist
- The model cache directory `/home/whisper/.cache/huggingface` exists and is owned by the `whisper` user (named-volume
  initialization)
- Working directory `/tmp/workdir` exists and is accessible
- CA certificates are present
- **cpu**: the NVIDIA libraries are *absent* (negative test - GPU wheels belong only in the cuda variant)
- **cuda**: the cuBLAS and cuDNN library directories exist and ship the `libcublas.so.12*` / `libcudnn.so.9*` majors
  CTranslate2 links against

### 2. Command Execution Tests (`test/cpu_command_test.yml`, `test/cuda_command_test.yml`)

Validates:

- whisper-ctranslate2 version and help output
- The faster-whisper/CTranslate2 stack imports
- `HF_HOME` points at the pre-created model cache
- Working directory functionality
- The non-root `whisper` user exists
- **cpu**: `import nvidia.cublas` fails (negative test)
- **cuda**: the NVIDIA packages import and `LD_LIBRARY_PATH` contains both wheel library directories

**All cuda tests are GPU-independent by design**: CI runners have no GPU. Device selection in faster-whisper happens
at transcription time, so version, help, and import checks run cleanly without `--gpus`. Actual GPU execution is a
manual smoke test (see below).

### 3. Metadata Tests (`test/cpu_metadata_test.yml`, `test/cuda_metadata_test.yml`)

Validates:

- OCI-compliant labels are present and correct
- Container entrypoint and default command
- Working directory configuration
- User context (runs as the non-root `whisper` user)

## Running Tests

### Prerequisites

1. Docker must be installed and running
2. Build both whisper images locally before testing

### Important: Always Test Local Builds

**⚠️ Always build and test locally to ensure consistency:**

```bash
# Build the images locally with test tags
docker buildx build --load --provenance=false --target cpu -t ragedunicorn/whisper:test-cpu .
docker buildx build --load --provenance=false --target cuda -t ragedunicorn/whisper:test-cuda .
```

**Linux/macOS:**

```bash
# Run tests against your local builds
WHISPER_VERSION=test-cpu WHISPER_CUDA_VERSION=test-cuda docker compose -f docker-compose.test.yml run test-all
```

**Windows (PowerShell):**

```powershell
# Run tests against your local builds
$env:WHISPER_VERSION="test-cpu"; $env:WHISPER_CUDA_VERSION="test-cuda"; docker compose -f docker-compose.test.yml run test-all
```

**Windows (Command Prompt):**

```cmd
# Run tests against your local builds
set WHISPER_VERSION=test-cpu && set WHISPER_CUDA_VERSION=test-cuda && docker compose -f docker-compose.test.yml run test-all
```

**Why local testing is important:**
- Remote images (Docker Hub, GHCR) may have different labels due to CI/CD overrides
- Ensures you're testing exactly what you built
- Avoids false positives/negatives from version mismatches
- Guarantees consistent test results

**Never pull remote images for testing:**

**❌ DON'T DO THIS - may have different labels/settings:**

```bash
docker pull ragedunicorn/whisper:latest
docker compose -f docker-compose.test.yml run test-all
```

**✅ DO THIS - test your local builds:**

Linux/macOS:

```bash
docker buildx build --load --provenance=false --target cpu -t ragedunicorn/whisper:test-cpu .
docker buildx build --load --provenance=false --target cuda -t ragedunicorn/whisper:test-cuda .
WHISPER_VERSION=test-cpu WHISPER_CUDA_VERSION=test-cuda docker compose -f docker-compose.test.yml run test-all
```

Windows (PowerShell):

```powershell
docker buildx build --load --provenance=false --target cpu -t ragedunicorn/whisper:test-cpu .
docker buildx build --load --provenance=false --target cuda -t ragedunicorn/whisper:test-cuda .
$env:WHISPER_VERSION="test-cpu"; $env:WHISPER_CUDA_VERSION="test-cuda"; docker compose -f docker-compose.test.yml run test-all
```

### Functional Transcription Test

The structure tests verify the images without downloading a model. For an end-to-end check, transcribe the bundled
public-domain sample (downloads the ~75 MB tiny model into the `whisper-models` volume on first run):

**Linux/macOS:**

```bash
docker run --rm -v $(pwd)/media:/tmp/workdir -v whisper-models:/home/whisper/.cache/huggingface \
  ragedunicorn/whisper:test-cpu input/jfk.wav --model tiny --device cpu --output_format txt --output_dir output
cat media/output/jfk.txt   # "...ask what you can do for your country."
```

**Windows (PowerShell):**

```powershell
docker run --rm -v ${PWD}/media:/tmp/workdir -v whisper-models:/home/whisper/.cache/huggingface `
  ragedunicorn/whisper:test-cpu input/jfk.wav --model tiny --device cpu --output_format txt --output_dir output
Get-Content media/output/jfk.txt
```

### Manual GPU Smoke Test

GPU execution cannot run in CI (hosted runners have no GPU) - verify it manually on a machine with an NVIDIA GPU:

```bash
docker run --rm --gpus all -v $(pwd)/media:/tmp/workdir -v whisper-models:/home/whisper/.cache/huggingface \
  ragedunicorn/whisper:test-cuda input/jfk.wav --model tiny --device cuda --output_format txt --output_dir output
```

A cuBLAS/cuDNN loading error here means the NVIDIA wheel pins and `LD_LIBRARY_PATH` are out of sync - see
[DEVELOPMENT.md](DEVELOPMENT.md).

## Troubleshooting Test Failures

### NVIDIA Library Path Mismatches

The NVIDIA wheels ship versioned shared libraries whose exact file names change on updates, so `test/cuda_test.yml`
checks them with version-agnostic globs pinned only to the ABI major (`libcublas.so.12*`, `libcudnn.so.9*`). A failing
glob after a Renovate update means the wheel moved to a new library major - which CTranslate2 may not link against.

The site-packages directory in those paths is keyed to the Python minor version (`python3.12`). If the file structure
tests fail after a Python base bump, the test paths and the Dockerfile's `LD_LIBRARY_PATH` need the coordinated update
described in [DEVELOPMENT.md](DEVELOPMENT.md).

To inspect the current libraries in the image:

```bash
docker run --rm --entrypoint sh ragedunicorn/whisper:test-cuda -c \
  "find /usr/local/lib/python3.12/site-packages/nvidia -name '*.so*' | sort"
```

### Metadata Test Failures

**Common causes:**

1. **Testing remote images instead of local builds**
   - Remote images (Docker Hub, GHCR) have labels overridden by CI/CD
   - Always test your local builds with `WHISPER_VERSION=test-cpu` / `WHISPER_CUDA_VERSION=test-cuda`

2. **Label value mismatches**
   - CI/CD systems may capitalize values (e.g., "RagedUnicorn" vs "ragedunicorn")
   - GitHub Actions may override labels during build

3. **Version-specific labels**
   - The `org.opencontainers.image.version` label changes with each build
   - Build date labels are dynamic

4. **Python base image drift**
   - Both metadata tests assert `org.opencontainers.image.base.name` (e.g. `docker.io/library/python:X.X.X-slim`)
   - This value must match the `FROM python:X.X.X-slim` line and the `base.name` labels in the Dockerfile
   - Renovate keeps all of them in sync: the versions in the metadata tests and the Dockerfile labels are tracked by
     regex custom managers, so they bump together with the `FROM` line in a single `python` PR and no longer drift apart
   - If you bump Python manually, update both metadata test values in the same change

**Solution:** Always build and test locally before pushing (see above).

### Permission Errors

If you encounter Docker socket permission errors:

```bash
sudo docker compose -f docker-compose.test.yml run test-all
```

Or ensure your user is in the `docker` group:

```bash
sudo usermod -aG docker $USER
# Log out and back in for changes to take effect
```

## Writing New Tests

To add new tests, follow the Container Structure Test schema. Changes that affect both variants belong in both files
of the pair:

1. **File tests**: Add to `test/cpu_test.yml` and/or `test/cuda_test.yml`
2. **Command tests**: Add to `test/cpu_command_test.yml` and/or `test/cuda_command_test.yml`
3. **Metadata tests**: Add to `test/cpu_metadata_test.yml` and/or `test/cuda_metadata_test.yml`

Example of adding a new command test:

```yaml
- name: 'VAD filter option is available'
  command: 'whisper-ctranslate2'
  args: ['--help']
  expectedOutput:
    - 'vad_filter'
  exitCode: 0
```

## CI/CD Integration

These tests are automatically run in GitHub Actions:

- **On every push** to master branches
- **On every pull request** to master branches
- **Before releases** to ensure quality

The test workflow (`.github/workflows/test.yml`) runs a matrix over both variants:
1. Builds the variant's Docker image
2. Runs all Container Structure Tests for that variant
3. Verifies basic functionality - the cpu leg transcribes `media/input/jfk.wav` with the tiny model (downloaded from
   Hugging Face on every run, ~75 MB) and asserts the transcript; the cuda leg verifies the CUDA stack imports
4. Blocks releases if tests fail

Manual integration example:

```yaml
- name: Run Container Structure Tests
  env:
    WHISPER_VERSION: test-cpu
    WHISPER_CUDA_VERSION: test-cuda
  run: docker compose -f docker-compose.test.yml run test-all
```

The `test-all` service returns:
- Exit code 0: All tests passed
- Exit code 1: One or more tests failed

## Test Maintenance

When updating the Docker image:

1. **whisper-ctranslate2 version updates**: Usually no test changes needed (the version check asserts
   `whisper-ctranslate2 0.5`, which only needs loosening on a minor version jump)
2. **Python base updates**: Patch bumps need nothing; minor bumps need the coordinated path update described in
   [DEVELOPMENT.md](DEVELOPMENT.md)
3. **NVIDIA wheel updates**: Usually no test changes needed (globs are pinned to the ABI major only)
4. **Label changes**: Update both metadata tests to match new labels

Always run the full test suite before creating a release.
