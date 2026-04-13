# Blacksmith Runners for PR Build Pipeline

## Problem

The Build workflow on PRs runs on GitHub-hosted `ubuntu-latest` runners with no persistent Docker cache. Every run cold-pulls tool images from dhi.io, re-downloads Go modules, and recompiles Go binaries from source. The Go compilation of minio server and mc client dominates wall-clock time.

## Decision

Switch the Build workflow to Blacksmith runners with per-image sticky disks caching Docker's entire data directory. Keep all other workflows on `ubuntu-latest` for now.

## Constraints

- **Local/CI parity**: the Justfile and build scripts must work identically in CI and on developer machines. No CI-only build paths.
- **Attestation preservation**: `--sbom` and `--provenance` flags with `--load` require `driver: docker` + containerd-snapshotter. This rules out Blacksmith's `setup-docker-builder` action (which uses a `remote` driver that drops attestations on `--load`).
- **Parallel matrix jobs**: the Build workflow runs `custom-dhi-builds` as a matrix across images (minio, hugo, sbom-convert). Shared sticky disks under parallel writes are last-writer-wins, so each image needs its own disk.

## Design

### Runner change

All jobs in the Build workflow switch from `ubuntu-latest` to `blacksmith-2vcpu-ubuntu-2204`, including `resolve-images` (which doesn't use Docker but benefits from faster boot and network).

### Per-image sticky disk for Docker cache

The `setup-pipeline` composite action gains:
- A new optional input `cache-key` (string, default empty)
- When `cache-key` is set: stop Docker, mount a sticky disk at `/var/lib/docker` keyed to `docker-<cache-key>`, then configure containerd-snapshotter and restart Docker
- When `cache-key` is empty: current behavior (no sticky disk)

The sticky disk is mounted **before** the containerd-snapshotter daemon.json is written and Docker is restarted, so Docker starts with the cached state.

### Build workflow changes

- `custom-dhi-builds` passes `cache-key: ${{ matrix.image }}` to `setup-pipeline`
- `stock-dhi-images` passes `cache-key: stock-attestations` to `setup-pipeline`
- `resolve-images` does not use `setup-pipeline` (no Docker needed), stays simple

### What the cache captures

Each per-image sticky disk persists:
- **BuildKit layer cache** — Go module downloads and compilation layers are reused when the DHI yaml hasn't changed
- **Pulled container images** — tool images (grype, syft, gitleaks, etc.), build frontend (`dhi.io/build:2-debian13`), build SDK (`dhi.io/golang:...`)
- **Previously built images** — available immediately for `docker save` and scanning

### Cache lifecycle

- First run per image: cold build (same as today)
- Subsequent runs: warm cache, Go compilation skipped on cache hit
- Eviction: 7 days of inactivity (any PR build resets the timer)
- Corruption: a stale or corrupt cache results in a cold build — no worse than today

### What doesn't change

- Justfile and build scripts — untouched
- Local development workflow — identical
- Attestation extraction (`--load`, `docker save`, tar parsing) — unchanged
- Buildx driver (`docker`) — unchanged
- containerd-snapshotter configuration — unchanged
- Other workflows (pre-release, rescan, deploy, digest-pin-update) — unchanged

## Setup-pipeline action sequence (revised)

1. Install Just
2. (If `cache-key` set) Stop Docker daemon
3. (If `cache-key` set) Mount sticky disk at `/var/lib/docker` with key `docker-<cache-key>`
4. Write containerd-snapshotter daemon.json
5. Start/restart Docker daemon (always — with or without sticky disk, since containerd-snapshotter requires a restart regardless)
6. Set up Docker Buildx with `driver: docker`
7. Login to dhi.io (if configured)
8. Login to GHCR (if configured)

## Future considerations

- If cold builds remain slow, bump to `blacksmith-4vcpu-ubuntu-2204`
- Other workflows (pre-release, rescan) could adopt Blacksmith runners independently once the Build workflow is validated
- If Blacksmith's `setup-docker-builder` ever supports containerd-snapshotter or attestation preservation on `--load`, the sticky disk approach could be replaced with their native Docker layer caching
