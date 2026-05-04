---
title: "Provenance"
description: "Build provenance, attestation sources, and image verification for this release."
weight: 5
sidebar:
  open: true
---

Every container image in this release has authenticated provenance. Stock DHI
images carry Docker's full 15-attestation suite; custom images are built with
DHI tooling and signed via Sigstore.

## Attestation Sources

{{< release-images >}}

**Stock DHI images** — attestations provided by
[Docker Hardened Images](https://www.docker.com/products/hardened-images/),
including SBOM, VEX, SLSA provenance, and 12 additional attestation types.

**Custom images** — built using DHI YAML definitions with attestations generated
by our pipeline: CycloneDX SBOM (scout-sbom-indexer), SPDX SBOM (syft),
CVE scan (grype), secrets scan (gitleaks), hand-written VEX, and SLSA provenance
(buildx).

## Verification

All custom images are signed with [Sigstore](https://sigstore.dev) keyless
signing using GitHub Actions' OIDC identity. Verify signatures with
[cosign](https://github.com/sigstore/cosign):

```bash
cosign verify \
  --certificate-identity-regexp="https://github.com/wellmaintained/packages-dhi/" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/wellmaintained/sbomify-app:v0.1.0
```

Stock DHI images can be verified against Docker's signing infrastructure:

```bash
cosign verify \
  --certificate-identity-regexp="https://github.com/docker/" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  dhi.io/postgres:17
```

### Source

All source code is available at the tagged release:

- [Source tree](https://github.com/wellmaintained/packages-dhi) — browse the full source
- [Image definitions](https://github.com/wellmaintained/packages-dhi/tree/main/apps/sbomify-current/images) — DHI YAML build definitions
- [Tool images](https://github.com/wellmaintained/packages-dhi/blob/main/common/tool-images.lock.yaml) — tool image digests
- [App images](https://github.com/wellmaintained/packages-dhi/blob/main/apps/sbomify-current/app-images.lock.yaml) — stock and custom image digests
