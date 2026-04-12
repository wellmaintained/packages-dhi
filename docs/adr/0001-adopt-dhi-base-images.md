# 0001. Adopt Docker Hardened Images as Base Image Foundation

Date: 2026-04-12

## Status

accepted

## Context

The Nix-based packages repo builds 7 custom container images from scratch using
nix-compliance-inator for SBOM generation and manual nixpkgs overlays for CVE
patching. This approach provides strong reproducibility guarantees but requires
significant maintenance effort for base image hardening — patching openssl,
busybox CVEs, glibc vulnerabilities — work that Docker Hardened Images (DHI)
handles across 381+ images with 15 attestation types, automated CVE patching,
and SLSA Level 3 provenance.

Analysis of upstream sbomify's deployment pattern revealed that 6 of 7 custom
images are unnecessary: postgres, redis, keycloak, caddy, and minio-init all
use stock images with runtime configuration (volume mounts, environment
variables). Only the sbomify-app image requires a custom build.

## Decision

Create a new packages-dhi repo that:

1. Uses stock DHI images directly for infrastructure (postgres, redis,
   keycloak, caddy) — referenced by pinned digest, attestations extracted
   at build time
2. Builds custom images using DHI's YAML build frontend for sbomify-app,
   minio (learning exercise), and minio-init
3. Uses DHI hardened tool images (grype, cosign, syft, crane, gitleaks)
   for all build and scan operations
4. Produces identical compliance outputs: release website, compliance pack,
   signed images with attestations

### Relation to other ADRs

None (first ADR in new repo).

## Consequences

### Benefits

- Stock images carry DHI's full 15-attestation suite vs our current 3
- CVE patching for base images handled by Docker's team, not ours
- Prerequisites reduced from Nix to Docker + Just
- Only 1 custom image to build (sbomify-app) vs 7
- Secrets scanning and SPDX SBOMs added (new capabilities)

### Trade-offs

- Lose Nix reproducibility guarantee for infrastructure images
- Lose structural SBOM coupling (nix-compliance-inator)
- Depend on DHI registry availability (mitigated by digest pinning)
- DHI YAML build frontend is newer and less documented than Dockerfiles

### Future considerations

- Explore Docker Service Partner program for business development
- Monitor DHI catalog for minio addition (would eliminate our custom build)
- Evaluate Docker Scout subscription for health score attestation
- Consider contributing image definitions back to DHI catalog
