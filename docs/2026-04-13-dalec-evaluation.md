# ADR: Dalec Evaluation for Container Image Builds

## Status

Decided — staying with DHI tooling.

## Context

We evaluated [Dalec](https://github.com/project-dalec/dalec) (v0.20.4) as an alternative to our DHI-based image pipeline, using MinIO as the test case. Two capabilities motivated the experiment:

1. **Network-isolated compilation** — Dalec's `network_mode: "none"` prevents build steps from reaching the network, with Go modules pre-fetched via a `gomod` generator
2. **SBOM quality** — whether Dalec's declarative source tracking produces richer SBOMs than post-build binary analysis

## Experiment

We built a complete Dalec spec (`common/images/minio-by-dalec/dalec.yaml`) that:
- Compiles both minio server and mc client from source
- Uses Go 1.26.2 via an `http` source with sha256 digest verification
- Pre-fetches Go modules with `gomod` generators
- Compiles with `network_mode: "none"`
- Targets `trixie/testing/container` (Debian 13)

The image built successfully. Both binaries passed smoke tests.

## Findings

### Network isolation works, but DHI already supports it

Dalec's `network_mode: "none"` delivers on its promise — compilation runs with no network access. However, DHI's pipeline steps already support the same pattern: use `privileged: true` for a dependency download step, then omit `privileged` for the compile step (which runs hermetically by default). We implemented this split across all our DHI specs in commit `5f58d34`.

### SBOM quality is identical

Both the Dalec build's BuildKit-native SBOM (from attestation) and a syft post-scan produce **426 packages** (82 Debian + 344 Go modules). This is because BuildKit uses syft internally (`docker/buildkit-syft-scanner:stable-1`) regardless of whether Dalec or DHI is the frontend.

The `gomod` generator does not feed dependency information into the SBOM. The SBOM comes entirely from syft scanning the final container image — reverse-engineering Go modules from compiled binaries. So Dalec's declarative source tracking doesn't currently improve SBOM coverage over DHI's approach.

The BuildKit-native SBOM does include **4,576 file-level entries** (full filesystem inventory) that a standalone syft post-scan omits, plus SLSA provenance. But DHI already extracts these same attestations.

### Container base image is bloated

Dalec's Debian container target (`trixie/testing/container`) installs the `.deb` package into a full Debian base — **82 OS packages** including apt, bash, coreutils, dpkg, grep, sed, etc. Our DHI minio image has only **27 OS packages** (base-files, ca-certificates, and their minimal dependencies). Dalec doesn't offer a way to specify a minimal or distroless base image.

A two-stage approach (Dalec builds `.deb`, DHI installs binaries into minimal base) is possible but adds significant pipeline complexity: the `.deb` must be published to an HTTPS URL between stages, since DHI's `contents.files[].url` doesn't support local file references.

### Dalec spec quirks discovered

- `cmd` field must be a string, not a YAML array
- `${PATH}` in `build.env` is treated as a build arg reference, not a shell variable
- `${VAR:0:12}` bashism fails — build steps run in `/bin/sh`
- `args` values are expanded during spec resolution but not available as shell variables in build steps — must be passed through `build.env`
- Debian targets default to `.deb` output, not a container — use `trixie/testing/container` for containers
- RPM targets (azlinux3) pull ~500MB of build toolchain, making cold builds very slow (~30+ min just for package installation)

## Decision

Stay with DHI tooling. The hermetic compilation requirement is satisfied by splitting DHI pipeline steps into privileged download + hermetic compile, which is simpler than introducing a second build system.

## What would make us reconsider

- **Dalec supports minimal/distroless base images** — if Dalec could produce containers with a DHI-like minimal base (just base-files + ca-certificates), the single-spec simplicity would be compelling
- **Dalec's gomod generator feeds into the SBOM** — if Go module dependencies from source resolution appeared in the SBOM (rather than relying on binary analysis), that would provide genuinely richer supply chain metadata than DHI + syft
- **Dalec supports local file sources** — if the two-stage approach (Dalec `.deb` → DHI container) didn't require publishing to HTTPS, it would be more practical

## References

- Dalec experiment spec: `common/images/minio-by-dalec/dalec.yaml`
- Dalec experiment Justfile recipe: `build-minio-dalec`
- Hermetic build split: commit `5f58d34`
- Dalec project: https://github.com/project-dalec/dalec
- Dalec targets: https://project-dalec.github.io/dalec/targets
