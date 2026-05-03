---
title: "Dependencies"
description: "Container images, layer attribution, and Software Bills of Materials for this release."
weight: 1
sidebar:
  open: true
---

## Layer attribution

This release stacks four distinct provenance domains. Each row names
who patches that layer, on what cadence, where the evidence lives,
and **which vulnerability source covers that layer**. The split
matters: a single SBOM scan does not see the whole stack, because
some layers are dpkg-installed (visible to grype) and some are
built from source (invisible to grype). See
[Vulnerabilities → How the matrix is composed](../vulnerabilities/)
for the full picture.

Per [ADR-0012](https://github.com/wellmaintained/packages-dhi/blob/main/docs/adr/0012-layer-python-2.7-on-debian13-base.md):

| Layer                                   | Owner          | Patch cadence            | Evidence                                                                                                                                                                  | Vulnerability source                                            |
|-----------------------------------------|----------------|--------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------|
| debian13 rootfs + system libraries      | DHI            | DHI's standard cadence   | `vex.dhi.json`, DHI SLSA provenance (extracted via `extract-dhi-attestations`)                                                                                            | grype against the SBOM's deb purls (dpkg-visible)               |
| CPython 2.7.18 (interpreter, source-built) | wellmaintained | wellmaintained engineers | [`patches/`](https://github.com/wellmaintained/packages-dhi/tree/main/common/images/python-2.7/patches) + [`CVE-LOG.md`](https://github.com/wellmaintained/packages-dhi/blob/main/common/images/python-2.7/patches/CVE-LOG.md), `python-2.7.vex.json` | **`CVE-LOG.md` (NVD-seeded inventory)** — grype-blind, see below |
| pip / setuptools / wheel (bootstrap)    | wellmaintained | wellmaintained engineers | bootstrap installs at image build via `get-pip.py` (see `dhi.yaml`), tracked in the Python-2.7 image's CycloneDX SBOM                                                     | grype against the SBOM's pkg:pypi purls                          |
| Plone 5.2 + SENAITE 2.0.0               | upstream pinned| upstream (no patches today)| `senaite-lims.vex.json`, `app-images.lock.yaml`                                                                                                                          | grype against the SBOM (TODO — Step 5/7)                         |
| Deployment composition                  | wellmaintained | wellmaintained engineers | `apps/senaite/deployments/` (TODO — Step 6)                                                                                                                              | n/a — composition has no CVE surface of its own                  |

The `org.opencontainers.image.vendor` annotation on each image
reflects the **layer** that image publishes — `wellmaintained` for
the python-2.7 and senaite-lims images, `Docker, Inc.` for the
unmodified DHI base. The SBOM components below each image trace
through to whichever layer originally supplied them.

### The grype blind spot for source-installed CPython

CPython 2.7 in this image is built from source via
`./configure && make && make install` (per
[ADR-0011](https://github.com/wellmaintained/packages-dhi/blob/main/docs/adr/0011-build-python-2.7-from-canonical-sources.md)).
That means it lands at `/opt/python-2.7/` *without* registering
itself with `dpkg`. Grype reads dpkg's package database, so when
grype scans the python-2.7 image's SBOM it reports **zero findings
against the CPython interpreter** — not because there are no CVEs,
but because grype cannot see the package it's looking for.

The authoritative inventory for CPython-itself CVEs lives at
[`common/images/python-2.7/patches/CVE-LOG.md`](https://github.com/wellmaintained/packages-dhi/blob/main/common/images/python-2.7/patches/CVE-LOG.md),
seeded from the NVD CVE API against
`cpe:2.3:a:python:python:2.7` with `publishedDate >= 2020-01-01`.
That is the file consumers should read for the runtime layer's CVE
posture; the published `python-2.7.vex.json` is the
forward-facing companion that records the analysed subset (per
[ADR-0009](https://github.com/wellmaintained/packages-dhi/blob/main/docs/adr/0009-publish-vex-not-point-in-time-cves.md)).

This is a deliberate consequence of the source-build decision, not
a tooling gap. A dpkg-installed CPython would be visible to grype
*and* would lose the patch-traceability story this distribution is
built around. The trade-off is documented inline in
`common/images/python-2.7/dhi.yaml`.

## Images

<!--
  TODO (Step 5 + Step 8 final pass):
  Replace this with the {{< release-images >}} shortcode rendering once
  release-data tooling is generalised per-app. See ADR-0005 follow-up.
-->

| Image                                 | Source        | Variant     |
|---------------------------------------|---------------|-------------|
| `ghcr.io/wellmaintained/packages-dhi/python-2.7`   | custom (built from source, see [ADR-0011](https://github.com/wellmaintained/packages-dhi/blob/main/docs/adr/0011-build-python-2.7-from-canonical-sources.md)) | runtime |
| `ghcr.io/wellmaintained/packages-dhi/senaite-lims` | custom (TODO — Step 5) | runtime |
| `dhi.io/nginx:1.29`                                | stock (DHI)   | runtime     |

## SBOMs

<!--
  TODO (Step 5/8): replace with {{< sbom-summary-table >}} once data/ is
  populated by a senaite-aware extract-release-data run.
-->

CycloneDX SBOMs for all container images in this release will be
extracted from OCI attestations attached to each image and rendered
here as browsable component trees with downloadable JSON files.

### How SBOMs are generated for heritage images

**Stock DHI images** (nginx) carry SBOMs generated by
[Docker Hardened Images](https://www.docker.com/products/hardened-images/)
as part of their 15-attestation suite. These are extracted from the
DHI registry at build time.

**Custom heritage images** (python-2.7, senaite-lims) are built
using DHI YAML definitions with `dhi.io/scout-sbom-indexer` generating
CycloneDX SBOMs. The SBOM captures:

- The upstream source fetch (`pkg:github/python/cpython@v2.7.18` for
  Python; SENAITE/Plone source URLs for the LIMS)
- Each Debian package from the runtime rootfs (DHI's deb purls)
- The wellmaintained patch series — each `.patch` file applied
  during the build is captured as a build step in the SLSA
  provenance, and the resulting binary's hash is bound to the
  applied patch sequence.

See [ADR-0003](https://github.com/wellmaintained/packages-dhi/blob/main/docs/adr/0003-derive-sboms-from-build-attestations.md)
for the SBOM-from-attestations contract.

## Previous releases

Historical releases and compliance bundles are available at
[GitHub Releases](https://github.com/wellmaintained/packages-dhi/releases).
