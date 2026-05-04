---
title: "Quickstart"
description: "Deploy this release and download the compliance audit pack."
weight: 0
sidebar:
  open: true
---

## Deploy

<!--
  TODO (Step 6 — senaite-local-deployment yak):
  Replace this block with a docker-compose.yml snippet and `docker compose up`
  walkthrough once the deployment files land at apps/senaite/deployments/.
  See apps/sbomify/release-website/layouts/shortcodes/quickstart-deploy.html
  for the precedent rendering pattern (uses the {{< quickstart-deploy >}}
  shortcode against generated data/).
-->

The local deployment is **not yet available** — it ships as part of
the senaite local-deployment yak (`senaite-local-deployment`). When
that lands, this page renders a `docker compose up` walkthrough plus
links to the compose file at `apps/senaite/deployments/`.

In the meantime, individual images are buildable with:

```
just ci build python-2.7
just ci build senaite-lims
```

## Audit Pack

<!--
  TODO (Step 5/8 — final pass):
  Once the senaite-lims image lands and the release-data extractor has
  been generalised to support per-app artifact bundles (see ADR-0005
  follow-up), this block renders a download link to the compliance pack
  ZIP and a manifest of its contents.
-->

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
