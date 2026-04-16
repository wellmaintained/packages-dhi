#!/usr/bin/env bash
# tool-shim.bash — Download, cache, and run a tool binary.
#
# Reads version, URL, and checksum from tool-versions.yaml.
# Caches binaries in .tool-cache/{tool}-{version}.
# Same binary locally and in CI — no Docker required.
set -euo pipefail

TOOL="$1"; shift

# Find repo root by walking up to find common/tool-versions.lock.yaml
dir="$PWD"
while [[ "$dir" != "/" ]]; do
    [[ -f "$dir/common/tool-versions.lock.yaml" ]] && break
    dir="$(dirname "$dir")"
done
REPO_ROOT="$dir"
LOCKFILE="$REPO_ROOT/common/tool-versions.lock.yaml"

# Read tool metadata from lock file
VERSION="$(yq -r ".$TOOL.version" "$LOCKFILE")"
URL="$(yq -r ".$TOOL.url" "$LOCKFILE")"
CHECKSUM="$(yq -r ".$TOOL.checksum" "$LOCKFILE")"
BINARY_NAME="$(yq -r ".$TOOL.binary" "$LOCKFILE")"
RAW="$(yq -r ".$TOOL.raw // false" "$LOCKFILE")"

[[ "$VERSION" == "null" || -z "$VERSION" ]] && { echo "tool-shim: unknown tool '$TOOL'" >&2; exit 1; }

CACHE_DIR="${PACKAGES_DHI_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/packages-dhi}/tools"
BINARY="${CACHE_DIR}/${TOOL}-${VERSION}"

if [ ! -x "$BINARY" ]; then
    mkdir -p "$CACHE_DIR"
    EXPECTED="${CHECKSUM#sha256:}"
    tmpfile=$(mktemp)

    echo "tool-shim: downloading ${TOOL} v${VERSION}..." >&2
    curl -sL "$URL" -o "$tmpfile"

    ACTUAL=$(sha256sum "$tmpfile" | cut -d' ' -f1)
    if [ "$ACTUAL" != "$EXPECTED" ]; then
        rm -f "$tmpfile"
        echo "tool-shim: checksum mismatch for ${TOOL}" >&2
        echo "  expected: ${EXPECTED}" >&2
        echo "  actual:   ${ACTUAL}" >&2
        exit 1
    fi

    if [ "$RAW" = "true" ]; then
        mv "$tmpfile" "$BINARY"
    else
        tar -xzf "$tmpfile" -C "$CACHE_DIR" "$BINARY_NAME"
        mv "$CACHE_DIR/$BINARY_NAME" "$BINARY"
        rm -f "$tmpfile"
    fi

    chmod +x "$BINARY"
    echo "tool-shim: installed ${TOOL} v${VERSION}" >&2
fi

exec "$BINARY" "$@"
