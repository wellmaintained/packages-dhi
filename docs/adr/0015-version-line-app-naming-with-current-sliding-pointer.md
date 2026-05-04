# 0015. Version-Line App Naming with -current Sliding Pointer

Date: 2026-05-04

## Status

proposed

## Context

The 2026-05-04 session surfaced two related observations.
Building a second heritage demo (SENAITE 1.3 alongside the
existing SENAITE 2.x work) made it clear that a single
`apps/senaite/` carrying two image variants conflated audiences
and made the per-image compliance pack ambiguous. And the
manifest had no convention for *which* version-lines deserve
their own deployable, nor for how an app's recommended line
evolves as upstream moves on.

The compliance frame is not optional. The CRA, the
OpenVEX/CycloneDX/SPDX/NTIA SBOM stack, and the revalidation
regimes our customers live under (ISO/IEC 17025, GxP) all want
per-version-line packaging with version as a primary identity
field. The evidence base is captured in
`docs/research/version-line-criteria.md`, which derives a
four-criteria decision rule and applies it to SENAITE (1.3 vs
2.x — all four fire) and sbomify (CalVer; year-jumps tested per
criterion). This ADR does not restate the brief; it converts the
brief's findings into an app-naming and lifecycle convention, and
closes the operational gap the brief leaves open: how the manifest
absorbs new fired-criteria releases without forcing every consumer
reference to change at the same time.

## Decision

### 1. Per-version apps with the version in the app name

Each parallel-supported version-line is a separate app with its
version baked into the directory and image names:
`apps/senaite-1.3/`, `apps/senaite-2.3/`, `apps/sbomify-26/`. One
app, one image-stream, one compliance pack, one VEX file, one
declaration of conformity. No unversioned apps; the prior
`sbomify` app lives at `apps/sbomify-current/` under this convention.

### 2. The `-current` sliding pointer

Every app gets a companion `<app>-current` deployable that always
references the latest recommended version-line. When upstream
ships a release that fires the criteria, today's `-current` is
snapshot-renamed to `<app>-<version>` and a new `-current` is
spun up against the new line (see Worked Example).

`-current` is the entry point for consumers who want "the
recommended line, tracking forward"; the explicit
`<app>-<version>` entries are the entry point for consumers who
must pin (revalidated labs, GxP customers, anyone whose
change-management process forbids silent line transitions).

### 3. Four-criteria decision rule for spawning a new app

Whether an upstream release warrants snapshotting `-current` is
decided by the four-criteria rule in
`docs/research/version-line-criteria.md`: a new app is spawned
when *any one* of (a) breaking ABI/API/runtime change, (b) the
upgrade fails the CRA Article 13(8) free-and-frictionless test,
(c) dependency closure shifts materially, or (d) customer
revalidation is triggered. Patches never trigger, majors almost
always do, minors are judged. The evidence is not duplicated
here — read the brief.

### 4. No umbrella site (deferred)

A cross-version "umbrella" landing page — the place where the
wellmaintained value pitch would live — is **not** introduced
now. We do not yet know what content it needs, and producing it
before a third version-line is on the table would invent
requirements rather than discover them. Defer until three
version-lines are live for the same app, or until a customer
explicitly asks for the cross-version view. Until then, the
narrative lives on some non-repo surface.

### 5. Naming granularity per project's natural cadence

Granularity follows the project, not a global rule:

- **SENAITE (SemVer):** `<app>-<major>.<minor>` (e.g.
  `senaite-1.3`, `senaite-2.3`). Plone version tracks the minor.
- **sbomify (CalVer, yearly):** `<app>-<year>` (e.g.
  `sbomify-26`). The calendar year is the support boundary.
- **Future apps:** pick the granularity at which the four-criteria
  rule actually fires. Document the choice in the app's README;
  do not retrofit a global convention.

### Relation to other ADRs

- **ADR-0010 (SENAITE 2.0.0 as Primary Heritage Demo Target)** —
  the *claim* (a Python 2.7 / Plone 5.2 stack can ship with a
  current compliance posture) is unchanged. The *target version*
  is refined: the demo becomes `apps/senaite-2.3/` (rebuilt
  against the latest 2.x line) plus a `apps/senaite-current/`
  pointer. A follow-up amend may be drafted once the restructure
  lands; the restructure itself is tracked separately and is out
  of scope here.

## Consequences

### Benefits

- Each app's audience gets focused content. Per-version SBOMs and
  VEX files are unambiguous — the format-native shape is what we
  ship.
- Version-lines evolve at independent cadences. SENAITE 1.3's
  patch cycle does not block a SENAITE 2.x minor.
- The `-current` pointer abstracts "latest recommended" away from
  version-baking. Track-forward consumers do not chase rename PRs;
  must-pin consumers have an explicit versioned target.
- Maps cleanly onto how Python.org, postgresql.org, Java LTS, and
  the major Linux distros structure parallel-supported releases.

### Trade-offs

- More apps to maintain. Two parallel-supported SENAITE lines
  plus `-current` is three directories where there used to be
  one. Structural separation has a price; we accept it because
  the alternative (compliance ambiguity) is worse.
- Common base images (e.g. `common/images/python-2.7/`) need an
  explicit policy for what stays shared versus what gets lifted.
- The snapshot procedure is operational discipline, not enforced
  by tooling. A release-time checklist — eventually a Justfile
  recipe — is the natural mitigation.
- The cross-version narrative loses its central place in the repo
  until the umbrella ships.

### Future considerations

- A `just snapshot-current <app>` recipe covering the rename,
  image-name rewrite, manifest update, and Justfile-default
  refresh.
- A manifest lint that every app is either `<app>-<version>` or a
  `-current`, with exactly one `-current` per family.
- VEX pull-through across version-lines that share a runtime
  layer remains structurally duplicative until ADR-0009's
  pull-through future-consideration ships.

## Worked Example

A hypothetical SENAITE 2.7 release that fires criterion 1 (Plone
6.0 — breaking runtime change).

**Starting state.** `apps/senaite-current/` tracks SENAITE 2.6.x
on Plone 5.2. `apps/senaite-1.3/` and `apps/senaite-2.3/` exist as
explicit snapshots for revalidated lab customers. The Justfile
default for `senaite-up` resolves to `-current`.

**Trigger.** Upstream ships SENAITE 2.7.0 on Plone 6.0. Criterion
1 fires; 2.7 warrants its own app.

**Procedure.**

1. **Snapshot today's `-current`.** Rename
   `apps/senaite-current/` → `apps/senaite-2.6/`; update the image
   name to `senaite-2.6`. The compliance pack, release website,
   VEX file, and deployment manifest now live under the explicit
   2.6 identity.
2. **Spin up the new `-current`.** Create `apps/senaite-current/`
   from a copy of `apps/senaite-2.6/` and rebase its image
   definition onto Plone 6.0 / SENAITE 2.7.
3. **Update Justfile defaults.** Repoint any hardcoded default-app
   recipe whose path no longer exists. With the parameterised
   `app-up`/`app-down` recipes from the multi-app generalisation
   work, this is usually a default-value change.
4. **Refresh manifest and release website.** Both `senaite-2.6`
   and `senaite-current` now appear in `apps/` listings, the image
   manifest, and the per-app release website tree.
   `senaite-2.6`'s site freezes at 2.6's narrative;
   `senaite-current`'s picks up the 2.7 story.

**Customer impact.** Consumers of `senaite-current` auto-track
to 2.7 on next pull — they opted in by choosing the sliding
pointer. Consumers pinned to `senaite-2.3` are unaffected.
Consumers who were on `senaite-current` while it pointed at 2.6
and who *don't* want to move to 2.7 retag to `senaite-2.6`; the
content they were already running is bit-identical to the
snapshotted build, so the rename is a manifest event, not a
rebuild. The procedure is reversible up until step 2's image push.

## References

- `docs/research/version-line-criteria.md` — research brief:
  CRA Article 13(8), the four-criteria rule, SBOM-format identity,
  OSS-project precedent.
- ADR-0010 — SENAITE 2.0.0 as primary heritage demo target. This
  ADR refines the *target version*; the claim is unchanged.
- Yak `session-2026-05-04-1146` — decision log (16:10
  separate-apps; 16:50 no-umbrella + per-project-cadence; 17:50
  `-current` sliding pointer).
