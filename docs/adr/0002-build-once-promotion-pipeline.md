# 0002. Build-Once Promotion Pipeline

Date: 2026-04-13

## Status

accepted

## Context

Container images should be built exactly once and promoted through environments
by adding metadata — never rebuilt. Rebuilding introduces risk: a "release" image
may differ from the one that passed CI, and the compliance artifacts (SBOMs,
vulnerability scans, provenance) attached to the release describe a different
build than what was tested.

This pipeline must also produce a versioned collection of images that can be
deployed together, inspected for compliance, and cleaned up when no longer needed.

## Decision

Adopt a three-phase promotion pipeline with CalVer app-collection versioning,
matching the pattern established in `wellmaintained/packages`.

### Phase 1: PR Build

Every commit on a pull request builds all custom images (hugo, minio,
sbomify-app, sbom-convert) and pushes them to GHCR with a **component tag**:

    {name}-{version}-{sha7}

For example: `minio-RELEASE.2025-10-15-abc1234`

Each image is signed with cosign and attested with its SBOM and SLSA provenance.
The build also extracts attestations for stock DHI images (postgres, redis,
keycloak, caddy) from the DHI registry. All compliance artifacts are uploaded as
GitHub Actions artifacts.

A quality gate validates SBOM completeness before the PR can merge.

### Phase 2: Pre-Release (merge to main)

When a PR merges, the pre-release workflow promotes the already-built images —
it does not rebuild them. For each custom image, it resolves the component tag
from the PR's head SHA and adds an **app-collection tag** to the same digest:

    sbomify-v{APP_VERSION}-{YYYYMMDD}.{N}

For example: `sbomify-v26.1.0-20260413.1`

The app version is extracted from the sbomify-app component tag. The build number
`N` increments when multiple merges occur on the same day.

The workflow downloads the compliance artifacts from the PR build, assembles a
compliance pack (SBOMs, scans, VEX, pinned docker-compose.yml), and creates a
GitHub pre-release with the compliance zip attached.

### Phase 3: Release Promotion

A human reviews the pre-release and promotes it by removing the pre-release flag
in the GitHub UI. This triggers the release workflow, which:

1. Adds a **released-on tag** to each custom image:

       released-on:{ISO8601-timestamp}

   This tag prevents the image from being cleaned up.

2. Builds and deploys the release website to GitHub Pages.

### Cleanup

A weekly workflow deletes custom image versions from GHCR that are older than
7 days and lack a `released-on:` tag. This removes stale component-tagged images
from old PRs while preserving every released version indefinitely.

Stock DHI images are not stored in GHCR and are not subject to cleanup.

### Tag Summary

| Tag | Purpose | Lifetime |
|-----|---------|----------|
| `{name}-{version}-{sha7}` | Identify a specific build from a PR commit | Cleaned up after 7 days unless released |
| `sbomify-v{version}-{YYYYMMDD}.{N}` | Group images into a deployable app-collection | Kept as long as any image in the collection is released |
| `released-on:{timestamp}` | Mark images as promoted, prevent cleanup | Permanent |

## Consequences

- Images are built once during PR CI and never rebuilt. The release contains
  exactly the bits that were tested.
- Compliance artifacts (SBOMs, provenance, vulnerability scans) are generated
  at build time and flow through to the release without regeneration.
- Stock DHI images remain in the DHI registry, referenced by pinned digest.
  Only custom-built images pass through GHCR.
- Stale PR images are automatically cleaned up, preventing unbounded GHCR
  storage growth.
- The app-collection CalVer tag provides a single version identifier for the
  entire set of images deployed together.
