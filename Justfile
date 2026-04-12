# packages-dhi — DHI-native image pipeline
# Prerequisites: Docker (with buildx), Just

set dotenv-load := false

repo_root := justfile_directory()
manifest := repo_root / ".github/image-manifest.json"
artifacts_dir := repo_root / ".artifacts"

# ── Tool Wrappers ──────────────────────────────────
# All tools run via DHI hardened images for CI/local parity.
# Tool versions are pinned in .github/image-manifest.json

# Resolve the full image ref (image:tag) for a tool from the manifest
_tool-ref tool:
    @jq -r --arg name "{{tool}}" '.tools[] | select(.name == $name) | "\(.image):\(.tag)"' {{manifest}}

grype *ARGS:
    docker run --rm -v {{repo_root}}:/work -w /work $(just _tool-ref grype) {{ARGS}}

cosign *ARGS:
    docker run --rm -v {{repo_root}}:/work -w /work $(just _tool-ref cosign) {{ARGS}}

syft *ARGS:
    docker run --rm -v {{repo_root}}:/work -w /work $(just _tool-ref syft) {{ARGS}}

crane *ARGS:
    docker run --rm -v {{repo_root}}:/work -w /work $(just _tool-ref crane) {{ARGS}}

gitleaks *ARGS:
    docker run --rm -v {{repo_root}}:/work -w /work $(just _tool-ref gitleaks) {{ARGS}}

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

# ── Tool Management ────────────────────────────────

# Check for newer tool versions in the DHI registry
update-tools:
    #!/usr/bin/env bash
    set -euo pipefail
    manifest="{{manifest}}"
    tmp=$(mktemp)
    cp "$manifest" "$tmp"
    changed=0
    for row in $(jq -c '.tools[]' "$manifest"); do
        name=$(echo "$row" | jq -r '.name')
        image=$(echo "$row" | jq -r '.image')
        current_tag=$(echo "$row" | jq -r '.tag')
        # List tags from registry, pick the latest matching the same major prefix
        prefix=$(echo "$current_tag" | grep -oP '^\d+')
        latest_tag=$(docker run --rm $(jq -r --arg name crane '.tools[] | select(.name == $name) | "\(.image):\(.tag)"' "$manifest") ls --platform linux/amd64 "$image" 2>/dev/null \
            | grep -P "^${prefix}-" | sort -V | tail -1) || true
        if [ -z "$latest_tag" ]; then
            echo "  $name: $current_tag (no updates found)"
        elif [ "$latest_tag" = "$current_tag" ]; then
            echo "  $name: $current_tag (up to date)"
        else
            echo "  $name: $current_tag → $latest_tag"
            tmp2=$(mktemp)
            jq --arg name "$name" --arg tag "$latest_tag" \
                '(.tools[] | select(.name == $name)).tag = $tag | (.tools[] | select(.name == $name)).digest = ""' \
                "$tmp" > "$tmp2" && mv "$tmp2" "$tmp"
            changed=1
        fi
    done
    if [ "$changed" -eq 1 ]; then
        mv "$tmp" "$manifest"
        echo ""
        echo "Manifest updated. Run 'just pin-tool-digests' to resolve digests."
    else
        rm "$tmp"
        echo ""
        echo "All tools are up to date."
    fi

# Resolve SHA256 digests for all pinned tool versions
pin-tool-digests:
    #!/usr/bin/env bash
    set -euo pipefail
    manifest="{{manifest}}"
    crane_ref=$(jq -r '.tools[] | select(.name == "crane") | "\(.image):\(.tag)"' "$manifest")
    for row in $(jq -c '.tools[]' "$manifest"); do
        name=$(echo "$row" | jq -r '.name')
        image=$(echo "$row" | jq -r '.image')
        tag=$(echo "$row" | jq -r '.tag')
        ref="${image}:${tag}"
        digest=$(docker run --rm "$crane_ref" digest --platform linux/amd64 "$ref" 2>/dev/null) || true
        if [ -n "$digest" ]; then
            echo "  $name: $ref @ $digest"
            tmp=$(mktemp)
            jq --arg name "$name" --arg digest "$digest" \
                '(.tools[] | select(.name == $name)).digest = $digest' \
                "$manifest" > "$tmp" && mv "$tmp" "$manifest"
        else
            echo "  $name: $ref (failed to resolve digest)"
        fi
    done

# ── Info ───────────────────────────────────────────

# Show all images and their sources
images:
    @echo "=== DHI Tools ==="
    @jq -r '.tools[] | "  \(.name): \(.image):\(.tag) \(if .digest == "" then "(no digest)" else "@ \(.digest)" end)"' {{manifest}}
    @echo ""
    @echo "=== Stock DHI Images ==="
    @jq -r '.stock[] | "  \(.name): \(.source) @ \(if .digest == "" then "unpinned" else .digest end)"' {{manifest}}
    @echo ""
    @echo "=== Custom Images ==="
    @jq -r '.custom[] | "  \(.name): \(.definition) → \(.registry)"' {{manifest}}
