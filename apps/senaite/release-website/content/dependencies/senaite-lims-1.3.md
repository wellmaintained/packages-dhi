---
title: "senaite-lims-1.3"
description: "Software Bill of Materials for the senaite-lims-1.3 heritage application image (Plone 4.3.20 / Zope 2.13.30 line)."
---

{{< sbom-image-meta image="senaite-lims-1.3" >}}

## About this image

SENAITE 1.3.5 + Plone 4.3.20 + Zope 2.13.30 + their pinned
dependency tree, running on the same wellmaintained python-2.7
runtime image as the [`senaite-lims`](../senaite-lims/) (2.0.x)
sibling. This is the deeper-cliff release line — the one
migration-blocked operators are still running in production because
the jump to 2.0.x already required moving to Plone 5.2 and Zope 4 /
WSGI, which is a non-trivial migration in its own right.

The image build is **not yet implemented** — it ships as part of
the `senaite-lims-1.3` image yak. The image definition lives at
`apps/senaite/images/senaite-lims-1.3/prod.yaml`; today the
manifest entry at `apps/senaite/app-images.yaml` references this
path as a forward declaration.

### How 1.3.x differs from 2.0.x

Both lines target the same use case (heritage SENAITE LIMS on a
maintained supply chain) and share the same python-2.7 base, but
the application stack diverges sharply:

| Layer            | senaite-lims-1.3 (this image)            | senaite-lims (2.0.x)                     |
|------------------|------------------------------------------|------------------------------------------|
| SENAITE          | senaite.lims 1.3.5 (`senaite.core.*` namespace) | senaite.lims 2.0.0 (`senaite.app.*` namespace) |
| Plone            | Plone 4.3.20                             | Plone 5.2.4                              |
| Zope             | Zope 2.13.30 — classic ZServer (no WSGI) | Zope 4 — WSGI                            |
| Buildout recipe  | plone.recipe.zope2instance 4.4.1         | plone.recipe.zope2instance 6.x           |
| Python           | CPython 2.7.18 (shared base)             | CPython 2.7.18 (shared base)             |
| Runtime base     | wellmaintained python-2.7 image          | wellmaintained python-2.7 image          |

The 1.3.x line is *deeper* on the heritage cliff: an older Plone
release, an older Zope release, an older transitive dependency
graph (Chameleon 3.9.1, z3c.pt 3.3.1, WeasyPrint 0.42.3, …), and a
broader CVE surface area — the consequence of a longer interval
between SENAITE 1.3.5's release and today's CVE feed. The reward
for that surface area is direct: operators stuck on 1.3.x can
upgrade their *runtime* without first upgrading their *application*.

### Layer attribution

This image inherits the python-2.7 + debian13 layers from the
[base image](../python-2.7/) — same provenance, same patch
cadence, same source-build-vs-dpkg-visibility story. What this
image *adds* on top is the application stack:

| Layer (this image only)            | Owner             | Patch cadence                | Evidence                                                                       |
|------------------------------------|-------------------|------------------------------|--------------------------------------------------------------------------------|
| Plone 4.3.20                       | upstream pinned   | upstream (no patches today)  | `senaite-lims-1.3.vex.json`, `app-images.lock.yaml`                            |
| Zope 2.13.30 + ZTK 1.0.8           | upstream pinned   | upstream (no patches today)  | `senaite-lims-1.3.vex.json`                                                    |
| SENAITE 1.3.5 + sibling addons     | upstream pinned   | upstream (no patches today)  | `senaite-lims-1.3.vex.json`                                                    |
| Pre-pip site-packages overlay      | wellmaintained    | wellmaintained (build-time)  | `apps/senaite/images/senaite-lims-1.3/prod.yaml` (the `--target` install list) |

The pre-pip overlay is the line in the build that does the actual
heritage work for 1.3.x. Plone 4.3.20's `versions.cfg` pins fewer
transitives than 5.2.4's, so buildout's `easy_install` reaches for
the latest version of Chameleon, z3c.pt, dicttoxml, z3c.jbot, and
several others — all of which dropped Python 2 support after the
1.3.5 release window. The build pre-installs Py2-compatible
versions into the runtime site-packages with `pip --no-deps`, so
buildout finds them already present and skips its own
materialisation. The decision rationale and per-package list are
inline in `prod.yaml`.

### Vulnerability posture (vs the 2.0.x sibling)

The composition of three vulnerability sources documented in the
[python-2.7 page](../python-2.7/#three-vulnerability-sources-not-one)
applies unchanged: debian13 system libraries are dpkg-visible to
grype; CPython 2.7 is grype-blind and tracked in
[`CVE-LOG.md`](https://github.com/wellmaintained/packages-dhi/blob/main/common/images/python-2.7/patches/CVE-LOG.md);
the application layer is grype-visible against the SBOM's pypi purls.

What changes for 1.3.x is the *application layer's* finding count.
A snapshot grype run against the senaite-lims-1.3 image surfaces
substantially more findings than the same scan against
senaite-lims (2.0.x) — roughly **371 vs 174** at the time of
writing. The delta is not a quality-of-build issue; it is the
literal cost of running an older Plone / Zope / addon graph
against today's CVE feed. Each additional finding is a candidate
for a `not_affected` VEX statement (with deployment-context
reasoning) or an `affected` statement (with a tracking issue) per
the [heritage VEX policy](../../vulnerabilities/#heritage-vex-policy).

### VEX corpus

The VEX file lives at
`apps/senaite/images/senaite-lims-1.3/senaite-lims-1.3.vex.json`
and follows the same OpenVEX 0.2.0 contract as the 2.0.x sibling.
Initial authoring (≈277 statements against the snapshot grype
findings) lands as part of the `senaite-lims-1.3-vex-policy` yak;
this image's VEX is the first point where the heritage VEX policy
gets applied to a stack with materially more application-layer
findings than the 2.0.x line.

The same statuses, justifications, and deployment-context-reasoning
requirements documented in
[`apps/senaite/VEX-POLICY.md`](https://github.com/wellmaintained/packages-dhi/blob/main/apps/senaite/VEX-POLICY.md)
apply unchanged. `under_investigation` remains the honest default;
boilerplate justifications fail review.

## Component Tree

{{< sbom-tree-viewer image="senaite-lims-1.3" >}}

The component tree renders above once the senaite-lims-1.3 image
build attestation is available; the tree-viewer reads the SBOM JSON
copied into `static/artifacts/sboms/` by the release-data extractor.
