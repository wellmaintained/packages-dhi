# packages-dhi — DHI-native image pipeline for wellmaintained packages
# Prerequisites: Docker (with buildx), Just, yq

set dotenv-load := false

repo_root := justfile_directory()
app_manifest := repo_root / "apps/sbomify/app-images.yaml"
artifacts_dir := repo_root / ".artifacts"

# ── Helpers ────────────────────────────────────────

# Resolve the DHI YAML path for a custom image name
_image-path image:
    @yq -r '."{{image}}".definition | select(. != null)' {{app_manifest}}

# Resolve the registry for a custom image name
_image-registry image:
    @yq -r '."{{image}}".registry | select(. != null)' {{app_manifest}}

# Resolve the version for a custom image (from DHI YAML git URL)
_image-version image:
    #!/usr/bin/env bash
    set -euo pipefail
    def=$(just _image-path {{image}})
    version=$(grep -oP 'git\+https://[^#]+#\K[^"]+' "$def" | head -1 || true)
    if [ -n "$version" ]; then
        echo "$version"
        exit 0
    fi
    echo "unknown"

# ── Build ──────────────────────────────────────────

# Build all custom DHI images
build-all:
    #!/usr/bin/env bash
    set -euo pipefail
    for name in $(yq -r 'to_entries[] | select(.value | has("definition")) | .key' "{{app_manifest}}"); do
        echo "=== Building ${name} ==="
        just build "$name"
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
    {{repo_root}}/bin/grype "sbom:${out}/sbom.cdx.json" -o json > "${out}/cves.json" 2>/dev/null \
        && echo "  saved ${out}/cves.json" || echo "  (scan failed)"

    echo ""
    echo "=== Gitleaks secrets scan ==="
    {{repo_root}}/bin/gitleaks detect --source="docker-archive:${out}/image.tar" \
        -f json -r "${out}/secrets.json" 2>/dev/null \
        && echo "  saved ${out}/secrets.json" || echo "  (no secrets found)"

    # Copy VEX file if one exists
    vex_file=$(find "{{repo_root}}" -name "{{image}}.vex.yaml" -path "*/images/*" 2>/dev/null | head -1)
    [ -n "$vex_file" ] && cp "$vex_file" "${out}/vex.yaml" && echo "  copied VEX: ${vex_file}"

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

# Update everything: tool checksums and stock image digests
update: update-tools update-app-images
    @echo ""
    @echo "=== Summary ==="
    @just images

# Resolve tool URLs from version templates and compute checksums
update-tools:
    #!/usr/bin/env bash
    set -euo pipefail
    spec="{{repo_root}}/common/tool-versions.yaml"
    lock="{{repo_root}}/common/tool-versions.lock.yaml"

    echo "=== Pinning tool checksums ==="
    echo "# AUTO-GENERATED by 'just update-tools' — do not edit" > "$lock"

    for name in $(yq -r 'keys | .[]' "$spec"); do
        version=$(yq -r ".$name.version" "$spec")
        url_template=$(yq -r ".$name.url" "$spec")
        binary=$(yq -r ".$name.binary" "$spec")
        raw=$(yq -r ".$name.raw // false" "$spec")

        # Resolve ${version} in URL template
        url="${url_template//\$\{version\}/$version}"

        echo -n "  $name v$version: "
        tmpfile=$(mktemp)
        curl -sL "$url" -o "$tmpfile"
        checksum=$(sha256sum "$tmpfile" | cut -d' ' -f1)
        rm -f "$tmpfile"
        echo "sha256:${checksum}"

        yq -i ".$name.version = \"$version\"" "$lock"
        yq -i ".$name.url = \"$url\"" "$lock"
        yq -i ".$name.checksum = \"sha256:$checksum\"" "$lock"
        yq -i ".$name.binary = \"$binary\"" "$lock"
        if [ "$raw" = "true" ]; then
            yq -i ".$name.raw = true" "$lock"
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
    @yq -r 'to_entries[] | "  \(.key): \(.value.version)"' {{repo_root}}/tool-versions.yaml
    @echo ""
    @echo "=== Stock Images ==="
    @yq -r 'to_entries[] | select(.value | has("source")) | "  \(.key): \(.value.source)"' {{app_manifest}}
    @echo ""
    @echo "=== Custom Images ==="
    @yq -r 'to_entries[] | select(.value | has("definition")) | "  \(.key): \(.value.definition) → \(.value.registry)"' {{app_manifest}}
