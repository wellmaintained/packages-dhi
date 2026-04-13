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

    # Export image as tar to extract build attestations
    echo ""
    echo "=== Exporting image ==="
    docker save "${reg}:dev" -o "${out}/image.tar"

    # Extract SPDX SBOM and SLSA provenance from build attestations
    echo ""
    echo "=== Extracting build attestations ==="
    tar -xf "${out}/image.tar" -C "${out}" index.json
    manifest_list_digest=$(jq -r '.manifests[0].digest' "${out}/index.json" | cut -d: -f2)
    tar -xf "${out}/image.tar" -C "${out}" "blobs/sha256/${manifest_list_digest}"
    att_digest=$(jq -r '.manifests[] | select(.annotations["vnd.docker.reference.type"] == "attestation-manifest") | .digest' "${out}/blobs/sha256/${manifest_list_digest}" | cut -d: -f2)
    tar -xf "${out}/image.tar" -C "${out}" "blobs/sha256/${att_digest}"

    for layer in $(jq -r '.layers[] | @base64' "${out}/blobs/sha256/${att_digest}"); do
        predicate_type=$(echo "$layer" | base64 -d | jq -r '.annotations["in-toto.io/predicate-type"]')
        layer_digest=$(echo "$layer" | base64 -d | jq -r '.digest' | cut -d: -f2)
        tar -xf "${out}/image.tar" -C "${out}" "blobs/sha256/${layer_digest}"
        case "$predicate_type" in
            *spdx*)
                jq '.predicate' "${out}/blobs/sha256/${layer_digest}" > "${out}/sbom.spdx.json"
                pkg_count=$(jq '.packages | length' "${out}/sbom.spdx.json")
                echo "  SPDX SBOM: ${pkg_count} packages"
                ;;
            *provenance*)
                jq '.predicate' "${out}/blobs/sha256/${layer_digest}" > "${out}/provenance.slsa.json"
                echo "  SLSA provenance extracted"
                ;;
        esac
    done

    # Clean up temp blobs (keep image.tar for scanning and debugging)
    rm -f "${out}/index.json"
    rm -rf "${out}/blobs"

    # Convert SPDX to CycloneDX (DHI build produces SPDX; convert for consistency with stock images)
    echo ""
    echo "=== Converting SPDX → CycloneDX ==="
    {{repo_root}}/bin/sbom-convert convert "${out}/sbom.spdx.json" -f cyclonedx -o "${out}/sbom.cdx.json"
    cdx_components=$(jq '.components | length' "${out}/sbom.cdx.json")
    cdx_deps=$(jq '.dependencies | length' "${out}/sbom.cdx.json")
    echo "  CycloneDX SBOM: ${cdx_components} components, ${cdx_deps} dependencies"

    echo ""
    echo "=== Grype vulnerability scan ==="
    {{repo_root}}/bin/grype "sbom:/work/.artifacts/{{image}}/sbom.cdx.json" -o json > "${out}/cves.json" 2>/dev/null \
        && echo "  saved ${out}/cves.json" || echo "  (scan failed)"

    echo ""
    echo "=== Gitleaks secrets scan ==="
    {{repo_root}}/bin/gitleaks detect --source="docker-archive:/work/.artifacts/{{image}}/image.tar" \
        -f json -r "/work/.artifacts/{{image}}/secrets.json" 2>/dev/null \
        && echo "  saved ${out}/secrets.json" || echo "  (no secrets found)"

    # Copy VEX file if one exists
    vex_file=$(find "{{repo_root}}" -name "{{image}}.vex.yaml" -path "*/images/*" 2>/dev/null | head -1)
    [ -n "$vex_file" ] && cp "$vex_file" "${out}/vex.yaml" && echo "  copied VEX: ${vex_file}"

    echo ""
    echo "=== Artifacts ==="
    ls -lh "${out}/"

# ── Stock DHI Images ──────────────────────────────

# Build the experimental Dalec-based MinIO image (local only)
build-minio-dalec:
    #!/usr/bin/env bash
    set -euo pipefail
    def="common/images/minio-by-dalec/dalec.yaml"
    tag="ghcr.io/wellmaintained/minio-by-dalec:dev"
    out="{{artifacts_dir}}/minio-by-dalec"
    mkdir -p "$out"

    echo "=== Building Dalec MinIO (target: trixie/testing/container) ==="
    docker buildx build \
        -f "${def}" \
        --target trixie/testing/container \
        --platform linux/amd64 \
        --sbom=true \
        --provenance=true \
        --tag "${tag}" \
        --load \
        .

    echo ""
    echo "=== Extracting SBOM from image attestation ==="
    # Export as OCI to access attestation layers directly
    docker save "${tag}" -o "${out}/image.tar"
    # Extract SBOM from attestation manifest in the containerd image store
    docker buildx imagetools inspect "${tag}" --raw 2>/dev/null | \
        jq -r '.manifests[]? | select(.annotations["vnd.docker.reference.type"] == "attestation-manifest") | .digest' | \
        head -1 | while read digest; do
            if [ -n "$digest" ]; then
                docker buildx imagetools inspect "${tag}@${digest}" --raw 2>/dev/null | \
                    jq -r '.layers[]? | select(.annotations["in-toto.io/predicate-type"] | test("spdx")) | .digest' | \
                    head -1 | while read layer_digest; do
                        if [ -n "$layer_digest" ]; then
                            echo "  Found SBOM attestation layer: ${layer_digest}"
                        fi
                    done
            fi
        done || true
    # Fallback: use syft to scan the image for SBOM comparison
    echo ""
    echo "=== Generating syft SPDX SBOM (for comparison) ==="
    {{repo_root}}/bin/syft "docker-archive:/work/.artifacts/minio-by-dalec/image.tar" -o spdx-json > "${out}/sbom.spdx.json" 2>/dev/null \
        && echo "  saved ${out}/sbom.spdx.json ($(jq '.packages | length' "${out}/sbom.spdx.json") packages)" \
        || echo "  (syft scan failed)"
    rm -f "${out}/image.tar"

    echo ""
    echo "=== Quick smoke test ==="
    docker run --rm --entrypoint /usr/bin/minio "${tag}" --version
    docker run --rm --entrypoint /usr/bin/mc "${tag}" --version

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
