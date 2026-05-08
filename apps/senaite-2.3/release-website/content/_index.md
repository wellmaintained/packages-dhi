---
title: "senaite-2.3"
description: "SENAITE LIMS 2.3.0 on Plone 5.2.9 / Python 2.7 — heritage LIMS distributed with full SBOM, VEX, and patch provenance."
layout: hextra-home
---

<div style="margin-top: 2rem; margin-bottom: 1.5rem;">
{{< hextra/hero-headline >}}
  senaite-2.3 · DHI
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

## The 2.3.x line

SENAITE 2.3.0 shipped in October 2022 on Plone 5.2.9, which runs on
Python 2.7. Python 2.7 reached upstream end-of-life on **2020-01-01**,
nearly three years before SENAITE 2.3.0 was released and over six
years before this distribution.

In practical terms that means:

- **CPython 2.7 is unmaintained upstream.** No new security releases
  from python.org since 2.7.18 in April 2020.
- **Plone 5.2 is in extended support.** Active community has moved
  to Plone 6 / Python 3 (SENAITE 2.5+).
- **A current operator running SENAITE 2.3.x** is on a stack the
  rest of the world has stopped patching.

This distribution exists to demonstrate that "stopped patching" and
"can't be distributed compliantly" are different statements. The
runtime is heritage; the supply-chain artifacts are current.

## Why 2.3.x

`senaite-2.3` is the per-version-line snapshot of the most recent
2.x point that remains 2.7-friendly. It exists alongside
[`senaite-1.3`](https://wellmaintained.github.io/packages-dhi/senaite-1.3/)
(the deeper-cliff line, Plone 4.3 / Zope 2.13) and
[`senaite-current`](https://wellmaintained.github.io/packages-dhi/senaite-current/)
(the sliding pointer to the latest recommended line).

Per [ADR-0015](https://github.com/wellmaintained/packages-dhi/blob/main/docs/adr/0015-version-line-app-naming-with-current-sliding-pointer.md),
each version-line is a separate app — one image-stream, one
compliance pack, one VEX file, one declaration of conformity. A
revalidated lab on 2.3.x stays on a maintained supply chain
without being forced through a Plone-major-version migration.

## What wellmaintained adds

| Layer                                              | Owner          | What changed                                                                       |
|----------------------------------------------------|----------------|------------------------------------------------------------------------------------|
| debian13 rootfs + system libraries                 | DHI            | Hardened, attested, SBOM + VEX from DHI                                            |
| CPython 2.7.18 + patch series                      | wellmaintained | Built from canonical sources, CVE patches                                          |
| Plone 5.2.9 + SENAITE 2.3.0                        | upstream       | Pinned versions + Py2-compatible transitive overlay, packaged into the `senaite-lims` image |
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
SENAITE / Plone versions and do not patch them today; if a CVE forces
patching the application layer, the same patch policy applies. The
2.3.x line carries a Py2-compatible transitive overlay (magnitude,
Pyphen, et_xmlfile, openpyxl, requests stack, …) installed at build
time — see [dependencies/senaite-lims](dependencies/senaite-lims/)
for the rationale.

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
