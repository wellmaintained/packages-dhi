---
title: "senaite"
description: "SENAITE LIMS — two heritage release lines (1.3.x and 2.0.x) on Python 2.7, distributed with full SBOM, VEX, and patch provenance."
layout: hextra-home
---

<div style="margin-top: 2rem; margin-bottom: 1.5rem;">
{{< hextra/hero-headline >}}
  senaite · DHI heritage
{{< /hextra/hero-headline >}}
</div>

<div style="margin-bottom: 1rem;">
{{< hextra/hero-subtitle >}}
  An open-source LIMS that looks like the SENAITE you know.
  The runtime underneath has been off the cliff since 2020.
{{< /hextra/hero-subtitle >}}
</div>

<div style="text-align: center; opacity: 0.6; font-size: 0.9rem; margin-bottom: 2rem;">
  This is a <a href="https://github.com/wellmaintained/packages-dhi">wellmaintained/packages-dhi</a> distribution built on <a href="https://www.docker.com/products/hardened-images/">Docker Hardened Images</a>.
</div>

## The heritage cliff

SENAITE 2.0.0 shipped in September 2020 on Plone 5.2, which runs on
Python 2.7. Python 2.7 reached upstream end-of-life on **2020-01-01**
— eight months *before* SENAITE 2.0.0 was released, six years before
this distribution.

In practical terms that means:

- **CPython 2.7 is unmaintained upstream.** No new security releases
  from python.org since 2.7.18 in April 2020.
- **Plone 5.2 is in extended support.** Active community has moved
  to Plone 6 / Python 3 (SENAITE 2.5.x).
- **A current operator running SENAITE 2.0.x** is on a stack the
  rest of the world has stopped patching.

This distribution exists to demonstrate that "stopped patching" and
"can't be distributed compliantly" are different statements. The
runtime is heritage; the supply-chain artifacts are current.

## Two heritage release lines

Operators who haven't migrated to SENAITE 2.0.x are not all on the
same cliff. Two release lines ship from this distribution, both on
the same wellmaintained Python 2.7 base:

| Release line | SENAITE  | Plone     | Zope            | For operators who…                                                                  |
|--------------|----------|-----------|-----------------|-------------------------------------------------------------------------------------|
| 2.0.x        | 2.0.0    | 5.2.4     | 4 (WSGI)        | took the Plone 5 / Zope 4 jump but stopped before Plone 6 / Python 3                |
| 1.3.x        | 1.3.5    | 4.3.20    | 2.13.30 (ZServer) | are still running the pre-Plone-5 stack — the migration to 2.0.x was already non-trivial |

Both lines are first-class citizens here. The 2.0.x line is the
modernization path; the 1.3.x line covers the migration-blocked
estate. The wellmaintained pitch is that we support **both**
indefinitely — a customer running SENAITE 1.3.5 in production today
can stay on a maintained supply chain without first being forced
through a Plone-major-version migration.

The 1.3.x line sits *deeper* on the cliff (older Plone, older
Zope, older transitive dependency graph, broader CVE surface) and
the per-image pages in [Dependencies](dependencies/) make the delta
explicit. The cost of customer-survival inertia is visible —
roughly **371 grype findings against 1.3.x vs 174 against 2.0.x** at
the time of writing — and is paid by us in VEX-authoring time, not
by the operator in a forced upgrade.

## What wellmaintained adds

| Layer                                              | Owner          | What changed                                                                       |
|----------------------------------------------------|----------------|------------------------------------------------------------------------------------|
| debian13 rootfs + system libraries                 | DHI            | Hardened, attested, SBOM + VEX from DHI                                            |
| CPython 2.7.18 + patch series                      | wellmaintained | Built from canonical sources, CVE patches                                          |
| Plone 5.2.4 + SENAITE 2.0.0 (2.0.x line)           | upstream       | Pinned versions, packaged into the `senaite-lims` image                            |
| Plone 4.3.20 + Zope 2.13.30 + SENAITE 1.3.5 (1.3.x line) | upstream | Pinned versions + Py2-compatible transitive overlay, packaged into the `senaite-lims-1.3` image |
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

The **upstream** rows are the application code itself, in two
release lines. We pin specific SENAITE / Plone / Zope versions per
line and do not patch them today; if a CVE forces patching the
application layer, the same patch policy applies. The 1.3.x line
also carries a Py2-compatible transitive overlay (Chameleon, z3c.pt,
WeasyPrint, …) installed at build time — see
[dependencies/senaite-lims-1.3](dependencies/senaite-lims-1.3/) for
the rationale.

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
