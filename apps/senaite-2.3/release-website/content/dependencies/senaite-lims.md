---
title: "senaite-lims"
description: "Software Bill of Materials for the senaite-lims (2.3.x) heritage application image."
---

{{< sbom-image-meta image="senaite-lims" >}}

## About this image

SENAITE 2.3.0 + Plone 5.2.9 + their pinned dependency tree, running
on the wellmaintained python-2.7 runtime image. This is the per-version
2.3.x snapshot built per the convention in
[ADR-0015](https://github.com/wellmaintained/packages-dhi/blob/main/docs/adr/0015-version-line-app-naming-with-current-sliding-pointer.md).

The 2.3.x line is the most recent point on the SENAITE 2.x track that
remains compatible with Plone 5.2 / Python 2.7. SENAITE 2.4 onward
moves to Plone 6 / Python 3; consumers who track that line use
`senaite-current` (which slides forward as upstream releases land)
or pin to the future `senaite-2.x` snapshot once one is published.

### Why a Py2-compatible transitive overlay

Several SENAITE 2.3.0 transitive dependencies have moved to Python 3
only since the 2022 release window (magnitude, Pyphen, requests,
urllib3, certifi, idna, openpyxl, et_xmlfile, unittest2). buildout's
[versions] pins are not honoured for indirect deps in the 2026/PyPI
mismatch scenario — easy_install fetches the latest and then fails
to parse Py3 syntax. The image build pre-installs each package via
`pip install` (which respects `requires_python` and resolves the
last 2.7-compatible release), so when buildout runs it finds the
egg already in site-packages and skips its own materialisation.

The pin set is recorded in
[`apps/senaite-2.3/images/senaite-lims/buildout/buildout.cfg`](https://github.com/wellmaintained/packages-dhi/blob/main/apps/senaite-2.3/images/senaite-lims/buildout/buildout.cfg)
under `[versions]`, with the same set repeated as a
`pip install --target` step in the image's
[`prod.yaml`](https://github.com/wellmaintained/packages-dhi/blob/main/apps/senaite-2.3/images/senaite-lims/prod.yaml).

## Component Tree

{{< sbom-tree-viewer image="senaite-lims" >}}

The component tree renders above once the senaite-lims image build
attestation is available; the tree-viewer reads the SBOM JSON copied
into `static/artifacts/sboms/` by the release-data extractor.
