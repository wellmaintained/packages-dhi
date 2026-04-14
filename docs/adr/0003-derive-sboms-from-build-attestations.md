# 0003. Derive SBOMs from DHI Build Attestations

Date: 2026-04-13

## Status

accepted

## Context

Container images built with DHI's build frontend and `--sbom=generator=dhi.io/scout-sbom-indexer:1`
embed an SPDX SBOM and SLSA provenance as OCI attestation layers. A separate
tool (syft) can also scan the built image to produce its own SBOM, but this
creates two independent descriptions of the same image that may disagree.

The DHI-produced SBOM is authoritative — it understands the DHI build format,
tracks packages installed via the DHI YAML definition, and includes file-level
detail with full relationship data.

## Decision

Extract the SPDX SBOM and SLSA provenance directly from the build attestation
layers embedded in the image, rather than generating independent SBOMs by
scanning the image with syft.

For CycloneDX format (needed for consistency with stock DHI images), convert the
extracted SPDX SBOM using protobom/sbom-convert, which preserves the dependency
relationships. The syft convert command was evaluated but drops all relationship
data during conversion.

The Grype vulnerability scan runs against the CycloneDX SBOM, ensuring
vulnerability findings trace back to the same authoritative component list.

## Consequences

- Both SBOM formats (SPDX and CycloneDX) derive from the same DHI build
  attestation. There is one source of truth for what is in the image.
- The SPDX SBOM includes file-level detail and relationships that the CycloneDX
  conversion preserves (protobom/sbom-convert maps SPDX relationships to
  CycloneDX dependencies).
- The BuildKit SBOM generator protocol only supports SPDX output. CycloneDX
  cannot be produced directly during the build.
- protobom/sbom-convert is added as a custom DHI tool image for the conversion
  step.
