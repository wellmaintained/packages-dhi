# Build MinIO from source

## Problem

The minio image downloads pre-compiled binaries from MinIO's CDN. The resulting SBOM can only record "minio version X" and "mc version X" as opaque components — it cannot enumerate the hundreds of Go module dependencies baked into each binary.

Building from source lets the SBOM indexer inspect the compiled Go binaries and produce a complete transitive dependency list.

## Design

### Consolidate minio and minio-init into one image

The minio-init image exists solely to run `mc` commands that create buckets. The minio image already ships `mc`. Merging them eliminates a redundant image and its build/scan/release overhead.

The bucket-creation script (`create-minio-buckets.sh`) contains sbomify-specific logic — which buckets to create, which access policies to set. It belongs in the sbomify deployment, not the generic minio image.

After this change:
- `common/images/minio/dhi.yaml` builds a generic image containing `minio` server and `mc` client
- `apps/sbomify/deployments/` mounts `create-minio-buckets.sh` into the init container at runtime
- `common/images/minio-init/` is deleted

### Build minio and mc from source

Replace the binary downloads with two Go build stages using `dhi.io/golang:1.26-alpine3.23-dev`.

> **Prerequisite:** Confirm `dhi.io/golang:1.26-alpine3.23-dev` exists in the DHI catalog before implementation. Pin by digest once confirmed. If unavailable, fall back to the latest available Go version (e.g. 1.25).

**Stage 1 — minio server:**
- Source: `git+https://github.com/minio/minio.git#RELEASE.2025-10-15T17-29-55Z`
- Build: single `privileged: true` step combining `go mod download` and `go build`
- Ldflags for version embedding:
  ```
  -X github.com/minio/minio/cmd.Version=RELEASE.2025-10-15T17-29-55Z
  -X github.com/minio/minio/cmd.ReleaseTag=RELEASE.2025-10-15T17-29-55Z
  -X github.com/minio/minio/cmd.CommitID=<git sha>
  -X github.com/minio/minio/cmd.ShortCommitID=<short sha>
  ```
- Output: `/usr/local/bin/minio`

**Stage 2 — mc client:**
- Source: `git+https://github.com/minio/mc.git#RELEASE.2025-08-13T08-35-41Z`
- Build: single `privileged: true` step combining `go mod download` and `go build`
- Ldflags for version embedding:
  ```
  -X github.com/minio/mc/cmd.Version=RELEASE.2025-08-13T08-35-41Z
  -X github.com/minio/mc/cmd.ReleaseTag=RELEASE.2025-08-13T08-35-41Z
  -X github.com/minio/mc/cmd.CommitID=<git sha>
  -X github.com/minio/mc/cmd.ShortCommitID=<short sha>
  ```
- Output: `/usr/local/bin/mc`

> **Note:** The exact ldflags should be verified against each project's `Makefile` during implementation — the fields above are based on minio's known build system but may need adjustment.

**Version upgrade:** This change upgrades the minio server from `RELEASE.2025-09-07T16-13-09Z` (current) to `RELEASE.2025-10-15T17-29-55Z` (latest). The mc client stays at `RELEASE.2025-08-13T08-35-41Z` (already latest).

### Rename `latest.yaml` to `dhi.yaml`

The filename `latest.yaml` implies a version strategy, but every version inside is pinned. Rename to `dhi.yaml` across all surviving images — it describes what the file is (a DHI image definition), not a version. The minio-init `latest.yaml` is deleted rather than renamed.

Affected files:
- `common/images/minio/latest.yaml` → `dhi.yaml`
- `common/images/hugo/latest.yaml` → `dhi.yaml`
- References in `apps/sbomify/app-images.yaml`, `app-images.lock.yaml`, `common/tool-images.yaml`, `common/tool-images.lock.yaml`

### Docker-compose changes

The `MINIO_ACCESS_KEY` / `MINIO_SECRET_KEY` environment variables move from the image definition to the docker-compose `environment:` block — credentials should not be baked into images.

```yaml
sbomify-minio:
  image: ghcr.io/wellmaintained/minio:latest
  environment:
    MINIO_ACCESS_KEY: minioadmin
    MINIO_SECRET_KEY: minioadmin
  # entrypoint and command unchanged (set in image)

sbomify-minio-init:
  image: ghcr.io/wellmaintained/minio:latest
  entrypoint: ["/usr/local/bin/create-minio-buckets.sh"]
  volumes:
    - ./scripts/create-minio-buckets.sh:/scripts/create-minio-buckets.sh:ro
  environment:
    AWS_ENDPOINT_URL_S3: ...
    AWS_MEDIA_STORAGE_BUCKET_NAME: ...
    AWS_SBOMS_STORAGE_BUCKET_NAME: ...
  depends_on:
    sbomify-minio:
      condition: service_healthy
```

### Files to create

- `apps/sbomify/deployments/scripts/create-minio-buckets.sh` — extracted from image definition (new directory)

### Files to delete

- `common/images/minio-init/` — entire directory
- `apps/sbomify/release-website/content/dependencies/minio-init.md`

### Files to update

- `common/images/minio/dhi.yaml` — rewrite with Go source builds, include `mc`
- `apps/sbomify/deployments/docker-compose.yml` — init container uses minio image with mounted script; minio service gets credentials in environment block
- `apps/sbomify/app-images.yaml` / `app-images.lock.yaml` — remove minio-init, update minio definition path
- `common/tool-images.yaml` / `common/tool-images.lock.yaml` — update hugo definition path
- `.github/workflows/*.yml` — remove minio-init from image lists (build.yml, pre-release.yml, rescan-vulnerabilities.yml, sbom-quality-gate.yml)
- `CLAUDE.md` — remove minio-init from structure description
- `docs/adr/0001-adopt-dhi-base-images.md` — update to reflect minio-init no longer exists as a separate image
- `apps/sbomify/release-website/content/dependencies/_index.md` — update references

### Generated files to regenerate

These files are generated output committed to the repo. They must be regenerated after the above changes:

- `apps/sbomify/release-website/public/` — regenerate with `just release-website` (contains minio-init references in sidebar, SBOM tables, provenance pages)
- Release data artifacts — regenerate with `just release-data`

## Versions

| Component | Version | Note |
|-----------|---------|------|
| Go (builder) | 1.26 | `dhi.io/golang:1.26-alpine3.23-dev` (pin by digest once confirmed) |
| minio server | RELEASE.2025-10-15T17-29-55Z | upgraded from RELEASE.2025-09-07T16-13-09Z |
| mc client | RELEASE.2025-08-13T08-35-41Z | unchanged (already latest) |

## SBOM outcome

After this change, the SBOM for the minio image will contain the full Go module dependency graph for both `minio` and `mc` — every transitive dependency with its version — rather than two opaque binary entries.
