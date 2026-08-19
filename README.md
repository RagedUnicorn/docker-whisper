# docker-whisper

![](./docs/docker_whisper.svg)

[![Release Build](https://github.com/RagedUnicorn/docker-whisper/actions/workflows/docker_release.yml/badge.svg)](https://github.com/RagedUnicorn/docker-whisper/actions/workflows/docker_release.yml)
[![Test](https://github.com/RagedUnicorn/docker-whisper/actions/workflows/test.yml/badge.svg)](https://github.com/RagedUnicorn/docker-whisper/actions/workflows/test.yml)
![License: MIT](docs/license_badge.svg)

> Docker image for Whisper speech recognition with whisper-ctranslate2 - transcribe and translate audio and video, on CPU or NVIDIA GPU.

## Overview

This Docker image provides [whisper-ctranslate2](https://github.com/Softcatala/whisper-ctranslate2), a command-line
client compatible with the original OpenAI Whisper CLI but built on [faster-whisper](https://github.com/SYSTRAN/faster-whisper)
and [CTranslate2](https://github.com/OpenNMT/CTranslate2), which transcribes up to four times faster than
`openai/whisper` at the same accuracy. It runs on the official Python slim image.

Two variants are published from this repository:

- **cpu** (`latest`) - runs anywhere; use it for occasional transcription on machines without an NVIDIA GPU
- **cuda** (`latest-cuda`) - ships the CUDA 12 runtime libraries (cuBLAS + cuDNN 9); with an NVIDIA GPU, transcription
  is an order of magnitude faster and the `large-v3` model becomes practical

## Features

- **Two variants**: portable CPU image and GPU-accelerated CUDA image
- **Video files work directly**: audio and video containers (mp4, mkv, ...) are decoded by PyAV - no separate ffmpeg
  extraction step
- **Model cache**: models are downloaded once into `~/.cache/huggingface`; mount a named volume there and the
  container stays disposable
- **Whisper CLI compatible**: same arguments as the original OpenAI Whisper CLI, plus faster-whisper extras (VAD
  filter, word timestamps, batched inference)
- **Non-root**: Runs as the unprivileged `whisper` user by default
- **Multi-arch**: the cpu variant is published for amd64 and arm64 (cuda is amd64-only)

## Models

Models are downloaded automatically from Hugging Face on first use (see [Model Cache](#model-cache)):

| Model            | Parameters | Download | Notes                                             |
|------------------|------------|----------|---------------------------------------------------|
| `tiny`           | 39 M       | ~75 MB   | Fastest, rough quality - good for tests           |
| `base`           | 74 M       | ~145 MB  |                                                   |
| `small`          | 244 M      | ~480 MB  | Good quality/speed balance on CPU                 |
| `medium`         | 769 M      | ~1.5 GB  | CPU sweet spot with `--compute_type int8`         |
| `large-v3`       | 1550 M     | ~3.1 GB  | Best quality - recommended default on GPU         |
| `distil-large-v3`| 756 M      | ~1.5 GB  | English-only, close to large-v3 quality, faster   |

### Not included

- **Live microphone transcription** (`--live_transcribe`) - requires PortAudio and an audio device, neither of which
  exists inside a container
- **Speaker diarization** (`--hf_token` + pyannote) - requires PyTorch, deliberately excluded to keep the image small

## Quick Start

```bash
# Pull the image (cpu variant)
docker pull ragedunicorn/whisper:latest

# Transcribe a file from the current directory (model is cached in a named volume)
docker run --rm -v $(pwd):/tmp/workdir -v whisper-models:/home/whisper/.cache/huggingface \
  ragedunicorn/whisper:latest video.mp4 --model medium --compute_type int8 --output_dir .
```

With an NVIDIA GPU:

```bash
docker pull ragedunicorn/whisper:latest-cuda

docker run --rm --gpus all -v $(pwd):/tmp/workdir -v whisper-models:/home/whisper/.cache/huggingface \
  ragedunicorn/whisper:latest-cuda video.mp4 --model large-v3 --device cuda --output_dir .
```

For development and building from source, see [DEVELOPMENT.md](DEVELOPMENT.md).

## Usage

The container uses `whisper-ctranslate2` as the entrypoint, so any Whisper parameters can be passed directly to the
`docker run` command. Running the image without arguments prints the CLI help.

### Basic Usage

**Linux/macOS:**

```bash
# Using latest version (cpu)
docker run --rm -v $(pwd):/tmp/workdir -v whisper-models:/home/whisper/.cache/huggingface \
  ragedunicorn/whisper:latest [whisper-options]

# Using exact version
docker run --rm -v $(pwd):/tmp/workdir -v whisper-models:/home/whisper/.cache/huggingface \
  ragedunicorn/whisper:0.5.7-cpu-1 [whisper-options]
```

**Windows (PowerShell):**

```powershell
# Using latest version (cpu)
docker run --rm -v ${PWD}:/tmp/workdir -v whisper-models:/home/whisper/.cache/huggingface `
  ragedunicorn/whisper:latest [whisper-options]

# Using the CUDA variant
docker run --rm --gpus all -v ${PWD}:/tmp/workdir -v whisper-models:/home/whisper/.cache/huggingface `
  ragedunicorn/whisper:latest-cuda [whisper-options] --device cuda
```

### Examples

The volume mounts are omitted below for brevity - add
`-v $(pwd):/tmp/workdir -v whisper-models:/home/whisper/.cache/huggingface` (and `--gpus all` for the cuda variant)
as shown above.

#### Transcribe a Video File

```bash
docker run --rm ... ragedunicorn/whisper:latest video.mp4 --model medium --compute_type int8 --output_dir .
```

#### Generate Subtitles Only

```bash
docker run --rm ... ragedunicorn/whisper:latest video.mp4 --model small --output_format srt --output_dir .
```

#### Translate Any Language to English

```bash
docker run --rm ... ragedunicorn/whisper:latest interview.wav --task translate --model small --output_dir .
```

#### Pin the Spoken Language

Skips language detection and improves accuracy when the language is known:

```bash
docker run --rm ... ragedunicorn/whisper:latest video.mp4 --model medium --language de --output_dir .
```

#### Word-level Timestamps

```bash
docker run --rm ... ragedunicorn/whisper:latest video.mp4 --model small --word_timestamps True --output_dir .
```

#### GPU Transcription with the Best Model

```bash
docker run --rm --gpus all ... ragedunicorn/whisper:latest-cuda video.mp4 --model large-v3 --device cuda --output_dir .
```

### GPU Support

The cuda variant bundles the CUDA 12 runtime libraries (cuBLAS and cuDNN 9) as pip wheels - the
[mechanism documented by faster-whisper](https://github.com/SYSTRAN/faster-whisper#gpu) - so the host only needs:

- An NVIDIA GPU with a driver supporting CUDA 12
- GPU-enabled Docker: Docker Desktop with the WSL2 backend (Windows) or the
  [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/index.html) (Linux)

Pass `--gpus all` to `docker run` and `--device cuda` to whisper-ctranslate2. Without `--device cuda` the CLI
auto-selects, and without `--gpus all` the cuda image silently falls back to CPU.

### Model Cache

On first use of a model, faster-whisper downloads it from Hugging Face into `/home/whisper/.cache/huggingface`
(`HF_HOME`). Mount a named volume there so models survive `--rm` containers:

```bash
docker run --rm -v whisper-models:/home/whisper/.cache/huggingface ...
```

The image pre-creates the cache directory owned by the `whisper` user, so a fresh named volume is initialized
writable. After the first download the image works fully offline for that model.

## Docker Compose Usage

This repository includes Docker Compose configurations for easier usage and common transcription workflows.

### Basic Setup

1. Create a `media` directory structure:

```bash
mkdir -p media/input media/output
```

2. Place your input files in `media/input/`

3. Run whisper using docker compose:

```bash
docker compose run --rm whisper input/video.mp4 --model medium --output_dir output

# Or on the GPU
docker compose run --rm whisper-cuda input/video.mp4 --model large-v3 --device cuda --output_dir output
```

The compose services already mount the `whisper-models` volume for the model cache.

### Example Configurations

The `examples/` directory contains specialized docker-compose files for common tasks:

#### Transcription (`examples/docker-compose.transcribe.yml`)

```bash
# Transcribe the bundled JFK sample to plain text
docker compose -f examples/docker-compose.transcribe.yml run --rm transcribe-txt

# Generate SRT subtitles
docker compose -f examples/docker-compose.transcribe.yml run --rm transcribe-srt
```

#### Translation (`examples/docker-compose.translate.yml`)

```bash
# Translate a non-English recording to English
docker compose -f examples/docker-compose.translate.yml run --rm translate
```

#### GPU Transcription (`examples/docker-compose.cuda.yml`)

```bash
# Transcribe on the GPU
docker compose -f examples/docker-compose.cuda.yml run --rm cuda-transcribe
```

See [examples/README.md](examples/README.md) for the full list of example services.

### Environment Variables

- `WHISPER_VERSION`: Specify the cpu image version (default: latest)
- `WHISPER_CUDA_VERSION`: Specify the cuda image version (default: latest-cuda)

### Tips

1. **Custom Commands**: Override the default command:

   ```bash
   docker compose run --rm whisper input/podcast.mp3 --model small --language en --output_format txt --output_dir output
   ```

2. **CPU speed**: On CPU, `--compute_type int8` roughly halves memory use and speeds up inference with negligible
   quality loss

3. **Persistent Settings**: The repository includes a `.env` file with default settings. You can modify it to set your
   preferred versions:

   ```env
   WHISPER_VERSION=0.5.7-cpu-1
   WHISPER_CUDA_VERSION=0.5.7-cuda-1
   ```

## Versioning

This project uses semantic versioning that matches the Docker image contents:

**Format:** `{whisper_ctranslate2_version}-{cpu|cuda}-{build_number}`

Examples:
- `0.5.7-cpu-1` - whisper-ctranslate2 0.5.7, CPU variant, build 1
- `0.5.7-cuda-1` - whisper-ctranslate2 0.5.7, CUDA variant, build 1
- `latest` - Most recent stable release (cpu)
- `latest-cuda` - Most recent stable release (cuda)

A single git tag (`v{whisper_ctranslate2_version}-{build_number}`) produces both variant images. Unlike the Alpine
siblings there is no base-OS segment in the tag - Python base bumps only increment the build number.

For detailed release process and versioning guidelines, see [RELEASE.md](RELEASE.md).

## Automated Dependency Updates

This project uses [Renovate](https://docs.renovatebot.com/) to automatically check for updates to:
- Python base image version (patch updates automerge; minor bumps need a coordinated update of the CUDA library path,
  see [DEVELOPMENT.md](DEVELOPMENT.md))
- whisper-ctranslate2 pip pin
- NVIDIA CUDA runtime wheels (cuBLAS + cuDNN, grouped into one PR)

Renovate runs weekly (every Monday) and creates pull requests when updates are available.

## Documentation

- [Development Guide](DEVELOPMENT.md) - Building, debugging, and contributing
- [Testing Guide](TEST.md) - Running and writing tests
- [Release Process](RELEASE.md) - Creating releases and versioning

## Links

- [whisper-ctranslate2](https://github.com/Softcatala/whisper-ctranslate2)
- [faster-whisper](https://github.com/SYSTRAN/faster-whisper)
- [CTranslate2](https://github.com/OpenNMT/CTranslate2)
- [OpenAI Whisper](https://github.com/openai/whisper)

# License

MIT License

Copyright (c) 2026 Michael Wiesendanger

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
