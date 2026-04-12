# packages-dhi — DHI-native image pipeline
# Prerequisites: Docker (with buildx), Just, yq

set dotenv-load := false

repo_root := justfile_directory()
tool_manifest := repo_root / "common/tool-images.yaml"
app_manifest := repo_root / "apps/sbomify/app-images.yaml"
artifacts_dir := repo_root / ".artifacts"

# ── Helpers ────────────────────────────────────────

# Resolve the DHI YAML path for a custom image name (searches both manifests)
_image-path image:
    @yq -r '."{{image}}".definition | select(. != null)' {{tool_manifest}} {{app_manifest}} | head -1

# Resolve the registry for a custom image name (searches both manifests)
_image-registry image:
    @yq -r '."{{image}}".registry | select(. != null)' {{tool_manifest}} {{app_manifest}} | head -1

# ── Build ──────────────────────────────────────────

# Build all custom DHI images
build-all:
    #!/usr/bin/env bash
    set -euo pipefail
    for manifest in "{{tool_manifest}}" "{{app_manifest}}"; do
        for name in $(yq -r 'to_entries[] | select(.value | has("definition")) | .key' "$manifest"); do
            echo "=== Building ${name} ==="
            just build "$name"
        done
    done

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
    {{repo_root}}/bin/grype "${reg}:dev"
    echo "=== Gitleaks secrets scan ==="
    {{repo_root}}/bin/gitleaks detect --source="${reg}:dev" || true

# Generate SPDX SBOM for a custom image
sbom-spdx image:
    #!/usr/bin/env bash
    set -euo pipefail
    reg=$(just _image-registry {{image}})
    mkdir -p {{artifacts_dir}}/{{image}}
    {{repo_root}}/bin/syft "${reg}:dev" -o spdx-json > {{artifacts_dir}}/{{image}}/sbom.spdx.json

# ── Stock DHI Images ──────────────────────────────

# Extract attestations for all stock DHI images
extract-dhi-attestations:
    {{repo_root}}/scripts/extract-dhi-attestations

# ── Release ────────────────────────────────────────

# Generate Hugo data files from build artifacts
release-data:
    {{repo_root}}/scripts/extract-release-data

# Build the release website locally
release-website:
    just release-data
    {{repo_root}}/bin/hugo --source apps/sbomify/release-website --minify

# Serve the release website locally for preview
release-website-serve:
    just release-data
    {{repo_root}}/bin/hugo server --source apps/sbomify/release-website --bind 0.0.0.0 --port 1313

# Assemble compliance pack ZIP
compliance-pack version:
    {{repo_root}}/scripts/build-compliance-pack {{version}}

# ── Compose ───────────────────────────────────────

# Build digest-pinned docker-compose.yml from source + app-images.lock.yaml
build-sbomify-compose:
    #!/usr/bin/env bash
    set -euo pipefail
    lock="{{app_manifest}}"
    lock="${lock%.yaml}.lock.yaml"
    src="{{repo_root}}/apps/sbomify/deployments/docker-compose.yml"
    out="{{artifacts_dir}}/docker-compose.yml"
    mkdir -p "{{artifacts_dir}}"
    cp "$src" "$out"
    for name in $(yq -r 'to_entries[] | select(.value.source != null and .value.digest != null) | .key' "$lock"); do
        source=$(yq -r ".$name.source" "$lock")
        digest=$(yq -r ".$name.digest" "$lock")
        pinned="${source}@${digest}"
        echo "  ${name}: ${source} → ${pinned}"
        sed -i "s|image: ${source}|image: ${pinned}|g" "$out"
    done
    echo "Written to ${out}"

# ── Update ────────────────────────────────────────

# Update everything: tool versions, tool digests, app image digests, compose .env
update: update-tools update-app-images
    @echo ""
    @echo "=== Summary ==="
    @just images

# Check for newer tool versions and pin digests
update-tools:
    #!/usr/bin/env bash
    set -euo pipefail
    manifest="{{tool_manifest}}"
    lock="{{repo_root}}/common/tool-images.lock.yaml"

    echo "=== Checking tool versions ==="
    for name in $(yq -r 'to_entries[] | select(.value | has("image")) | .key' "$manifest"); do
        image=$(yq -r ".$name.image" "$manifest")
        current_tag=$(yq -r ".$name.tag" "$manifest")
        prefix=$(echo "$current_tag" | grep -oP '^\d+')
        latest_tag=$("{{repo_root}}/bin/crane" ls --platform linux/amd64 "$image" 2>/dev/null \
            | grep -P "^${prefix}-" | grep -vP '(dev|fips|rc|beta|alpha)' | sort -V | tail -1) || true
        if [ -z "$latest_tag" ]; then
            echo "  $name: $current_tag (no updates found)"
        elif [ "$latest_tag" = "$current_tag" ]; then
            echo "  $name: $current_tag (up to date)"
        else
            echo "  $name: $current_tag → $latest_tag"
            yq -i ".$name.tag = \"$latest_tag\"" "$manifest"
        fi
    done

    echo ""
    echo "=== Pinning tool digests ==="
    cp "$manifest" "$lock"
    sed -i '1i # AUTO-GENERATED by '\''just update-tools'\'' — do not edit' "$lock"
    for name in $(yq -r 'to_entries[] | select(.value | has("image")) | .key' "$manifest"); do
        image=$(yq -r ".$name.image" "$manifest")
        tag=$(yq -r ".$name.tag" "$manifest")
        ref="${image}:${tag}"
        digest=$("{{repo_root}}/bin/crane" digest --platform linux/amd64 "$ref" 2>/dev/null) || true
        if [ -n "$digest" ]; then
            echo "  $name: $ref @ $digest"
            yq -i ".$name.digest = \"$digest\"" "$lock"
        else
            echo "  $name: $ref (failed to resolve digest)"
        fi
    done

# Pin stock image digests and generate app lock file
update-app-images:
    #!/usr/bin/env bash
    set -euo pipefail
    manifest="{{app_manifest}}"
    lock="{{repo_root}}/apps/sbomify/app-images.lock.yaml"

    echo "=== Pinning app image digests ==="
    cp "$manifest" "$lock"
    sed -i '1i # AUTO-GENERATED by '\''just update-app-images'\'' — do not edit' "$lock"
    for name in $(yq -r 'to_entries[] | select(.value | has("source")) | .key' "$manifest"); do
        source=$(yq -r ".$name.source" "$manifest")
        echo -n "  $name ($source): "
        digest=$("{{repo_root}}/bin/crane" digest "$source" 2>/dev/null) || true
        if [ -n "$digest" ]; then
            echo "$digest"
            yq -i ".$name.digest = \"$digest\"" "$lock"
        else
            echo "(failed to resolve digest)"
        fi
    done

# ── Info ───────────────────────────────────────────

# List all custom image names as JSON array (for CI matrices)
custom-images:
    #!/usr/bin/env bash
    set -euo pipefail
    names=""
    for manifest in "{{tool_manifest}}" "{{app_manifest}}"; do
        names+=$(yq -r 'to_entries[] | select(.value | has("definition")) | .key' "$manifest")$'\n'
    done
    echo "$names" | grep -v '^$' | jq -cRn '[inputs]'

# List app custom image names as JSON array (for CI matrices)
custom-app-images:
    @yq -o=json -I0 '[to_entries[] | select(.value | has("definition")) | .key]' {{app_manifest}}

# Show all images and their sources
images:
    @echo "=== Tools ==="
    @yq -r 'to_entries[] | select(.value | has("image")) | "  \(.key): \(.value.image):\(.value.tag)"' {{tool_manifest}}
    @echo ""
    @echo "=== Stock Images ==="
    @yq -r 'to_entries[] | select(.value | has("source")) | "  \(.key): \(.value.source)"' {{app_manifest}}
    @echo ""
    @echo "=== Custom Images ==="
    @for manifest in "{{tool_manifest}}" "{{app_manifest}}"; do \
        yq -r 'to_entries[] | select(.value | has("definition")) | "  \(.key): \(.value.definition) → \(.value.registry)"' "$manifest"; \
    done
