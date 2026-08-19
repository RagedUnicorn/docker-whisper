# Whisper Docker Image

Whisper speech recognition with [whisper-ctranslate2](https://github.com/Softcatala/whisper-ctranslate2)
(faster-whisper/CTranslate2) - transcribe and translate audio and video, on CPU or NVIDIA GPU.

## Quick Start

```bash
# Pull latest version (cpu variant)
docker pull ragedunicorn/whisper:latest

# Or the CUDA variant / a specific version
docker pull ragedunicorn/whisper:latest-cuda
docker pull ragedunicorn/whisper:0.5.7-cpu-1

# Transcribe a file (model is cached in a named volume)
docker run --rm -v $(pwd):/tmp/workdir -v whisper-models:/home/whisper/.cache/huggingface \
  ragedunicorn/whisper:latest video.mp4 --model medium --compute_type int8 --output_dir .
```

## Features

- 🚀 **Fast**: faster-whisper/CTranslate2 transcribes up to 4x faster than openai/whisper at the same accuracy
- ⚡ **Two variants**: portable CPU image (`latest`) and GPU-accelerated CUDA 12 image (`latest-cuda`)
- 🎥 **Video files work directly**: mp4/mkv audio is decoded by PyAV - no separate ffmpeg step
- 📦 **Model cache**: models download once into a mountable `~/.cache/huggingface` volume
- 🔒 **Non-root**: Runs as the unprivileged `whisper` user by default
- 🏗️ **Multi-platform**: cpu variant supports linux/amd64 and linux/arm64 (cuda is amd64-only)

## Usage Examples

### Transcribe a video file

```bash
docker run --rm -v $(pwd):/tmp/workdir -v whisper-models:/home/whisper/.cache/huggingface \
  ragedunicorn/whisper:latest video.mp4 --model medium --compute_type int8 --output_dir .
```

### Generate SRT subtitles

```bash
docker run --rm -v $(pwd):/tmp/workdir -v whisper-models:/home/whisper/.cache/huggingface \
  ragedunicorn/whisper:latest video.mp4 --model small --output_format srt --output_dir .
```

### Translate any language to English

```bash
docker run --rm -v $(pwd):/tmp/workdir -v whisper-models:/home/whisper/.cache/huggingface \
  ragedunicorn/whisper:latest interview.wav --task translate --model small --output_dir .
```

### GPU transcription (NVIDIA, CUDA 12 driver required)

```bash
docker run --rm --gpus all -v $(pwd):/tmp/workdir -v whisper-models:/home/whisper/.cache/huggingface \
  ragedunicorn/whisper:latest-cuda video.mp4 --model large-v3 --device cuda --output_dir .
```

**Not included**: live microphone transcription (needs an audio device) and speaker diarization (needs PyTorch).

## Tags

This image uses semantic versioning with a variant infix:

**Format:** `{whisper_ctranslate2_version}-{cpu|cuda}-{build_number}`

### Version Examples

- `latest` - Most recent stable release (cpu variant)
- `latest-cuda` - Most recent stable release (cuda variant)
- `0.5.7-cpu-1` - whisper-ctranslate2 0.5.7, CPU variant, build 1
- `0.5.7-cuda-1` - whisper-ctranslate2 0.5.7, CUDA variant, build 1
- `0.5.7-cpu-2` - Rebuild of the same version (base image bump, fixes)

When updates are available through automated dependency management, new releases are created with appropriate version tags.

## Links

- **GitHub**: [https://github.com/RagedUnicorn/docker-whisper](https://github.com/RagedUnicorn/docker-whisper)
- **Issues**: [https://github.com/RagedUnicorn/docker-whisper/issues](https://github.com/RagedUnicorn/docker-whisper/issues)
- **Releases**: [https://github.com/RagedUnicorn/docker-whisper/releases](https://github.com/RagedUnicorn/docker-whisper/releases)

## License

MIT License - See [GitHub repository](https://github.com/RagedUnicorn/docker-whisper) for details.
