# `find` scope audit — scripts/ + ci/

Date: 2026-05-08
Author: Yakira (nightshift, supervised-by David Laing)

## Why

Yaktor's commit 6dd5b32 (2026-05-04) tightened
`scripts/generate-compliance-artifacts` to scope its VEX `find` to
`apps/${APP}/images/` + `common/images/`. Pre-fix, the unscoped find
walked the whole repo and returned the first `<image>.vex.json` hit —
fine when only one app shipped, ambiguous now that four apps
(`sbomify-current`, `senaite-1.3`, `senaite-2.3`, `senaite-current`)
each ship a `senaite-lims` image with its own VEX.

This audit walks every shell script under `scripts/`, every recipe
under `ci/`, and the top-level `Justfile`, asking: does any other
broad scan (find, glob, loop) leak across apps the way the original
VEX find did?

## Method

```
rg -n '\bfind\b' scripts/ ci/ Justfile common/scripts/ .github/
rg -n 'apps/' scripts/ ci/ common/scripts/
```

For each invocation, classify scope as one of:

- **per-APP** — rooted at `apps/${APP}/...` (or `${APP_*}` derived var)
- **artifacts-scoped** — iterates `${ARTIFACTS}/*/`, which is per-build
  (CI populates artifacts for one APP per workflow run)
- **registry-scoped** — operates on GHCR / OCI image refs, no
  filesystem APP concept
- **intentionally repo-wide** — by design covers all apps
- **latent bug** — unscoped where it should be scoped

## Findings

| File / line | Pattern | Scope | Verdict |
|---|---|---|---|
| `scripts/generate-compliance-artifacts:128` | `find apps/${APP}/images common/images -name '${IMAGE}.vex.json'` | per-APP + common | already fixed (6dd5b32) ✓ |
| `Justfile:169` (`lint-yaml`) | `find {{repo_root}} -name '*.yaml' -o -name '*.yml'` | intentionally repo-wide | correct — lint covers every app |
| `scripts/extract-release-data:130,165,282` | `for dir in "${ARTIFACTS}"/*/` | artifacts-scoped | correct — `${ARTIFACTS}` is per-build |
| `scripts/build-compliance-pack:26` | `for dir in "${ARTIFACTS}"/*/` | artifacts-scoped | correct |
| `scripts/extract-dhi-attestations` | reads `apps/${APP}/app-images.lock.yaml` | per-APP | correct |
| `scripts/build-image` | reads `apps/${APP}/app-images.yaml` | per-APP | correct |
| `scripts/list-custom-images` | reads `apps/${APP}/app-images.yaml` | per-APP | correct |
| `scripts/create-release-notes` | reads `apps/${APP}/app-images.yaml` | per-APP | correct |
| `scripts/build-compliance-pack` | reads `apps/${APP}/...` | per-APP | correct |
| `scripts/cleanup-stale-images` | GHCR API sweep | registry-scoped | N/A — no APP concept |
| `scripts/resolve-component-tag` | `crane ls REGISTRY` | registry-scoped | N/A |
| `scripts/tag-app-collection` | `crane tag REGISTRY@DIGEST` | registry-scoped | N/A |
| `ci/mod.just` | uses `{{app}}` throughout | per-APP | correct |
| `common/scripts/{enrich-sbom,tool-shim,uvx-shim}.bash` | no `find`, no `apps/` refs | shared | N/A — no APP concept |

No `apps/` reference in `scripts/` or `ci/` is unscoped. No `find`
invocation in `scripts/` or `ci/` walks the whole repo other than the
already-fixed line in `generate-compliance-artifacts`.

## Conclusion

**No latent bugs found.** Yaktor's 6dd5b32 was the single
find-scope-sensitive script in this codebase. Every other script
either:

- starts from `apps/${APP}/...` (per-APP work),
- iterates `${ARTIFACTS}/*/` (per-build, single APP populates that
  directory), or
- works against the registry (no filesystem APP concept).

The one repo-wide `find` (`Justfile:lint-yaml`) is intentional — YAML
lint is meant to cover every app — and is not VEX-shaped (matches
file extension, not a per-image artefact name).

## Out of scope (noted for future yaks)

- Adding shell tests / shellcheck rules that enforce
  `apps/${APP}/...` rooting in scripts.
- Sniff-test against `APP=senaite-current` (or another app) once the
  build pipeline is wired for non-sbomify apps; today only
  `sbomify-current` runs end-to-end, so the worst-case "VEX collision
  across apps" can't actually be exercised yet.
