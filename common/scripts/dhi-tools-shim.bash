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

# In CI: extract the binary from the DHI image and run natively.
# This avoids credential passthrough, OIDC token forwarding, and cache
# permission issues that come from running tools inside containers.
if [ "${CI:-}" = "true" ]; then
    TOOLS_DIR="${REPO_ROOT}/.dhi-tools-extracted"
    BINARY="${TOOLS_DIR}/${TOOL}-${TAG}"

    if [ ! -x "$BINARY" ]; then
        mkdir -p "$TOOLS_DIR"
        echo "dhi-tools-shim: extracting ${TOOL} from ${IMAGE}:${TAG}..." >&2
        CONTAINER=$(docker create "${IMAGE}:${TAG}" 2>/dev/null)
        for path in "/usr/bin/${TOOL}" "/usr/local/bin/${TOOL}"; do
            if docker cp "${CONTAINER}:${path}" "$BINARY" 2>/dev/null; then
                chmod +x "$BINARY"
                break
            fi
        done
        docker rm "$CONTAINER" >/dev/null 2>&1
        if [ ! -x "$BINARY" ]; then
            echo "dhi-tools-shim: failed to extract ${TOOL} from ${IMAGE}:${TAG}" >&2
            exit 1
        fi
        echo "dhi-tools-shim: extracted ${TOOL} to ${BINARY}" >&2
    fi

    exec "$BINARY" "$@"
fi

# Locally: run inside the DHI container.
# Translate real paths to /work paths since the repo is mounted at /work.
ARGS=()
for arg in "$@"; do
    ARGS+=("${arg//$REPO_ROOT//work}")
done

exec docker run --rm \
    -v "$REPO_ROOT:/work" -w /work \
    --user "$(id -u):$(id -g)" \
    -v "${HOME}/.docker/config.json:/tmp/.docker/config.json:ro" \
    -e DOCKER_CONFIG=/tmp/.docker \
    "$IMAGE:$TAG" "${ARGS[@]}"
