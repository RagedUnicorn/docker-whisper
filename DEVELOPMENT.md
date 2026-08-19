# Development Guide

This document provides information for developers working on the whisper Docker image.

## Development Environment

### Prerequisites

- Docker installed and running
- Docker Compose installed
- Git for version control
- Text editor or IDE

### Project Structure

```
docker-whisper/
├── Dockerfile              # Both image variants (base, cuda, cpu stages)
├── docker-compose.yml      # Basic usage configuration (whisper + whisper-cuda)
├── docker-compose.dev.yml  # Development environment
├── docker-compose.test.yml # Test orchestration for both variants
├── .env                    # Default environment variables
├── examples/               # Example Docker Compose configurations
│   ├── docker-compose.transcribe.yml
│   ├── docker-compose.translate.yml
│   └── docker-compose.cuda.yml
├── media/                  # Local working directory (input/output)
│   └── input/jfk.wav       # Bundled public-domain test sample
├── test/                   # Container Structure Tests (per variant)
│   ├── cpu_test.yml
│   ├── cpu_command_test.yml
│   ├── cpu_metadata_test.yml
│   ├── cuda_test.yml
│   ├── cuda_command_test.yml
│   └── cuda_metadata_test.yml
└── docs/                   # Documentation assets
```

### Image Variants

The Dockerfile builds two variants from a shared `base` stage:

- **`cpu`** - the default target (last stage), published as `latest`
- **`cuda`** - adds the NVIDIA CUDA runtime wheels (cuBLAS + cuDNN 9) and `LD_LIBRARY_PATH`, published as
  `latest-cuda`

The `cpu` stage is last, so a bare `docker build .` produces the CPU image. Both variants stay on the official Python
slim base - the CUDA libraries come from pip wheels (faster-whisper's documented mechanism), not from an `nvidia/cuda`
base image.

## Development Workflow

### 1. Local Development Mode

The `docker-compose.dev.yml` file provides an interactive development environment:

```bash
# Build the image locally
docker compose -f docker-compose.dev.yml build

# Run in development mode (interactive shell)
docker compose -f docker-compose.dev.yml run --rm whisper-dev

# Inside the container, you can run whisper-ctranslate2 manually
whisper-ctranslate2 --version
whisper-ctranslate2 input/jfk.wav --model tiny --output_dir output
```

The development mode:

- Overrides the entrypoint to `/bin/bash` for interactive access
- Mounts the `./media` directory for testing files
- Mounts the shared `whisper-models` volume so models are not re-downloaded
- Sets a custom prompt to identify the development environment
- Keeps STDIN open and allocates a TTY

### 2. Building the Images

```bash
# Build both variants
docker buildx build --load --provenance=false --target cpu -t ragedunicorn/whisper:test-cpu .
docker buildx build --load --provenance=false --target cuda -t ragedunicorn/whisper:test-cuda .

# Build with specific versions
docker buildx build --load --provenance=false --target cpu \
  --build-arg WHISPER_CTRANSLATE2_VERSION=0.5.7 \
  --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
  --build-arg VERSION=0.5.7-cpu-1 \
  -t ragedunicorn/whisper:0.5.7-cpu-1 .

# Multi-platform build (cpu only - the cuda variant is amd64-only)
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --target cpu \
  -t ragedunicorn/whisper:dev .
```

### 3. Testing Your Changes

After making changes, always build and test locally:

```bash
# Build your changes locally
docker buildx build --load --provenance=false --target cpu -t ragedunicorn/whisper:test-cpu .
docker buildx build --load --provenance=false --target cuda -t ragedunicorn/whisper:test-cuda .
```

#### Running Tests (Cross-Platform)

**Linux/macOS:**

```bash
# Run all tests against your local builds
WHISPER_VERSION=test-cpu WHISPER_CUDA_VERSION=test-cuda docker compose -f docker-compose.test.yml run test-all

# Run specific tests during development
WHISPER_VERSION=test-cpu docker compose -f docker-compose.test.yml up container-test-command-cpu
```

**Windows Command Prompt:**

```cmd
# Run all tests against your local builds
set WHISPER_VERSION=test-cpu && set WHISPER_CUDA_VERSION=test-cuda && docker compose -f docker-compose.test.yml run test-all
```

**Windows PowerShell:**

```powershell
# Run all tests against your local builds
$env:WHISPER_VERSION="test-cpu"; $env:WHISPER_CUDA_VERSION="test-cuda"; docker compose -f docker-compose.test.yml run test-all

# Run specific tests during development
$env:WHISPER_VERSION="test-cpu"; docker compose -f docker-compose.test.yml up container-test-command-cpu
```

**Important:** Never test against remote images - they may have different labels or configurations due to CI/CD overrides.

See [TEST.md](TEST.md) for detailed testing information.

## Making Changes

### Version Updates

This project uses [Renovate](https://docs.renovatebot.com/) to automatically manage dependency updates. Four versions
are pinned in the Dockerfile via `# renovate:`-commented ARGs and the `FROM` line:

- **whisper-ctranslate2**: pip pin, tracked via PyPI (minor/patch automerge)
- **nvidia-cublas-cu12 / nvidia-cudnn-cu12**: pip pins, tracked via PyPI and grouped into one PR (cudnn depends on
  cublas, so they move together; majors stay manual - a cuBLAS major follows the CUDA major CTranslate2 is built
  against, and a cuDNN major changes the `libcudnn.so.9` soname asserted in `test/cuda_test.yml`)
- **Python base image**: tracked via Docker Hub (patch automerge only, see below)

The Python base version is referenced in several places that must stay aligned:

- The `FROM python:X.X.X-slim` line in the Dockerfile (tracked by Renovate's built-in Dockerfile manager)
- The `org.opencontainers.image.base.name` OCI labels in both variant stages (tracked by a regex custom manager)
- The base version asserted in `test/cpu_metadata_test.yml` and `test/cuda_metadata_test.yml` (tracked by a regex
  custom manager)

All of these resolve to the same `python` dependency at the same version, so Renovate bumps them together in a single
PR - the base image, the labels, and the metadata tests no longer drift apart.

**Manual step on Python minor bumps (e.g. 3.12 → 3.13):** the NVIDIA wheels install their libraries under a
site-packages path keyed to the Python minor version. A minor bump must update, in the same change:

1. The `LD_LIBRARY_PATH` in the Dockerfile's cuda stage (`python3.12` → `python3.13`)
2. The `python3.12` site-packages paths asserted in `test/cpu_test.yml` (NVIDIA-absence check) and
   `test/cuda_test.yml` (library directory and glob checks)

This is why the Renovate config automerges only **patch** updates for the Python base - a minor-bump PR without the
coordinated path update fails CI by design.

When Renovate creates a PR:

1. Review the changes in the PR
2. Check the CI/CD pipeline passes all tests
3. Test the build locally if it's a major version update
4. Merge the PR if everything looks good

### Adding Optional Features

whisper-ctranslate2 has optional capabilities that are deliberately excluded to keep the image small:

- **Speaker diarization** needs PyTorch (`pip install torch`) - several GB
- **Live microphone transcription** needs PortAudio (`libportaudio2`) and an audio device passed into the container

To build a variant with one of these, add the dependency in the `base` stage, then:

1. Add command tests verifying the feature imports/runs in `test/cpu_command_test.yml` and `test/cuda_command_test.yml`
2. Update the "Not included" lists in README.md and DOCKERHUB.md
3. Test the build locally

## Code Style and Best Practices

### Dockerfile Best Practices

1. **Shared base stage**: Everything common to both variants belongs in `base`; variant stages only add their delta
2. **Layer optimization**: Group related commands to minimize layers
3. **Cache efficiency**: Order commands from least to most frequently changed
4. **Security**: Run as a non-root user; keep the dependency set minimal
5. **Labels**: Follow OCI naming conventions; per-variant title/description live in the variant stages

### Documentation

1. **README.md**: Keep focused on user-facing information
2. **Comments**: Add comments in Dockerfile for complex operations
3. **Examples**: Provide working examples for new features
4. **Commit messages**: Use conventional format (feat:, fix:, docs:, etc.)

### Testing

1. **Test everything**: New features must include tests
2. **Test edge cases**: Include negative tests where appropriate (the CPU image asserts the NVIDIA libraries are absent)
3. **Keep tests GPU-independent**: CI runners have no GPU - cuda tests must verify presence and importability, not
   actual GPU execution
4. **Test organization**: Group related tests together

## Debugging

### Common Issues

**Build failures:**

```bash
# Verbose build output
docker buildx build --load --provenance=false --progress=plain --no-cache --target cpu -t ragedunicorn/whisper:debug .
```

**Model download issues:**

```bash
# Check the Hugging Face cache location and contents
docker run --rm --entrypoint sh ragedunicorn/whisper:test-cpu -c 'echo "$HF_HOME" && ls -la "$HF_HOME"'

# With the named volume mounted
docker run --rm -v whisper-models:/home/whisper/.cache/huggingface \
  --entrypoint sh ragedunicorn/whisper:test-cpu -c 'ls -la "$HF_HOME/hub"'
```

**CUDA library issues:**

```bash
# Check the NVIDIA wheel libraries are present (cuda variant)
docker run --rm --entrypoint sh ragedunicorn/whisper:test-cuda -c \
  "ls /usr/local/lib/python3.12/site-packages/nvidia/cublas/lib /usr/local/lib/python3.12/site-packages/nvidia/cudnn/lib"

# Check the dynamic linker path
docker run --rm --entrypoint sh ragedunicorn/whisper:test-cuda -c 'echo "$LD_LIBRARY_PATH"'

# Verify GPU access end-to-end (requires an NVIDIA GPU on the host)
docker run --rm --gpus all -v $(pwd)/media:/tmp/workdir -v whisper-models:/home/whisper/.cache/huggingface \
  ragedunicorn/whisper:test-cuda input/jfk.wav --model tiny --device cuda --output_dir output
```

## Contributing

### Before Submitting Changes

1. Run the full test suite
2. Update documentation if needed
3. Add tests for new features
4. Ensure your code follows the existing style
5. Write clear commit messages

### Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes using conventional commits
4. Push to your fork
5. Open a Pull Request with a clear description

### Release Process

See [RELEASE.md](RELEASE.md) for information about creating releases.
