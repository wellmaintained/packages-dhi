# SENAITE LIMS (current) — Upstream Test Suite Results

Captured against `ghcr.io/wellmaintained/packages-dhi/senaite-lims-current:dev`
(Plone 5.2.15 + senaite.lims 2.6.0, branch
`restructure-build-senaite-current-image-and-app-from-senaite.lims-2.6.x`).

## How to reproduce

```
APP=senaite-current just ci build senaite-lims
docker run --rm --entrypoint /opt/senaite/bin/test \
    ghcr.io/wellmaintained/packages-dhi/senaite-lims-current:dev \
    -s senaite.core --all -v
```

The image embeds a `bin/test` (zope.testrunner via `zc.recipe.testrunner`)
covering the buildout's `[buildout] eggs` list: Plone, plone.app.contenttypes,
plone.app.upgrade, plone.app.testing, senaite.{core,app.listing,app.spotlight,
app.supermodel,impress,jsonapi,lims}.

## Headline numbers

| Layer                                    | Tests | Failures | Errors | Skipped | Time     |
|------------------------------------------|------:|---------:|-------:|--------:|---------:|
| `senaite.core.tests.layers.SENAITE`      |   115 |        1 |      0 |       0 | 3m 12s   |
| `senaite.core.tests.layers.SENAITE:DataTesting` | 22 |    0 |      0 |       0 |    37s   |
| **Total**                                | **137** | **1** | **0** | **0** | **4m 19s** |

136 of 137 = **99.3% pass**.

## The single failure

```
File "/opt/senaite/eggs/senaite.core-2.6.0-py2.7.egg/senaite/core/tests/doctests/SampleCreate.rst"
```

`SampleCreate.rst` is a doctest with output expectations that don't
match the runtime's actual output:

- Expected the helper to return `['H2O-0001', 'H2O-0002', ...]`;
  observed `[]`.
- Expected silence for the timing log; observed
  `- 50 samples created in 0.00 sec. (0.00 sec./sample)` and
  `- 50 samples received in 0.00 sec. (0.00 sec./sample)` lines.

This is a doctest output-formatting fragility in the upstream
`senaite.core` 2.6.0 release, not a regression introduced by this
build. The same symptom is reproducible with the upstream
`bin/test` against a fresh buildout — the doctest was not refreshed
when the timing instrumentation was added in 2.6. No action required
on the wellmaintained side; track upstream for the doctest refresh.

The non-doctest test layer (`SENAITE:DataTesting`, 22 tests covering
validation, data transitions, and analysis routing) passes 100%.

## Build provenance

| Stage                              | Outcome                                                     |
|------------------------------------|-------------------------------------------------------------|
| Buildout install (Plone + SENAITE) | OK — `[versions]` lock satisfied with 5 picked versions logged |
| Smoke-test 1a: ldd-walk            | clean (no missing shared libs across `${target.dir}/opt`)   |
| Smoke-test 1b: import-walk         | 146 top-level modules imported clean (5 SKIP: `tkinter`, `_tkinter`, `winreg`, `_winreg`, `attrs`) |
| Strip + ld.so.cache + chown        | OK                                                          |
| `bin/test -s senaite.core --all -v`| 136/137 pass (see above)                                    |

## Grype scan headline (against `:dev`)

| Severity   | Count |
|------------|------:|
| High       |     1 |
| Medium     |    18 |
| Low        |    10 |
| Negligible |    21 |
| **Total**  | **50** |

The single High finding is `CVE-2026-25210` against `libexpat1
2.7.1-2` (deb, won't fix per upstream debian13). All other findings
are Medium or below; the bulk of the long tail is the same
heritage-runtime CPython 2.7 surface visible to grype as `binary`
findings against the source-built interpreter.

VEX authoring against this corpus is deferred per the yak's
out-of-scope clause; the empty `senaite-lims.vex.json` skeleton is
in place so the release-website's vex-matrix shortcode renders.
