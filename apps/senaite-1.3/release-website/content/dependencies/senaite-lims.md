---
title: "senaite-lims"
description: "Software Bill of Materials for the senaite-lims 1.3.5 heritage application image (Plone 4.3.20 / Zope 2.13.30)."
---

{{< sbom-image-meta image="senaite-lims" >}}

## About this image

SENAITE 1.3.5 + Plone 4.3.20 + Zope 2.13.30 + their pinned
dependency tree, running on the wellmaintained python-2.7 runtime
image. This is the deeper-cliff release line — the one
migration-blocked operators are still running in production because
the jump to a more recent SENAITE already required moving to Plone
5.2 and Zope 4 / WSGI, which is a non-trivial migration in its own
right.

The image definition lives at
`apps/senaite-1.3/images/senaite-lims/prod.yaml`; the manifest entry
at `apps/senaite-1.3/app-images.yaml` references this path.

### The 1.3.x stack

| Layer            | Version / source                         |
|------------------|------------------------------------------|
| SENAITE          | senaite.lims 1.3.5 (`senaite.core.*` namespace) |
| Plone            | Plone 4.3.20                             |
| Zope             | Zope 2.13.30 — classic ZServer (no WSGI) |
| Buildout recipe  | plone.recipe.zope2instance 4.4.1         |
| Python           | CPython 2.7.18 (shared base)             |
| Runtime base     | wellmaintained python-2.7 image          |

The 1.3.x line uses an older transitive dependency graph (Chameleon
3.9.1, z3c.pt 3.3.1, WeasyPrint 0.42.3, …) and a broader CVE surface
area — the consequence of a longer interval between SENAITE 1.3.5's
release and today's CVE feed. The reward for that surface area is
direct: operators stuck on 1.3.x can upgrade their *runtime* without
first upgrading their *application*.

### Layer attribution

This image inherits the python-2.7 + debian13 layers from the
[base image](../python-2.7/) — same provenance, same patch
cadence, same source-build-vs-dpkg-visibility story. What this
image *adds* on top is the application stack:

| Layer (this image only)            | Owner             | Patch cadence                | Evidence                                                                       |
|------------------------------------|-------------------|------------------------------|--------------------------------------------------------------------------------|
| Plone 4.3.20                       | upstream pinned   | upstream (no patches today)  | `senaite-lims.vex.json`, `app-images.lock.yaml`                                |
| Zope 2.13.30 + ZTK 1.0.8           | upstream pinned   | upstream (no patches today)  | `senaite-lims.vex.json`                                                        |
| SENAITE 1.3.5 + sibling addons     | upstream pinned   | upstream (no patches today)  | `senaite-lims.vex.json`                                                        |
| Pre-pip site-packages overlay      | wellmaintained    | wellmaintained (build-time)  | `apps/senaite-1.3/images/senaite-lims/prod.yaml` (the `--target` install list) |

The pre-pip overlay is the line in the build that does the actual
heritage work for 1.3.x. Plone 4.3.20's `versions.cfg` pins fewer
transitives than later Plone releases, so buildout's `easy_install`
reaches for the latest version of Chameleon, z3c.pt, dicttoxml,
z3c.jbot, and several others — all of which dropped Python 2 support
after the 1.3.5 release window. The build pre-installs Py2-compatible
versions into the runtime site-packages with `pip --no-deps`, so
buildout finds them already present and skips its own materialisation.
The decision rationale and per-package list are inline in `prod.yaml`.

### Vulnerability posture

The composition of three vulnerability sources documented in the
[python-2.7 page](../python-2.7/#three-vulnerability-sources-not-one)
applies unchanged: debian13 system libraries are dpkg-visible to
grype; CPython 2.7 is grype-blind and tracked in
[`CVE-LOG.md`](https://github.com/wellmaintained/packages-dhi/blob/main/common/images/python-2.7/patches/CVE-LOG.md);
the application layer is grype-visible against the SBOM's pypi purls.

A snapshot grype run against the senaite-lims image surfaces roughly
**371 findings** in the application layer at the time of writing.
Each finding is a candidate for a `not_affected` VEX statement (with
deployment-context reasoning) or an `affected` statement (with a
tracking issue) per the [heritage VEX policy](../../vulnerabilities/#heritage-vex-policy).

### VEX corpus

The VEX file lives at
`apps/senaite-1.3/images/senaite-lims/senaite-lims.vex.json`
and follows the OpenVEX 0.2.0 contract. The same statuses,
justifications, and deployment-context-reasoning requirements
documented in
[`apps/senaite-1.3/VEX-POLICY.md`](https://github.com/wellmaintained/packages-dhi/blob/main/apps/senaite-1.3/VEX-POLICY.md)
apply unchanged. `under_investigation` remains the honest default;
boilerplate justifications fail review.

## Component Tree

{{< sbom-tree-viewer image="senaite-lims" >}}

The component tree renders above once the senaite-lims image
build attestation is available; the tree-viewer reads the SBOM JSON
copied into `static/artifacts/sboms/` by the release-data extractor.
