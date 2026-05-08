---
title: "Quickstart"
description: "Deploy this release and download the compliance audit pack."
weight: 0
sidebar:
  open: true
---

## Deploy

{{< quickstart-deploy >}}

In the meantime, individual images are buildable with:

```
APP=senaite-1.3 just ci build python-2.7
APP=senaite-1.3 just ci build senaite-lims
```

The full local-deployment composition lives at
`apps/senaite-1.3/deployments/`. Bring it up with:

```
APP=senaite-1.3 just app-up
```

## Audit Pack

{{< quickstart-audit-pack >}}

The compliance pack for this release will include, per image:

- CycloneDX SBOM (`<image>.cdx.json`)
- SPDX SBOM (`<image>.spdx.json`)
- SLSA provenance (`provenance.slsa.json`)
- OpenVEX (`<image>.vex.json`) — wellmaintained-authored for custom
  images; DHI-supplied for stock images (named `vex.dhi.json`)
- Secrets scan (`secrets.json`)

Following [ADR-0009](https://github.com/wellmaintained/packages-dhi/blob/main/docs/adr/0009-publish-vex-not-point-in-time-cves.md),
the pack does **not** include a point-in-time `cves.json`. Consumers
who want a live vulnerability view re-scan the SBOM with VEX
suppressions applied:

```bash
grype sbom:senaite-lims.cdx.json --vex senaite-lims.vex.json
```

## Previous Releases

Historical releases and compliance bundles are available at
[GitHub Releases](https://github.com/wellmaintained/packages-dhi/releases).
