# 0004. Unified Build Produces All Compliance Artifacts

Date: 2026-04-13

## Status

accepted

## Context

Compliance artifacts for a container image — SBOMs, provenance, vulnerability
scans, secrets scans — were originally produced by separate commands (`just
build`, `just scan`, `just sbom-spdx`) run independently. This created several
problems:

- Artifacts could get out of sync if one step was skipped or failed.
- The workflow required callers to know the correct sequence of commands.
- The image tar was exported multiple times for different tools.

## Decision

`just build <image>` produces the image and all compliance artifacts in a single
invocation. The output directory `artifacts/<image>/` contains everything needed
for compliance after one command:

1. Build the Docker image with DHI SBOM and provenance attestations.
2. Export the image to a tar file.
3. Extract the SPDX SBOM and SLSA provenance from the build attestations.
4. Convert SPDX to CycloneDX via protobom/sbom-convert.
5. Run Grype CVE scan against the CycloneDX SBOM.
6. Run Gitleaks secrets scan against the image tar.
7. Copy VEX file if one exists for the image.

The separate `scan` and `sbom-spdx` targets were removed.

## Consequences

- One command produces a complete, consistent set of artifacts. No partial state.
- CI workflows call `just build` once per image. No separate scan or SBOM steps.
- The image tar remains in `artifacts/<image>/` for debugging and secrets
  scanning.
- Local and CI builds produce identical artifact sets.
