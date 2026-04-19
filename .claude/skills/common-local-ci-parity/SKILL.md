---
name: common-local-ci-parity
description: Use when a change adds, updates, or moves a tool used by the build pipeline, or adds CI logic that differs from local — e.g. "update hugo / grype / cosign / syft / crane / gitleaks / sbom-convert to latest", "bump tool version", "pin tool version", "add a new tool to the pipeline", "Python-based tool", "uv tool", "uvx", "install X in CI", "pip install in CI", "npm install -g in CI", "apt-get install in the workflow", "add a GitHub Action that runs X directly", writing a workflow step that replaces a local script, editing `common/tool-versions.yaml`, `common/tool-versions.lock.yaml`, `bin/`, shim scripts, or `.github/workflows/*`.
---

# Local = CI Parity

## The Principle

A developer running the pipeline locally must execute **the same tool binaries, at the same versions, invoked by the same scripts** as CI does. "Works on my machine, fails in CI" (and the reverse) is treated as a pipeline defect, not a local-environment quirk. CI is thin — it adds authentication, artefact flow, tagging, and publishing — but never replaces build logic.

## When This Applies

- Bumping, adding, or removing a tool used anywhere in the build, scan, or packaging pipeline.
- Writing a CI workflow step that inlines a build/scan/package command.
- Adding a step to a workflow that uses `apt-get`, `pip install`, `npm install -g`, `uv pip install`, or a third-party GitHub Action that replaces a local tool.
- Creating a new script or `just` target that is called only by CI, or only by local.
- Proposing "just use setup-X action" when the equivalent shim/binary already exists locally.

## Rules

1. **Tools are versioned by a spec + lock pair.**
   - A human-edited spec file declares the desired version (and download URL template for binaries, or simply `type: uvx` for PyPI tools).
   - A generated lock file records the resolved version plus an integrity mechanism (SHA-256 checksum for binaries; PyPI integrity via the package manager for uvx tools).
   - Both files are committed together. The lock file is the runtime source of truth.
2. **Every tool is reached through a shim.**
   - A per-tool script in `bin/` (which is on `PATH` locally and in CI) delegates to a generic shim that reads the lock file and runs the pinned version.
   - There are two shim shapes: one for binaries (download + checksum verify + cache), one for uvx/PyPI (read version, delegate to `uvx tool@version`).
   - No caller — local or CI — invokes the tool binary through any other path.
3. **Core build logic lives in scripts**, not in `just` recipes or workflow YAML. `just` targets and GitHub Actions steps call the same scripts.
4. **CI adds orchestration only.**
   - Authentication (registry logins, OIDC tokens).
   - Artefact flow (uploading/downloading between jobs).
   - Tagging, promotion, publishing.
   - Nothing that changes what gets built or how.
5. **CI-only steps (push, sign, attest) are dry-runnable locally.** The local run verifies prerequisites, resolves the real commands, and prints what CI would execute — without credentials.
6. **Updating a tool is a two-step dance.** Edit the version in the spec (or directly in the lock file for uvx tools), run the update command to refresh URLs/checksums, commit both files. Never hand-edit a resolved URL or checksum.
7. **Unified caches.** Tool binaries, tool databases (Grype DB, etc.), language caches (`uv`, Hugo), and SBOM enrichment outputs all live under a single project cache root so the same cache is reused across local runs, worktrees, and CI.

## Common Violations

- **`pip install sbomify-action` in a workflow step.** Use the uvx shim; add the tool via the spec+lock pattern.
- **A GitHub Action (`setup-hugo`, `install-grype-action`, etc.) used instead of the local shim.** CI must call the same shim `bin/hugo` / `bin/grype` as local. `setup-uv` is acceptable only because `uv` itself is the delivery mechanism — the tools `uv` runs still come from the shim path.
- **Pinning a tool version inside a workflow YAML.** The version lives in the lock file.
- **A `just` recipe with build logic in its body**, not delegated to a `scripts/` script. CI cannot share that logic; parity breaks.
- **A "setup" script that exists only for CI** (or only for local). Setup is the same: clone, direnv/`.envrc`, shims resolve on first use.
- **Sign / push / attest steps that have no local dry-run path.** They cannot be rehearsed, so they only surface in CI.
- **Hand-edited resolved URL or checksum in the lock file.** The lock file is generated. Re-run the update command.
- **Tool caches scattered across per-tool directories.** Unify them under the project cache root so the CI cache key is meaningful and worktrees share state.

## Decision Heuristics

- Before writing a workflow step, ask: "Can a developer reproduce this step locally by running the same command?" If no, the step is doing something only CI is allowed to do (auth, artefact flow, publishing) — or it is a violation.
- Before adding a third-party GitHub Action, ask: "Does this replace a tool I already have in `bin/`?" If yes, don't use it.
- If the pipeline starts to diverge (`just build-local` vs `just build-ci`), back up — the divergence is the bug.
