# Build-Once Promotion Pipeline

## Problem

The current CI rebuilds images on every merge to main, producing release
artifacts that may differ from what was tested during the PR. Compliance
artifacts (SBOMs, vulnerability scans, provenance) are regenerated rather than
carried forward from the build that passed CI.

## Design

See [ADR-0002](../adr/0002-build-once-promotion-pipeline.md) for the
rationale and tag hierarchy.

### Tagging scheme

| Tier | Format | Applied by | Example |
|------|--------|-----------|---------|
| Component | `{name}-{version}-{sha7}` | `build.yml` | `minio-RELEASE.2025-10-15-abc1234` |
| App-collection | `sbomify-v{APP_VERSION}-{YYYYMMDD}.{N}` | `pre-release.yml` | `sbomify-v26.1.0-20260413.1` |
| Released | `released-on:{ISO8601}` | `deploy-release-website.yml` | `released-on:2026-04-13T14:30:00Z` |

Component and app-collection tags point to the same digest. Promotion adds tags;
it never rebuilds.

### Workflow: build.yml (PR)

Triggers on `pull_request`.

**Job: stock-dhi-images** (unchanged)
- Extract attestations for stock DHI images
- Upload as GitHub Actions artifact

**Job: resolve-images**
- Run `scripts/list-custom-images` to get image list as JSON

**Job: custom-dhi-builds** (matrix over custom images)
1. `just build {image}` — build image, produce all compliance artifacts in
   `.artifacts/{image}/`
2. Compute component tag: parse image name+version from manifest, append
   `-{sha7}` from `github.event.pull_request.head.sha`
3. `docker tag {reg}:dev {reg}:{component_tag}`
4. `docker push {reg}:{component_tag}`
5. `cosign sign {reg}:{component_tag}`
6. `cosign attest --type cyclonedx` with `.artifacts/{image}/sbom.cdx.json`
7. `cosign attest --type slsaprovenance` with `.artifacts/{image}/provenance.slsa.json`
8. Upload `.artifacts/{image}/` as GitHub Actions artifact (7-day retention)

**Job: sbom-quality-gate** (dependent on custom-dhi-builds)
- Validate SBOM exists and has packages (as now)
- Check CVE severity (warn, don't fail)

### Workflow: pre-release.yml (merge to main)

Triggers on `push` to main.

**Job: resolve-pr**
- Reverse-lookup the PR from the merge commit SHA via GitHub API
- Extract PR head SHA for component tag resolution

**Job: resolve-version**
- Resolve sbomify-app component tag via `crane ls` + grep for SHA7
- Parse app version from the component tag
- Compute CalVer: count existing tags for today, increment build number
- Output: `sbomify-v{APP_VERSION}-{YYYYMMDD}.{N}`

**Job: tag-app-collection** (matrix over custom images)
- Resolve each image's component tag via `crane ls` + SHA7
- Get digest via `crane digest`
- Add app-collection tag via `crane tag {reg}@{digest} {app_collection_version}`

**Job: build-compliance-pack**
- Download per-image artifacts from the PR build workflow
- Extract stock DHI attestation artifacts
- Assemble compliance pack zip (SBOMs, scans, VEX, pinned docker-compose.yml)

**Job: create-release**
- Generate release notes with image/digest table
- Create GitHub pre-release via `gh release create --prerelease`
- Attach compliance pack zip + docker-compose.yml

### Workflow: deploy-release-website.yml (promotion)

Triggers on `release: types: [released]`.

**Job: tag-released**
- Parse release body for image names and digests
- Add `released-on:{timestamp}` tag to each custom image via `crane tag`

**Job: build-and-deploy**
- Download compliance bundle from release assets
- Build Hugo release website from bundle data
- Deploy to GitHub Pages

### Workflow: cleanup-stale-images.yml (new)

Triggers weekly (Sunday 03:00 UTC) and on `workflow_dispatch`.

**Job: cleanup** (matrix over custom images: hugo, minio, sbomify-app, sbom-convert)
- List all versions via GitHub Packages API
- Delete versions where:
  - All tags lack a `released-on:` prefix
  - `updated_at` is older than 7 days
- Stock DHI images are not in GHCR; not subject to cleanup

### Scripts (new or modified)

| Script | Purpose |
|--------|---------|
| `scripts/resolve-component-tag` | Find component tag for an image by SHA7 via `crane ls` |
| `scripts/tag-app-collection` | Add app-collection tag to an image digest via `crane tag` |
| `scripts/cleanup-stale-images` | Delete old untagged GHCR image versions |
| `scripts/create-release-notes` | Generate markdown release notes with image/digest table |

### What stays the same

- `just build` — still builds images and produces all compliance artifacts locally
- `digest-pin-update.yml` — weekly lock file updates
- `rescan-vulnerabilities.yml` — weekly vulnerability rescans
- Stock DHI images — referenced by digest in lock file, attestations from DHI registry
- `scripts/extract-dhi-attestations` — unchanged
- `scripts/extract-release-data` — unchanged
- `scripts/build-compliance-pack` — unchanged (called from pre-release job)
