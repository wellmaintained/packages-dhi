# SENAITE 2.3.x VEX Authoring Policy

This document is the operational handbook for authoring OpenVEX statements
against the SENAITE LIMS 2.3.x heritage image set
(`senaite-lims-2.3` and its `python-2.7` base layer). It is the per-version-line
counterpart of `apps/senaite-current/VEX-POLICY.md` (the live current line) and
`apps/senaite-1.3/VEX-POLICY.md` (the 1.3 heritage line); ADR-0015 governs the
per-version-line app naming.

It is the **how**. The **why** lives in two ADRs:

- [ADR-0009 — Publish VEX, not point-in-time CVE lists](../../docs/adr/0009-publish-vex-not-point-in-time-cves.md)
  establishes the format (OpenVEX v0.2.0), the file location convention
  (`<image>.vex.json` next to each image's DHI YAML), the consumer
  re-scan path (`grype sbom:<image>.cdx.json --vex <image>.vex.json`),
  and the contract that empty `statements: []` represents *"no
  analysis yet"* — not *"no CVEs"*.
- ADR-0014 — VEX policy for heritage application images (Yakitty's
  ADR; lands on a sibling branch alongside this handbook) records
  *the policy decision* for heritage Python 2.7 / Plone 5.2.4
  workloads. This document is its operational counterpart.

When ADR-0009 and this handbook disagree, ADR-0009 wins; it is the
contract. This document explains how to live up to it for the SENAITE
images specifically.

## 1. The four valid VEX statuses

OpenVEX defines exactly four `status` values. SENAITE uses them as
follows.

| Status | When it applies | Required justification | Notes column |
|--------|-----------------|------------------------|--------------|
| `under_investigation` | We know about the CVE but have not yet reasoned about its impact on this deployment. | None (not allowed). | `impact_statement` is the human signal — write what we are waiting on. |
| `not_affected` | We have analysed the CVE; this image, as deployed, is **not vulnerable**. | One of the five OpenVEX justifications (see §2). | `status_notes` MUST contain deployment-context-specific reasoning (see §3). |
| `affected` | We have analysed the CVE; this image **is vulnerable** and no fix has shipped yet. | None (not allowed). | `impact_statement` describes blast radius and mitigations the operator can apply. Pair with a tracking issue. |
| `fixed` | A patch has been applied (in `series` / `NNNN-*.patch`) that resolves the CVE. | None (not allowed). | `status_notes` should link to the patch file and to the upstream commit it backports. Cross-references `common/images/python-2.7/patches/CVE-LOG.md`. |

`under_investigation` is the **honest default**. If you cannot produce
deployment-specific reasoning for `not_affected`, the correct status is
`under_investigation`. ADR-0009 is explicit: *empty/lazy VEX is honest;
lying VEX is worse than missing VEX.*

## 2. Required justifications for `not_affected`

OpenVEX defines five justifications. Pick the one that most narrowly
explains why the deployment is not exposed:

| Justification | Use when |
|---|---|
| `component_not_present` | The vulnerable component is in the SBOM but is not actually shipped in the image (e.g. a build-time dep). Prefer the more specific `vulnerable_code_not_in_execute_path` if the component **is** shipped but never invoked. |
| `vulnerable_code_not_present` | The component is shipped but the specific function / module containing the CVE is not compiled in or has been removed (e.g. a `--without-feature` build flag). |
| `vulnerable_code_not_in_execute_path` | The vulnerable code is shipped and reachable in principle, but the SENAITE / Plone runtime never calls it (e.g. `pip` on disk but no runtime exec, a TLS code path on a non-TLS listener). |
| `vulnerable_code_cannot_be_controlled_by_adversary` | The vulnerable code runs but only on data from a trusted source (e.g. admin-configured catalog regex; CVE requires a config flag we don't set). |
| `inline_mitigations_already_exist` | The deployment has a control that prevents exploitation (e.g. reverse proxy strips header X; CSP blocks inline JS). Document the control specifically. |

**Boilerplate is the #1 agent failure mode.** "Not exploitable in this
deployment context" is **not** a justification — it's a refusal to
write one. If you find yourself reaching for that phrase, switch to
`under_investigation`.

## 3. Documentation requirements per status

Every statement carries a `vulnerability.name` (CVE or GHSA ID), a
`products` array (purl referencing the image and, optionally, the
component path), a `status`, and a `timestamp`. Beyond that:

### `not_affected` — deployment context must be EXPLICIT

The `status_notes` must answer: **why does THIS deployment not expose
this vulnerability?** Generic upstream reasoning ("the maintainer
disputes this CVE") is acceptable *only* alongside a deployment-specific
follow-up sentence ("…and SENAITE is not affected because we don't
expose the vulnerable parser to untrusted input — admin-configured
catalog regex is the only entry point and admin is a trusted role per
Plone's ACL model").

**Good** — concrete, image-specific, names the deployment property
that closes the attack surface:

> CVE-2026-XXXX affects glibc's regex compilation against
> attacker-controlled patterns. SENAITE 2.3.0 does not accept regex
> from untrusted input — only the admin user (authenticated) can
> configure custom catalog text indexes, and admin is a trusted role
> per Plone's ACL model. Justification:
> `vulnerable_code_cannot_be_controlled_by_adversary`.

**Good** — names a build-time fact about this image:

> pip is present in the runtime image as a side-effect of the
> get-pip.py bootstrap during build, but no runtime code path
> invokes it. The senaite-lims entrypoint is `bin/instance`
> (Plone Zope2 server); the image filesystem is read-only at
> runtime; pip is never exec'd. Justification:
> `vulnerable_code_not_in_execute_path`.

**Bad** — boilerplate, no deployment specifics:

> Not exploitable in this deployment context.

**Bad** — repeats the upstream advisory without saying what's
deployment-specific:

> Maintainer disputes this as a security issue.

### `affected` — paired with a tracking issue

`impact_statement` describes who can exploit, under what
conditions, and what mitigations the operator can apply *today*
(rate limit, network policy, feature flag, reverse-proxy header
strip). Open a tracking yak / GitHub issue for the fix and link it.

### `fixed` — link the patch

For Python 2.7 backports, the `status_notes` links to the patch
file in `common/images/python-2.7/patches/` and to the upstream
commit it backports. The same patch is recorded in
`common/images/python-2.7/patches/CVE-LOG.md` (see ADR-0009 §"Custom
images need hand-authored VEX" and the CVE-LOG.md "Maintaining this
log" section — VEX statements and CVE-LOG entries are written in the
same commit).

### `under_investigation` — be specific about what we're waiting on

Use `impact_statement`, not `status_notes` (status_notes is reserved
for resolved analyses). State *what would close this investigation*:

- "Waiting for upstream Debian security update; trixie has no fixed
  package yet."
- "Waiting on DHI base-image rebuild that ships the fixed glibc."
- "Waiting on principal review — initial draft says
  `not_affected` because Plone's ACL gates the entry point, but the
  reviewer needs to confirm no anonymous traversal path reaches the
  vulnerable code."

## 4. Inheritance: heritage images and the DHI base layer

`senaite-lims` is built on top of the wellmaintained `python-2.7`
image, which is itself built on the DHI `debian13` rootfs. CVEs may
appear at any of three layers:

1. **Debian system libraries** (`glibc`, `ncurses`, `sqlite3`,
   `util-linux`, `xz-utils`, `zlib`, `libcap2`, `systemd`, …)
   — DHI's territory. DHI hardens `debian13` and ships VEX for it.
   Wellmaintained inherits both the binaries and DHI's analysis.
2. **The Python 2.7 interpreter and bootstrap toolchain**
   (`cpython` 2.7.18, `pip` 20.3.4, `setuptools` 44.x,
   `wheel` 0.33.x) — wellmaintained's territory.
3. **The application stack** (`plone`, `zope`, `senaite.*`,
   `pillow`, `lxml`, JavaScript bundles served by Plone's resource
   registry) — wellmaintained's territory; SENAITE-specific.

Each layer's VEX file covers the components introduced *at that
layer*:

- `python-2.7.vex.json` covers the `cpython` interpreter, the
  `pip`/`setuptools`/`wheel` bootstrap, and any system-library CVE
  whose deployment-specific reasoning is the same for every
  consumer of the python-2.7 image (i.e. there is nothing
  senaite-specific about why a glibc regex CVE is not exploitable
  through Python 2.7's `re` module).
- `senaite-lims.vex.json` covers the Plone / Zope / senaite stack
  and any system-library CVE whose deployment-specific reasoning
  is **senaite-specific** (e.g. "this CVE matters for an HTTP
  server but the image only listens on Plone's bin/instance").

When an inherited finding has the same answer at multiple layers,
the **lower layer** owns the statement. The senaite-lims VEX file
should not duplicate statements that python-2.7 already covers
unless the senaite deployment changes the calculation.

### "Inherited from DHI's hardening" is a valid deployment-context reason

For Debian system-library CVEs that DHI's `vex.dhi.json` (vendor VEX)
already handles, our wellmaintained-layer VEX statement reads:

> Inherited from the DHI debian13 base image. DHI publishes vendor
> VEX (`vex.dhi.json`, attached as an OCI attestation on the base)
> covering this CVE; status will reduce when DHI updates the base
> with the fixed package. Justification:
> `vulnerable_code_cannot_be_controlled_by_adversary`.

This is **not** boilerplate — it names a concrete supply-chain fact
(DHI's hardening cadence) that closes the loop for the consumer:
they know who owns the fix and how it gets to them.

## 5. Review process

VEX statements are authored by an agent; they are **published only
after principal-level engineer review**.

1. **Agent drafts** the VEX file as part of the same commit that
   updates the image's `<image>.vex.json` and (where applicable) the
   `python-2.7/patches/CVE-LOG.md` row. The PR description must list:
   - the grype scan output the statements were drafted against
     (commit + date);
   - which findings were promoted from `under_investigation` and why;
   - the reviewer requested.
2. **Principal review** verifies, for each `not_affected` statement:
   - the justification matches the actual code path;
   - the deployment-context reasoning names a real property of the
     SENAITE deployment (not boilerplate);
   - no `affected` finding has been silently downgraded.
3. **Reviewer-blocking conditions**: any `not_affected` statement
   whose `status_notes` does not name a concrete deployment
   property; any `fixed` statement without a corresponding patch
   file under `common/images/python-2.7/patches/`; any new
   `affected` statement without a tracking issue.
4. **Time-bounded re-review** — VEX statements are durable but not
   permanent. Re-review the full VEX corpus on each major Plone or
   Python release; re-review individual statements when the
   underlying code path changes (a new buildout entry, a new
   exposed endpoint, a new file upload feature).

The reviewer signs off in the PR; the merge is the publication
event.

## 6. Scope notes — what the SENAITE deployment looks like

The reasoning in §3 leans on these deployment facts. They are
recorded here so reviewers can challenge them when they cease to be
true.

- **Authenticated-only access.** SENAITE is a laboratory
  information management system. The expected deployment runs
  behind a reverse proxy, with authenticated lab staff as the
  only users. Anonymous access is limited to the login screen.
  Where a CVE requires *a logged-in user with admin rights* to
  trigger, that user is by Plone's ACL model a trusted role.
- **Plone 5.2.9 / Zope 4 stack.** ZODB-backed (no SQL
  injection surface). The HTTP listener is Plone's `bin/instance`;
  no external WSGI server is present in the runtime image.
- **Read-only image filesystem.** The runtime image runs as the
  unprivileged `senaite` user (uid 65532). `/opt/senaite/var/`
  is the only writable path (ZODB + logs); everything else is
  read-only at OCI mount time.
- **No build toolchain at runtime.** `pip`, `setuptools`, `wheel`,
  `gcc`, `make` are present *only* in the python-2.7 builder
  stage. They are absent from the runtime image. CVEs against
  these components carry `vulnerable_code_not_in_execute_path`
  with a citation to the build pipeline.
- **JS bundles run in the authenticated user's browser.** Plone's
  resource registry ships bundled JS (moment, marked,
  datatables.net, tinymce, hoek, hawk, qs, underscore,
  json-schema, minimist, form-data, requirejs, …) as static
  assets served behind authentication. Many CVEs against these
  bundles are prototype pollution / regex DoS / CSP bypass
  issues. A rational `not_affected` justification names the
  deployment property that makes the JS-side exploit untrue:
  *the only callers are authenticated lab staff with
  admin-controlled access*; *the input the gadget consumes is
  produced by the SENAITE backend, not user-supplied JSON*.
- **Image processing is server-side** for sample uploads
  (microscopy, gels). Pillow 6.2.2 is the image processor.
  Pillow CVEs that crash on crafted inputs **are** within the
  attack surface (an authenticated lab tech could upload a
  crafted PNG); these typically default to `under_investigation`
  pending principal review of the upload pipeline (file-type
  whitelist, size limits, processing isolation).

When any of these facts changes — for instance, if a deployment
exposes SENAITE to anonymous users on the public internet — the
VEX statements that depend on them must be revisited. Reviewers
should treat such a change as a signal to re-review the corpus.

## 7. How consumers verify our VEX

Per ADR-0009 §"Decision", the canonical consumer re-scan is:

```
grype sbom:senaite-lims.cdx.json --vex senaite-lims.vex.json
```

Grype consumes OpenVEX natively. A statement of `not_affected` or
`fixed` removes the CVE from the consumer's local re-scan output.
A statement of `under_investigation` or `affected` keeps the CVE
visible — which is the point: those are the rows the operator
should read.

The same command works for the python-2.7 base layer:

```
grype sbom:python-2.7.cdx.json --vex python-2.7.vex.json
```

Consumers who pull both VEX files (e.g. for a multi-layer scan)
get the union of suppressions; they apply only to their matching
products.

## 8. File locations and conventions

| File | Purpose | Updated by |
|---|---|---|
| `apps/senaite-2.3/VEX-POLICY.md` | This document. | Principal review when the policy changes (rare). |
| `apps/senaite-2.3/images/senaite-lims/senaite-lims.vex.json` | OpenVEX statements for the senaite-lims image (2.3.x line). | Same commit as the image-level finding it triages. |
| `common/images/python-2.7/python-2.7.vex.json` | OpenVEX statements for the python-2.7 base image. | Same commit as the image-level finding it triages. |
| `common/images/python-2.7/patches/CVE-LOG.md` | Per-CVE patch decision log; OpenVEX-vocabulary status column. | Same commit as the patch / VEX statement that resolves the row. |
| `common/images/python-2.7/patches/series` | Patch series; one entry per `fixed` Python 2.7 CVE. | Same commit as the matching VEX `fixed` statement. |

The pipeline finds VEX files via the glob
`*/images/*/<image>.vex.json` in
`scripts/generate-compliance-artifacts:121-130`. **Do not** move
VEX files outside this layout — they will become invisible to the
compliance pack assembly. If you need multi-file VEX (one per
CVE for review workflow), propose it via ADR; do not silently
break the existing glob.

## 9. Quick-reference checklist for the agent

When triaging a new grype finding, walk this list:

1. Read the CVE's NVD entry and the upstream advisory. Note the
   precondition for exploitation.
2. Identify the deployment property that closes (or fails to
   close) the attack surface. Cross-reference §6.
3. Pick the narrowest applicable justification from §2.
4. Draft a `status_notes` (for `not_affected` / `fixed`) or
   `impact_statement` (for `under_investigation` / `affected`).
   Read it aloud: does it name a *concrete* property of this
   deployment?
5. If yes, the statement is ready for review.
6. If no, change status to `under_investigation` and write what
   the reviewer needs to confirm.
7. Group by component family in the JSON to keep diffs reviewable.
8. Commit alongside any patch / CVE-LOG.md update so the audit
   trail is atomic.
