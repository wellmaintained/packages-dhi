---
title: "Vulnerabilities"
description: "Per-image OpenVEX statements for this release."
weight: 3
sidebar:
  hide: true
---

The table below maps the status of known CVEs at the time of release.
Details are available in the [OpenVEX](https://openvex.dev/) format as
part of the [compliance pack]({{< relref "quickstart#audit-pack" >}}).

## How the vulnerability matrix is composed

A heritage stack composed of four provenance domains (see
[Dependencies](../dependencies/) for the layer table) is **not** the
same as a single grype run with one number at the bottom. Different
layers have different vulnerability sources; the matrix surfaces
all of them so a reader sees the complete picture, not the
dpkg-visible subset.

Three sources feed the matrix:

### 1. Debian system libraries (DHI's territory)

Debian packages installed into the runtime rootfs by
`# syntax=dhi.io/build:2-debian13` — glibc, ncurses, sqlite3,
util-linux, xz-utils, zlib, and the t64-suffixed runtime libraries
that CPython links against. These are **dpkg-visible**: grype reads
the SBOM's deb purls and matches them against the upstream advisory
database.

A snapshot grype run against the python-2.7 image (2026-05-03)
returns **25 findings** in this layer, distributed across glibc and
the surrounding system-library set. The mix is dominated by
glibc — debian13's pinned glibc is older than the CVE feed because
DHI's base hardens on a release cadence, not a CVE-by-CVE cadence.
This count moves down when DHI updates the base; we do not patch
debian13 ourselves, so the cadence is theirs (per
[ADR-0001](https://github.com/wellmaintained/packages-dhi/blob/main/docs/adr/0001-adopt-dhi-base-images.md)).

### 2. pip / setuptools / wheel (wellmaintained's bootstrap territory)

The Python-2.7 image bootstraps a 2.7-compatible pip, setuptools,
and wheel via `get-pip.py` during the build (the last release line
that supports Python 2.7 is pip 20.3.4). These tools are visible to
grype as `pkg:pypi/...` purls in the SBOM.

A snapshot grype run returns **9 findings** in this layer. The
trio is unmaintained upstream — there will be no pip 20.4 — so
every CVE that lands against this version sits in
wellmaintained's queue. Either we patch (and log the patch under
[`patches/`](https://github.com/wellmaintained/packages-dhi/tree/main/common/images/python-2.7/patches),
per [ADR-0013](https://github.com/wellmaintained/packages-dhi/blob/main/docs/adr/0013-patch-backport-policy-for-eol-runtimes.md))
or we VEX with a deployment-context-specific justification (per
[ADR-0014](https://github.com/wellmaintained/packages-dhi/blob/main/docs/adr/0014-vex-policy-for-heritage-application-images.md)).

### 3. CPython 2.7 itself (CVE-LOG.md — grype-blind)

CPython is **invisible to grype** in this image because it is built
from source and installed without registering with `dpkg` (see
[Dependencies → The grype blind spot](../dependencies/)). A grype
scan reports zero findings against the interpreter — that is a
property of the scanner's input, not a property of the image's
risk surface.

The authoritative inventory lives at
[`common/images/python-2.7/patches/CVE-LOG.md`](https://github.com/wellmaintained/packages-dhi/blob/main/common/images/python-2.7/patches/CVE-LOG.md):
**24 CPython 2.7 CVEs** seeded from the NVD CVE API
(`cpe:2.3:a:python:python:2.7`, `publishedDate >= 2020-01-01`),
each starting at `under_investigation` and moving through the
OpenVEX status vocabulary as triage proceeds. That file is the
load-bearing record for the runtime layer's CVE posture. The
published `python-2.7.vex.json` mirrors the analysed subset.

### What the rendered matrix does

Once the matrix shortcode lands, it composes all three sources
into one CVE × container view: one row per CVE, one column per
image, status drawn from VEX where present, falling back to grype's
finding (for dpkg-visible layers) or to the CVE-LOG (for the
source-built CPython layer). A single "33 findings" headline
number does not appear anywhere — that figure would obscure the
attribution story this release is built to demonstrate.

### Two application-layer columns: 1.3.x vs 2.0.x

The matrix now carries one column per application-layer image —
both `senaite-lims` (the 2.0.x line, on Plone 5.2.4 / Zope 4) and
`senaite-lims-1.3` (the 1.3.x line, on Plone 4.3.20 / Zope 2.13.30).
The container list is data-derived from the release manifest, so
the column set tracks `apps/senaite/app-images.yaml` automatically;
both images appear without further matrix edits.

The two columns are not equivalent. A snapshot grype run surfaces
substantially more findings against 1.3.x — roughly **371 vs 174**
at the time of writing — because Plone 4.3 / Zope 2.13 / the
SENAITE 1.3.5 transitive graph predates the 2.0.x graph by several
years against today's CVE feed. The headline isn't "1.3.x is more
vulnerable." It is the literal cost of supporting customers who
haven't taken the Plone-4-to-5 jump yet, paid by us in VEX-authoring
hours per release rather than by the operator in a forced upgrade.

Each line is analysed against the same heritage VEX policy below.
The bulk of the 1.3.x corpus authoring lands as part of the
`senaite-lims-1.3-vex-policy` yak (≈277 statements against the
snapshot grype findings); the 2.0.x corpus is already populated
with the 174-statement initial pass. As both corpuses fill in, the
matrix's "WAIT" cells convert to specific `not_affected`
justifications or `affected` tracking issues.

## Heritage VEX policy

This release follows [ADR-0014](https://github.com/wellmaintained/packages-dhi/blob/main/docs/adr/0014-vex-policy-for-heritage-application-images.md),
which applies the framework established in
[ADR-0009](https://github.com/wellmaintained/packages-dhi/blob/main/docs/adr/0009-publish-vex-not-point-in-time-cves.md)
to heritage application images. The relevant addenda for senaite:

- **`not_affected` requires deployment-context-specific reasoning.**
  Boilerplate justifications ("internal only", "not exposed") fail
  review. Each statement names the configuration fact the
  justification depends on, so the VEX is falsifiable.
- **Heritage-runtime feature-absence is a first-class justification.**
  CVEs filed against features that don't exist in Python 2.7
  (e.g. asyncio, f-strings, walrus operator) are marked
  `vulnerable_code_not_present` with the absent feature named
  explicitly.
- **Principal-level review before publication.** Author and
  reviewer must be different engineers — same separation rule as
  patches under [ADR-0013](https://github.com/wellmaintained/packages-dhi/blob/main/docs/adr/0013-patch-backport-policy-for-eol-runtimes.md).

## VEX matrix

{{< vex-matrix >}}

The CVE × container matrix above renders the OpenVEX statements
extracted from each image's `vex.json` artifact. The container list
adapts to whichever images this release actually ships — both the
2.0.x and 1.3.x application images appear as columns when their
build artefacts are present. Until the senaite VEX authoring
corpuses are fully established, this table renders mostly the
"WAIT" / empty state; initial statements are landing per release
line as part of the corresponding policy yaks.

## Re-scanning live

Per ADR-0009, this release publishes only OpenVEX as compliance
documentation about vulnerabilities. Consumers who want a live CVE
view re-scan the shipped SBOM with VEX suppressions applied:

```bash
grype sbom:senaite-lims.cdx.json --vex senaite-lims.vex.json
```

Grype consumes OpenVEX natively, so the consumer's "what's
vulnerable now" list reflects today's vulnerability database minus
our durable analysis.
