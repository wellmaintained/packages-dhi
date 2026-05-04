---
title: "senaite-1.3"
description: "SENAITE LIMS 1.3.5 — heritage release line on Plone 4.3.20 / Zope 2.13.30 / Python 2.7, distributed with full SBOM, VEX, and patch provenance."
layout: hextra-home
---

<div style="margin-top: 2rem; margin-bottom: 1.5rem;">
{{< hextra/hero-headline >}}
  senaite-1.3 · DHI heritage
{{< /hextra/hero-headline >}}
</div>

<div style="margin-bottom: 1rem;">
{{< hextra/hero-subtitle >}}
  An open-source LIMS that looks like the SENAITE you know.
  The runtime underneath has been off the cliff since 2020,
  and this release line sits *deeper* on the cliff than the 2.x line.
{{< /hextra/hero-subtitle >}}
</div>

<div style="text-align: center; opacity: 0.6; font-size: 0.9rem; margin-bottom: 2rem;">
  This is a <a href="https://github.com/wellmaintained/packages-dhi">wellmaintained/packages-dhi</a> distribution built on <a href="https://www.docker.com/products/hardened-images/">Docker Hardened Images</a>.
</div>

## The heritage cliff

SENAITE 1.3.5 shipped on Plone 4.3.20 / Zope 2.13.30, which runs on
Python 2.7. Python 2.7 reached upstream end-of-life on **2020-01-01**
— SENAITE 1.3.5 was already several years in production at that point.

In practical terms that means:

- **CPython 2.7 is unmaintained upstream.** No new security releases
  from python.org since 2.7.18 in April 2020.
- **Plone 4.3 is past extended support.** Active community has moved
  to Plone 6 / Python 3.
- **Zope 2.13 / ZServer is a pre-WSGI runtime.** The migration to
  SENAITE 2.x already required moving to Plone 5.2 + Zope 4 / WSGI —
  a non-trivial migration in its own right, before the further jump
  to Plone 6 / Python 3.
- **A current operator running SENAITE 1.3.x** is on a stack the
  rest of the world has stopped patching.

This distribution exists to demonstrate that "stopped patching" and
"can't be distributed compliantly" are different statements. The
runtime is heritage; the supply-chain artifacts are current.

## Why a 1.3-specific release line

Operators stuck on SENAITE 1.3.x are not all on the same cliff as
operators on SENAITE 2.x. The 1.3.x line covers the migration-blocked
estate — customers for whom the jump to 2.x already meant moving from
Plone 4.3 → 5.2 and Zope 2.13 → Zope 4 / WSGI, and who haven't taken
that jump yet.

The wellmaintained pitch is that we support 1.3.x indefinitely — a
customer running SENAITE 1.3.5 in production today can stay on a
maintained supply chain without first being forced through a
Plone-major-version migration.

The 1.3.x line sits *deeper* on the cliff than the 2.x line: an older
Plone, an older Zope, an older transitive dependency graph, and a
broader CVE surface. Roughly **371 grype findings** land against the
1.3.x application layer at the time of writing — paid by us in
VEX-authoring time, not by the operator in a forced upgrade.

## What wellmaintained adds

| Layer                                              | Owner          | What changed                                                                       |
|----------------------------------------------------|----------------|------------------------------------------------------------------------------------|
| debian13 rootfs + system libraries                 | DHI            | Hardened, attested, SBOM + VEX from DHI                                            |
| CPython 2.7.18 + patch series                      | wellmaintained | Built from canonical sources, CVE patches                                          |
| Plone 4.3.20 + Zope 2.13.30 + SENAITE 1.3.5        | upstream       | Pinned versions + Py2-compatible transitive overlay, packaged into the `senaite-lims` image |
| Deployment composition                             | wellmaintained | docker-compose, configuration, secrets                                             |

The **wellmaintained** rows are the value-add. Every byte of CPython
in this image traces to either the upstream `v2.7.18` git tag or to
a patch in `common/images/python-2.7/patches/` with a named author,
named reviewer, and a CVE reference. See
[ADR-0011](https://github.com/wellmaintained/packages-dhi/blob/main/docs/adr/0011-build-python-2.7-from-canonical-sources.md)
and [ADR-0013](https://github.com/wellmaintained/packages-dhi/blob/main/docs/adr/0013-patch-backport-policy-for-eol-runtimes.md)
for the policy.

The **DHI** row is the rest of the operating environment — patched
on DHI's cadence, attested to DHI's standards. We do not maintain
debian13. See [ADR-0001](https://github.com/wellmaintained/packages-dhi/blob/main/docs/adr/0001-adopt-dhi-base-images.md).

The **upstream** row is the application code itself. We pin specific
SENAITE / Plone / Zope versions and do not patch them today; if a CVE
forces patching the application layer, the same patch policy applies.
The 1.3.x line carries a Py2-compatible transitive overlay (Chameleon,
z3c.pt, WeasyPrint, …) installed at build time — see
[dependencies/senaite-lims](dependencies/senaite-lims/) for the
rationale.

## Quick links

<div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 1rem; width: 100%; margin-bottom: 1rem;">

  <div style="border: 1px solid #e5e7eb; border-radius: 0.75rem; padding: 1rem 1.25rem;">
    <a href="quickstart/#deploy" style="text-decoration: none; color: inherit; font-weight: 700; white-space: nowrap;">🚀 Deploy</a>
    <br><span style="font-size: 0.8rem; opacity: 0.6;">docker-compose.yml</span>
  </div>

  <div style="border: 1px solid #e5e7eb; border-radius: 0.75rem; padding: 1rem 1.25rem;">
    <a href="quickstart/#audit-pack" style="text-decoration: none; color: inherit; font-weight: 700; white-space: nowrap;">📋 Audit Pack</a>
    <br><span style="font-size: 0.8rem; opacity: 0.6;">all compliance artifacts in one ZIP</span>
  </div>

</div>

<div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 1rem; width: 100%;">

  <div style="border: 1px solid #e5e7eb; border-radius: 0.75rem; padding: 1.25rem;">
    <div style="font-size: 1.1rem; font-weight: 700; margin-bottom: 0.5rem;"><a href="dependencies/" style="text-decoration: none; color: inherit; white-space: nowrap;">📦 Dependencies</a></div>
    <div style="font-size: 0.8rem; line-height: 1.7; opacity: 0.8;">
      DHI rootfs + heritage runtime + LIMS<br>
      CycloneDX SBOMs
    </div>
  </div>

  <div style="border: 1px solid #e5e7eb; border-radius: 0.75rem; padding: 1.25rem;">
    <div style="font-size: 1.1rem; font-weight: 700; margin-bottom: 0.5rem;"><a href="vulnerabilities/" style="text-decoration: none; color: inherit; white-space: nowrap;">🛡️ Vulnerabilities</a></div>
    <div style="font-size: 0.8rem; line-height: 1.7; opacity: 0.8;">
      OpenVEX per layer<br>
      Heritage-runtime triage
    </div>
  </div>

  <div style="border: 1px solid #e5e7eb; border-radius: 0.75rem; padding: 1.25rem;">
    <div style="font-size: 1.1rem; font-weight: 700; margin-bottom: 0.5rem;"><a href="licenses/" style="text-decoration: none; color: inherit; white-space: nowrap;">⚖️ Licenses</a></div>
    <div style="font-size: 0.8rem; line-height: 1.7; opacity: 0.8;">
      PSF-2.0, GPL, MIT, BSD<br>
      Source disclosure
    </div>
  </div>

  <div style="border: 1px solid #e5e7eb; border-radius: 0.75rem; padding: 1.25rem;">
    <div style="font-size: 1.1rem; font-weight: 700; margin-bottom: 0.5rem;"><a href="provenance/" style="text-decoration: none; color: inherit; white-space: nowrap;">🔍 Provenance</a></div>
    <div style="font-size: 0.8rem; line-height: 1.7; opacity: 0.8;">
      DHI + wellmaintained + upstream<br>
      Per-layer attribution
    </div>
  </div>

</div>
