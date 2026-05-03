---
title: "Licenses"
description: "License notices, source availability, and compliance artifacts for third-party components in this release."
weight: 4
sidebar:
  open: true
---

This section fulfils our obligations as distributors of open source software
included in this release, following [OpenChain ISO/IEC 5230](https://openchainproject.org/license-compliance)
compliance artifact conventions.

| Section | Description |
|---------|-------------|
| [License Notices](license-notices/) | Copyright and license texts for all components |
| [Required Source Disclosure](source-availability/) | Source code links for components requiring disclosure |
| [Exceptions](exceptions/) | Components with unknown or unresolved licensing |

## License Summary

<!--
  TODO (Step 5/8): {{< license-summary-table >}}
  License summary will render here once release-data tooling is
  generalised per-app.
-->

The license-summary table will render here once release-data
tooling is generalised per-app and SBOM data is populated for the
senaite images.

The expected license mix:

- **CPython 2.7** — PSF-2.0
- **Plone 5.2 / SENAITE 2.0.0** — GPL-2.0 (Plone) + ZPL-2.1 (Zope) + various
- **Debian 13 system libraries** — mixed (most LGPL, BSD, MIT; a
  handful GPL — see source-availability)
- **nginx** — BSD-2-Clause
