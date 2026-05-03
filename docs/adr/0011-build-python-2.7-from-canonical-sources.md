# 0011. Build Python 2.7 from Canonical Sources

Date: 2026-05-03

## Status

proposed

## Context

ADR-0010 commits to SENAITE 2.0.0 as the primary heritage demo target,
which means we need a Python 2.7 runtime. Python 2.7 reached upstream
EOL on **2020-01-01** — six years before this ADR. python.org has not
shipped a release since `2.7.18` (2020-04). Anyone running Python 2.7
today is running unmaintained code unless someone else is patching it.

Four sourcing options exist:

1. **Tauthon** — a community fork of CPython 2.7 that backports
   selected Python 3 syntax features. It diverges from 2.7 semantics
   intentionally (e.g. `f`-strings, type-annotation syntax). Anything
   built against it is no longer plain "Python 2.7".
2. **TuxCare ELS for Python** — a commercial extended-support service
   that publishes patched Python 2.7 binaries. The patch source is
   proprietary; consumers pay for access and trust TuxCare's CVE
   triage. The provenance chain ends at TuxCare's word.
3. **Pre-built third-party images** (e.g. dockerhub `python:2.7`,
   community-maintained 2.7 wheels). Most are unmaintained; the
   handful that are actively patched do so without published
   patch-decision logs and rarely sign their releases.
4. **Build from canonical python.org sources, plus a wellmaintained
   patch series.** Source pinned to the upstream `v2.7.18` git tag.
   Patches authored or backported by wellmaintained engineers, each
   with an upstream-fix reference and a reviewer signoff. Build
   produces a CycloneDX SBOM via DHI's scout-sbom-indexer (per
   ADR-0003).

The demo's value proposition is **provenance** — every byte of the
runtime traceable to either upstream Python or to a named
wellmaintained engineer's patch with a stated CVE rationale. Options
1–3 each break that chain at a different point: Tauthon by changing
the language, TuxCare by hiding the patch source, prebuilt images by
having no published audit trail at all.

## Decision

**Build CPython 2.7 from canonical python.org sources, pinned to the
`v2.7.18` upstream tag, plus a wellmaintained-authored patch series.**

The image definition (`common/images/python-2.7/dhi.yaml`) fetches
sources via:

```yaml
contents:
  builds:
    - name: cpython-build
      contents:
        files:
          - url: "git+https://github.com/python/cpython.git#v2.7.18"
            spdx:
              packages:
                - name: cpython
                  purl: "pkg:github/python/cpython@v2.7.18"
                  license: PSF-2.0
```

The patch series lives at
`common/images/python-2.7/patches/{series,*.patch}` and is applied
during the build pipeline before `./configure && make`. Each patch
file carries its own provenance trailer (`Upstream-CVE`,
`Upstream-Fix`, `Backported-By`, `Reviewed-By`); the policy is
codified in ADR-0013.

Because the build runs under DHI's BuildKit frontend with
`--sbom=generator=dhi.io/scout-sbom-indexer:1`, the source fetch and
the resulting binary are both captured in the SPDX SBOM as components
with full purl attribution. The image's compliance posture is
identical to a current image's (ADR-0003) — the only difference is
that the runtime is older than the SBOM tooling.

### Relation to other ADRs

- **ADR-0001 (DHI base images)** — Python 2.7 is built as a custom
  image under that foundation; the build runs against a debian13
  rootfs supplied by DHI (see ADR-0012 for the layer split).
- **ADR-0003 (Derive SBOMs from build attestations)** — building from
  source still produces a build-attestation SBOM via the same DHI
  scout-sbom-indexer flow used by every other custom image. The
  source `git+https://...#v2.7.18` URL becomes a discrete SPDX
  component, so "what runtime did this come from" is answerable from
  the SBOM alone.
- **ADR-0013 (Patch backport policy)** — codifies how the patch series
  alongside this build is governed.

## Consequences

### Benefits

- **Single audit chain.** Every byte of the Python runtime traces to
  one of two sources: an upstream commit on the `v2.7.18` tag, or a
  patch in `common/images/python-2.7/patches/` with an explicit
  reviewer. There is no third-party black box.
- **Compatible with the rest of the pipeline.** The build emits an
  SPDX SBOM, a SLSA provenance, and (once VEX statements land) an
  OpenVEX file — the same triple the rest of the repo's images carry.
  Heritage doesn't get a different compliance story, just an older
  runtime under the same one.
- **Patch policy is reviewable from outside.** A consumer who wants
  to know which CVEs we've addressed can read the patch headers and
  `CVE-LOG.md` directly. No subscription, no NDA.
- **Tauthon's API drift is avoided.** Code that targets stock
  Python 2.7 (including SENAITE 2.0.0 and Plone 5.2) runs without
  modification.

### Trade-offs

- **We own the patches.** Every CVE published against CPython 2.7
  becomes a wellmaintained triage decision: backport, ignore (with
  VEX justification), or accept as a known limitation. There is no
  vendor to defer to.
- **Build complexity.** Building CPython from source is more
  ceremony than `FROM python:2.7`. The build YAML carries a
  multi-stage compile step plus a pip-bootstrap step that needs
  network access (`get-pip.py`); see `dhi.yaml` for the wiring.
- **PGO is disabled.** `--enable-optimizations` runs the CPython 2.7
  test suite to collect a profile, and `test_ftplib` hangs against
  OpenSSL 3.x on debian13. The fix would require backporting test
  infrastructure that 2.7 never had. We trade ~10–20% interpreter
  speed for a build that finishes — appropriate for a heritage demo.
  Documented inline in `dhi.yaml`.
- **TuxCare may be a better answer for some operators.** Operators
  who specifically want a vendor SLA and don't need transparent
  patch provenance are not the audience for this demo. We do not
  position this build as a TuxCare replacement.
- **Grype-blind for CPython itself.** Because the build runs
  `./configure && make && make install` rather than installing
  CPython as a Debian package, the resulting binary at
  `/opt/python-2.7/` is not registered with `dpkg`. Grype (and any
  other dpkg-driven scanner reading the SBOM) reports zero
  findings against CPython itself, even though CVEs filed against
  the 2.7 line are real. The authoritative inventory therefore
  lives in `common/images/python-2.7/patches/CVE-LOG.md`, seeded
  from the NVD CVE API; the published `python-2.7.vex.json`
  mirrors the analysed subset. Any consumer-facing rendering must
  surface CVE-LOG alongside grype's output, not in place of it
  (the heritage release-website does this explicitly under
  Dependencies → "The grype blind spot for source-installed
  CPython"). The trade is intentional: switching to a
  dpkg-installed CPython would be grype-visible at the cost of
  losing the per-patch provenance story this ADR is built around.

### Future considerations

- **Mirror pip 20.3.4.** The build currently fetches `get-pip.py`
  from `bootstrap.pypa.io` at install time, which means the
  cpython-build stage runs `privileged: true`. Mirroring the pip
  wheel into the build context (or shipping it from the patch
  directory) would let us drop the privileged step. Tracked
  implicitly by the senaite-lims yak.
- **Optimised build via offline PGO profile.** A
  separately-collected, hand-curated PGO profile (independent of
  the broken `test_ftplib` path) could restore the 10–20% speedup
  without re-enabling the regression suite. Not a blocker;
  performance-of-the-interpreter is not the demo's point.
- **A second heritage runtime.** If the demo extends to a second EOL
  language (e.g. Ruby 2.x), the same canonical-sources-plus-patch-
  series pattern should apply. ADR-0013 codifies the policy
  generically rather than Python-specifically for that reason.
