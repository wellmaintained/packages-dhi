# 0007. Enrich SBOMs with sbomify-action

Date: 2026-04-14

## Status

accepted

## Context

The DHI build pipeline produces SBOMs via docker-scout that have broad
ecosystem coverage (Python, Go, npm, Debian OS packages) but are weak on
metadata enrichment. A comparison against the sbomify trust centre SBOMs
showed significant quality gaps:

- 42% of components have licenses (vs 87% in trust centre)
- 5% have descriptions (vs 87%)
- 13% have supplier info (vs 87%)
- 0% have external references (vs 87%)
- No lifecycle (end-of-support, end-of-life) data
- All components typed as `application` rather than `library`/`framework`

The sbomify-action tool (github.com/sbomify/sbomify-action) can enrich an
existing SBOM with metadata from public registries (PyPI, deps.dev,
crates.io, ClearlyDefined, Repology, and others) without requiring an
sbomify account.

## Decision

Enrich the CycloneDX SBOMs produced by the existing pipeline using
sbomify-action's `--sbom-file` mode with `--enrich --no-upload`. The
enrichment runs as the final step of SBOM production, overwriting the
CycloneDX file in place. The raw SPDX SBOM from docker-scout is preserved
unchanged as the original source of truth.

### Enrich after conversion, not before

The enrichment step runs on the CycloneDX SBOM (after sbom-convert), not on
the raw SPDX. sbomify-action's enrichment is CycloneDX-native — its property
names (`cdx:lifecycle:milestone:*`, `sbomify:enrichment:source`) and
metadata fields map directly to CycloneDX structures. Running enrichment on
SPDX and then converting risks the converter dropping enrichment-added
fields that it does not know how to map.

### Both stock and custom images

Both custom-built images (via `just build`) and stock DHI images (via
`just extract-dhi-attestations`) are enriched through the same tool and
shim. Stock images benefit equally — their attestation-extracted SBOMs have
the same metadata gaps.

## Consequences

- SBOMs gain descriptions, licenses, supplier info, external references,
  and lifecycle data for components where public registry data exists.
  Enrichment is best-effort — private or vendored packages will not be
  enriched.
- The enrichment step requires network access to public package registries
  during both local builds and CI. This is acceptable since the pipeline
  already requires Docker registry access.
- The raw SPDX SBOM (`sbom.spdx.json`) remains the unmodified source of
  truth from docker-scout. The CycloneDX SBOM (`sbom.cdx.json`) is both
  converted and enriched — there is no separate unenriched CycloneDX file.
- sbomify-action is packaged via `uvx` (see ADR-0008).
