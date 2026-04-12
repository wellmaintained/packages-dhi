#!/usr/bin/env bash
set -euo pipefail

TOOL="$1"; shift

# Find repo root by walking up to find common/tool-images.yaml
dir="$PWD"
while [[ "$dir" != "/" ]]; do
    [[ -f "$dir/common/tool-images.yaml" ]] && break
    dir="$(dirname "$dir")"
done
REPO_ROOT="$dir"
MANIFEST="$REPO_ROOT/common/tool-images.yaml"

# Read tool image:tag
IMAGE="$(yq -r ".$TOOL.image" "$MANIFEST")"
TAG="$(yq -r ".$TOOL.tag" "$MANIFEST")"

[[ "$IMAGE" == "null" || -z "$IMAGE" ]] && { echo "dhi-tools-shim: unknown tool '$TOOL'" >&2; exit 1; }

exec docker run --rm \
    -v "$REPO_ROOT:/work" -w /work \
    --user "$(id -u):$(id -g)" \
    -v "${HOME}/.docker/config.json:/tmp/.docker/config.json:ro" \
    -e DOCKER_CONFIG=/tmp/.docker \
    "$IMAGE:$TAG" "$@"
