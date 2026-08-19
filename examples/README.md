# whisper Docker Examples

This directory contains docker-compose configurations for common transcription tasks.

## Setup

The examples read input files from `media/input/` and write results to `media/output/` (relative to the repository
root). A sample `media/input/jfk.wav` ships with the repository, so the `transcribe-txt` example (and the
`run-examples` run configuration) work out of the box with no setup.

To try the other examples, drop your own recordings into `media/input/` using the file names each service expects (see
the tables below):

```bash
# media/input/ already exists with the bundled sample; add more recordings as needed
cp my-recording.mp4 media/input/video.mp4
```

The `media/` directory is otherwise gitignored - only the bundled sample is tracked, so your own inputs and all
generated outputs stay out of version control.

Every example mounts the shared `whisper-models` named volume, so a model is downloaded once and reused across all
examples and the root compose file.

All commands below are run from the repository root.

## Transcription (`docker-compose.transcribe.yml`)

| Service          | What it does                                                  |
|------------------|---------------------------------------------------------------|
| `transcribe-txt` | Transcribe `input/jfk.wav` to plain text (tiny model)         |
| `transcribe-srt` | Generate SRT subtitles from `input/jfk.wav` (small model)     |
| `transcribe-all` | Write every output format at once (txt, vtt, srt, tsv, json)  |

```bash
docker compose -f examples/docker-compose.transcribe.yml run --rm transcribe-txt
```

## Translation (`docker-compose.translate.yml`)

| Service         | What it does                                                    |
|-----------------|-----------------------------------------------------------------|
| `translate`     | Translate `input/speech.wav` (any language) to English text     |
| `translate-srt` | Translate `input/speech.wav` to English SRT subtitles           |

```bash
docker compose -f examples/docker-compose.translate.yml run --rm translate
```

## GPU Transcription (`docker-compose.cuda.yml`)

Requires an NVIDIA GPU and GPU-enabled Docker (Docker Desktop WSL2 backend or the NVIDIA Container Toolkit).

| Service                | What it does                                                 |
|------------------------|--------------------------------------------------------------|
| `cuda-transcribe`      | Transcribe `input/jfk.wav` on the GPU (small model)          |
| `cuda-transcribe-large`| Transcribe `input/video.mp4` with large-v3 (GPU recommended) |

```bash
docker compose -f examples/docker-compose.cuda.yml run --rm cuda-transcribe
```

## Customizing

The services use fixed file names (`input/jfk.wav` etc.) to stay copy-paste simple. For ad-hoc commands, use the main
compose file from the repository root and pass any whisper-ctranslate2 arguments directly:

```bash
docker compose run --rm whisper input/interview.mp4 --model medium --language de --output_dir output
```

## Image Version

All examples use `ragedunicorn/whisper:${WHISPER_VERSION:-latest}` (`${WHISPER_CUDA_VERSION:-latest-cuda}` for the GPU
examples). To run them against a different version:

**Linux/macOS:**

```bash
WHISPER_VERSION=test-cpu docker compose -f examples/docker-compose.transcribe.yml run --rm transcribe-txt
```

**Windows (PowerShell):**

```powershell
$env:WHISPER_VERSION="test-cpu"; docker compose -f examples/docker-compose.transcribe.yml run --rm transcribe-txt
```
