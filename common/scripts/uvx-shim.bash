#!/usr/bin/env bash
# uvx-shim.bash — Run a uvx-packaged tool at a pinned version.
#
# Reads version from tool-versions.lock.yaml.
# Requires uvx (from uv) to be installed.
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

[[ -f "$LOCKFILE" ]] || { echo "uvx-shim: cannot find tool-versions.lock.yaml" >&2; exit 1; }

# Read tool metadata from lock file
VERSION="$(yq -r ".$TOOL.version" "$LOCKFILE")"

[[ "$VERSION" == "null" || -z "$VERSION" ]] && { echo "uvx-shim: unknown tool '$TOOL'" >&2; exit 1; }

exec uvx "$TOOL@$VERSION" "$@"
