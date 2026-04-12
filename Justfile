# packages-dhi — DHI-native image pipeline
# Prerequisites: Docker (with buildx), Just

set dotenv-load := false

repo_root := justfile_directory()
manifest := repo_root / ".github/image-manifest.json"
artifacts_dir := repo_root / ".artifacts"

# ── Tool Wrappers ──────────────────────────────────
# All tools run via DHI hardened images for CI/local parity.

grype *ARGS:
    docker run --rm -v {{repo_root}}:/work -w /work dhi.io/grype {{ARGS}}

cosign *ARGS:
    docker run --rm -v {{repo_root}}:/work -w /work dhi.io/cosign {{ARGS}}

syft *ARGS:
    docker run --rm -v {{repo_root}}:/work -w /work dhi.io/syft {{ARGS}}

crane *ARGS:
    docker run --rm -v {{repo_root}}:/work -w /work dhi.io/crane {{ARGS}}

gitleaks *ARGS:
    docker run --rm -v {{repo_root}}:/work -w /work dhi.io/gitleaks {{ARGS}}

# ── Helpers ────────────────────────────────────────

# Resolve the DHI YAML path for a custom image name
_image-path image:
    @jq -r --arg name "{{image}}" '.custom[] | select(.name == $name) | .definition' {{manifest}}

# Resolve the registry for a custom image name
_image-registry image:
    @jq -r --arg name "{{image}}" '.custom[] | select(.name == $name) | .registry' {{manifest}}

# ── Build ──────────────────────────────────────────

# Build a custom DHI image locally
build image:
    #!/usr/bin/env bash
    set -euo pipefail
    def=$(just _image-path {{image}})
    reg=$(just _image-registry {{image}})
    echo "Building ${def} → ${reg}:dev"
    docker buildx build \
        -f "${def}" \
        --sbom=generator=dhi.io/scout-sbom-indexer:1 \
        --provenance=1 \
        --tag "${reg}:dev" \
        --load \
        .

# ── Scan ───────────────────────────────────────────

# Scan a custom image for vulnerabilities and secrets
scan image:
    #!/usr/bin/env bash
    set -euo pipefail
    reg=$(just _image-registry {{image}})
    echo "=== Grype vulnerability scan ==="
    just grype "${reg}:dev"
    echo "=== Gitleaks secrets scan ==="
    just gitleaks detect --source="${reg}:dev" || true

# Generate SPDX SBOM for a custom image
sbom-spdx image:
    #!/usr/bin/env bash
    set -euo pipefail
    reg=$(just _image-registry {{image}})
    mkdir -p {{artifacts_dir}}/{{image}}
    just syft "${reg}:dev" -o spdx-json > {{artifacts_dir}}/{{image}}/sbom.spdx.json

# ── Stock DHI Images ──────────────────────────────

# Extract attestations for all stock DHI images
extract-dhi-attestations:
    {{repo_root}}/scripts/extract-dhi-attestations

# Resolve and pin current digests for all stock DHI images
pin-digests:
    {{repo_root}}/scripts/pin-digests

# ── Release ────────────────────────────────────────

# Generate Hugo data files from build artifacts
release-data:
    {{repo_root}}/scripts/extract-release-data

# Build the release website locally
release-website:
    just release-data
    hugo --source apps/sbomify/release-website

# Assemble compliance pack ZIP
compliance-pack version:
    {{repo_root}}/scripts/build-compliance-pack {{version}}

# ── Info ───────────────────────────────────────────

# Show all images and their sources
images:
    @echo "=== Stock DHI Images ==="
    @jq -r '.stock[] | "  \(.name): \(.source) @ \(if .digest == "" then "unpinned" else .digest end)"' {{manifest}}
    @echo ""
    @echo "=== Custom Images ==="
    @jq -r '.custom[] | "  \(.name): \(.definition) → \(.registry)"' {{manifest}}
