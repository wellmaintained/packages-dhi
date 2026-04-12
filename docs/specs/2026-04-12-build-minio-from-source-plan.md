# Build MinIO From Source — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build minio server and mc client from Go source for complete SBOM coverage, consolidate minio + minio-init into one image, rename `latest.yaml` to `dhi.yaml`.

**Architecture:** Two Go build stages in a single DHI YAML compile minio and mc from git source using `dhi.io/golang:1.26-alpine3.23-dev`. The init container script moves to the sbomify deployment and is mounted at runtime.

**Tech Stack:** DHI YAML build frontend, Go 1.26, Docker buildx, Just

**Spec:** `docs/specs/2026-04-12-build-minio-from-source-design.md`

---

## Chunk 1: Rename `latest.yaml` to `dhi.yaml`

A standalone refactor with no functional changes. Complete this first so all subsequent work uses the new filename.

### Task 1: Rename hugo image definition

**Files:**
- Rename: `common/images/hugo/latest.yaml` → `common/images/hugo/dhi.yaml`
- Modify: `common/tool-images.yaml:19`
- Modify: `common/tool-images.lock.yaml:25`

- [ ] **Step 1: Rename the file**

```bash
git mv common/images/hugo/latest.yaml common/images/hugo/dhi.yaml
```

- [ ] **Step 2: Update tool-images.yaml**

In `common/tool-images.yaml`, change line 19:
```yaml
# before
  definition: common/images/hugo/latest.yaml
# after
  definition: common/images/hugo/dhi.yaml
```

- [ ] **Step 3: Update tool-images.lock.yaml**

In `common/tool-images.lock.yaml`, change line 25:
```yaml
# before
  definition: common/images/hugo/latest.yaml
# after
  definition: common/images/hugo/dhi.yaml
```

- [ ] **Step 4: Verify build resolves the new path**

```bash
just _image-path hugo
```

Expected: `common/images/hugo/dhi.yaml`

- [ ] **Step 5: Commit**

```bash
git add common/images/hugo/ common/tool-images.yaml common/tool-images.lock.yaml
git commit -m "refactor: rename hugo latest.yaml to dhi.yaml"
```

### Task 2: Rename minio image definition

**Files:**
- Rename: `common/images/minio/latest.yaml` → `common/images/minio/dhi.yaml`
- Modify: `apps/sbomify/app-images.yaml:13`
- Modify: `apps/sbomify/app-images.lock.yaml:18`

- [ ] **Step 1: Rename the file**

```bash
git mv common/images/minio/latest.yaml common/images/minio/dhi.yaml
```

- [ ] **Step 2: Update app-images.yaml**

In `apps/sbomify/app-images.yaml`, change line 13:
```yaml
# before
  definition: common/images/minio/latest.yaml
# after
  definition: common/images/minio/dhi.yaml
```

- [ ] **Step 3: Update app-images.lock.yaml**

In `apps/sbomify/app-images.lock.yaml`, change line 18:
```yaml
# before
  definition: common/images/minio/latest.yaml
# after
  definition: common/images/minio/dhi.yaml
```

- [ ] **Step 4: Verify build resolves the new path**

```bash
just _image-path minio
```

Expected: `common/images/minio/dhi.yaml`

- [ ] **Step 5: Commit**

```bash
git add common/images/minio/ apps/sbomify/app-images.yaml apps/sbomify/app-images.lock.yaml
git commit -m "refactor: rename minio latest.yaml to dhi.yaml"
```

---

## Chunk 2: Rewrite minio image to build from source

### Task 3: Verify DHI Go builder image exists

Before writing the build definition, confirm the image tag is available.

- [ ] **Step 1: Check DHI golang image availability**

```bash
docker pull dhi.io/golang:1.26-alpine3.23-dev --quiet 2>&1 || echo "FAILED"
```

If this fails, try `1.25-alpine3.23-dev` as fallback. Record the exact tag and digest for use in later steps.

- [ ] **Step 2: Get the image digest**

```bash
./bin/crane digest dhi.io/golang:1.26-alpine3.23-dev
```

Record this digest — it will be used in `dhi.yaml` to pin the builder image.

### Task 4: Verify minio and mc ldflags

Check the actual Makefiles to confirm the correct ldflags before writing the build definition.

- [ ] **Step 1: Check minio server Makefile**

```bash
git clone --depth=1 --branch RELEASE.2025-10-15T17-29-55Z https://github.com/minio/minio.git /tmp/minio-src
grep -A 20 'LDFLAGS' /tmp/minio-src/Makefile
```

Record the exact `-X` flags used for version embedding.

- [ ] **Step 2: Check mc client Makefile**

```bash
git clone --depth=1 --branch RELEASE.2025-08-13T08-35-41Z https://github.com/minio/mc.git /tmp/mc-src
grep -A 20 'LDFLAGS' /tmp/mc-src/Makefile
```

Record the exact `-X` flags used for version embedding.

- [ ] **Step 3: Clean up**

```bash
rm -rf /tmp/minio-src /tmp/mc-src
```

### Task 5: Rewrite minio dhi.yaml with Go source builds

**Files:**
- Modify: `common/images/minio/dhi.yaml` (full rewrite)

- [ ] **Step 1: Write the new DHI YAML**

Rewrite `common/images/minio/dhi.yaml` with the following structure. Replace the placeholders with values discovered in Tasks 3-4:
- `GOLANG_DIGEST` → the sha256 digest from Task 3 Step 2
- `# TODO: insert go build with ldflags from Task 4` → the actual `go build -ldflags '...'` command from the Makefile

```yaml
# syntax=dhi.io/build:2-alpine3.23

name: MinIO Server
image: ghcr.io/wellmaintained/minio
variant: runtime
tags:
  - latest
platforms:
  - linux/amd64

contents:
  repositories:
    - https://dl-cdn.alpinelinux.org/alpine/v3.23/main
    - https://dl-cdn.alpinelinux.org/alpine/v3.23/community
  packages:
    - alpine-baselayout-data
    - ca-certificates-bundle
  builds:
    - name: minio-server
      uses: dhi.io/golang:1.26-alpine3.23-dev@GOLANG_DIGEST
      contents:
        files:
          - url: "git+https://github.com/minio/minio.git#RELEASE.2025-10-15T17-29-55Z"
            path: ${source.dir}/minio
            spdx:
              name: minio
              version: "RELEASE.2025-10-15T17-29-55Z"
              packages:
                - name: minio
                  purl: "pkg:golang/github.com/minio/minio@RELEASE.2025-10-15T17-29-55Z"
                  license: AGPL-3.0-or-later
            uid: 0
            gid: 0
      pipeline:
        - name: build minio server
          work-dir: ${source.dir}/minio
          privileged: true
          runs: |
            set -eux -o pipefail
            go mod download
            # TODO: insert go build command with ldflags from Task 4 (minio)
            mkdir -p ${target.dir}/usr/local/bin
            install -m 0755 minio ${target.dir}/usr/local/bin/minio
      outputs:
        - source: ${target.dir}/usr/local/bin
          target: /usr/local/bin
          uid: 0
          gid: 0

    - name: mc-client
      uses: dhi.io/golang:1.26-alpine3.23-dev@GOLANG_DIGEST
      contents:
        files:
          - url: "git+https://github.com/minio/mc.git#RELEASE.2025-08-13T08-35-41Z"
            path: ${source.dir}/mc
            spdx:
              name: mc
              version: "RELEASE.2025-08-13T08-35-41Z"
              packages:
                - name: mc
                  purl: "pkg:golang/github.com/minio/mc@RELEASE.2025-08-13T08-35-41Z"
                  license: AGPL-3.0-or-later
            uid: 0
            gid: 0
      pipeline:
        - name: build mc client
          work-dir: ${source.dir}/mc
          privileged: true
          runs: |
            set -eux -o pipefail
            go mod download
            # TODO: insert go build command with ldflags from Task 4 (mc)
            mkdir -p ${target.dir}/usr/local/bin
            install -m 0755 mc ${target.dir}/usr/local/bin/mc
      outputs:
        - source: ${target.dir}/usr/local/bin
          target: /usr/local/bin
          uid: 0
          gid: 0

    - name: data-dir
      pipeline:
        - name: create data directory
          runs: |
            set -eux -o pipefail
            mkdir -p ${target.dir}/data
            chown 65532:65532 ${target.dir}/data
      outputs:
        - source: ${target.dir}/data
          target: /data
          uid: 65532
          gid: 65532

accounts:
  run-as: minio
  users:
    - name: minio
      uid: 65532
      gid: 65532
  groups:
    - name: minio
      gid: 65532
      members:
        - minio

annotations:
  org.opencontainers.image.description: A minimal MinIO S3-compatible object storage server with mc client
  org.opencontainers.image.licenses: AGPL-3.0-or-later

entrypoint:
  - /usr/local/bin/minio

cmd:
  - server
  - /data

ports:
  - 9000/tcp
  - 9001/tcp
```

Note: `MINIO_ACCESS_KEY` / `MINIO_SECRET_KEY` environment variables are intentionally removed from the image — credentials will be set in docker-compose.

- [ ] **Step 2: Build the image**

```bash
just build minio
```

This will take several minutes (Go compilation). Expected: successful build.

- [ ] **Step 3: Verify the binaries work**

```bash
docker run --rm ghcr.io/wellmaintained/minio:dev minio --version
docker run --rm --entrypoint mc ghcr.io/wellmaintained/minio:dev --version
```

Both should print version strings matching the pinned releases, not `0.0.0-UNKNOWN`.

- [ ] **Step 4: Verify SBOM contains Go dependencies**

```bash
just sbom-spdx minio
jq '.packages | length' .artifacts/minio/sbom.spdx.json
```

Expected: significantly more than 2 packages (the old SBOM had ~2-3; the new one should have hundreds of Go module dependencies).

- [ ] **Step 5: Commit**

```bash
git add common/images/minio/dhi.yaml
git commit -m "feat: build minio and mc from Go source for complete SBOM"
```

---

## Chunk 3: Consolidate minio-init into minio

### Task 6: Extract init script to sbomify deployments

**Files:**
- Create: `apps/sbomify/deployments/scripts/create-minio-buckets.sh`
- Delete: `common/images/minio-init/latest.yaml`

- [ ] **Step 1: Create the scripts directory and init script**

```bash
mkdir -p apps/sbomify/deployments/scripts
```

Create `apps/sbomify/deployments/scripts/create-minio-buckets.sh`:

```bash
#!/bin/sh
set -e
echo "Waiting for MinIO to be ready..."
until mc alias set myminio "$AWS_ENDPOINT_URL_S3" "${AWS_ACCESS_KEY_ID:-minioadmin}" "${AWS_SECRET_ACCESS_KEY:-minioadmin}"; do
  echo "MinIO not ready, retrying in 2s..."
  sleep 2
done
echo "Creating buckets..."
mc mb --ignore-existing "myminio/$AWS_MEDIA_STORAGE_BUCKET_NAME"
mc mb --ignore-existing "myminio/$AWS_SBOMS_STORAGE_BUCKET_NAME"
echo "Setting public access on media bucket..."
mc anonymous set public "myminio/$AWS_MEDIA_STORAGE_BUCKET_NAME"
echo "Done."
```

```bash
chmod +x apps/sbomify/deployments/scripts/create-minio-buckets.sh
```

- [ ] **Step 2: Delete the minio-init image definition**

```bash
rm -rf common/images/minio-init/
```

- [ ] **Step 3: Commit**

```bash
git add apps/sbomify/deployments/scripts/create-minio-buckets.sh
git rm -r common/images/minio-init/
git commit -m "refactor: extract minio-init script to sbomify deployment"
```

### Task 7: Update docker-compose to use consolidated image

**Files:**
- Modify: `apps/sbomify/deployments/docker-compose.yml:62-83`

- [ ] **Step 1: Update the minio service**

Add environment variables for credentials (previously baked into image):

```yaml
  sbomify-minio:
    image: ghcr.io/wellmaintained/minio:latest
    environment:
      MINIO_ACCESS_KEY: minioadmin
      MINIO_SECRET_KEY: minioadmin
    ports:
      - "${MINIO_API_PORT:-9000}:9000"
      - "${MINIO_CONSOLE_PORT:-9001}:9001"
    volumes:
      - sbomify_minio_data:/data
    healthcheck:
      test: ["CMD", "mc", "ready", "local"]
      interval: 5s
      timeout: 5s
      retries: 5
```

- [ ] **Step 2: Update the minio-init service**

Replace the minio-init image with the minio image + mounted script:

```yaml
  sbomify-minio-init:
    image: ghcr.io/wellmaintained/minio:latest
    entrypoint: ["/scripts/create-minio-buckets.sh"]
    volumes:
      - ./scripts/create-minio-buckets.sh:/scripts/create-minio-buckets.sh:ro
    environment:
      AWS_ENDPOINT_URL_S3: ${AWS_ENDPOINT_URL_S3:-http://sbomify-minio:9000}
      AWS_MEDIA_STORAGE_BUCKET_NAME: ${AWS_MEDIA_STORAGE_BUCKET_NAME:-sbomify-media}
      AWS_SBOMS_STORAGE_BUCKET_NAME: ${AWS_SBOMS_STORAGE_BUCKET_NAME:-sbomify-sboms}
    depends_on:
      sbomify-minio:
        condition: service_healthy
```

- [ ] **Step 3: Commit**

```bash
git add apps/sbomify/deployments/docker-compose.yml
git commit -m "refactor: use consolidated minio image for init container"
```

### Task 8: Remove minio-init from manifests

**Files:**
- Modify: `apps/sbomify/app-images.yaml:16-18` (remove minio-init entry)
- Modify: `apps/sbomify/app-images.lock.yaml:21-23` (remove minio-init entry)

- [ ] **Step 1: Remove minio-init from app-images.yaml**

Delete these lines from `apps/sbomify/app-images.yaml`:
```yaml
minio-init:
  definition: common/images/minio-init/latest.yaml
  registry: ghcr.io/wellmaintained/minio-init
```

- [ ] **Step 2: Remove minio-init from app-images.lock.yaml**

Delete these lines from `apps/sbomify/app-images.lock.yaml`:
```yaml
minio-init:
  definition: common/images/minio-init/latest.yaml
  registry: ghcr.io/wellmaintained/minio-init
```

- [ ] **Step 3: Verify manifest resolution still works**

```bash
just _image-path minio
just _image-registry minio
just images
```

Expected: minio resolves correctly, minio-init no longer appears.

- [ ] **Step 4: Commit**

```bash
git add apps/sbomify/app-images.yaml apps/sbomify/app-images.lock.yaml
git commit -m "refactor: remove minio-init from image manifests"
```

---

## Chunk 4: Update CI workflows

### Task 9: Remove minio-init from GitHub Actions workflows

**Files:**
- Modify: `.github/workflows/build.yml:57` (remove from matrix)
- Modify: `.github/workflows/pre-release.yml:36,45,53` (remove from for loops)
- Modify: `.github/workflows/rescan-vulnerabilities.yml:28` (remove from for loop)
- Modify: `.github/workflows/sbom-quality-gate.yml:18` (remove from matrix)

- [ ] **Step 1: Update build.yml**

Remove `- minio-init` from the matrix at line 57:
```yaml
        image:
          - hugo
          - minio
          - sbomify-app
```

- [ ] **Step 2: Update pre-release.yml**

Change all three `for` loops (lines 36, 45, 53) from:
```bash
for image in hugo minio minio-init sbomify-app; do
```
to:
```bash
for image in hugo minio sbomify-app; do
```

- [ ] **Step 3: Update rescan-vulnerabilities.yml**

Change the `for` loop at line 28 from:
```bash
for image in minio minio-init sbomify-app; do
```
to:
```bash
for image in minio sbomify-app; do
```

- [ ] **Step 4: Update sbom-quality-gate.yml**

Change the matrix at line 18 from:
```yaml
        image: [minio, minio-init, sbomify-app]
```
to:
```yaml
        image: [minio, sbomify-app]
```

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/
git commit -m "ci: remove minio-init from all workflows"
```

---

## Chunk 5: Update documentation and generated files

### Task 10: Update documentation

**Files:**
- Modify: `CLAUDE.md:8`
- Modify: `docs/adr/0001-adopt-dhi-base-images.md:20,32`
- Modify: `apps/sbomify/release-website/content/dependencies/_index.md:30`
- Delete: `apps/sbomify/release-website/content/dependencies/minio-init.md`

- [ ] **Step 1: Update CLAUDE.md**

Change line 8 from:
```
- `common/images/` — Shared infrastructure images (minio, minio-init, hugo)
```
to:
```
- `common/images/` — Shared infrastructure images (minio, hugo)
```

- [ ] **Step 2: Update ADR**

In `docs/adr/0001-adopt-dhi-base-images.md`:

Change line 20 from:
```
images are unnecessary: postgres, redis, keycloak, caddy, and minio-init all
```
to:
```
images are unnecessary: postgres, redis, keycloak, and caddy all
```

Change line 32 from:
```
   minio (learning exercise), and minio-init
```
to:
```
   and minio (built from Go source for complete SBOM coverage)
```

- [ ] **Step 3: Update release website dependencies page**

In `apps/sbomify/release-website/content/dependencies/_index.md`, change line 30 from:
```
**Custom images** (minio, minio-init, sbomify-app) are built using DHI YAML
```
to:
```
**Custom images** (minio, sbomify-app) are built using DHI YAML
```

- [ ] **Step 4: Delete minio-init release website page**

```bash
git rm apps/sbomify/release-website/content/dependencies/minio-init.md
```

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md docs/adr/0001-adopt-dhi-base-images.md apps/sbomify/release-website/content/dependencies/
git commit -m "docs: remove minio-init references, update minio description"
```

### Task 11: Regenerate release website

**Files:**
- Regenerate: `apps/sbomify/release-website/public/` (contains stale minio-init references)

- [ ] **Step 1: Regenerate release data and website**

Note: `just release-data` pulls attestation data from built images. It works against locally-built `:dev` tagged images from `just build`. Ensure `just build minio` has been run (Task 5, Step 2) before this step.

```bash
just release-website
```

This runs `just release-data` (extracts attestation data) then Hugo build. The `public/` directory will be regenerated without minio-init pages.

- [ ] **Step 2: Verify minio-init is gone from output**

```bash
grep -r "minio-init" apps/sbomify/release-website/public/ || echo "Clean — no minio-init references"
```

Expected: "Clean — no minio-init references"

- [ ] **Step 3: Commit generated files**

```bash
git add apps/sbomify/release-website/public/
git commit -m "chore: regenerate release website without minio-init"
```

---

## Chunk 6: End-to-end verification

### Task 12: Full build and scan

- [ ] **Step 1: Build all images**

```bash
just build-all
```

Expected: all images build successfully (hugo, minio, sbomify-app). No minio-init build attempted.

- [ ] **Step 2: Scan minio image**

```bash
just scan minio
```

Expected: grype and gitleaks scans complete (vulnerabilities are informational, not blocking).

- [ ] **Step 3: Verify SBOM quality**

```bash
just sbom-spdx minio
jq '.packages[] | .name' .artifacts/minio/sbom.spdx.json | head -20
```

Expected: Go module names visible in the SBOM (e.g., `github.com/minio/minio`, `golang.org/x/net`, `google.golang.org/grpc`).

- [ ] **Step 4: Smoke-test docker-compose**

```bash
cd apps/sbomify/deployments
docker compose up sbomify-minio sbomify-minio-init -d
docker compose logs sbomify-minio-init --follow
```

Expected: init container starts, waits for minio, creates buckets, exits successfully. Press Ctrl+C after seeing "Done."

```bash
docker compose down
cd ../../..
```
