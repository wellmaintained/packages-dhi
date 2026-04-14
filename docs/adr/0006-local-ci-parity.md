# 0006. Local and CI Parity

Date: 2026-04-14

## Status

accepted

## Context

Differences between local development and CI environments are a persistent
source of "works on my machine" failures and difficult-to-reproduce bugs. When
CI uses different tool versions, different execution paths, or different
orchestration than local development, problems found in CI cannot be diagnosed
locally, and work validated locally may fail in CI.

## Decision

Local development and CI must run the same tools, at the same versions, via
the same scripts.

### Same tools, same versions

All tools (crane, cosign, grype, syft, gitleaks, hugo, sbom-convert) are pinned
in `tool-versions.yaml` with exact versions and SHA-256 checksums. The
`bin/` shims download the pinned binary on first use and cache it in
`.tool-cache/`. There is no separate tool installation path for CI.

### Same scripts

`just` targets are the unit of work. CI workflows are thin wrappers that call
`just build`, `just extract-dhi-attestations`, `just release-website`, etc.
CI-specific concerns (checkout, registry login, artifact upload, release
creation) live in the workflow files. Build logic, scanning, SBOM generation,
and compliance packaging live in `Justfile` and `scripts/` — shared between
local and CI.

### CI adds, never replaces

CI workflows add orchestration on top of local scripts:

- **Authentication** — registry logins, OIDC tokens
- **Artifact flow** — uploading/downloading between jobs
- **Tagging and promotion** — component tags, app-collection tags, released-on tags
- **Publishing** — GitHub releases, GitHub Pages deployment

None of these change what gets built or how. A developer running `just build minio`
locally produces the same image and compliance artifacts as CI does.

## Consequences

- A developer can reproduce any CI step locally by running the corresponding
  `just` target.
- Tool version updates are a single change to `tool-versions.yaml`, effective
  locally and in CI immediately.
- CI workflows remain simple — they orchestrate, authenticate, and publish,
  but delegate all build and compliance work to shared scripts.
- Tools are not delivered via Docker containers, avoiding credential
  passthrough, OIDC forwarding, and cache permission issues that created
  divergence between local and CI execution.
