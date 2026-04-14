# Tool Image Version Tags

## Problem

Custom tool images (hugo, sbom-convert) are built and pushed to GHCR with
component tags (e.g. `hugo-0.160.1-abc1234`) but not with their manifest
version tag (e.g. `0.160.1`). The dhi-tools-shim looks up tools by the `tag`
field in `tool-images.yaml`, so it can't find the extracted binary in CI unless
the version tag exists in GHCR.

Currently these version tags are bootstrapped manually via `docker push`.

## Fix

The build workflow should also push each custom tool image with its manifest
version tag, in addition to the component tag. This ensures the shim can
always extract the correct binary.

In `build.yml`, after pushing with the component tag:

```yaml
- name: Push version tag for tool images
  run: |
    VERSION=$(just _image-version "${{ matrix.image }}")
    REG="${{ steps.tag.outputs.registry }}"
    docker tag "${REG}:dev" "${REG}:${VERSION}"
    docker push "${REG}:${VERSION}"
```

This makes tool images self-bootstrapping — no manual push needed after the
first PR build.
# Test full pipeline
