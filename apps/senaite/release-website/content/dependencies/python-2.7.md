---
title: "python-2.7"
description: "Software Bill of Materials for the python-2.7 heritage runtime image."
---

<!--
  TODO (Step 5/8): replace these placeholder paragraphs with the
  {{< sbom-image-meta image="python-2.7" >}} and
  {{< sbom-tree-viewer image="python-2.7" >}} shortcodes once
  release-data tooling is generalised per-app and data/ is populated.
-->

## About this image

CPython 2.7.18 built from canonical python.org sources (`v2.7.18`
upstream tag), layered on `dhi.io/build:2-debian13`. Patches applied
during the build are recorded in
[`common/images/python-2.7/patches/series`](https://github.com/wellmaintained/packages-dhi/tree/main/common/images/python-2.7/patches)
with full provenance trailers.

Today the patch series is empty — the build applies the upstream
`v2.7.18` tag as-is. As CVEs are triaged against CPython 2.7, real
patches land here with an `Upstream-CVE`, `Upstream-Fix`,
`Backported-By`, and `Reviewed-By` for each.

### Three vulnerability sources, not one

The python-2.7 image's risk surface is composed from three layers,
each with its own vulnerability source. A single grype scan sees
**two of the three**:

| Layer in this image                | Visible to grype?       | Source of truth                                                                                                                 |
|------------------------------------|-------------------------|---------------------------------------------------------------------------------------------------------------------------------|
| debian13 system libraries (dpkg)   | ✅ via deb purls         | DHI's `vex.dhi.json` + grype against the SBOM                                                                                   |
| pip / setuptools / wheel (PyPI)    | ✅ via `pkg:pypi/...`    | wellmaintained-authored `python-2.7.vex.json` + grype against the SBOM                                                          |
| CPython 2.7.18 (source-installed)  | ❌ grype-blind           | [`CVE-LOG.md`](https://github.com/wellmaintained/packages-dhi/blob/main/common/images/python-2.7/patches/CVE-LOG.md) (24 NVD-seeded CVEs) + `python-2.7.vex.json` |

The third row is the consequence of the source-build decision. A
dpkg-installed CPython would be grype-visible *and* would lose the
patch-traceability story (no per-patch provenance, no NNNN-numbered
series, no two-engineer rule). We trade scanner visibility for
audit-trail completeness, and surface the CVE-LOG separately so
consumers see the full picture rather than the dpkg-visible subset.
See [Vulnerabilities](../../vulnerabilities/) for the composed view.

See:

- [ADR-0011: Build Python 2.7 from canonical sources](https://github.com/wellmaintained/packages-dhi/blob/main/docs/adr/0011-build-python-2.7-from-canonical-sources.md)
- [ADR-0012: Layer Python 2.7 on debian13 base](https://github.com/wellmaintained/packages-dhi/blob/main/docs/adr/0012-layer-python-2.7-on-debian13-base.md)
- [ADR-0013: Patch backport policy for EOL runtimes](https://github.com/wellmaintained/packages-dhi/blob/main/docs/adr/0013-patch-backport-policy-for-eol-runtimes.md)

## Component Tree

<!-- TODO (Step 5/8): {{< sbom-tree-viewer image="python-2.7" >}} -->

The component tree will render here once release-data tooling is
generalised to extract per-app SBOM data into the senaite
release-website's `data/` directory.
