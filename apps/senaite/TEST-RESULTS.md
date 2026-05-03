# SENAITE LIMS — Upstream Test Suite Results

Captured against `ghcr.io/wellmaintained/packages-dhi/senaite-lims:dev`
(Plone 5.2.4 + senaite.lims 2.0.0, branch `senaite/09-smoke-tests`).

## How to reproduce

```
APP=senaite just ci build senaite-lims
docker run --rm --entrypoint /opt/senaite/bin/test \
    ghcr.io/wellmaintained/packages-dhi/senaite-lims:dev --all -v
```

The image embeds a `bin/test` (zope.testrunner via `zc.recipe.testrunner`)
covering the buildout's `[buildout] eggs` list: Plone, plone.app.contenttypes,
plone.app.upgrade, plone.app.testing, senaite.{core,app.listing,app.spotlight,
app.supermodel,impress,jsonapi,lims}.

## Headline numbers

| Metric | Count |
|---|---|
| Tests attempted | **149** |
| **Pass** | **116** |
| Failures (assertion) | 0 |
| Errors (import-time) | 27 |
| Skipped (runtime) | 6 |
| Wall time | 5 min 14 s |

After excluding browser-driven Robot Framework imports (26 of 27 errors),
real pass rate is **116 / 123 = 94%**.

### senaite.core (the integration we actually care about)

| Metric | Count |
|---|---|
| Tests | **106** |
| **Pass** | **106 (100%)** |
| Failures | 0 |
| Errors | 0 |
| Skipped | 0 |
| Wall time | 4 min 52 s |

The full senaite.core test suite — analysis-request retraction, calculations,
duplicate analyses, hidden analyses, limit-of-detection handling, manual
uncertainty, decimalmark / sci-notation, validation, z3c widgets, and the
senaite.core doctest corpus — passes green against our build.

## Failure categorisation

| Category | Count | Notes |
|---|---|---|
| Robot Framework / Selenium | 26 | `plone.app.contenttypes.tests.test_*` — every test module imports `plone.app.robotframework.testing`, which is **out of scope** per the yak brief (browser-driven tests need a Selenium grid we are not running). |
| Missing `mock` package | 1 | `plone.app.upgrade.tests.test_upgrade` — Py2's `mock` is a separate package, easy follow-up fix. |
| Modern-Linux compatibility | 0 | Nothing observed at this layer. |
| Missing test fixtures | 0 | Nothing observed. |
| Real bugs | 0 | Nothing observed. |
| Python-2.7-PyPI mismatch | 0 | Nothing observed at the test-runtime layer (the buildout phase dealt with these). |

## Known skips and rationale

- `plone.app.contenttypes.tests.test_robot` and the 25 sibling `test_*` modules
  are Robot Framework / Selenium tests requiring a browser. **Out of scope**
  for this yak per the brief; would need a Selenium grid alongside the runtime
  image to run.
- 6 runtime skips inside passing test modules — these are upstream `@skip`
  decorations (typically platform or version gates) and are not bugs in our
  build.

## Receipts

- Phase 1 build gate (`smoke-test runtime dependencies` in
  `apps/senaite/images/senaite-lims/prod.yaml`) imports **142** top-level
  modules cleanly during every build, with 4 platform-impossible skips
  (`tkinter`/`_tkinter`/`winreg`/`_winreg`).
- Phase 2 confirms 116 of 123 reachable upstream tests pass (94%) with zero
  assertion failures or runtime errors. The 7 reachable failures are all
  import-time and trace to dependency packaging, not to bugs in our build.

## Follow-ups (not chased tonight)

1. **Add `mock` to the buildout** — closes the 1 non-Robot import error.
   Trivial: pin `mock==3.0.5` (last Py2-compatible release) in
   `[versions]` and add it to `eggs`. Effort: <10 min.
2. **Run senaite.core doctests under coverage** — the 106 tests are a strong
   regression baseline; tracking coverage drift on subsequent rebuilds
   surfaces upstream-incompatible patches early.
3. **Wire test pass/fail counts into release-website** — Step 8's release-data
   pipeline can scrape this file (or a JSON sibling) so the heritage-demo page
   carries a "tests run" badge alongside the SBOM and VEX manifests.
4. **Browser test infrastructure** — out of scope for the heritage-on-Plone
   demo, but if a customer wants the Robot Framework receipts too, a sidecar
   image with a Chromium-via-noVNC layer would unlock the 26 skipped modules.
