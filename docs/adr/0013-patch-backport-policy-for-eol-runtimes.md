# 0013. Patch Backport Policy for EOL Runtimes

Date: 2026-05-03

## Status

proposed

## Context

ADR-0011 commits to building Python 2.7 from canonical sources plus
a wellmaintained patch series. That decision implies a patch process
but does not codify one. Without a written policy:

- A patch's provenance lives in the engineer's head (or worse, in
  Slack scrollback). Two years from now, *why* a particular fix is in
  the tree is no longer recoverable from the file alone.
- There is no enforced separation between "the engineer who backports
  the patch" and "the engineer who reviews it" — a common audit-trail
  weakness for small teams under time pressure.
- The relationship between a patch (which suppresses a CVE by fixing
  it) and a VEX statement (which suppresses a CVE by explaining it
  away) is implicit. A consumer reading the artifact can't easily
  tell whether `CVE-2024-XXXX` is fixed in our build or merely
  declared not_affected.
- A future EOL runtime (Ruby 2.x, Node 12, ...) under the same
  programme would need its own ad-hoc convention if there were no
  shared one to inherit.

The patch series scaffold yak (Step 2 of the senaite project) already
laid down the operational policy for the Python 2.7 patches in
`common/images/python-2.7/patches/README.md`. That file is precisely
the right shape, but its scope is "the Python 2.7 patches in this
directory". The policy is **broader** — it should apply to every EOL
runtime maintained under the wellmaintained programme.

This ADR promotes that operational document to a project-wide policy
ADR. It does not change the policy itself. The patches/README.md stays
where it is, as the runtime-specific instance; this ADR records the
*decision* that the policy applies generally.

## Decision

**Adopt the patch policy currently codified in
`common/images/python-2.7/patches/README.md` as the policy for any
EOL runtime maintained under the wellmaintained programme.**

The policy has six components. Each applies to every
`<runtime>/patches/` directory the programme manages.

### 1. Filename convention

```
NNNN-short-kebab-description.patch
```

`NNNN` is a 4-digit zero-padded sequence number. Sequence reflects
**apply order**, not authorship chronology. Description is a
kebab-case summary, ideally referencing the upstream CVE or fix
subject (e.g. `0001-cve-2023-24329-urlsplit-leading-whitespace.patch`).

### 2. Required patch header

Every `.patch` file MUST begin with:

```
From: <upstream commit author or wellmaintained engineer> <email>
Date: <date authored or backported, YYYY-MM-DD>
Subject: [PATCH] <one-line summary>

Upstream-CVE: CVE-YYYY-NNNNN          (or "none" if not CVE-driven)
Upstream-Fix: <URL to upstream commit, typically a 3.x backport>
Upstream-Bug: <URL to bpo / GH issue, if separate from Upstream-Fix>
Backported-By: <wellmaintained engineer name> <email>
Backported-Date: YYYY-MM-DD
Reviewed-By: <wellmaintained engineer name> <email>
Reviewed-Date: YYYY-MM-DD
Notes: <optional — non-trivial backport rationale, conflict resolution,
        scope changes vs upstream, follow-ups>

---
<unified diff against the runtime's pinned upstream tag>
```

The trailers are *project-specific* (not understood by `patch` or
`quilt` directly), but standard `From:`/`Subject:` lines pass through
unmodified by the apply tools. The trailers exist so that **the
patch file alone is sufficient to audit the patch's provenance** —
no out-of-band lookup, no ticketing-system scrollback.

### 3. Quilt-style series file

A `series` file in the patches directory lists patches in apply
order, one per line:

```
0001-cve-2023-24329-urlsplit-leading-whitespace.patch
0002-cve-2024-12345-some-other-fix.patch
# Comment lines start with '#' and are skipped.
```

The build pipeline applies them sequentially with `patch -p1` (or
`quilt push -a`) before invoking the runtime's configure/make.

### 4. Author–reviewer separation

A patch MUST have a `Backported-By` and a `Reviewed-By`, **and they
MUST be different engineers**. A single-engineer patch series is not
acceptable for a published heritage runtime; the policy fails closed.
This is a deliberate design decision — the demo's value rests on the
audit trail, and an audit trail without a second pair of eyes carries
no weight.

### 5. CVE-LOG.md as the patch-decision ledger

Each runtime's `patches/` directory carries a `CVE-LOG.md` file
listing every CVE the team has triaged for that runtime, with one of:

| Status                | Meaning                                                  |
|-----------------------|----------------------------------------------------------|
| `under_investigation` | We know about this CVE; analysis pending.                |
| `not_affected`        | Reachable analysis says this CVE doesn't apply. VEX statement records the justification. |
| `affected`            | Vulnerable; not yet patched. Consumer-visible risk.       |
| `fixed`               | A patch in `series` addresses the CVE. Linked from the log. |

Statuses follow the OpenVEX vocabulary (per ADR-0009) so the
`CVE-LOG.md` and the published `<image>.vex.json` stay aligned.

### 6. Coupling between patches and VEX

A patch and a VEX statement are alternative ways to suppress the
same CVE — fixing it vs. explaining why it doesn't apply. The
relationship MUST be kept consistent:

- **Adding a patch.** When a CVE moves to `fixed`, retract any
  `not_affected` VEX statement for that CVE in the consuming
  image's `<image>.vex.json`. A `fixed` patch supersedes a
  `not_affected` justification (the code path no longer exists, so
  any reasoning about it is obsolete).
- **Removing a patch.** If a patch is removed (because upstream-
  equivalent behaviour is achieved another way), any VEX statement
  that referenced the patch must be re-authored or amended.
- **`not_affected` without a patch.** Permitted, but the VEX
  statement's `status_notes` MUST give deployment-context-specific
  reasoning (per ADR-0014). Boilerplate like "mitigated by network
  policy" is not acceptable.

### Relation to other ADRs

- **ADR-0011 (Build Python 2.7 from canonical sources)** — Python 2.7
  is the first runtime governed by this policy. Its patch directory
  (`common/images/python-2.7/patches/`) is the reference
  implementation.
- **ADR-0009 (Publish VEX, not point-in-time CVEs)** — patches and
  VEX statements share the OpenVEX status vocabulary; this ADR's
  patch–VEX coupling rules build on 0009's framework.
- **ADR-0014 (VEX policy for heritage application images)** —
  applies the VEX side of this coupling at the application-image
  layer.

## Consequences

### Benefits

- **Provenance is auditable from the artifact.** A consumer who
  pulls the image, extracts the source, and inspects a single
  `.patch` file can trace it to an upstream fix, a CVE, a backport
  date, and two named engineers. No subscription, no ticketing
  system, no Slack history.
- **Two-engineer rule fails closed.** The policy refuses to ship a
  patch authored and reviewed by the same engineer. Catches
  inadvertent self-review.
- **Patches and VEX stay in sync by rule, not by reminder.** The
  coupling rules mean a `fixed` patch landing in `series` triggers
  a corresponding VEX retraction; reviewers know to look for both
  sides of the change in a single commit.
- **Generalises to a second EOL runtime.** When a Ruby 2.x or
  Node 12 maintenance line lands under wellmaintained, the policy
  is already written; only the directory location changes.

### Trade-offs

- **Two engineers per patch is a real cost.** Small CVE backports
  that take an hour to author take a second hour to review. The
  policy accepts this — heritage runtimes are not high-throughput
  workstreams.
- **The `Notes:` trailer can grow into mini-essays.** Non-trivial
  backports across version-skipped APIs need narrative explanation.
  We accept verbose patch headers as the price of the audit trail.
- **CVE-LOG.md is hand-maintained.** No tooling currently
  cross-checks `CVE-LOG.md` against the `series` file or against
  the consuming image's VEX statements. Drift is possible. A
  follow-up linter could close this gap.

### Future considerations

- **CVE-LOG ↔ series ↔ VEX consistency linter.** A tool that, given
  a runtime's patches directory and the consuming image's
  `<image>.vex.json`, verifies: every `fixed` row in CVE-LOG has a
  corresponding patch file; every `not_affected` row has a VEX
  statement; every patch has a CVE-LOG row. Tracked as a future
  pipeline yak.
- **Standardised patch-header parser.** A small utility that
  extracts the trailer fields from `.patch` files and emits a
  structured manifest (e.g. as a CycloneDX `vulnerability` block
  or a per-image enrichment payload). Would let the release-
  website render the patch-decision history alongside the SBOM.
- **Second EOL runtime under the same policy.** When a new EOL
  language joins the programme, this ADR is the contract — copy
  the patches directory shape, install the two-engineer rule, link
  the CVE-LOG. Consider amending this ADR rather than writing a
  fresh per-runtime ADR, unless the new runtime forces a meaningful
  divergence.
