---
title: "Required Source Disclosure"
description: "Source code for components where the license requires disclosure."
weight: 2
---

## Required Source Disclosure

The following components are distributed under licenses that require us to
make source code available. Components under copyleft licenses (GPL, LGPL,
MPL, etc.) are listed here.

All images use [Docker Hardened Images](https://docs.docker.com/docker-hub/dhi/)
or are built from source with pinned dependencies. Source URLs for all components
are recorded in the CycloneDX SBOM under the `externalReferences` field with
type `distribution`. Download the SBOM from the
[Dependencies](../../dependencies/) section to access them.

### Heritage-specific notes

- **CPython 2.7.18** — sources at
  [github.com/python/cpython at v2.7.18](https://github.com/python/cpython/tree/v2.7.18).
  Patches applied during the build are kept verbatim in
  [`common/images/python-2.7/patches/`](https://github.com/wellmaintained/packages-dhi/tree/main/common/images/python-2.7/patches).
  Anyone receiving the binary can reproduce the source by checking out
  the upstream tag and applying the series in order.
- **Plone 5.2 / SENAITE 2.0.0** — pinned versions are in
  [`apps/senaite/images/senaite-lims/prod.yaml`](https://github.com/wellmaintained/packages-dhi/blob/main/apps/senaite/images/senaite-lims/prod.yaml)
  (forward-declared until the senaite-lims-image yak lands). Source
  URLs for each component are recorded in the SBOM.
