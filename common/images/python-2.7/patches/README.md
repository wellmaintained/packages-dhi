# Python 2.7 Patch Series

Patches applied on top of CPython 2.7.18 (the last upstream release;
upstream EOL 2020-01-01) to keep this image maintained for senaite's
heritage stack. Authored and reviewed by wellmaintained.

## Scope

This directory holds the **patch series** — the actual `.patch` files
applied to CPython 2.7 sources during the build, plus the `series`
manifest that controls apply order, plus `CVE-LOG.md` which records
**patch decisions** for CVEs filed against CPython 2.7.

This directory does **not** hold:

- VEX statements. VEX statements live in the per-image
  `<image>.vex.json` files per
  [ADR-0009](../../../../docs/adr/0009-publish-vex-not-point-in-time-cves.md).
  For a CVE marked `not_affected` in `CVE-LOG.md`, the cross-referenced
  VEX statement ID lives in the consuming image's
  `<image>.vex.json` (e.g. `apps/senaite/images/senaite-lims/senaite-lims.vex.json`).
- Image build wiring. How patches flow into the SBOM as discrete
  components is a Step 3 concern — see the python-2.7 base image
  scaffold yak. Step 2 (this scaffold) only lays down the directory,
  policy, and CVE log.

## Patch policy

### Filename convention

```
NNNN-short-kebab-description.patch
```

- `NNNN` — 4-digit zero-padded sequence number (`0001-`, `0002-`, ...).
- Sequence reflects **apply order**, not chronology of authorship.
- Description is a kebab-case summary, ideally referencing the upstream
  CVE or fix subject (e.g. `0001-cve-2023-24329-urlsplit-leading-whitespace.patch`).

### Required patch header

Every patch file MUST begin with a header of the form:

```
From: <upstream commit author or wellmaintained engineer> <email>
Date: <date the patch was authored or backported, YYYY-MM-DD>
Subject: [PATCH] <one-line summary>

Upstream-CVE: CVE-YYYY-NNNNN (if applicable; otherwise "none")
Upstream-Fix: <URL to upstream commit, typically a Python 3.x backport>
Upstream-Bug: <URL to bpo / GH issue, if separate from the fix commit>
Backported-By: <wellmaintained engineer name> <email>
Backported-Date: YYYY-MM-DD
Reviewed-By: <wellmaintained engineer name> <email>
Reviewed-Date: YYYY-MM-DD
Notes: <optional — non-trivial backport rationale, conflict resolution,
        scope changes vs upstream, follow-ups>

---
<unified diff against CPython 2.7.18 sources>
```

The header is **not** comment-stripped before `patch`/`quilt` apply —
standard `From:`/`Subject:` lines pass through unmodified. The
`Upstream-*`, `Backported-*`, and `Reviewed-*` keys are project-specific
trailers; they exist to make provenance auditable from the patch file
alone (no out-of-band lookup required).

### Series file

The `series` file lists patches in apply order, one per line, in
quilt-style format:

```
0001-cve-2023-24329-urlsplit-leading-whitespace.patch
0002-cve-2024-12345-some-other-fix.patch
# Comment lines start with '#' and are skipped.
# Blank lines are skipped.
```

The build pipeline applies them sequentially with `patch -p1` (or
`quilt push -a`, depending on Step 3's wiring choice) before invoking
`./configure && make`.

### Adding a new patch

1. Identify the upstream fix (typically a Python 3.x commit) and the
   CVE it addresses.
2. Backport the diff against CPython 2.7.18. Resolve conflicts;
   document non-trivial resolutions in the patch's `Notes:` trailer.
3. Save as `common/images/python-2.7/patches/NNNN-short-kebab.patch`
   with the next sequence number.
4. Append the filename to `series`.
5. Update `CVE-LOG.md`: move the CVE row's status to `fixed` and link
   to the patch file.
6. If the CVE was previously marked `not_affected` (and thus had a VEX
   statement in `<image>.vex.json`), retract the VEX statement — a
   `fixed` patch supersedes a `not_affected` justification. Update the
   relevant `<image>.vex.json` accordingly.
7. Commit patch + series + CVE-LOG + (if applicable) VEX update in a
   single commit so the audit trail is atomic.

### Removing a patch

Patches are only removed if upstream-equivalent behaviour is achieved
some other way (e.g. switching to a different library, dropping the
affected feature). Removal requires:

1. Delete the `.patch` file and remove its line from `series`.
2. Update `CVE-LOG.md`: revert the CVE row to its prior status (likely
   `under_investigation` or `not_affected`, with a fresh justification).
3. Re-author or amend any VEX statement that referenced the removed
   patch.

## Layout

```
common/images/python-2.7/patches/
├── README.md          (this file — patch policy)
├── series             (apply order; one patch filename per line)
├── CVE-LOG.md         (per-CVE patch decision log)
└── NNNN-*.patch       (the patches themselves; none yet)
```

## Related

- [ADR-0009: Publish VEX, Not Point-in-Time CVE Lists](../../../../docs/adr/0009-publish-vex-not-point-in-time-cves.md)
  — VEX policy, OpenVEX status vocabulary used by `CVE-LOG.md`.
- [`CVE-LOG.md`](CVE-LOG.md) — current patch-decision status for each
  tracked CVE.
- `series` — quilt-style apply order manifest.
