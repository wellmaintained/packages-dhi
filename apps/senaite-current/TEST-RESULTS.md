# SENAITE LIMS (current) — Upstream Test Suite Results

Captured against `ghcr.io/wellmaintained/packages-dhi/senaite-lims-current:dev`
(Plone 5.2.15 + senaite.lims 2.6.0, branch
`restructure-build-senaite-current-image-and-app-from-senaite.lims-2.6.x`).

## How to reproduce

```
APP=senaite-current just ci build senaite-lims
docker run --rm --entrypoint /opt/senaite/bin/test \
    ghcr.io/wellmaintained/packages-dhi/senaite-lims-current:dev --all -v
```

The image embeds a `bin/test` (zope.testrunner via `zc.recipe.testrunner`)
covering the buildout's `[buildout] eggs` list: Plone, plone.app.contenttypes,
plone.app.upgrade, plone.app.testing, senaite.{core,app.listing,app.spotlight,
app.supermodel,impress,jsonapi,lims}.

## Headline numbers

_To be captured once the senaite-lims-current image build completes
successfully on this branch._

This file mirrors the structure of `apps/senaite/TEST-RESULTS.md` (2.0
baseline) and will be populated by running the test command above and
pasting its summary line.
