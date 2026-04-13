# Blacksmith Runners for PR Build Pipeline

## Problem

The Build workflow on PRs runs on GitHub-hosted `ubuntu-latest` runners. The Go compilation of minio server and mc client dominates wall-clock time. Total pipeline takes ~7 minutes.

## Decision

Switch the Build workflow to Blacksmith runners (`blacksmith-2vcpu-ubuntu-2204`). No caching infrastructure — just faster hardware.

## Result

**~55% faster builds** (7m → ~3m 10s) with a one-line `runs-on` change per job. No changes to the Justfile, build scripts, or local development workflow.

## What we tried

### 1. Blacksmith runners only (adopted)

Changed `runs-on: ubuntu-latest` → `runs-on: blacksmith-2vcpu-ubuntu-2204` across all Build workflow jobs. Kept the existing `docker` driver with containerd-snapshotter.

**Result: ~55% faster.** Minio dropped from 6m 45s to ~2m 37s. The speedup comes from faster CPU (Go compilation) and faster NVMe I/O.

### 2. Sticky disk at `/var/lib/docker` (rejected)

Mounted a Blacksmith sticky disk over Docker's entire data directory to persist BuildKit's internal cache.

**Result: containerd metadata corruption.** The containerd-snapshotter stores metadata in a bolt DB that references snapshot IDs by content hash. Restoring `/var/lib/docker` from a snapshot causes `"parent snapshot does not exist: not found"` errors because the metadata DB references snapshots that don't match the restored blobs.

Also required stopping Docker before the sticky disk post-job unmount (`sudo systemctl stop docker docker.socket` with `if: always()`) because Docker holds `/var/lib/docker` busy.

### 3. `--cache-to/--cache-from type=local` with sticky disk (rejected)

Mounted a sticky disk at `/tmp/buildx-cache` (separate from `/var/lib/docker`) and used `--cache-to type=local,dest=/tmp/buildx-cache,mode=max` and `--cache-from type=local,src=/tmp/buildx-cache`.

**Result: cache export works, import silently fails.** The `docker` driver has unreliable `type=local` cache import even with containerd-snapshotter enabled. This is a known BuildKit limitation. 70+ build steps, only 1 showed CACHED.

### 4. Blacksmith's `setup-docker-builder` with remote driver (rejected)

Switched to `useblacksmith/setup-docker-builder` which uses a `remote` BuildKit driver with built-in sticky disk caching at `/var/lib/buildkit`. Changed Justfile to use `--output type=oci,dest=file.tar` since the remote driver drops attestations on `--load`.

**Result: DHI pipeline steps are uncacheable.** The DHI frontend (`# syntax=dhi.io/build:2-debian13`) marks all pipeline steps with `ignore_cache`. Even trivial `echo` steps re-execute on every build. Confirmed by adding test steps and observing they never show CACHED across runs.

Additional findings:
- `type=docker` output format cannot export manifest lists (needed for attestations) — must use `type=oci`
- `docker load` cannot import OCI-format tars — different internal layout
- `useblacksmith/setup-docker-builder` uses a single repo-scoped sticky disk with no per-key scoping — matrix jobs suffer last-writer-wins. Fixed by mounting our own `useblacksmith/stickydisk` at `/var/lib/buildkit` before the builder action, keyed per image.
- The 70 cached layers (Debian package downloads, base image setup) save negligible time because those downloads already complete in <0.1s on Blacksmith's network
- The cache infrastructure overhead (sticky disk mount, buildkitd startup, OCI export) actually made builds ~30s slower than the simple setup

### 5. Per-image sticky disk with Blacksmith builder (rejected)

Added `useblacksmith/stickydisk` keyed to `buildkit-${{ matrix.image }}` before `setup-docker-builder` to give each matrix job its own persistent BuildKit cache.

**Result: cache mechanism works correctly** (70 CACHED layers, cache.db grows from 0.03 MB to 1.00 MB, persists across runs), but provides no meaningful speedup because the cached layers are already fast and the expensive pipeline steps (Go compilation) are uncacheable.

## Key findings

1. **DHI pipeline steps are uncacheable.** The DHI build frontend sets `ignore_cache` on all pipeline operations. This is not caused by `privileged: true` — BuildKit caches privileged steps normally (the security mode is part of the cache key, not a bypass flag). The DHI frontend itself makes this choice, likely for reproducibility guarantees.

2. **`privileged: true` in DHI means network access, not `--security=insecure`.** Non-privileged DHI steps run hermetically (no network). This is separate from BuildKit's privilege escalation.

3. **Blacksmith hardware alone provides the biggest win.** Faster CPU and NVMe I/O cut Go compilation time by ~60%. No cache infrastructure needed.

4. **The `docker` driver with containerd-snapshotter is the simplest correct setup.** It supports `--load` with attestations preserved, works identically locally and in CI, and requires no special configuration beyond the daemon.json change.

5. **`useblacksmith/setup-docker-builder` doesn't support matrix builds.** Its sticky disk is repo-scoped with no key parameter. Parallel matrix jobs share one disk with last-writer-wins semantics.

## Implementation

Only two files change:

**`.github/workflows/build.yml`** — change `runs-on` for all three jobs:
```yaml
runs-on: blacksmith-2vcpu-ubuntu-2204  # was: ubuntu-latest
```

**`.github/actions/setup-pipeline/action.yml`** — unchanged from the original. Keeps `docker` driver, containerd-snapshotter, and registry logins.

**Justfile** — unchanged. `just build` works identically locally and in CI.

## Future considerations

- If DHI adds cache support for pipeline steps, revisit the Blacksmith builder + per-image sticky disk approach
- If cold builds remain too slow, bump to `blacksmith-4vcpu-ubuntu-2204`
- Other workflows (pre-release, rescan) could adopt Blacksmith runners independently
