---
title: "Dependencies"
description: "Container images, deployment artifacts, and Software Bills of Materials for this release."
weight: 1
sidebar:
  open: true
---

{{< release-overview >}}

## Images

{{< release-images >}}

## SBOMs

CycloneDX SBOMs for all container images in this release. Each SBOM is
extracted from OCI attestations attached to the container image and included
here as a browsable component tree with a downloadable JSON file.

{{< sbom-summary-table >}}

### How SBOMs Are Generated

**Stock DHI images** (postgres, redis, keycloak, caddy) carry SBOMs generated
by [Docker Hardened Images](https://www.docker.com/products/hardened-images/)
as part of their 15-attestation suite. These are extracted from the DHI registry
at build time.

**Custom images** (minio, minio-init, sbomify-app) are built using DHI YAML
definitions with `dhi.io/scout-sbom-indexer` generating CycloneDX SBOMs, plus
SPDX SBOMs via [Syft](https://github.com/anchore/syft).

## Previous releases

Historical releases and compliance bundles are available at
[GitHub Releases](https://github.com/wellmaintained/packages-dhi/releases).
