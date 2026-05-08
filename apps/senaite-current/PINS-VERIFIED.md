# SENAITE current (2.6.0) — Pin Verification

Audit pass on 2026-05-08 confirming every senaite-current source pin is
present with a SHA-256 checksum or immutable upstream ref, and every pin
carries a comment explaining what it is and why pinned.

## Where pins live

| File | Role |
|---|---|
| `app-images.yaml` | Image manifest (stock vs custom) |
| `images/senaite-lims/prod.yaml` | DHI image definition + buildout heredoc |
| `images/senaite-lims/buildout/{buildout.cfg,versions.cfg}` | Human-reference buildout config (canonical at heredoc) |

## Pinned sources / tools

| What | Where | Pin | Form | Comment present |
|---|---|---|---|---|
| senaite.lims 2.6.0 | `prod.yaml` builder `files:` | `git+https://github.com/senaite/senaite.lims.git#2.6.0` + spdx | git tag | yes |
| python-2.7 base image | `prod.yaml` builder `uses:` | `ghcr.io/wellmaintained/packages-dhi/python-2.7:dev` | tag (digest TODO — see Gaps) | yes (TODO note inline) |
| senaite.impress 2.6.0 | install step `git clone --branch=2.6.0` | branch ref (live clone — see Gaps) | branch | yes (pyphen-pin override rationale) |
| zc.buildout | `prod.yaml` install step + `[versions]` | `2.13.3` | exact version | yes |
| setuptools | `prod.yaml` install step + `[versions]` | `44.1.1` | exact version | yes |
| Plone 5.2.15 versions | `prod.yaml` buildout heredoc | `extends = https://dist.plone.org/release/5.2.15/versions.cfg` | URL (live fetch — see Gaps) | yes |
| senaite.core, .app.listing, .app.spotlight, .app.supermodel, .impress, .jsonapi | `[versions]` block | exact (all 2.6.0) | exact | yes |
| Plone hotfix / SiteErrorLog | `[versions]` | `Products.PloneHotfix20200121=1.1`, `Products.SiteErrorLog=5.4` | exact | yes |
| Heritage Py2-only transitives | `[versions]` block + `pip install --target=...` | exact (Pyphen 0.9.5, openpyxl 2.6.4, requests 2.27.1, urllib3 1.26.18, certifi 2021.10.8, idna 2.10, magnitude 0.9.4, et_xmlfile 1.0.1, unittest2 1.1.0, pdfrw 0.4, chardet 4.0.0, zipp 1.2.0, zc.recipe.cmmi 1.3.6, zc.recipe.testrunner 2.2) | exact | yes |

## python-2.7 base image (`common/images/python-2.7/dhi.yaml`)

Shared between all three senaite apps; pins verified once here:

| What | Pin | Form |
|---|---|---|
| CPython 2.7.18 | `git+https://github.com/python/cpython.git#v2.7.18` + spdx | git tag |
| `get-pip.py` | `https://bootstrap.pypa.io/pip/2.7/get-pip.py` + `checksum: sha256:40ee07eac6674b8d60fce2bbabc148cf0e2f1408c167683f110fd608b8d6f416` | URL + SHA-256 |
| `dhi.io/python:3.14-debian13-dev` builder base | `@sha256:6d08fa284915b06d2fcc0405c0732871a6b95973174e43ceed16c4452a1233d5` | OCI digest |
| pip / setuptools / wheel (bootstrap) | `pip==20.3.4`, `setuptools<45`, `wheel<0.34` | exact / range (last Py2-compatible — comment block) |

## Status

- `just update-tools` — clean (no diff)
- `just lint-yaml` — passes
- No senaite/plone/cpython/buildout cruft leaked into `common/tool-versions.yaml`
  (build-host tools only, per Yakob 2026-05-03 routing decision)

## Known gaps (carried forward, not new findings)

These are already-acknowledged follow-ups; flagged here for completeness, not
fixed in this yak:

1. **python-2.7 base is tag-pinned, not digest-pinned.** `prod.yaml` carries
   an inline `TODO` block calling for a published GHCR component-tag digest
   once the CI pre-release pipeline pushes `python-2.7`.
2. **senaite.impress is fetched via `git clone --depth=1 --branch=2.6.0`** at
   build time (no commit SHA pin). Same caveat as 2.3.
3. **`buildout/versions.cfg` is an empty `[versions]` placeholder.** Tracked
   by the `populate senaite-current versions.cfg lock` yak.
4. **Plone versions.cfg `extends = https://dist.plone.org/release/5.2.15/versions.cfg`** is a live HTTPS fetch with no SHA-256.

— verified by Yakitty, 2026-05-08
