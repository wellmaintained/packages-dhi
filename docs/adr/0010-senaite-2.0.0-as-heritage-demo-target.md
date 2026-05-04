# 0010. SENAITE 2.0.0 as Primary Heritage Demo Target

Date: 2026-05-03

## Status

proposed

## Context

The senaite work in this repo exists to demonstrate one specific claim:
**a Python 2.7 / Plone 5.2 stack — six years past upstream EOL — can be
distributed today with the same compliance posture (SBOMs, VEX, signed
attestations, patch provenance) that we apply to current images.** That
claim only lands if the demo target *looks* current to a casual reader
while *being* irretrievably heritage underneath. The choice of which
SENAITE release to target is the difference between a credible demo and
an obvious museum piece.

SENAITE is an actively-maintained Plone-based LIMS. The community has
shipped multiple major lines:

| Line   | Released | Plone | Python | Notes                                       |
|--------|----------|-------|--------|---------------------------------------------|
| 1.3.x  | 2018     | 4.3   | 2.7    | Last on Plone 4; reference deployments still exist |
| 2.0.0  | 2020-09  | 5.2   | 2.7    | First on Plone 5.2; visually indistinguishable from later 2.x lines |
| 2.5.0  | 2024     | 6.0   | 3.x    | First on Python 3                           |

The relevant cliff is Python 2.7's upstream EOL on **2020-01-01**. Plone
5.2 is the last Plone line that runs on Python 2; SENAITE 2.0.0 is the
first SENAITE line on Plone 5.2. So SENAITE 2.0.0 is the **last hop
before the language runtime falls off**, and it shipped *after* that
runtime had already lost upstream support.

Picking 2.5.0 would mean Python 3 — there is no heritage cliff to
demonstrate. Picking 1.3.x would mean Plone 4, an older theme, an older
admin UI — visibly old to anyone who has used a recent SENAITE. The
demo would read as "look at this old thing", not "look at this thing
that looks current".

2.0.0 hits the spot: the screens, navigation, and admin look like the
SENAITE a current operator knows. The runtime underneath is the cliff.

## Decision

**Adopt SENAITE 2.0.0 as the primary heritage demo target.** All
artifacts (image definitions, app manifest entry, release-website
content, ADR cross-references) treat 2.0.0 as the canonical version
unless explicitly scoped to a different line.

The image will be tagged `senaite-v2.0.0-<YYYYMMDD>.<N>` to match the
existing release-tag convention (sbomify uses
`sbomify-v26.1.0-20260426.2`). 2.0.0 is the SENAITE upstream version;
the date+sequence segment is our build identifier.

### Relation to other ADRs

- **ADR-0001 (Adopt DHI as Base Image Foundation)** — establishes the
  base-image model this demo extends. SENAITE 2.0.0 is a new app under
  that foundation; nothing in 0001 changes.

## Consequences

### Benefits

- The demo's central claim ("you think you're on current SENAITE; you
  are on six-years-EOL Python") is legible from the screenshot alone.
  No technical narration is needed to make the point land.
- 2.0.0 is the *last* SENAITE line on Python 2.7, which makes it the
  most relevant target — anyone still running a Python 2 stack today is
  on 2.0.x or earlier. Demonstrating compliance for 2.0.0 covers the
  population we expect to reach.
- Plone 5.2 is well-documented and the upstream tarball+egg layout is
  stable, which keeps the build reproducible from canonical sources
  (see ADR-0011).

### Trade-offs

- 2.0.0 is not the most recent SENAITE; consumers running 2.5.x get no
  direct demonstration here. They are also not on the cliff, so the
  compliance argument is conventional rather than load-bearing — but
  it does mean this demo doesn't double as a "current SENAITE" reference.
- The 2.0.0 tag is from 2020. We are building it in 2026, against
  patched dependencies and a current debian13 rootfs. Anyone expecting
  bit-identical reproduction of the 2020 release will not get it; what
  they get is the 2.0.0 application layer running on a current,
  attested base — which is the entire point.

### Future considerations

- **1.3.x as a secondary demo.** A follow-up yak may add SENAITE 1.3
  (Plone 4) as a secondary heritage line. The compliance machinery is
  the same; the visible cliff is older. Useful for demonstrating that
  even a deeper heritage stack can be brought into compliance, at the
  cost of a less "current-looking" UI.
- **2.5.x as a control.** If we ever need to A/B the heritage story
  against a current SENAITE on Python 3, building 2.5.x alongside
  would isolate the Python-runtime contribution to the compliance
  narrative. Out of scope until the heritage story is itself shipped.
- **When SENAITE 2.x reaches its own community EOL,** revisit this
  ADR. The "look current" argument depends on 2.x still being
  recognisable; once the active community moves entirely to 3.x or
  later major lines, 2.0.0 becomes visibly old and the demo loses its
  twist.
