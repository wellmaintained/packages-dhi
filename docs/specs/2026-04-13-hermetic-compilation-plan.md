# Hermetic Compilation Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split privileged DHI pipeline steps so dependency downloads use network but compilation runs hermetically.

**Architecture:** Each `privileged: true` pipeline step that mixes fetching and compiling is split into two steps: a privileged download step and a hermetic compile step. This follows the existing pattern in sbomify-app's python-app stage.

**Tech Stack:** DHI YAML specs, Docker buildx

---

## Chunk 1: Minio hermetic builds

### Task 1: Split minio-server pipeline step

**Files:**
- Modify: `common/images/minio/dhi.yaml:31-51`

- [ ] **Step 1: Split the minio-server pipeline into download + compile**

Replace the single pipeline step at line 31-51 with two steps. The first runs `go mod download` with `privileged: true`. The second runs `go build` + `install` without `privileged` (hermetic).

```yaml
      pipeline:
        - name: download go modules
          work-dir: ${source.dir}/minio
          privileged: true
          runs: |
            set -eux -o pipefail
            go mod download
        - name: compile minio server
          work-dir: ${source.dir}/minio
          runs: |
            set -eux -o pipefail
            CGO_ENABLED=0 go build \
              -tags kqueue \
              -trimpath \
              --ldflags "-s -w \
                -X github.com/minio/minio/cmd.Version=2025-10-15T17:29:55Z \
                -X github.com/minio/minio/cmd.CopyrightYear=2025 \
                -X github.com/minio/minio/cmd.ReleaseTag=RELEASE.2025-10-15T17-29-55Z \
                -X github.com/minio/minio/cmd.CommitID=9e49d5e7a648f00e26f2246f4dc28e6b07f8c84a \
                -X github.com/minio/minio/cmd.ShortCommitID=9e49d5e7a648" \
              -o minio
            mkdir -p ${target.dir}/usr/local/bin
            install -m 0755 minio ${target.dir}/usr/local/bin/minio
            mkdir -p ${target.dir}/data
            chown 65532:65532 ${target.dir}/data
```

- [ ] **Step 2: Split the mc-client pipeline step the same way**

Replace the single pipeline step for mc-client with two steps, same pattern.

```yaml
      pipeline:
        - name: download go modules
          work-dir: ${source.dir}/mc
          privileged: true
          runs: |
            set -eux -o pipefail
            go mod download
        - name: compile mc client
          work-dir: ${source.dir}/mc
          runs: |
            set -eux -o pipefail
            GO111MODULE=on CGO_ENABLED=0 go build \
              -trimpath \
              -tags kqueue \
              --ldflags "-s -w \
                -X github.com/minio/mc/cmd.Version=2025-08-13T08:35:41Z \
                -X github.com/minio/mc/cmd.CopyrightYear=2025 \
                -X github.com/minio/mc/cmd.ReleaseTag=RELEASE.2025-08-13T08-35-41Z \
                -X github.com/minio/mc/cmd.CommitID=7394ce0dd2a80935aded936b09fa12cbb3cb8096 \
                -X github.com/minio/mc/cmd.ShortCommitID=7394ce0dd2a8" \
              -o mc
            mkdir -p ${target.dir}/usr/local/bin
            install -m 0755 mc ${target.dir}/usr/local/bin/mc
```

- [ ] **Step 3: Build minio image to verify**

Run: `just build minio`
Expected: Build completes successfully. Both `go mod download` steps run with network, both compile steps run hermetically.

- [ ] **Step 4: Smoke test**

Run: `docker run --rm ghcr.io/wellmaintained/minio:dev --version`
Expected: Shows minio version RELEASE.2025-10-15T17-29-55Z

Run: `docker run --rm --entrypoint mc ghcr.io/wellmaintained/minio:dev --version`
Expected: Shows mc version RELEASE.2025-08-13T08-35-41Z

- [ ] **Step 5: Commit**

```bash
git add common/images/minio/dhi.yaml
git commit -m "refactor: split minio build into hermetic download + compile steps"
```

### Task 2: Split sbomify frontend pipeline step

**Files:**
- Modify: `apps/sbomify/images/sbomify-app/prod.yaml:41-54`

- [ ] **Step 1: Split the frontend pipeline into install + build**

Replace the single `install and build frontend` step with two steps:

```yaml
      pipeline:
        - name: install frontend dependencies
          work-dir: ${source.dir}/sbomify
          privileged: true
          runs: |
            set -eux -o pipefail
            bun install --frozen-lockfile
        - name: build frontend
          work-dir: ${source.dir}/sbomify
          runs: |
            set -eux -o pipefail
            bun run copy-deps
            bun x vite build
            # Stage compiled frontend assets for the final image
            mkdir -p ${target.dir}/staticfiles
            cp -a sbomify/static/dist ${target.dir}/staticfiles/dist
            cp -a sbomify/static/css ${target.dir}/staticfiles/css
            cp -a sbomify/static/webfonts ${target.dir}/staticfiles/webfonts
```

- [ ] **Step 2: Build sbomify-app image to verify**

Run: `just build sbomify-app`
Expected: Build completes successfully.

If the build fails because `bun x vite build` needs network, move it into step 1:

```yaml
      pipeline:
        - name: install deps and build frontend
          work-dir: ${source.dir}/sbomify
          privileged: true
          runs: |
            set -eux -o pipefail
            bun install --frozen-lockfile
            bun run copy-deps
            bun x vite build
        - name: stage frontend assets
          work-dir: ${source.dir}/sbomify
          runs: |
            set -eux -o pipefail
            mkdir -p ${target.dir}/staticfiles
            cp -a sbomify/static/dist ${target.dir}/staticfiles/dist
            cp -a sbomify/static/css ${target.dir}/staticfiles/css
            cp -a sbomify/static/webfonts ${target.dir}/staticfiles/webfonts
```

- [ ] **Step 3: Commit**

```bash
git add apps/sbomify/images/sbomify-app/prod.yaml
git commit -m "refactor: split sbomify frontend build into hermetic install + build steps"
```
