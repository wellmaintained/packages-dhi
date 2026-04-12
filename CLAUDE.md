# packages-dhi

DHI-native image pipeline for wellmaintained packages.

## Structure

- `common/images/` — Shared infrastructure images (minio, minio-init)
- `apps/sbomify/` — sbomify application (images, deployments, release website)
- `.github/` — CI workflows and image manifest
- `scripts/` — Build, scan, and release scripts
- `docs/adr/` — Architecture decision records

## Prerequisites

- Docker (with buildx)
- Just

## Quick Start

```
just build minio          # Build a custom image
just scan minio           # Scan for vulnerabilities and secrets
just extract-dhi-attestations  # Pull stock image attestations
just release-data         # Generate release website data
```

## Image Manifest

`.github/image-manifest.json` is the single source of truth for all images:
- `stock` — DHI images used directly, pinned by digest
- `custom` — Images we build, with DHI YAML definition paths
