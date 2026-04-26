# Architecture Decision Records

ADRs document significant architectural and design decisions.

## Index

| # | Decision | Status |
|---|----------|--------|
| [0001](0001-adopt-dhi-base-images.md) | Adopt Docker Hardened Images as Base Image Foundation | accepted |
| [0002](0002-build-once-promotion-pipeline.md) | Build-Once Promotion Pipeline | accepted |
| [0003](0003-derive-sboms-from-build-attestations.md) | Derive SBOMs from DHI Build Attestations | accepted |
| [0004](0004-unified-build-produces-all-compliance-artifacts.md) | Unified Build Produces All Compliance Artifacts | accepted |
| [0005](0005-build-website-at-pre-release-deploy-from-artifact.md) | Build Release Website at Pre-Release, Deploy from Artifact | accepted |
| [0006](0006-local-ci-parity.md) | Local and CI Parity | accepted |
| [0007](0007-enrich-sboms-with-sbomify-action.md) | Enrich SBOMs with sbomify-action | accepted |
| [0008](0008-uvx-tool-packaging.md) | uvx tool packaging for Python-based tools | accepted |
| [0009](0009-publish-vex-not-point-in-time-cves.md) | Publish VEX, Not Point-in-Time CVE Lists | proposed |

## When to Write an ADR

Write an ADR when making decisions that:
- Change the architecture or core design patterns
- Introduce new dependencies or technologies
- Affect multiple components or the public API
- Have long-term maintenance implications
- Future maintainers will ask "why did we do it this way?"

Not for: minor implementation details, bug fixes, refactoring,
configuration changes.
