#!/usr/bin/env bash
# enrich-sbom.bash — Enrich a CycloneDX SBOM via sbomify-action, with content-addressed caching.
#
# Usage:
#   common/scripts/enrich-sbom.bash <sbom.cdx.json> <component-name>
#
# Enriches the SBOM file in-place. Caches enriched output keyed on
# input content + sbomify-action version so identical inputs skip enrichment.
set -euo pipefail

SBOM_FILE="$1"
COMPONENT_NAME="$2"

[[ -f "$SBOM_FILE" ]] || { echo "enrich-sbom: file not found: $SBOM_FILE" >&2; exit 1; }

# Find repo root (same pattern as tool-shim.bash)
dir="$PWD"
while [[ "$dir" != "/" ]]; do
    [[ -f "$dir/common/tool-versions.lock.yaml" ]] && break
    dir="$(dirname "$dir")"
done
REPO_ROOT="$dir"
LOCKFILE="$REPO_ROOT/common/tool-versions.lock.yaml"

# Compute cache key from SBOM content + sbomify-action version
sbom_hash=$(sha256sum "$SBOM_FILE" | cut -d' ' -f1)
sbomify_version=$(yq -r '."sbomify-action".version' "$LOCKFILE")
cache_key=$(echo -n "${sbom_hash}:${sbomify_version}" | sha256sum | cut -d' ' -f1)

CACHE_DIR="${PACKAGES_DHI_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/packages-dhi}/compliance-artifacts"
cached_file="${CACHE_DIR}/${cache_key}/sbom.cdx.json"

if [ -f "$cached_file" ]; then
    cp "$cached_file" "$SBOM_FILE"
    components=$(jq '.components | length' "$SBOM_FILE")
    echo "enriched (${components} components, cache hit ${cache_key:0:12}...)"
else
    "${REPO_ROOT}/bin/sbomify-action" \
        --sbom-file "$SBOM_FILE" \
        --enrich --no-upload \
        --component-name "$COMPONENT_NAME" \
        -o "${SBOM_FILE}.enriched.tmp"
    mv "${SBOM_FILE}.enriched.tmp" "$SBOM_FILE"

    # Store in cache
    mkdir -p "${CACHE_DIR}/${cache_key}"
    cp "$SBOM_FILE" "$cached_file"
    components=$(jq '.components | length' "$SBOM_FILE")
    echo "enriched (${components} components, cached ${cache_key:0:12}...)"
fi
