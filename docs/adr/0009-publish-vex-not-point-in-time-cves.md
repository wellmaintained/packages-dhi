# 0009. Publish VEX, Not Point-in-Time CVE Lists

Date: 2026-04-26

## Status

accepted

## Context

The release pipeline used to ship a grype-produced CVE list alongside the
SBOM in every release: `cves.json` per image, embedded in the compliance
pack, surfaced on the release-website as a per-image "what's vulnerable"
table.

That artifact has a structural problem: **a CVE list is true the instant
it's printed and wrong every minute after.** New CVEs are disclosed daily,
existing CVEs get re-scored, fixes ship, advisories are retracted —
independent of whether we ever rebuild or republish the image. Eight hours
after a release the list is already stale. Eight days later it is
misleading. Eight months later (a normal cadence for a stable release) it
is straightforwardly wrong about both what's vulnerable and what isn't.

Consumers who needed an accurate view at any given moment had to ignore
our published list and re-scan the SBOM themselves — meaning the published
list cost storage, attention, and trust, and bought nothing.

What does NOT go stale at the same rate is **our analysis** of which CVEs
matter for our images. When we say "OpenSSL CVE-2024-1234 doesn't apply
to postgres because the relevant code path isn't reachable in the way we
configure it" — that statement stays true for that image, that
configuration, that CVE, until the configuration changes. It's a
durable signal about a CVE the world will continue to talk about.

[OpenVEX](https://openvex.dev/) is the standard format for that kind of
analysis: per-CVE statements with a `status`
(`under_investigation` / `not_affected` / `affected` / `fixed`) plus a
`justification` (`vulnerable_code_not_present`,
`vulnerable_code_not_in_execute_path`, etc.) and free-form
`status_notes`. DHI ships OpenVEX for the stock images we consume; we
hand-author OpenVEX for our custom images.

## Decision

The release publishes **only OpenVEX** as compliance documentation about
vulnerabilities. The compliance pack ships, per image, the CycloneDX SBOM
and the `vex.json` — and nothing else CVE-related. The release-website
renders the published VEX as a CVE × container matrix showing only
the CVEs we have a statement for; everything else is blank by design.

Consumers who want a live CVE view re-scan the shipped SBOM with VEX
suppressions applied:

```
grype sbom:<image>.cdx.json --vex <image>.vex.json
```

Grype consumes OpenVEX natively and applies the suppressions, so the
consumer's "what's vulnerable now" list reflects today's vulnerability
database minus our durable analysis. We document this as the canonical
re-scan command on the website's Quickstart page.

### Grype still runs internally — for descriptions, not for publishing

The build pipeline still runs `grype sbom:<file>` after enrichment and
writes `artifacts/<image>/cves.json`, but that file is **not** included in
the compliance pack. It exists solely to hand short human-readable CVE
descriptions to the release-website's matrix Summary column. OpenVEX has
no `description` field and DHI's vendor VEX populates only
`vulnerability.name`, so without grype the matrix would show CVE IDs
with no plain-English context. Using the grype-generated description as
display copy doesn't reintroduce staleness because the description of
what `CVE-2024-1234` *is* changes on the order of years, not days.

### SBOMs need an operating-system component for grype to work

DHI's CycloneDX SBOMs encode distro information only as deb purl
qualifiers (`pkg:deb/debian/openssl@…?os_name=debian&os_version=13`).
Grype does not consult those qualifiers for distro detection — it looks
for a CycloneDX `type: operating-system` component. Without one,
`grype sbom:<file>` returns zero matches against a Debian rootfs.

`enrich-sbom.bash` therefore injects an `operating-system` component
synthesised from the deb purl qualifiers, after `sbomify-action`
enrichment. This makes the SBOM self-describing: both our internal
description-fetching grype run and the consumer's live re-scan work
without a `--distro` flag. (See ADR-0007 for the surrounding enrichment
flow; the OS-component injection sits inside that pipeline. A follow-up
moves the synthesis upstream into `sbomify-action` itself.)

### Custom images need hand-authored VEX

DHI ships VEX for every stock image. For our custom images
(`minio`, `sbomify-app`) we author `vex.json` ourselves, alongside the
image definition. An empty `statements: []` is valid OpenVEX and
represents the honest state ("we have not analysed any CVEs for this
image yet") — it does not silently claim no CVEs exist.

### Relation to other ADRs

- ADR-0002 (build once, promote via metadata) — VEX is part of the
  artifact set built once at PR time and promoted unchanged on release.
- ADR-0004 (unified build produces all compliance artifacts) — that
  ADR's step list still applies; "Run Grype CVE scan" stays in the
  pipeline, but its output now feeds enrichment, not the published
  pack. The pack-builder (`scripts/build-compliance-pack`) deliberately
  excludes `cves.json`.
- ADR-0007 (enrich SBOMs with sbomify-action) — the OS-component
  injection introduced here lives in the same `enrich-sbom.bash` step
  this ADR established.

## Consequences

### Benefits

- The compliance pack stops carrying a document that is wrong by
  design. Consumers who care about accuracy re-scan; consumers who just
  need to see our analysis read the VEX directly. Both paths give them
  something correct.
- The release-website matrix is a stable view — the only way for a row
  to change is for us to author or amend a VEX statement, which is an
  intentional editorial action with an audit trail in git history.
- A new VEX statement immediately suppresses its CVE in every
  consumer's local re-scan, without us having to republish.
- The matrix surfaces "open investigations" as a first-class signal —
  a `WAIT` pill telling the reader *we know about this CVE and are
  waiting on upstream*. That's information a CVE list has no way to
  express.

### Trade-offs

- We must own VEX authoring for our custom images. Until those
  `statements: []` arrays get populated, the matrix shows the custom
  images' columns as fully blank, which honestly represents "no
  analysis yet" but means consumers see no suppressions for those
  images and re-scans return their full grype output. A separate yak
  tracks authoring real VEX against the DHI-provided Go and Python
  purls.
- Consumers who want a one-glance "are there any criticals?" answer at
  release time have to run the re-scan command themselves. The
  Quickstart page documents it; the release notes call it out; but
  it's a step, not a glance.
- The matrix has an "Unknown" severity band for CVEs where neither
  Docker Scout nor grype provided a CVSS score (typically 2026 CVEs
  newer than the pinned grype DB, or pre-2015 CVEs aged out). Today
  this is a single CVE; over time the count will grow as the grype DB
  ages relative to long-lived stable releases.

### Future considerations

- VEX authoring workflow. The `design VEX authoring workflow` yak
  covers turning the manual yaml-edit-and-commit loop into something
  reviewer-friendly — possibly via the SaaS sbomify VEX plugin once it
  ships (sbomify/sbomify#778), possibly via a local CLI.
- Base-image VEX pull-through. Custom images currently see only their
  own hand-authored VEX. Threading the base image's `vex.dhi.json`
  into our custom-image artifact set at build time would let us
  inherit DHI's vendor analysis automatically — the same way our SBOMs
  already inherit DHI's package list.
- Alignment with sbomify's trust centre. The sbomify SaaS surfaces VEX
  per release; once the SaaS plugin lands we can publish to that
  surface alongside the static release-website, so consumers have both
  a self-hosted and a centralised view of the same VEX corpus.
- ADR for the matrix rendering itself. This ADR commits to publishing
  VEX as the data; a follow-up ADR may capture the specific UX
  decisions (CVE × container layout, severity bands, hover-for-notes)
  if they prove durable enough to warrant their own record.
