---
title: "nginx"
description: "Software Bill of Materials for the nginx container image."
---

<!--
  TODO (Step 5/8): {{< sbom-image-meta image="nginx" >}}
  Stock DHI image — SBOM is extracted from DHI registry attestations
  by extract-dhi-attestations once release-data tooling is generalised.
-->

## About this image

`dhi.io/nginx:1.29` — stock Docker Hardened Image, used as the
front-end web server in the senaite deployment. SBOM, VEX, and
SLSA provenance are extracted directly from DHI's registry
attestations; we do not patch this image.

See [ADR-0001](https://github.com/wellmaintained/packages-dhi/blob/main/docs/adr/0001-adopt-dhi-base-images.md)
for the stock-image consumption pattern.

## Component Tree

<!-- TODO (Step 5/8): {{< sbom-tree-viewer image="nginx" >}} -->

The component tree will render here once release-data tooling is
generalised per-app.
