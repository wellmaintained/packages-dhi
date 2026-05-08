# 0014. VEX Policy for Heritage Application Images

Date: 2026-05-03

## Status

proposed

## Context

ADR-0009 establishes the project's general VEX policy: publish
OpenVEX as durable analysis, exclude point-in-time CVE lists from
the compliance pack, let consumers re-scan the SBOM with VEX
suppressions applied. That ADR is framed for the catalogue of
current images (postgres, redis, sbomify-app, minio, ...). It does
not address a population that the heritage demo introduces:
**application images stacked on EOL runtimes**, where the CVE
volume per image is structurally larger and the VEX-authoring
discipline determines whether the demo's compliance claim is
credible or empty.

A heritage application image (e.g. `senaite-lims` on Python 2.7)
sees a different VEX surface than a current image:

- **Volume.** Python 2.7 alone has accumulated more CVEs since
  2020-01-01 than the rest of this repo's stock images combined.
  Plone 5.2 has its own backlog. Most of these CVEs do not apply
  to the heritage deployment as configured, but each one needs a
  *named* reason rather than a default.
- **Justification difficulty.** Many of the CVEs that don't apply
  don't apply *because* of how the senaite stack is composed —
  Caddy strips a header before it reaches Plone, the gunicorn
  worker doesn't expose a particular code path, the SQL backend
  isn't reachable from the user-facing process. These are
  deployment-specific, not runtime-specific. A boilerplate
  `vulnerable_code_not_in_execute_path` with no narrative is
  meaningless.
- **Audit stakes.** The heritage image is the demo's central
  exhibit. If a consumer audits the VEX and finds rote
  justifications, the entire compliance argument collapses. A
  single weak `not_affected` undermines every other statement on
  the same image.
- **Patch–VEX interplay.** Because the runtime has a patch series
  (per ADR-0011, governed by ADR-0013), a CVE may be addressed by
  a patch *or* a VEX statement *or* (briefly, during a triage
  cycle) under_investigation in both. The application-image VEX
  must stay aligned with the runtime image's patch decisions.

ADR-0009 already says the right things; it does not say them with
the specificity a heritage stack needs. This ADR **applies the
framework established in ADR-0009 to senaite-specific (and future
heritage) application images**. It does not supersede 0009. It does
not change 0009's pack-exclusion rules, OS-component injection,
re-scan command, or any other ADR-0009 commitment.

## Decision

**Apply the ADR-0009 VEX framework to heritage application images,
with the following heritage-specific addenda.** Each addendum is a
constraint on top of 0009, not a replacement.

### Status vocabulary (unchanged from ADR-0009)

OpenVEX v0.2.0 statuses:

- `under_investigation` — analysis pending.
- `not_affected` — analysis complete; CVE does not apply.
- `affected` — vulnerable; consumer-visible risk.
- `fixed` — addressed by a patch (typically referenced in the
  runtime image's CVE-LOG, per ADR-0013).

### Required justifications for `not_affected`

Every `not_affected` statement MUST set one of OpenVEX's standard
justifications:

- `component_not_present`
- `vulnerable_code_not_present`
- `vulnerable_code_not_in_execute_path`
- `vulnerable_code_cannot_be_controlled_by_adversary`
- `inline_mitigations_already_exist`

A `not_affected` without a justification fails review. (OpenVEX
treats it as a schema error; we treat it as a review gate.)

### Deployment-context-specific reasoning required

`status_notes` on every `not_affected` and `affected` statement
MUST give reasoning that names the deployment-context-specific
reason the justification holds. Examples of acceptable narrative:

> The senaite stack runs Plone behind Caddy (per the version-line
> compose at `apps/senaite-current/deployments/docker-compose.yml`).
> Caddy strips the
> `X-Forwarded-Host` header before the request reaches gunicorn,
> so the redirect-confusion path described in CVE-2024-XXXX is not
> reachable. If Caddy is removed from the deployment, this VEX
> statement no longer applies.

Examples that fail review:

> Mitigated by network policy.
> Not in execute path.
> Internal only.
> Not exposed.

The fail patterns share two properties: they could be true of
*any* image without modification, and they do not name what would
falsify the claim. The required form names the configuration the
reasoning depends on, so a future operator changing that
configuration knows the VEX is no longer load-bearing.

### Heritage runtime feature-absence is a first-class justification

For CVEs filed against a feature that does not exist in the
heritage runtime (e.g. `asyncio` did not exist in Python 2.7), the
correct justification is `vulnerable_code_not_present` — and the
`status_notes` MUST say so:

> CVE-2024-XXXX is filed against `asyncio.tls`. The asyncio module
> was introduced in Python 3.4; it does not exist in CPython 2.7.18.
> Verified absent from `/opt/python-2.7/lib/python2.7/`.

This is the heritage demo's most common justification pattern, and
the one most prone to terse "not applicable" hand-waves. The
verbosity rule applies here, *especially* here.

### Principal-level review before publication

Every `not_affected` and `affected` statement MUST be reviewed by a
**wellmaintained principal** (or designated principal-level
reviewer) before publication. Author and reviewer MUST be different
engineers — same separation rule as patches under ADR-0013. The
review focuses on whether `status_notes` names a falsifiable
deployment fact, not on free-form prose quality.

`under_investigation` statements may be authored without principal
review, on the understanding that they ship as honest
"analysis-pending" markers and must not be left in that state
beyond a triage window.

### Cross-image consistency

A CVE filed against the python-2.7 layer may surface in *every*
heritage application image's grype output (because every such image
inherits the runtime). The VEX policy:

- The **runtime image** (`python-2.7`) carries the canonical
  analysis for runtime-layer CVEs in `python-2.7.vex.json`.
- The **application image** (`senaite-lims`) carries
  application-specific analysis in `senaite-lims.vex.json` —
  including CVEs that fall through the runtime layer because of
  the way the application uses (or does not use) it.
- Duplication is acceptable when the application's deployment
  context changes the analysis (e.g. Caddy in front, sandbox
  configuration). Pure copy-paste is not — if the application's
  reasoning is identical to the runtime's, the runtime VEX is
  sufficient.
- Once base-image VEX pull-through ships (ADR-0009 future
  considerations), this duplication minimises automatically.

### Relation to other ADRs

- **ADR-0009 (Publish VEX, not point-in-time CVEs)** — this ADR
  *applies* the framework established in 0009 to senaite-specific
  application images. It does **not** supersede 0009. All of 0009's
  commitments (publish-only-VEX, OS-component injection, the
  `grype --vex` re-scan command, `cves.json` excluded from the
  compliance pack) hold unchanged. This ADR adds heritage-specific
  authoring constraints; the substrate is unchanged.
- **ADR-0011 (Build Python 2.7 from canonical sources)** —
  establishes the heritage runtime that this VEX policy governs at
  the application layer.
- **ADR-0013 (Patch backport policy)** — patches and VEX are
  alternative suppressions of the same CVE; this ADR's
  cross-image-consistency rules tie into 0013's patch–VEX coupling.

## Consequences

### Benefits

- **The `not_affected` claim is auditable.** A reviewer reading a
  heritage VEX statement can check, from the deployment files
  alone, whether the deployment-context fact named in
  `status_notes` is true. The VEX is *falsifiable*.
- **The demo's compliance argument scales with the CVE backlog.**
  As new Python 2.7 CVEs surface against the runtime, the same
  authoring discipline produces statements that hold up. The
  policy does not bend as volume grows.
- **Consumer expectations are stable.** A consumer pulling the
  release one year, two years, or five years from now sees the
  same VEX shape — durable, justified, principal-reviewed.
- **Failed-review patterns are concrete.** The "fails review"
  examples above are precise enough to use as a checklist; a
  reviewer doesn't need to invent a heuristic on the spot.

### Trade-offs

- **Authoring cost.** A deployment-context-specific
  `status_notes` field takes longer to write than a one-liner.
  For a heritage stack with hundreds of runtime CVEs, this is a
  real and ongoing cost. We accept it as the price of the
  compliance argument; we do not accept boilerplate as a
  shortcut.
- **Principal-review bottleneck.** A small principal pool
  reviewing a large CVE backlog is a queueing system. The
  expectation is that `under_investigation` is *visible* in the
  matrix during the queue — that's the ADR-0009 design — not that
  the queue is invisible to consumers. If the queue grows
  pathologically, that's a staffing signal, not a policy bug.
- **Cross-image VEX duplication until pull-through.** Until
  base-image VEX pull-through (ADR-0009 future considerations)
  ships, runtime-level analyses get repeated in application-image
  VEX where the application has its own deployment-context
  reasoning. This is duplication-by-honesty rather than
  duplication-by-laziness, but it is duplication.

### Future considerations

- **VEX-authoring tooling.** ADR-0009 already tracks a "design VEX
  authoring workflow" yak. The heritage volume strengthens the
  case: a CLI or SaaS plugin that surfaces CVE-by-CVE prompts,
  pre-populates the `vulnerable_code_not_present` justification
  when the runtime feature is absent, and enforces the
  principal-review gate would scale this policy to the throughput
  the demo will need.
- **Linting `status_notes` for boilerplate.** A static check that
  flags `status_notes` containing only the failed-review patterns
  ("not exposed", "internal only") could pre-empt many review
  rejections. Worth a follow-up yak once the first heritage VEX
  corpus exists.
- **Per-image principal designation.** The principal-review
  requirement is global today. As the heritage portfolio grows, a
  per-image principal-of-record (recorded in image annotations or
  a separate ownership manifest) may become useful. Out of scope
  until there is a second heritage stack to differentiate.
- **Re-evaluation when SENAITE 2.0.0's community line ages out.**
  This policy is calibrated for an active heritage demo with a
  recognisable upstream. If SENAITE 2.0.0 itself is forgotten by
  its community, the deployment-context arguments may need to
  shift toward "this stack is preserved as-is for migration,
  here's the CVE landscape we accept" — a different framing that
  this ADR does not currently cover.
