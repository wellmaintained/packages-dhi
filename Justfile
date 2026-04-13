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

# Build a custom DHI image and produce all compliance artifacts
build image:
    #!/usr/bin/env bash
    set -euo pipefail
    def=$(just _image-path {{image}})
    reg=$(just _image-registry {{image}})
    out="{{artifacts_dir}}/{{image}}"
    mkdir -p "$out"

    echo "=== Building ${def} → ${reg}:dev ==="
    docker buildx build \
        -f "${def}" \
        --platform linux/amd64 \
        --sbom=generator=dhi.io/scout-sbom-indexer:1 \
        --provenance=1 \
        --tag "${reg}:dev" \
        --load \
        .

    # Export image as tar so containerised tools can access it
    echo ""
    echo "=== Exporting image for scanning ==="
    docker save "${reg}:dev" -o "${out}/image.tar"

    echo ""
    echo "=== Generating CycloneDX SBOM ==="
    {{repo_root}}/bin/syft "docker-archive:/work/.artifacts/{{image}}/image.tar" -o cyclonedx-json > "${out}/sbom.cdx.json"

    echo ""
    echo "=== Generating SPDX SBOM ==="
    {{repo_root}}/bin/syft "docker-archive:/work/.artifacts/{{image}}/image.tar" -o spdx-json > "${out}/sbom.spdx.json"

    echo ""
    echo "=== Grype vulnerability scan ==="
    {{repo_root}}/bin/grype "docker-archive:/work/.artifacts/{{image}}/image.tar" -o json > "${out}/cves.json" 2>/dev/null \
        && echo "  saved ${out}/cves.json" || echo "  (scan failed)"

    echo ""
    echo "=== Gitleaks secrets scan ==="
    {{repo_root}}/bin/gitleaks detect --source="docker-archive:/work/.artifacts/{{image}}/image.tar" \
        -f json -r "${out}/secrets.json" 2>/dev/null || true

    # Copy VEX file if one exists
    vex_file=$(find "{{repo_root}}" -name "{{image}}.vex.yaml" -path "*/images/*" 2>/dev/null | head -1)
    [ -n "$vex_file" ] && cp "$vex_file" "${out}/vex.yaml" && echo "  copied VEX: ${vex_file}"

    # Clean up tar
    rm -f "${out}/image.tar"

    echo ""
    echo "=== Artifacts ==="
    ls -lh "${out}/"

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
