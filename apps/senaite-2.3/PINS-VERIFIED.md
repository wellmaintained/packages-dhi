# SENAITE 2.3 — Pin Verification

Audit pass on 2026-05-08 confirming every senaite-2.3 source pin is present
with a SHA-256 checksum or immutable upstream ref, and every pin carries a
comment explaining what it is and why pinned.

## Where pins live

| File | Role |
|---|---|
| `app-images.yaml` | Image manifest (stock vs custom) |
| `images/senaite-lims/prod.yaml` | DHI image definition + buildout heredoc |
| `images/senaite-lims/buildout/{buildout.cfg,versions.cfg}` | Human-reference buildout config (canonical at heredoc) |

## Pinned sources / tools

| What | Where | Pin | Form | Comment present |
|---|---|---|---|---|
| senaite.lims 2.3.0 | `prod.yaml` builder `files:` | `git+https://github.com/senaite/senaite.lims.git#2.3.0` + spdx | git tag | yes |
| python-2.7 base image | `prod.yaml` builder `uses:` | `ghcr.io/wellmaintained/packages-dhi/python-2.7:dev` | tag (digest TODO — see Gaps) | yes |
| senaite.impress 2.3.0 | install step `git clone --branch=2.3.0` | branch ref (live clone — see Gaps) | branch | yes (pyphen-pin override rationale) |
| zc.buildout | `prod.yaml` install step + `[versions]` | `2.13.3` | exact version | yes |
| setuptools | `prod.yaml` install step + `[versions]` | `44.1.1` | exact version | yes |
| Plone 5.2.9 versions | `prod.yaml` buildout heredoc | `extends = https://dist.plone.org/release/5.2.9/versions.cfg` | URL (live fetch — see Gaps) | yes |
| senaite.core, .app.listing, .app.spotlight, .app.supermodel, .impress, .jsonapi | `[versions]` block | exact (all 2.3.0) | exact | yes |
| Plone hotfix / SiteErrorLog | `[versions]` | `Products.PloneHotfix20200121=1.1`, `Products.SiteErrorLog=5.4` | exact | yes |
| Heritage Py2-only transitives | `[versions]` block + `pip install --target=...` | exact (Pyphen 0.9.5, openpyxl 2.6.4, requests 2.27.1, urllib3 1.26.18, certifi 2021.10.8, idna 2.10, magnitude 0.9.4, et_xmlfile 1.0.1, unittest2 1.1.0, pdfrw 0.4, chardet 4.0.0, zipp 1.2.0, zc.recipe.cmmi 1.3.6, zc.recipe.testrunner 2.2) | exact | yes |

## Status

- `just update-tools` — clean (no diff)
- `just lint-yaml` — passes
- No senaite/plone/cpython/buildout cruft leaked into `common/tool-versions.yaml`
  (build-host tools only, per Yakob 2026-05-03 routing decision)

## Known gaps (carried forward, not new findings)

These are already-acknowledged follow-ups; flagged here for completeness, not
fixed in this yak:

1. **python-2.7 base is tag-pinned, not digest-pinned.** Same brittleness
   noted in 1.3 + current siblings; comment block in `prod.yaml` calls it out.
2. **senaite.impress is fetched via `git clone --depth=1 --branch=2.3.0`** at
   build time (no commit SHA pin). The patched `setup.py` lives in the
   builder, which means a force-push to the upstream `2.3.0` tag would
   silently change inputs. SENAITE upstream tags are not signed.
3. **`buildout/versions.cfg` is an empty `[versions]` placeholder.** Tracked
   by the `populate senaite-2.3 versions.cfg lock` yak.
4. **Plone versions.cfg `extends = https://dist.plone.org/release/5.2.9/versions.cfg`** is a live HTTPS fetch with no SHA-256.

— verified by Yakitty, 2026-05-08
