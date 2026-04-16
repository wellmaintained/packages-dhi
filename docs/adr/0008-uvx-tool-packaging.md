# 0008. uvx tool packaging for Python-based tools

Date: 2026-04-15

## Status

accepted

## Context

The tool-versions system (ADR-0006) manages binary tools by downloading
platform-specific archives, verifying SHA-256 checksums, and caching them
locally. Some tools (sbomify-action, yamllint) are Python packages
distributed via PyPI rather than standalone binaries.

Managing a Python virtualenv per tool would add complexity. `uvx` (from
the `uv` package manager) can run any PyPI package at a pinned version
as a one-liner: `uvx tool@version`, with PyPI handling integrity
verification.

## Decision

Introduce a `type: uvx` tool type alongside the existing binary tools.

### Spec vs lock file

Binary tools declare their version in `tool-versions.yaml` (the spec),
and `just update-tools` resolves URLs and checksums into the lock file.
uvx tools have no URL or checksum to resolve, so their version lives
directly in `tool-versions.lock.yaml`. The spec file declares only the
tool name and `type: uvx`.

`just update-tools` preserves uvx versions from the existing lock file
when regenerating.

### Shim architecture

A generic `common/scripts/uvx-shim.bash` reads the version from the lock
file and runs `uvx tool@version`. Per-tool shims in `bin/` (e.g.,
`bin/sbomify-action`, `bin/yamllint`) delegate to `uvx-shim.bash` — the
same pattern as binary tools delegating to `tool-shim.bash`.

### CI

CI gains `uvx` via `astral-sh/setup-uv` in the setup-pipeline action.
No other workflow changes are needed since tools are invoked through the
existing shims.

## Consequences

- Python-based tools can be added to the pipeline without managing
  virtualenvs or downloading platform-specific binaries.
- `uv` becomes an implicit runtime dependency of the pipeline, added to
  CI via `astral-sh/setup-uv` and to local prerequisites alongside
  Docker, Just, and yq.
- PyPI handles integrity verification; there are no SHA-256 checksums
  in the lock file for uvx tools.
- To bump a uvx tool version, edit `tool-versions.lock.yaml` directly
  (not the spec file).
