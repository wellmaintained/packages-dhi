---
title: "senaite (current)"
description: "SENAITE LIMS 2.6.0 — the current rolling line of the wellmaintained distribution. Plone 5.2.15 on Python 2.7, with full SBOM, VEX, and patch provenance."
layout: hextra-home
---

<div style="margin-top: 2rem; margin-bottom: 1.5rem;">
{{< hextra/hero-headline >}}
  senaite · DHI (current)
{{< /hextra/hero-headline >}}
</div>

<div style="margin-bottom: 1rem;">
{{< hextra/hero-subtitle >}}
  The rolling latest line of the wellmaintained SENAITE distribution.
  Tracks today's recommended upstream — pin to a numbered line for stability.
{{< /hextra/hero-subtitle >}}
</div>

<div style="text-align: center; opacity: 0.6; font-size: 0.9rem; margin-bottom: 2rem;">
  This is a <a href="https://github.com/wellmaintained/packages-dhi">wellmaintained/packages-dhi</a> distribution built on <a href="https://www.docker.com/products/hardened-images/">Docker Hardened Images</a>.
</div>

> **Heads-up.** `senaite-current` is the rolling latest line. The
> contents move forward as upstream ships releases that fire the
> [version-line criteria](https://github.com/wellmaintained/packages-dhi/blob/main/docs/research/version-line-criteria.md).
> Operators with revalidation cycles, GxP change-control, or any
> change-management process that forbids silent line transitions
> should pin to a numbered line — today that is `senaite-2.3` (heritage
> 2.x snapshot) or `senaite-1.3` (the pre-Plone-5 heritage cliff).

## What's in this image today

`senaite-current` currently packages **SENAITE LIMS 2.6.0** on
**Plone 5.2.15** running on **Python 2.7**. The 2.6 line is the last
SENAITE release that still targets Python 2.7 — `senaite.core` 2.6.0's
`setup.py` explicitly caps Pillow<7, openpyxl==2.6.4, tinycss2<1, and a
dozen other transitive deps with comments like *"X does not support
Python 2.x anymore"*. When the next SENAITE release ships against
Python 3 / Plone 6, this image will snapshot-rename to `senaite-2.6`
and a fresh `senaite-current` will spin up on the new line.

## The heritage cliff (still relevant)

SENAITE has been working on a Python 3 / Plone 6 migration for years;
the 2.6.x line is the final stop before that jump lands. In practical
terms today:

- **CPython 2.7 is unmaintained upstream.** No new security releases
  from python.org since 2.7.18 in April 2020.
- **Plone 5.2 is in extended support.** Active development has moved
  to Plone 6.
- **A current operator running SENAITE 2.6.x** is still on a Python
  2.7 stack the rest of the world has stopped patching.

This distribution exists to demonstrate that *"stopped patching
upstream"* and *"can't be distributed compliantly"* are different
statements. The runtime is heritage; the supply-chain artifacts are
current.

## What wellmaintained adds

| Layer                                                   | Owner          | What changed                                                            |
|---------------------------------------------------------|----------------|-------------------------------------------------------------------------|
| debian13 rootfs + system libraries                      | DHI            | Hardened, attested, SBOM + VEX from DHI                                 |
| CPython 2.7.18 + patch series                           | wellmaintained | Built from canonical sources, CVE patches                               |
| Plone 5.2.15 + SENAITE 2.6.0                            | upstream       | Pinned versions, packaged into the `senaite-lims-current` image         |
| Deployment composition                                  | wellmaintained | docker-compose, configuration, secrets                                  |

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
SENAITE / Plone versions per line and do not patch them today; if a
CVE forces patching the application layer, the same patch policy
applies.

## Other release lines

| Line             | senaite.lims | Plone   | Python | Audience                                                                  |
|------------------|--------------|---------|--------|----------------------------------------------------------------------------|
| **current**      | 2.6.0        | 5.2.15  | 2.7    | Operators tracking the latest recommended SENAITE line                    |
| senaite-2.3      | 2.3.0        | 5.2.x   | 2.7    | Pinned 2.x snapshot — change-managed environments that need a stable target |
| senaite-1.3      | 1.3.5        | 4.3.20  | 2.7    | Migration-blocked estate still on the pre-Plone-5 stack                   |

See the per-line distributions for the numbered snapshots.

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
