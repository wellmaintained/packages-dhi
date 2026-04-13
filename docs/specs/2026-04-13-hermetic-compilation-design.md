# Hermetic Compilation in DHI Pipeline Steps

## Problem

DHI pipeline steps that compile from source currently use `privileged: true` for the entire step, granting network access to both dependency fetching and compilation. This is unnecessary — only the dependency download needs network. The compilation step should run hermetically (no network) to prevent hostile build steps from making unauthorized network calls.

## Approach

Split each `privileged: true` pipeline step that mixes downloading and compiling into two steps:

1. A **download step** (`privileged: true`) that fetches dependencies
2. A **compile step** (no `privileged`, hermetic) that builds from the fetched dependencies

This follows the pattern already used in `apps/sbomify/images/sbomify-app/prod.yaml` where `install python deps` (privileged) is separate from `collect static files` and `prepare runtime` (hermetic).

## Changes

### `common/images/minio/dhi.yaml`

Both build stages (`minio-server`, `mc-client`) currently have a single pipeline step that runs `go mod download` then `go build`. Split each into:

- **Step 1** `download go modules` — `privileged: true`, runs `go mod download`
- **Step 2** `compile minio server` / `compile mc client` — hermetic, runs `go build` + `install`

### `apps/sbomify/images/sbomify-app/prod.yaml`

The `install and build frontend` step runs `bun install` then `vite build` then copies assets. Split into:

- **Step 1** `install frontend dependencies` — `privileged: true`, runs `bun install --frozen-lockfile`
- **Step 2** `build frontend` — hermetic, runs `bun run copy-deps` + `bun x vite build` + copy assets

If the hermetic vite build step fails because `bun x` needs network, move `bun x vite build` back into step 1.

### No changes needed

- `common/images/hugo/dhi.yaml` — no `privileged: true` steps; binary downloaded via HTTPS
- `apps/sbomify/images/sbomify-app/prod.yaml` python-app stage — already correctly split

## Verification

Build each changed image and confirm it produces identical binaries:

```bash
just build minio
just build sbomify-app
```

Both should complete without errors. Smoke-test the minio image:

```bash
docker run --rm ghcr.io/wellmaintained/minio:dev --version
docker run --rm --entrypoint mc ghcr.io/wellmaintained/minio:dev --version
```
