# ci module — orchestration targets mirroring the GitHub Actions build pipeline.
# Target names match GHA step names. CI-only steps (push, sign, attest)
# run as dry-runs locally.

repo_root := justfile_directory()
app_manifest := repo_root / "apps/sbomify/app-images.yaml"
artifacts_dir := repo_root / "artifacts"

# ── Full pipeline ─────────────────────────────────────────────

# Run the full CI build pipeline for a single image
build image: (build-image image) (generate-compliance-artifacts image) (compute-component-tag image) (push-to-ghcr image) (sign-image image) (attest-sbom image) (attest-provenance image)

# Run the full CI build pipeline for all custom images
build-all:
    #!/usr/bin/env bash
    set -euo pipefail
    for name in $({{repo_root}}/scripts/list-custom-images | jq -r '.[]'); do
        echo ""
        echo "=========================================="
        echo "=== Building ${name}"
        echo "=========================================="
        just ci build "$name"
    done

# ── Build phases ──────────────────────────────────────────────

# Build image (docker buildx)
build-image image:
    {{repo_root}}/scripts/build-image --image {{image}}

# Generate compliance artifacts (extract, convert, enrich, scan)
generate-compliance-artifacts image:
    {{repo_root}}/scripts/generate-compliance-artifacts --image {{image}}

# ── Stock DHI images ──────────────────────────────────────────

# Extract attestations for all stock DHI images
extract-dhi-attestations:
    {{repo_root}}/scripts/extract-dhi-attestations

# ── Helpers ───────────────────────────────────────────────────

_image-registry image:
    @yq -r '."{{image}}".registry | select(. != null)' {{app_manifest}}

_component-tag image:
    #!/usr/bin/env bash
    set -euo pipefail
    SHA7=$(git rev-parse --short=7 HEAD)
    DEF=$(yq -r '."{{image}}".definition | select(. != null)' "{{app_manifest}}")
    VERSION=$(grep -oP 'git\+https://[^#]+#\K[^"]+' "$DEF" 2>/dev/null | head -1 || true)
    [ -z "$VERSION" ] && VERSION="unknown"
    echo "{{image}}-${VERSION}-${SHA7}"

# ── CI-only steps (dry-run locally) ───────────────────────────

# Compute and display the component tag for an image
compute-component-tag image:
    #!/usr/bin/env bash
    set -euo pipefail
    TAG=$(just ci _component-tag "{{image}}")
    REG=$(just ci _image-registry "{{image}}")
    echo "==> Component tag: ${TAG}"
    echo "==> Registry: ${REG}"

# Push image to GHCR with component tag
push-to-ghcr image:
    #!/usr/bin/env bash
    set -euo pipefail
    TAG=$(just ci _component-tag "{{image}}")
    REG=$(just ci _image-registry "{{image}}")
    if [ "${CI:-}" = "true" ]; then
        docker tag "${REG}:dev" "${REG}:${TAG}"
        docker push "${REG}:${TAG}"
    else
        echo "[DRY-RUN] docker tag ${REG}:dev ${REG}:${TAG}"
        echo "[DRY-RUN] docker push ${REG}:${TAG}"
    fi

# Sign image with cosign
sign-image image:
    #!/usr/bin/env bash
    set -euo pipefail
    TAG=$(just ci _component-tag "{{image}}")
    REG=$(just ci _image-registry "{{image}}")
    "{{repo_root}}/bin/cosign" version > /dev/null 2>&1 || { echo "ERROR: cosign not available" >&2; exit 1; }
    if [ "${CI:-}" = "true" ]; then
        "{{repo_root}}/bin/cosign" sign --yes "${REG}:${TAG}"
    else
        echo "[DRY-RUN] cosign sign --yes ${REG}:${TAG}"
    fi

# Attest SBOM to image
attest-sbom image:
    #!/usr/bin/env bash
    set -euo pipefail
    TAG=$(just ci _component-tag "{{image}}")
    REG=$(just ci _image-registry "{{image}}")
    SBOM="{{artifacts_dir}}/{{image}}/sbom.cdx.json"
    [ -f "$SBOM" ] || { echo "ERROR: SBOM not found at ${SBOM}" >&2; exit 1; }
    if [ "${CI:-}" = "true" ]; then
        "{{repo_root}}/bin/cosign" attest --yes --type cyclonedx --predicate "$SBOM" "${REG}:${TAG}"
    else
        echo "[DRY-RUN] cosign attest --yes --type cyclonedx --predicate ${SBOM} ${REG}:${TAG}"
    fi

# Attest provenance to image
attest-provenance image:
    #!/usr/bin/env bash
    set -euo pipefail
    TAG=$(just ci _component-tag "{{image}}")
    REG=$(just ci _image-registry "{{image}}")
    PROVENANCE="{{artifacts_dir}}/{{image}}/provenance.slsa.json"
    [ -f "$PROVENANCE" ] || { echo "ERROR: provenance not found at ${PROVENANCE}" >&2; exit 1; }
    if [ "${CI:-}" = "true" ]; then
        "{{repo_root}}/bin/cosign" attest --yes --type slsaprovenance --predicate "$PROVENANCE" "${REG}:${TAG}"
    else
        echo "[DRY-RUN] cosign attest --yes --type slsaprovenance --predicate ${PROVENANCE} ${REG}:${TAG}"
    fi
