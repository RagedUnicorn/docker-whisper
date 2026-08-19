# Release Process

This document describes how to create a new release for the docker-whisper project.

## Quick Start

```bash
# Tag format: v{whisper_ctranslate2_version}-{build_number}
git tag -a v0.5.7-1 -m "v0.5.7-1"
git push origin v0.5.7-1
```

This automatically triggers the release process via GitHub Actions. A single git tag produces **both** variant images.

## Version Tag Format

See [README.md](README.md#versioning) for the complete versioning documentation.

**Format:** `v{whisper_ctranslate2_version}-{build_number}`

Unlike the Alpine-based siblings there is no base-OS segment in the tag - the Python base is an implementation detail,
and base bumps only increment the build number.

Examples:
- `v0.5.7-1` - Initial release
- `v0.5.7-2` - Rebuild with the same whisper-ctranslate2 version (Python base bump, NVIDIA wheel bump, fixes)
- `v0.5.8-1` - whisper-ctranslate2 update (build resets to 1)

Docker tags produced by `v0.5.7-1`:

- `0.5.7-cpu-1` and `latest` (cpu variant)
- `0.5.7-cuda-1` and `latest-cuda` (cuda variant)

## Release Workflow

When you push a tag, GitHub Actions automatically:

1. **Builds Docker images** (`.github/workflows/docker_release.yml`)
   - Re-runs the Container Structure Tests for both variants as a gate
   - cpu variant: linux/amd64 and linux/arm64; cuda variant: linux/amd64 only (the aarch64 CTranslate2 wheels are
     CPU-only builds)
   - Pushes both variants to both GitHub Container Registry and Docker Hub

2. **Creates GitHub Release** (`.github/workflows/github_release.yml`)
   - Generates changelog from commit history
   - Adds Docker pull commands for both variants
   - Links to the release

## When to Create a Release

Create a new release when:

1. **Renovate updates dependencies** - After merging Renovate PRs for whisper-ctranslate2, the Python base, or the
   NVIDIA wheels
2. **Bug fixes** - After fixing issues in the Dockerfile or build process
3. **Feature additions** - After adding new capabilities to the image
4. **Security patches** - Immediately after security-related updates

### Build Number Guidelines

- **Reset to 1**: When the whisper-ctranslate2 version changes
- **Increment**: For everything else - Python base bumps, NVIDIA wheel bumps, rebuilds with fixes or optimizations

## Post-Release Tasks

### Update Docker Hub Documentation

After creating a release, manually update the Docker Hub repository description:

1. Go to [Docker Hub](https://hub.docker.com/r/ragedunicorn/whisper)
2. Click "Manage Repository" → "Description"
3. Copy the contents of `DOCKERHUB.md`
4. Update any version numbers in the examples to match the latest release
5. Save the changes

**Note**: The `DOCKERHUB.md` file is maintained in the repository as the source of truth for Docker Hub documentation.

## Best Practices

### Commit Messages

Use conventional commit format for better changelogs:

- `feat:` New features
- `fix:` Bug fixes
- `docs:` Documentation changes
- `chore:` Maintenance tasks
- `refactor:` Code refactoring
- `test:` Test additions/changes
- `perf:` Performance improvements

Example:
```bash
git commit -m "feat: add batched inference example"
git commit -m "fix: correct model cache ownership"
git commit -m "docs: update usage examples"
```

### Pre-release Testing

Before creating a release:

1. Build both variants locally and run the full test suite (see [TEST.md](TEST.md))
2. Run the functional transcription test against the bundled sample
3. If a CUDA-related pin changed, run the manual GPU smoke test on a machine with an NVIDIA GPU
4. Check that the multi-platform cpu build works (especially arm64)

## Troubleshooting

### Release didn't trigger

- Ensure tag starts with `v` and follows the format (e.g., `v0.5.7-1`) - the release workflow rejects tags that do
  not match `v{version}-{build}`
- Check GitHub Actions tab for workflow runs
- Verify you have push permissions

### Docker build failed

- Check the Docker workflow logs
- Ensure the Dockerfile builds locally for both targets
- Verify multi-platform compatibility for the cpu variant

### Missing permissions

Ensure your repository has:
- GitHub Actions enabled
- Package write permissions for workflows
- Proper secrets configuration (GITHUB_TOKEN is automatic)

### Docker Hub Configuration

To enable Docker Hub deployment, you need to add these secrets to your GitHub repository:

1. Go to Settings → Secrets and variables → Actions
2. Add the following secrets:
   - `DOCKERHUB_USERNAME`: Your Docker Hub username
   - `DOCKERHUB_TOKEN`: Your Docker Hub access token (not password)

To create a Docker Hub access token:
1. Log in to Docker Hub
2. Go to Account Settings → Security
3. Click "New Access Token"
4. Give it a descriptive name (e.g., "GitHub Actions")
5. Copy the token and add it as `DOCKERHUB_TOKEN` secret

## Manual Release (if needed)

If automation fails, you can create a release manually:

1. Go to repository's "Releases" page
2. Click "Create a new release"
3. Choose your tag (must follow format: `v0.5.7-1`)
4. Add release notes
5. Include Docker pull commands:
   ```
   docker pull ghcr.io/ragedunicorn/docker-whisper:0.5.7-cpu-1
   docker pull ghcr.io/ragedunicorn/docker-whisper:0.5.7-cuda-1
   docker pull ragedunicorn/whisper:0.5.7-cpu-1
   docker pull ragedunicorn/whisper:0.5.7-cuda-1
   ```
