############################################
# Shared base: whisper-ctranslate2 on the official Python slim image
############################################
# renovate: datasource=pypi depName=whisper-ctranslate2
ARG WHISPER_CTRANSLATE2_VERSION=0.5.7
# renovate: datasource=pypi depName=nvidia-cublas-cu12 versioning=pep440
ARG NVIDIA_CUBLAS_VERSION=12.9.2.10
# renovate: datasource=pypi depName=nvidia-cudnn-cu12 versioning=pep440
ARG NVIDIA_CUDNN_VERSION=9.24.0.43

FROM python:3.12.14-slim AS base

ARG WHISPER_CTRANSLATE2_VERSION

# Base stage labels
LABEL org.opencontainers.image.authors="Michael Wiesendanger <michael.wiesendanger@gmail.com>" \
      org.opencontainers.image.source="https://github.com/ragedunicorn/docker-whisper" \
      org.opencontainers.image.licenses="MIT"

# whisper-ctranslate2 pulls in faster-whisper and CTranslate2. The Alpine base
# used across the family is not possible here: CTranslate2 publishes
# glibc-only wheels. No ffmpeg is installed: audio and video containers are
# decoded by PyAV, which bundles the FFmpeg libraries in its wheel. The
# official python image ships no EXTERNALLY-MANAGED marker, so pip installs
# system-wide without friction.
RUN pip install --no-cache-dir whisper-ctranslate2==${WHISPER_CTRANSLATE2_VERSION}

# Create non-root user for running whisper-ctranslate2. Debian trixie-slim
# ships useradd (passwd package) but not the family's usual adduser, hence
# the low-level tool. A home directory is created deliberately:
# faster-whisper downloads models through huggingface_hub into
# ~/.cache/huggingface. The cache directory is pre-created with whisper
# ownership so a named volume mounted there is initialized owned by the
# whisper user instead of root.
RUN useradd --create-home --shell /usr/sbin/nologin whisper && \
    mkdir -p /home/whisper/.cache/huggingface && \
    chown -R whisper:whisper /home/whisper/.cache

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    HF_HOME=/home/whisper/.cache/huggingface

# Create working directory for input/output files
WORKDIR /tmp/workdir

RUN chown -R whisper:whisper /tmp/workdir

############################################
# CUDA variant
############################################
FROM base AS cuda

ARG NVIDIA_CUBLAS_VERSION
ARG NVIDIA_CUDNN_VERSION
ARG BUILD_DATE
ARG VERSION

# OCI-compliant labels
LABEL org.opencontainers.image.title="whisper-ctranslate2 with CUDA on Python slim" \
      org.opencontainers.image.description="Whisper speech recognition CLI (faster-whisper/CTranslate2) Docker image with CUDA 12 GPU support built on the official Python slim image" \
      org.opencontainers.image.vendor="ragedunicorn" \
      org.opencontainers.image.authors="Michael Wiesendanger <michael.wiesendanger@gmail.com>" \
      org.opencontainers.image.source="https://github.com/ragedunicorn/docker-whisper" \
      org.opencontainers.image.documentation="https://github.com/ragedunicorn/docker-whisper/blob/master/README.md" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.base.name="docker.io/library/python:3.12.14-slim"

# GPU runtime libraries as pip wheels instead of an nvidia/cuda base image:
# this is faster-whisper's documented mechanism and keeps both variants on
# the same base. CTranslate2 4.x requires cuBLAS for CUDA 12 and cuDNN 9.
# nvidia-cudnn-cu12 depends on nvidia-cublas-cu12; both are pinned
# explicitly. The GPU driver itself comes from the host via --gpus all.
RUN pip install --no-cache-dir \
    nvidia-cublas-cu12==${NVIDIA_CUBLAS_VERSION} \
    nvidia-cudnn-cu12==${NVIDIA_CUDNN_VERSION}

# The wheel library directories under site-packages are keyed to the Python
# minor version: a python 3.12 -> 3.13 base bump must update this path (and
# the paths asserted in test/cuda_test.yml and test/cpu_test.yml).
ENV LD_LIBRARY_PATH=/usr/local/lib/python3.12/site-packages/nvidia/cublas/lib:/usr/local/lib/python3.12/site-packages/nvidia/cudnn/lib

USER whisper

ENTRYPOINT ["whisper-ctranslate2"]

CMD ["--help"]

############################################
# CPU variant (default target)
############################################
FROM base AS cpu

ARG BUILD_DATE
ARG VERSION

# OCI-compliant labels
LABEL org.opencontainers.image.title="whisper-ctranslate2 on Python slim" \
      org.opencontainers.image.description="Whisper speech recognition CLI (faster-whisper/CTranslate2) Docker image built on the official Python slim image, CPU variant" \
      org.opencontainers.image.vendor="ragedunicorn" \
      org.opencontainers.image.authors="Michael Wiesendanger <michael.wiesendanger@gmail.com>" \
      org.opencontainers.image.source="https://github.com/ragedunicorn/docker-whisper" \
      org.opencontainers.image.documentation="https://github.com/ragedunicorn/docker-whisper/blob/master/README.md" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.base.name="docker.io/library/python:3.12.14-slim"

USER whisper

ENTRYPOINT ["whisper-ctranslate2"]

CMD ["--help"]
