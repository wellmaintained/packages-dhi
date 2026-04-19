---
name: common-sbom-enrichment
description: Use when a change enriches SBOMs with metadata (licenses, descriptions, suppliers, external references, lifecycle data), or touches the order of conversion vs. enrichment — e.g. "enrich the SBOMs", "improve SBOM quality", "fill in component metadata", "add license / supplier / description fields", "enrich before converting", "enrich SPDX then convert", "overwrite the raw SBOM with enriched data", "add an enrichment step", "backfill SBOM metadata", or editing files matching `scripts/generate-compliance-*`, `scripts/*-enrich*`, `bin/*-enrich*`, `bin/sbomify*`, or any enrichment shim.
---

# Enrich After Conversion, Keep the Raw

## The Principle

Metadata enrichment (licences, descriptions, suppliers, external references, lifecycle data) runs **on the converted format**, after format conversion is complete, and is allowed to overwrite that converted file in place. The **raw build-time SBOM is never modified** — it stays on disk exactly as produced by the build, as the unmodified source of truth.

## When This Applies

- Adding or changing an enrichment step that adds component metadata from public registries.
- Deciding the order of conversion and enrichment in the compliance pipeline.
- Running enrichment on the raw SBOM format to "enrich everything earlier".
- Overwriting the raw build SBOM with an enriched version "since it's better now".
- Adding a new enrichment source or replacing the existing enrichment tool.
- Caching the enrichment output.

## Rules

1. **Two artefacts exist per image:** the raw SBOM as produced by the build (typically SPDX), and the converted+enriched SBOM in the target format (typically CycloneDX). Both ship; each serves a distinct purpose.
2. **Enrichment runs on the converted format, as the final SBOM step**, not on the raw build SBOM. The converted format is the one downstream consumers read; it is the right place for added metadata.
3. **The raw SBOM is immutable.** It is not the target of enrichment. It is not mutated by any step after the build. It is the unmodified source of truth.
4. **Enrichment is best-effort.** Components that cannot be looked up in public registries remain as they were — enrichment does not fail the build for private or vendored packages.
5. **Enrichment is additive.** It does not remove or invalidate existing fields; it fills gaps.
6. **The enrichment output is cacheable**, keyed on (raw SBOM content + tool versions). Identical inputs must produce identical enriched output.

## Common Violations

- **Running enrichment on the raw SBOM before conversion.** The converter may not understand enrichment-added fields in the source format and will drop them. Result: enrichment work is lost.
- **Converting the enriched SBOM into additional formats.** That makes the converter responsible for preserving enrichment metadata it was not designed for. Do the enrichment **per target format**, on the converted file.
- **Overwriting the raw SBOM with the enriched version.** Breaks the guarantee that the raw is the unmodified build output.
- **Publishing only the enriched SBOM.** Consumers who want to verify provenance need the raw one too. Ship both.
- **An enrichment step that fails the build when a component cannot be enriched.** Enrichment is best-effort; missing metadata is an expected state.
- **A cache keyed on the output file path rather than on input content + tool versions.** Produces stale enrichment after an underlying data source updates.
- **Enrichment running as a post-release step.** Enrichment belongs in the unified build, so the enriched SBOM is what flows through the release pipeline.

## Decision Heuristics

- Order: **build → extract raw SBOM → convert → enrich → scan**. Anything that rearranges that order is probably a violation; look closely.
- If an enrichment added field disappears between two pipeline stages, check whether enrichment ran before a conversion.
- If someone proposes "let's just enrich the raw SBOM — it's richer", explain that enrichment is format-specific and that the raw is the preserved source of truth. Enrich the converted copy instead.
- If you are writing code that mutates the raw SBOM after it was extracted, stop.
- If a new enrichment tool only operates on the raw format, treat that as a mismatch to solve — either convert before enriching (preserving the raw) or pick a tool that handles the target format.

## Why "keep the raw"

The raw build SBOM is the one artefact in the release that is provably a direct product of the build process. Everything downstream of it — conversion, enrichment, scan — is interpretation layered on top. Preserving the raw means that if any layer above it is later found to be wrong, the ground truth is still present, immutable, and independently verifiable. Enrichment is valuable; it is also optional in a way that the raw SBOM is not.
