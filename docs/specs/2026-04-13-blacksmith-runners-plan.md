# Blacksmith Runners for PR Build Pipeline — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Speed up PR builds by switching the Build workflow to Blacksmith runners with per-image Docker cache persistence.

**Architecture:** Keep the existing `docker` driver + containerd-snapshotter build pipeline unchanged. Add Blacksmith sticky disks to persist `/var/lib/docker` per matrix image. Only the `setup-pipeline` composite action and `build.yml` workflow change.

**Tech Stack:** GitHub Actions, Blacksmith runners, `useblacksmith/stickydisk@v1`

**Spec:** `docs/specs/2026-04-13-blacksmith-runners-design.md`

---

## Chunk 1: Setup-pipeline sticky disk support

### Task 1: Add cache-key input and sticky disk steps to setup-pipeline

**Files:**
- Modify: `.github/actions/setup-pipeline/action.yml`

- [ ] **Step 1: Add `cache-key` input to the action**

Add a new optional input with empty default at the top of the inputs section in `.github/actions/setup-pipeline/action.yml`:

```yaml
  cache-key:
    description: Sticky disk cache key for Docker data dir (empty = no cache)
    default: ''
```

- [ ] **Step 2: Add stop-Docker step (conditional on cache-key)**

Insert a new step **before** the existing "Enable containerd image store" step:

```yaml
    - name: Stop Docker for cache mount
      if: inputs.cache-key != ''
      shell: bash
      run: sudo systemctl stop docker
```

- [ ] **Step 3: Add sticky disk mount step (conditional on cache-key)**

Insert after the stop-Docker step, before "Enable containerd image store":

```yaml
    - name: Mount Docker cache (sticky disk)
      if: inputs.cache-key != ''
      uses: useblacksmith/stickydisk@v1
      with:
        key: docker-${{ inputs.cache-key }}
        path: /var/lib/docker
```

- [ ] **Step 4: Change Docker restart to always use start (not restart)**

The current "Enable containerd image store" step does `sudo systemctl restart docker`. After a sticky disk mount where Docker was stopped, `restart` may behave differently than `start`. Change the step to stop-then-start unconditionally so it works in both paths:

Replace the current "Enable containerd image store" step's run block:

```yaml
    - name: Enable containerd image store
      shell: bash
      run: |
        sudo mkdir -p /etc/docker
        echo '{"features":{"containerd-snapshotter":true}}' | sudo tee /etc/docker/daemon.json
        sudo systemctl stop docker 2>/dev/null || true
        sudo systemctl start docker
```

This is safe for both paths: when Docker was already stopped (sticky disk path), the `stop` is a no-op; when no sticky disk, it stops and restarts as before.

- [ ] **Step 5: Verify the final action.yml looks correct**

The full file should now read:

```yaml
name: Setup Pipeline
description: Checkout, install just, and optionally login to container registries

inputs:
  cache-key:
    description: Sticky disk cache key for Docker data dir (empty = no cache)
    default: ''
  dhi-login:
    description: Login to dhi.io registry
    default: 'true'
  dhi-username:
    description: DHI registry username
  dhi-token:
    description: DHI registry token
  ghcr-login:
    description: Login to ghcr.io registry
    default: 'false'
  ghcr-username:
    description: GHCR username (typically github.actor)
  ghcr-token:
    description: GHCR token (typically secrets.GITHUB_TOKEN)

runs:
  using: composite
  steps:
    - name: Install just
      uses: extractions/setup-just@dd310ad5a97d8e7b41793f8ef055398d51ad4de6 # v2

    - name: Stop Docker for cache mount
      if: inputs.cache-key != ''
      shell: bash
      run: sudo systemctl stop docker

    - name: Mount Docker cache (sticky disk)
      if: inputs.cache-key != ''
      uses: useblacksmith/stickydisk@v1
      with:
        key: docker-${{ inputs.cache-key }}
        path: /var/lib/docker

    - name: Enable containerd image store
      shell: bash
      run: |
        sudo mkdir -p /etc/docker
        echo '{"features":{"containerd-snapshotter":true}}' | sudo tee /etc/docker/daemon.json
        sudo systemctl stop docker 2>/dev/null || true
        sudo systemctl start docker

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@8d2750c68a42422c14e847fe6c8ac0403b4cbd6f # v3
      with:
        driver: docker

    - name: Login to dhi.io
      if: inputs.dhi-login == 'true'
      shell: bash
      run: echo "$DHI_TOKEN" | docker login dhi.io -u "$DHI_USERNAME" --password-stdin
      env:
        DHI_USERNAME: ${{ inputs.dhi-username }}
        DHI_TOKEN: ${{ inputs.dhi-token }}

    - name: Login to GHCR
      if: inputs.ghcr-login == 'true'
      shell: bash
      run: echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USERNAME" --password-stdin
      env:
        GHCR_USERNAME: ${{ inputs.ghcr-username }}
        GHCR_TOKEN: ${{ inputs.ghcr-token }}
```

- [ ] **Step 6: Commit**

```bash
git add .github/actions/setup-pipeline/action.yml
git commit -m "feat: add sticky disk Docker cache support to setup-pipeline"
```

---

## Chunk 2: Switch Build workflow to Blacksmith runners

### Task 2: Update build.yml to use Blacksmith runners and pass cache keys

**Files:**
- Modify: `.github/workflows/build.yml`

- [ ] **Step 1: Change `resolve-images` job to Blacksmith runner**

In `.github/workflows/build.yml`, change the `resolve-images` job:

```yaml
  resolve-images:
    name: Resolve image lists
    runs-on: blacksmith-2vcpu-ubuntu-2204
```

- [ ] **Step 2: Change `stock-dhi-images` job to Blacksmith runner and add cache-key**

```yaml
  stock-dhi-images:
    name: Extract DHI attestations
    runs-on: blacksmith-2vcpu-ubuntu-2204
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4
      - uses: ./.github/actions/setup-pipeline
        with:
          cache-key: stock-attestations
          dhi-username: ${{ vars.DHI_USERNAME }}
          dhi-token: ${{ secrets.DHI_TOKEN }}
```

Only the `runs-on` line and `cache-key` input are added. Everything else stays the same.

- [ ] **Step 3: Change `custom-dhi-builds` job to Blacksmith runner and add cache-key**

```yaml
  custom-dhi-builds:
    name: Build ${{ matrix.image }}
    needs: resolve-images
    runs-on: blacksmith-2vcpu-ubuntu-2204
    strategy:
      matrix:
        image: ${{ fromJSON(needs.resolve-images.outputs.custom-images) }}
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4
      - uses: ./.github/actions/setup-pipeline
        with:
          cache-key: ${{ matrix.image }}
          dhi-username: ${{ vars.DHI_USERNAME }}
          dhi-token: ${{ secrets.DHI_TOKEN }}
          ghcr-login: true
          ghcr-username: ${{ github.actor }}
          ghcr-token: ${{ secrets.GITHUB_TOKEN }}
```

Only the `runs-on` line and `cache-key` input are added. Everything else stays the same.

- [ ] **Step 4: Verify the full build.yml looks correct**

The complete file should read:

```yaml
name: Build

on:
  pull_request:
    paths:
      - 'common/**'
      - 'apps/**'
      - 'common/tool-images.yaml'
      - 'apps/sbomify/app-images.yaml'
      - '.github/workflows/build.yml'
      - 'scripts/**'
      - 'Justfile'
  workflow_dispatch:

permissions:
  contents: read
  packages: write

jobs:
  resolve-images:
    name: Resolve image lists
    runs-on: blacksmith-2vcpu-ubuntu-2204
    outputs:
      custom-images: ${{ steps.images.outputs.custom }}
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4
      - id: images
        run: echo "custom=$(./scripts/list-custom-images)" >> "$GITHUB_OUTPUT"

  stock-dhi-images:
    name: Extract DHI attestations
    runs-on: blacksmith-2vcpu-ubuntu-2204
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4
      - uses: ./.github/actions/setup-pipeline
        with:
          cache-key: stock-attestations
          dhi-username: ${{ vars.DHI_USERNAME }}
          dhi-token: ${{ secrets.DHI_TOKEN }}

      - name: Extract attestations
        run: just extract-dhi-attestations

      - name: Upload attestation artifacts
        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02 # v4
        with:
          name: stock-dhi-attestations
          path: .artifacts/

  custom-dhi-builds:
    name: Build ${{ matrix.image }}
    needs: resolve-images
    runs-on: blacksmith-2vcpu-ubuntu-2204
    strategy:
      matrix:
        image: ${{ fromJSON(needs.resolve-images.outputs.custom-images) }}
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4
      - uses: ./.github/actions/setup-pipeline
        with:
          cache-key: ${{ matrix.image }}
          dhi-username: ${{ vars.DHI_USERNAME }}
          dhi-token: ${{ secrets.DHI_TOKEN }}
          ghcr-login: true
          ghcr-username: ${{ github.actor }}
          ghcr-token: ${{ secrets.GITHUB_TOKEN }}

      - name: Build image and generate compliance artifacts
        run: just build ${{ matrix.image }}

      - name: Upload attestation artifacts
        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02 # v4
        with:
          name: custom-${{ matrix.image }}-attestations
          path: .artifacts/${{ matrix.image }}/
```

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/build.yml
git commit -m "feat: switch Build workflow to Blacksmith runners with per-image Docker cache"
```

---

## Chunk 3: Validate

### Task 3: Push and validate on a PR

- [ ] **Step 1: Create a feature branch and push**

```bash
git checkout -b feat/blacksmith-runners
git push -u origin feat/blacksmith-runners
```

- [ ] **Step 2: Open a PR**

```bash
gh pr create --title "Switch Build workflow to Blacksmith runners" --body "$(cat <<'EOF'
## Summary
- Switch all Build workflow jobs to `blacksmith-2vcpu-ubuntu-2204`
- Add per-image sticky disk Docker cache to `setup-pipeline` action
- No changes to Justfile, build scripts, or other workflows

## Expected behavior
- First run: cold build (same speed as before)
- Second run: warm Docker cache, significantly faster

## Spec
See `docs/specs/2026-04-13-blacksmith-runners-design.md`
EOF
)"
```

- [ ] **Step 3: Validate first run (cold cache)**

Check the PR build in GitHub Actions. Verify:
- All three jobs run on Blacksmith runners (visible in job logs)
- Sticky disk mount step appears in `stock-dhi-images` and `custom-dhi-builds` jobs
- Build completes successfully with all artifacts uploaded
- Attestation extraction still works (SBOM, provenance, CVE scan, secrets scan)

- [ ] **Step 4: Validate second run (warm cache)**

Re-run the workflow from the PR (or push a trivial change). Verify:
- Docker layer cache is warm (BuildKit logs show "CACHED" for compilation steps)
- Build is significantly faster
- All artifacts are still correct

- [ ] **Step 5: Compare build times**

Note the wall-clock times for cold vs warm builds. If warm builds are not faster, investigate whether the sticky disk is being mounted correctly (check for "Restoring sticky disk" in job logs).
