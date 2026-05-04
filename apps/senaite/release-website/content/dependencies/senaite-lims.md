---
title: "senaite-lims"
description: "Software Bill of Materials for the senaite-lims heritage application image."
---

{{< sbom-image-meta image="senaite-lims" >}}

## About this image

SENAITE 2.0.0 + Plone 5.2 + their pinned dependency tree, running on
the wellmaintained python-2.7 runtime image. See
[ADR-0010](https://github.com/wellmaintained/packages-dhi/blob/main/docs/adr/0010-senaite-2.0.0-as-heritage-demo-target.md)
for why 2.0.0 is the demo target.

The image build is **not yet implemented** — it ships as part of the
`senaite-lims-image` yak (Step 5). The expected image definition path
is `apps/senaite/images/senaite-lims/prod.yaml`; today the manifest
entry at `apps/senaite/app-images.yaml` references this path as a
forward declaration.

## Component Tree

{{< sbom-tree-viewer image="senaite-lims" >}}

The component tree renders above once the senaite-lims image build
attestation is available; the tree-viewer reads the SBOM JSON copied
into `static/artifacts/sboms/` by the release-data extractor.
