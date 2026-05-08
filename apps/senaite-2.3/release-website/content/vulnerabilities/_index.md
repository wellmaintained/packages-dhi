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

### Application-layer column: senaite-lims (2.3.x)

The matrix carries one column per application-layer image — for this
release line, that is `senaite-lims` running SENAITE 2.3.0 on
Plone 5.2.9 / Zope 4. The container list is data-derived from
`apps/senaite-2.3/app-images.yaml`.

A snapshot grype run against the 2.3.x image surfaces application-layer
findings that originate in the heritage transitive graph (2.7-only pins
of magnitude / Pyphen / requests / urllib3 / certifi / idna / openpyxl
plus Plone 5.2's bundled JS resource registry). The headline isn't a
single number — the count is meaningful only relative to a peer line
(see the [`senaite-1.3`](https://wellmaintained.github.io/packages-dhi/senaite-1.3/)
site for the deeper-cliff comparison and
[`senaite-current`](https://wellmaintained.github.io/packages-dhi/senaite-current/)
for the latest recommended line).

Each version-line is analysed against the same heritage VEX policy
below; the 2.3.x VEX corpus is initially empty (`statements: []`) and
fills in across follow-up VEX-authoring yaks. Until each statement is
authored, matrix cells render as `under_investigation` rather than
silent passes.

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
extracted from each image's `vex.json` artifact. Until the 2.3.x VEX
authoring corpus is established (the initial skeleton ships with
`statements: []`), this table renders mostly the "WAIT" / empty
state; statements land in follow-up VEX-authoring yaks.

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
