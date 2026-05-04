# SENAITE LIMS 1.3.x — Upstream Test Suite Results

Captured against `ghcr.io/wellmaintained/packages-dhi/senaite-lims-1.3:dev`
(Plone 4.3.20 + Zope 2.13 + senaite.lims 1.3.5, branch
`senaite-lims-1.3-smoke-tests`).

Sibling document: [`TEST-RESULTS.md`](TEST-RESULTS.md) covers the 2.0.0 build
on Plone 5.2.4.

## How to reproduce

```
APP=senaite just ci build senaite-lims-1.3
docker run --rm --entrypoint /opt/senaite-1.3/bin/test \
    ghcr.io/wellmaintained/packages-dhi/senaite-lims-1.3:dev --all -v
```

The image embeds `bin/test` (zope.testrunner via `zc.recipe.testrunner`)
covering the buildout's `[buildout] eggs` list: Plone, Pillow, lxml, and the
SENAITE 1.3.x sibling stack (senaite.core, senaite.core.{listing,spotlight,
supermodel}, senaite.impress, senaite.jsonapi, senaite.lims). The `[test]`
buildout part also pulls in `senaite.lims [test]` extras for the
plone.app.testing fixture.

## Headline numbers

| Metric | Count |
|---|---|
| Tests attempted | **100** |
| **Pass** | **100 (100%)** |
| Failures (assertion) | 0 |
| Errors (import-time) | 0 |
| Skipped (runtime) | 0 |
| Wall time | 4 min 22 s |

The full senaite.core 1.3.5 regression suite passes green — six-year-old
Plone 4.3 + Zope 2.13 code running its own test suite untouched on a 2026
Linux runtime. No assertion failures, no import errors, no skips.

### senaite.core (the integration we actually care about)

| Metric | Count |
|---|---|
| Tests | **100** |
| **Pass** | **100 (100%)** |
| Failures | 0 |
| Errors | 0 |
| Skipped | 0 |
| Wall time | 4 min 11 s |

Test layers exercised:

| Layer | Tests | Time |
|---|---|---|
| `bika.lims.testing.SENAITE:BaseTesting` | 76 | 2 min 56 s |
| `bika.lims.testing.SENAITE:DataTesting` | 24 | 46 s |

Coverage spans the senaite.core doctests + integration tests:
analysis-request lifecycle, calculations, duplicate analyses, hidden
analyses, limit-of-detection handling, manual uncertainty, decimal-mark /
sci-notation rendering, validation, z3c widgets, dynamic analysis specs,
and the bika.lims doctest corpus.

In 1.3.x the senaite.core code lives under the legacy `bika.lims` package
namespace (the rename to `senaite.core` happened in the 2.0.x line); test
discovery uses `-s bika.lims` rather than `-s senaite.core`. `--all` and
`-s bika.lims` produce identical totals.

## Comparison with 2.0.0

| Metric | 1.3.5 | 2.0.0 |
|---|---|---|
| Plone | 4.3.20 | 5.2.4 |
| Zope | 2.13 (ZServer) | 4.x (WSGI) |
| Python | 2.7 | 2.7 |
| senaite.core tests | **100 / 100 (100%)** | **106 / 106 (100%)** |
| Combined attempted | 100 | 149 |
| Combined pass | **100 (100%)** | 116 (78%) |
| Assertion failures | 0 | 0 |
| Import-time errors | 0 | 27 (26 Robot Framework + 1 mock) |
| Runtime skips | 0 | 6 |

**Both heritage demos pass their own regression suite green.** Where 2.0.0
shows 27 reachable import errors (all dependency-packaging issues, none real
bugs), 1.3.5 shows zero — because the 1.3 buildout's `[buildout] eggs` list
is narrower (no `plone.app.contenttypes` or `plone.app.upgrade`), so the
test runner doesn't try to import the Robot Framework / `mock` modules that
trip the 2.0 build.

The "interesting story" the brief asks about: **the 6+ year-old Plone 4.3 +
Zope 2.13 + senaite.lims 1.3.5 stack is exceptional on its own regression
suite**. 100% pass against a 2026 Linux runtime, on a base image (debian13 +
gcc 14) that didn't exist when this code was last released (2021-07-24).

## Failure categorisation

| Category | Count | Notes |
|---|---|---|
| Robot Framework / Selenium | 0 | The 1.3 buildout doesn't include `plone.app.contenttypes`, so the 26 Robot Framework import errors visible in 2.0 don't surface here. (Out of scope per yak brief regardless.) |
| Modern-Linux compatibility | 0 | Nothing observed at the test layer. The buildout phase already absorbed the gcc 14 / glibc 2.41 fallout via `CFLAGS=-Wno-error=*`. |
| Missing test fixtures | 0 | Nothing observed. |
| Real bugs | 0 | Nothing observed. |
| Python-2.7 / PyPI mismatch | 0 | Nothing observed at the test-runtime layer. The buildout's pre-pip step + namespace-init fix-up (z3c/zc/backports) absorbed the four discover-by-failure rounds during image bring-up; tests run clean. |
| Missing `mock` package | 0 | 1.3's eggs list doesn't include `plone.app.upgrade`, so the import error visible in 2.0 doesn't surface here. |

Zero categorisable failures across any axis.

## Receipts

- **Phase 1 build gate** (`smoke-test runtime dependencies` step in
  `apps/senaite/images/senaite-lims-1.3/prod.yaml`): `ldd`-walk + import-walk
  fire on every build. The import-walk imports every top-level module in
  `${target.dir}/opt/senaite-1.3/lib/python2.7/site-packages` plus every
  buildout egg, with 4 platform-impossible skips
  (`tkinter`/`_tkinter`/`winreg`/`_winreg`).
- **Phase 2 upstream tests** confirm 100 of 100 reachable upstream tests
  pass (100%) with zero assertion failures, zero import errors, zero
  skips. Reproduce via the `docker run` command above.

## Follow-ups (not chased tonight)

1. **Mirror 2.0's test surface for parity** — adding `plone.app.contenttypes`
   and `plone.app.upgrade` to the 1.3 `[buildout] eggs` list would expand
   the test pool to match 2.0. Likely surfaces the same Robot Framework
   import errors (out of scope) and the `mock` package error. Effort:
   ~10 min + a build cycle to verify.
2. **Run senaite.core 1.3.5 doctests under coverage** — the 100 tests are a
   strong regression baseline; tracking coverage drift on subsequent
   rebuilds surfaces upstream-incompatible patches early.
3. **Wire test pass/fail counts into release-website** — the same scrape
   target as the 2.0 follow-up; the heritage-demo page can carry "100/100
   senaite.core 1.3.5" and "106/106 senaite.core 2.0.0" badges side-by-side
   alongside the SBOM and VEX manifests.
4. **Browser test infrastructure** — out of scope for both heritage demos,
   same as 2.0. A sidecar Chromium-via-noVNC layer would unlock the Robot
   Framework modules in 2.0 (and any equivalent surface 1.3 picks up if
   follow-up #1 is taken).
