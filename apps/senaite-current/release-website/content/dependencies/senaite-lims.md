---
title: "senaite-lims-current"
description: "Software Bill of Materials for the senaite-lims-current application image."
---

{{< sbom-image-meta image="senaite-lims" >}}

## About this image

SENAITE 2.6.0 + Plone 5.2.15 + their pinned dependency tree, running
on the wellmaintained python-2.7 runtime image. The 2.6 line is the
final SENAITE release that targets Python 2.7 — `senaite.core` 2.6.0's
`setup.py` explicitly caps Pillow<7, openpyxl==2.6.4, tinycss2<1, and
a dozen other transitive deps with comments like *"X does not support
Python 2.x anymore"*.

The image is rebuilt whenever this `apps/senaite-current/` app changes;
when upstream ships a SENAITE release that fires the
[version-line criteria](https://github.com/wellmaintained/packages-dhi/blob/main/docs/research/version-line-criteria.md)
(today that means the long-promised Python 3 / Plone 6 jump), the
current snapshot will rename to `apps/senaite-2.6/` and a fresh
`apps/senaite-current/` will spin up on the new line.

## Component Tree

{{< sbom-tree-viewer image="senaite-lims" >}}

The component tree renders above once the senaite-lims-current image
build attestation is available; the tree-viewer reads the SBOM JSON
copied into `static/artifacts/sboms/` by the release-data extractor.
