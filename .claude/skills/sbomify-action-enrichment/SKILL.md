---
name: sbomify-action-enrichment
description: Use when a change touches how SBOMs are enriched in this repo — e.g. "enrich the CycloneDX SBOM", "bump the sbomify-action version", "replace sbomify-action with another enrichment tool", "swap the enrichment step for X", "enrichment is failing with a license-expression error", "add the enrichment step to extract-dhi-attestations", "uvx sbomify-action flags", "why does enrichment run in-place", editing `bin/sbomify-action`, `common/scripts/uvx-shim.bash`, `common/tool-versions.lock.yaml` (the sbomify-action entry), or the enrichment portion of `scripts/generate-compliance-artifacts`.
---

# sbomify-action Enrichment Mechanism

## The Mechanism

SBOM enrichment in this repo is performed by the `sbomify-action` PyPI package, invoked through `uvx` at a pinned version, operating on the CycloneDX SBOM produced by the format conversion step. The enrichment call is:

```
sbomify-action --sbom-file <artifacts/<image>/sbom.cdx.json> --enrich --no-upload
```

It overwrites `sbom.cdx.json` in place with the enriched version. The raw SPDX SBOM (`sbom.spdx.json`) is not touched. `--no-upload` keeps the tool offline-friendly: no sbomify-account call is required. Both custom-built images and stock DHI images go through the same enrichment shim, since both carry attestation-extracted SBOMs with identical metadata gaps.

## Implements

- `common-sbom-enrichment` — enrichment runs on the converted CycloneDX file, not on the raw SPDX. The raw SBOM is preserved.
- `common-local-ci-parity` — the tool is accessed via a shim in `bin/`, versioned by the spec+lock pattern, so local and CI runs enrich identically.

## Files / Tools Involved

- `bin/sbomify-action` — per-tool shim. Reads the pinned version from `common/tool-versions.lock.yaml`, invokes `uvx sbomify-action@<version> ...`. Contains a conditional in-place fix for a known bug in versions ≤ 26.1.0 where compound SPDX license expressions (`A OR B`) land as `license.id` instead of `license.expression`; the shim rewrites such fields in the output CycloneDX file after enrichment.
- `common/scripts/uvx-shim.bash` — generic dispatcher that other uvx-typed tools (yamllint, future additions) also use.
- `common/tool-versions.lock.yaml` — carries the `sbomify-action.version` pin. There is no checksum entry (PyPI handles integrity). There is no spec-file entry for uvx tools — the lock file is edited directly to bump the version.
- `scripts/generate-compliance-artifacts` — orchestrates extract → convert → **enrich** (calls `sbomify-action`) → scan. Caches the enriched CycloneDX keyed on SPDX content hash + tool versions, so identical inputs short-circuit both conversion and enrichment.
- `scripts/extract-dhi-attestations` — pulls stock-image SBOMs and feeds them through the same enrichment path as custom builds.

## Procedure: bumping the sbomify-action version

1. Read the current version in `common/tool-versions.lock.yaml` (`sbomify-action.version`). uvx-typed tools are versioned only in the lock file, not in the spec.
2. Edit the lock file directly, setting the new version.
3. If the new version crosses the 26.1.0 boundary, check whether the compound-license workaround in `bin/sbomify-action` is still needed; if the upstream fix shipped, simplify the shim.
4. Re-run `just build <image>` for at least one image whose SBOM contains compound license expressions (e.g. GPL-2.0 OR MIT in a dependency) and verify the enriched `sbom.cdx.json` is valid CycloneDX.
5. Commit `common/tool-versions.lock.yaml` (and any `bin/sbomify-action` change) together.

## Procedure: replacing sbomify-action with a different enrichment tool

1. Confirm the candidate tool operates on CycloneDX in place (or can be wrapped to). If it only enriches SPDX, it does not fit — enrichment here runs on the converted format, by design.
2. Add the new tool to `common/tool-versions.yaml` (and `lock.yaml`) via the appropriate `type:` (binary or `uvx`) and add a `bin/<tool>` shim.
3. Replace the `sbomify-action` invocation in `scripts/generate-compliance-artifacts` with the new tool's equivalent `--sbom-file --enrich --no-upload`-style invocation, preserving the in-place overwrite of `sbom.cdx.json` and leaving the raw SPDX untouched.
4. Invalidate the enrichment cache by changing the cache key component that identifies the enrichment tool version.
5. Remove the `bin/sbomify-action` shim and the compound-license workaround once no code references it.

## Notes

- The enrichment step requires network access to public package registries (PyPI, deps.dev, ClearlyDefined, Repology, etc.). This is acceptable — the build pipeline already requires network access for the container registry.
- Enrichment is best-effort: private or vendored components for which no public metadata exists remain as they were. This is expected behaviour; it must not fail the build.
- There is no separate "unenriched CycloneDX" file shipped — the release contains the raw SPDX and the converted+enriched CycloneDX, which together are the two SBOM artefacts per image.
