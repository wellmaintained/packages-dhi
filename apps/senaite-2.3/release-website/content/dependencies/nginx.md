---
title: "nginx"
description: "Software Bill of Materials for the nginx container image."
---

{{< sbom-image-meta image="nginx" >}}

## About this image

`dhi.io/nginx:1.29` — stock Docker Hardened Image, used as the
front-end web server in the senaite deployment. SBOM, VEX, and
SLSA provenance are extracted directly from DHI's registry
attestations; we do not patch this image.

See [ADR-0001](https://github.com/wellmaintained/packages-dhi/blob/main/docs/adr/0001-adopt-dhi-base-images.md)
for the stock-image consumption pattern.

## Component Tree

{{< sbom-tree-viewer image="nginx" >}}

The component tree above renders the nginx image's CycloneDX SBOM
extracted from DHI's per-image attestation suite.
