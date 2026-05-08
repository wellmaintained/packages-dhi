# SENAITE 1.3 — Pin Verification

Audit pass on 2026-05-08 confirming every senaite-1.3 source pin is present
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
| senaite.lims 1.3.5 | `prod.yaml` builder `files:` | `git+https://github.com/senaite/senaite.lims.git#1.3.5` + spdx | git tag | yes |
| python-2.7 base image | `prod.yaml` builder `uses:` | `ghcr.io/wellmaintained/packages-dhi/python-2.7:dev` | tag (digest TODO — see Gaps) | yes |
| zc.buildout | `prod.yaml` install step + `[versions]` | `2.13.3` | exact version | yes |
| setuptools | `prod.yaml` install step + `[versions]` | `44.1.1` | exact version | yes |
| Plone 4.3.20 versions | `prod.yaml` buildout heredoc | `extends = https://dist.plone.org/release/4.3.20/versions.cfg` | URL (live fetch — see Gaps) | yes |
| senaite.core, .core.listing, .core.spotlight, .core.supermodel, .impress, .jsonapi | `[versions]` block | exact (1.3.5 / 1.5.3 / 1.0.4 / 1.2.5 / 1.2.5 / 1.2.4) | exact | yes |
| Heritage Py2-only transitives | `[versions]` block + `pip install --no-deps --target=...` | exact (e.g. WeasyPrint 0.42.3, cairocffi 0.9.0, CairoSVG 1.0.20, Pyphen 0.9.5, openpyxl 2.6.4, requests 2.27.1, urllib3 1.26.18, certifi 2021.10.8, idna 2.10, magnitude 0.9.4, et_xmlfile 1.0.1, unittest2 1.1.0, pdfrw 0.4, chardet 4.0.0, beautifulsoup4 4.9.3, soupsieve 1.9.6, cssselect 1.1.0, Chameleon 3.9.1, z3c.pt 3.3.1, dicttoxml 1.7.4, z3c.jbot 1.1.1, backports.functools_lru_cache 1.6.6, five.pt 2.2.4, zopyx.txng3.ext 3.4.0, cffi 1.15.1, pycparser 2.21, zipp 1.2.0, zc.recipe.cmmi 1.3.6, zc.recipe.testrunner 2.2) | exact | yes (each block has rationale comment) |

## Status

- `just update-tools` — clean (no diff)
- `just lint-yaml` — passes
- No senaite/plone/cpython/buildout cruft leaked into `common/tool-versions.yaml`
  (build-host tools only, per Yakob 2026-05-03 routing decision)

## Known gaps (carried forward, not new findings)

These are already-acknowledged follow-ups; flagged here for completeness, not
fixed in this yak:

1. **python-2.7 base is tag-pinned, not digest-pinned.** `uses:
   ghcr.io/.../python-2.7:dev` resolves against whatever was last built/pushed.
   Comment block in `prod.yaml` calls this out as brittle; future fix is to
   pin a published GHCR component-tag digest.
2. **`buildout/versions.cfg` is an empty `[versions]` placeholder.** A
   transitive lock requires running buildout to completion and capturing
   `bin/buildout annotate`. Header of the file calls this out; tracked by the
   `populate senaite-2.3 versions.cfg lock` / `populate senaite-current
   versions.cfg lock` yaks (2.3 + current — no separate 1.3 yak yet).
3. **Plone versions.cfg `extends = https://dist.plone.org/release/4.3.20/versions.cfg`** is a live HTTPS fetch with no SHA-256. dist.plone.org tags
   are immutable in practice but the build relies on that promise.

— verified by Yakitty, 2026-05-08
