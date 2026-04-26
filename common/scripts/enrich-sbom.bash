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

# Inject an operating-system component from the deb purl qualifiers if the
# SBOM doesn't already declare one. Without this, grype can't auto-detect
# the distro (it doesn't look at purl qualifiers), so `grype sbom:<file>`
# returns zero matches against a debian rootfs. This mirrors what syft emits
# natively and is the minimum needed to make the SBOM self-describing. See
# docs/adr for the rationale behind injecting locally instead of waiting on
# sbomify-action upstream.
tmp_os="${SBOM_FILE}.os.tmp"
jq '
def purl_qualifiers($p):
  ($p | split("?")[1] // "")
  | split("&")
  | map(split("=") | select(length == 2) | {(.[0]): .[1]})
  | add // {};

([.components[]?
  | select(.purl? != null)
  | purl_qualifiers(.purl)
  | select(.os_name? and .os_version?)][0]) as $os
| if $os and ([.components[]? | select(.type? == "operating-system")] | length == 0)
  then .components += [{
    "type": "operating-system",
    "name": $os.os_name,
    "version": $os.os_version,
    "bom-ref": ("operating-system:\($os.os_name)@\($os.os_version)"),
    "description": ($os.os_distro // $os.os_name)
  }]
  else .
  end
' "$SBOM_FILE" > "$tmp_os"
mv "$tmp_os" "$SBOM_FILE"
if jq -e '[.components[] | select(.type == "operating-system")] | length > 0' "$SBOM_FILE" > /dev/null; then
    os_name=$(jq -r '[.components[] | select(.type == "operating-system")][0].name' "$SBOM_FILE")
    os_version=$(jq -r '[.components[] | select(.type == "operating-system")][0].version' "$SBOM_FILE")
    echo "os component: ${os_name}@${os_version}"
fi
