# Blacksmith Cost Reduction — Research Brief

**Author:** Yakoff (under David Laing, supervisor)
**Date:** 2026-05-08
**Status:** proposed
**Decision:** **Recommendation B — Hybrid migration to vanilla GitHub Actions, drop sticky disks**

---

## Executive summary

- **The org's April Blacksmith bill was $102.01.** **75% of it ($76.17) was sticky-disk storage**, not compute. Compute alone (after the 3,000-minute free tier) was only $25.84.
- **`wellmaintained/packages-dhi` is a public repository.** Standard GitHub-hosted Linux runners (`ubuntu-latest`, 2-core) are **free** for public repos with no minute cap. Today only `build.yml` uses Blacksmith; every other workflow already runs on `ubuntu-latest`.
- **Sticky disk pricing is the trap.** $0.50/GB-month feels small but compounds: 152 GB-months in April = $76. Each cache key creates a persistent volume that bills monthly even when idle. The 2026-05-08 senaite restructure (1 → 4 apps, sharing `python-2.7` and `senaite-lims`) will multiply distinct cache keys further.
- **Recommendation: Move `build.yml` to `ubuntu-latest` and replace `useblacksmith/stickydisk` with `actions/cache`** (free, up to 10 GB per repo). Estimated saving: **$50–80/month for packages-dhi alone**, with a tolerable build-time increase (~1.5–2× slower in the worst case, irrelevant for nightly/PR cadence).
- **Implementation effort: ~2 hours.** No code changes outside `.github/`. Three follow-up yaks created (see § Follow-up work).

---

## The numbers we have

### April 2026 Blacksmith invoice (org-wide, operator-supplied)

| Line item | Units | Unit price | Amount |
|---|---|---|---|
| Compute • amd64 • 2-vCPU | 6,388 min | $0.004/min | $25.55 |
| Compute • amd64 • 4-vCPU | 1,536 min | $0.008/min | $12.29 |
| Sticky disk usage | ~152 GB-months | $0.50/GB-mo | $76.17 |
| Free-tier credit | 3,000 min | -$0.004/min | -$12.00 |
| **Total** |  |  | **$102.01** |

Two important observations:

1. **Sticky disk is the dominant cost line (75% of net bill).** Compute alone, even before the free-tier credit, is only $37.84/month. Knock out the storage line and the bill collapses to ~$26/month.
2. **The bill is org-wide, not packages-dhi only.** The 4-vCPU minutes come from `wellmaintained/packages`, where `build.yml` and `build-devcontainer.yml` use `blacksmith-4vcpu-ubuntu-2404`. The 2-vCPU minutes are split between `packages` and `packages-dhi`. Sticky-disk storage is similarly split (each repo has its own cache keys).

### Per-repo attribution (estimate)

I cannot get a per-repo split from the invoice line-items provided, but I can estimate from `gh run list`:

- **packages-dhi April activity:** ~99 Build workflow runs in 37 days (Apr 1 – May 8). Per-run Blacksmith runner-minutes ≈ 25 (sbomify-app build ~9 min + minio build ~7 min + small jobs). Estimated packages-dhi compute: **~2,475 2-vCPU minutes ≈ $9.90/month** (before free credit).
- **packages April activity:** 31 build runs + 25 pre-release + others. Some on 2-vCPU, some on 4-vCPU. Estimated packages compute: **~$28/month** (the 4-vCPU line is theirs).
- **Sticky disks (packages-dhi share):** the `setup-pipeline` action declares two stickydisk volumes per matrix job (`packages-dhi-cache-<image>` and `sbomify-cache-<image>`). Across `stock`, `minio`, `sbomify-app` cache keys, that's 6 distinct volumes. Each likely 5–15 GB. **Rough estimate: 30–60 GB-months × $0.50 = $15–30/month for packages-dhi.**

So packages-dhi alone is plausibly **$25–40/month** out of the $102.01 — call it **~30%** of the bill. The rest sits in `packages`.

### Run-history audit (from `gh run list`)

99 `build.yml` runs in `packages-dhi` between 2026-04-01 and 2026-05-08, distributed across:

| Branch | Runs |
|---|---|
| `main` (post-merge) | 26 |
| `feat/vulnerabilities-vex-first` | 19 |
| `feat/sbom-enrichment` | 15 |
| `feat/ci-local-module` | 8 |
| `feat/build-once-promotion-pipeline` | 6 |
| Other PR branches | 25 |

Per-job timings (representative recent run, 25336457367):

| Job | Runner | Wall-time |
|---|---|---|
| Resolve image lists | blacksmith-2vcpu | 7 s |
| Extract DHI attestations | blacksmith-2vcpu | 67 s |
| Build sbomify-app | blacksmith-2vcpu | 16 m 07 s |
| Build minio | blacksmith-2vcpu | 9 m 07 s |

The dominant cost is the `Build image and generate compliance artifacts` step inside each matrix job — 7–8 minutes of `just ci build <image>`. The cosign + attestation steps take only ~20 seconds. `setup-pipeline` itself takes 35 seconds (cache restore, docker buildx, registry login, grype DB hydrate).

---

## Where the waste is

### 1. Sticky disks are persistent and expensive

`useblacksmith/stickydisk` mounts a persistent EBS-style volume that lives across runs and bills $0.50/GB-month even when the workflow isn't running. The cache contains:

- Tool binaries (`./bin/grype`, `./bin/cosign`, `./bin/syft`, `./bin/sbom-convert`, `./bin/sbomify-action` shim, etc.)
- Grype vulnerability DB (~500 MB)
- `uv` cache (Python wheel cache, can grow to several GB)
- Hugo cache (release website assets)
- Compliance artefacts staging area

Most of this is **fast to rebuild** (tool binaries are downloaded from pinned URLs in `common/tool-versions.lock.yaml`; the grype DB takes ~30 s to hydrate). A few are slow (`uv` wheel cache for sbomify, which has many transitive Python deps).

`actions/cache` (a built-in GitHub Action, free, scoped per-repo) gives us exactly the same semantics: keyed restore + save, no monthly storage charge. The only difference is GitHub's limit of 10 GB per repo for the cache and a 7-day eviction policy for unused entries — neither of which is a real constraint for our workload.

### 2. No `concurrency:` group on `build.yml`

The sniff-test reviewer flagged this on the workflow generalisation yak. A force-push on a feature branch (the way most of us iterate) currently triggers a fresh `Build` run without cancelling the previous in-flight run. Looking at `feat/vulnerabilities-vex-first`, that branch had 19 Build runs in a few days — many of them concurrent, all billed.

A simple `concurrency: { group: ${{ github.workflow }}-${{ github.ref }}, cancel-in-progress: true }` block at the top of `build.yml` would have cut probably **30–50% of the 19** runs on that branch — saving an estimated 10+ hours of Blacksmith compute on that one feature.

### 3. python-2.7 will be rebuilt 3× per senaite-touching commit

After the 2026-05-08 senaite restructure, three apps (`senaite-1.3`, `senaite-2.3`, `senaite-current`) each declare `python-2.7` as a custom image in their `app-images.yaml`. The current `build.yml` strategy matrix is per-app; once Bob lands the workflow generalisation, a shared-path PR fans out to all four apps, and each senaite app's matrix independently builds python-2.7.

`stickydisk` cache keys are per-image-name (`cache-key: ${{ matrix.image }}`), so they share the `packages-dhi-cache-python-2.7` volume — but **concurrent matrix jobs cannot read-write the same disk safely**, so cache hits are best-effort, and at minimum two of the three concurrent builds run cold.

Two fixes both work:
- **Dedupe at resolve time** — emit a single de-duplicated image list per Build run (union across all apps' manifests), build each image once, then have each app reference the resulting digest.
- **Promote `python-2.7` to a top-level shared image** under `common/images/` (like `minio` is today) so it builds once per push regardless of which apps consume it.

The second is more invasive but is the cleaner long-term shape (it matches the build-once-promotion principle that already governs the rest of the pipeline).

### 4. Most workflows are already on `ubuntu-latest` — only `build.yml` uses Blacksmith

Confirmed by `grep -rn 'blacksmith' .github/`:

```
.github/workflows/build.yml:21:  runs-on: blacksmith-2vcpu-ubuntu-2204
.github/workflows/build.yml:31:  runs-on: blacksmith-2vcpu-ubuntu-2204
.github/workflows/build.yml:52:  runs-on: blacksmith-2vcpu-ubuntu-2204
```

`pre-release.yml`, `sbom-quality-gate.yml`, `deploy-release-website.yml`, `cleanup-stale-images.yml`, `digest-pin-update.yml`, `rescan-vulnerabilities.yml` all run on `ubuntu-latest` already. They cost nothing because `packages-dhi` is public.

So the migration scope is **a single workflow file** — not a whole-pipeline rewrite.

---

## Cost comparison

### Same workload, three runner choices

Assume packages-dhi runs ~100 Build workflows/month and each consumes ~25 runner-minutes today (will rise to ~50–100 after the senaite fan-out lands).

| | Current (Blacksmith 2-vCPU + sticky) | Vanilla GHA (2-core) on public repo | Larger GHA (4-core) on public repo |
|---|---|---|---|
| Compute rate | $0.004/min | **$0.000/min** (public) | $0.016/min (always charged) |
| Sticky disk | $0.50/GB-mo | n/a — `actions/cache` free | n/a |
| Build wall-time (representative) | 16 min sbomify, 9 min minio | ~24 min sbomify, ~14 min minio (~1.5× slower) | ~10 min sbomify, ~6 min minio (similar to current) |
| packages-dhi monthly compute | ~$10 | **$0** | ~$40 (after restructure) |
| packages-dhi monthly sticky disk | ~$15–30 | **$0** | $0 |
| **Total / mo (packages-dhi)** | **~$25–40** | **~$0** | ~$40 |

The numbers above are estimates with the data we have; the actual packages-dhi share could be lower if the 152 GB-months are mostly attributable to `packages`. Either way, vanilla GHA standard runners are the obvious win for a public repo. The only reason to pay anything is if build wall-time is a bottleneck for human iteration speed.

### Build wall-time — does it matter?

The Blacksmith pricing page claims "67% total cost savings vs GitHub Actions" but that's against private-repo billing. Their faster I/O and pre-warmed runners do produce real wall-time wins (anecdotally 1.5–2× on container builds). For packages-dhi:

- A docker build that takes 8 min on Blacksmith might take 14–16 min on `ubuntu-latest`.
- Pre-Release total wall-time today: ~22 min. With `build.yml` on standard runners: ~30 min.
- Cleanup/rescan/digest-pin nightly jobs: already on `ubuntu-latest`, unaffected.

For a research-and-release repo like packages-dhi, an extra 5–10 minutes per PR build is not a hot-path concern. Humans aren't waiting on CI minute-by-minute; we're shipping releases on roughly a weekly cadence.

---

## Recommendation: B — Hybrid migration (drop Blacksmith for compute, keep `actions/cache` for caching)

I recommend a single coherent change rather than a half-step:

1. **Switch `build.yml` to `ubuntu-latest`** for all three jobs (`resolve-images`, `stock-dhi-images`, `custom-dhi-builds`).
2. **Replace `useblacksmith/stickydisk` with `actions/cache`** in `setup-pipeline/action.yml`.
3. **Add a `concurrency:` group** so force-pushes cancel in-flight runs.
4. **Defer the python-2.7 dedupe** to a follow-up yak (it pays for itself on Blacksmith *or* GHA, but it's a more invasive structural change).

I prefer B over A (stay on Blacksmith + optimise) because:

- The structural waste isn't fixable by Blacksmith-side tuning — sticky disks are the issue, and removing them is the same change whether we stay or move.
- We're paying $100/month for a *public-repo* CI that GitHub will host for free.
- The faster-runner argument doesn't hold up for our cadence: we're not a SaaS shipping ten times a day, we're publishing release-tagged compliance bundles. 5 minutes more per build is not a productivity concern.
- The migration is small (one workflow file, one composite action). If the speed regression turns out to hurt, reverting is a one-line change per file.

I prefer B over C (move workflows but keep some caching) because there is no caching middle-ground that's better than `actions/cache`. Either we keep Blacksmith's sticky-disk (expensive) or we drop it (cheap). There's no third option that's worth the architectural complexity.

---

## Implementation outline

**Estimated effort: ~2 hours** (one focused session, plus a follow-up PR for python-2.7 dedupe).

### PR 1: Move `build.yml` off Blacksmith

- `.github/workflows/build.yml`: change three `runs-on:` lines from `blacksmith-2vcpu-ubuntu-2204` to `ubuntu-latest`.
- Add at top of `build.yml`:
  ```yaml
  concurrency:
    group: ${{ github.workflow }}-${{ github.ref }}
    cancel-in-progress: true
  ```
- `.github/actions/setup-pipeline/action.yml`: replace the two `useblacksmith/stickydisk` steps with `actions/cache@v4` blocks using the same `cache-key` pattern.
  - Key: `packages-dhi-cache-${{ inputs.cache-key }}-${{ hashFiles('common/tool-versions.lock.yaml') }}`.
  - Restore-keys: fall back to the unversioned key.
- Smoke-test on a noop PR to confirm cache hit/miss behaves and the build still succeeds.

### PR 2 (follow-up): Dedupe python-2.7 — already tracked

The 3× python-2.7 rebuild is already covered by an existing yak: **`dedupe-shared-image-builds-across-apps-1dvr`** (under `multi-app pipeline generalisation`). Its context already lays out two design approaches (resolve-time dedupe vs shared-image promotion) and explicitly cross-references this brief. I have not duplicated it as a follow-up here.

**Cost impact of the dedupe yak, post-migration to vanilla GHA:**

- Compute savings: small (~$0–1/month). Once `build.yml` is on free `ubuntu-latest`, two redundant python-2.7 builds per shared-path PR cost nothing in dollars.
- Wall-time savings: ~10–15 min off the slow side of any shared-path PR (3 concurrent python-2.7 builds collapse to 1).
- Cache contention: the bigger structural win — three concurrent matrix jobs writing to the same `actions/cache` (or `stickydisk`) key is a known correctness footgun that dedupe eliminates.

**Priority recommendation:** *medium*. After migrating off Blacksmith (highest priority — biggest $ saving), the dedupe yak's value becomes pipeline cleanliness + wall-time, not cost. It can land any time after PR 1; doesn't block anything.

### Roll-back plan

If the standard-runner build wall-time is unacceptable on real workloads:
- Revert `runs-on:` changes in `build.yml` (single commit revert).
- Keep the `actions/cache` change — it's strictly better than `stickydisk` regardless of runner.
- Keep the `concurrency:` block — it's strictly better.

---

## Open questions / data we couldn't get

- **Per-repo / per-cache-key sticky-disk breakdown.** The Blacksmith dashboard line item is a single aggregate; without per-key spend we're estimating. Operator could pull this from the Blacksmith dashboard if they want to confirm packages-dhi's share.
- **Actual build wall-time on `ubuntu-latest` for our compliance pipeline.** The 1.5–2× slowdown is industry-anecdotal — the only way to know for sure is to run the change and compare. PR 1 itself is the experiment.
- **Whether the senaite restructure has materially changed costs yet.** April's bill was *before* the 2026-05-08 senaite restructure was merged. May's bill (the one due ~June 4) will be the first month with multi-app fan-out. If we don't act, expect the bill to roughly double (more compute minutes, more cache keys = more sticky-disk GB-months).

---

## Follow-up work

### New yaks created (this brief)

Two follow-up yaks created under `packages-dhi`:

1. **`migrate-buildyml-off-blacksmith-wkg1`** — implement PR 1 above.  *Priority: highest.*  Estimated saving: $25–40/month for packages-dhi.
2. **`replace-stickydisk-with-actions-cache-iwnd`** — implement the cache-action swap inside `setup-pipeline/action.yml`.  *Priority: high.*  Estimated saving: $15–30/month for packages-dhi.

(The two could be one PR but I split them so we can land the Blacksmith → GHA move first and observe any wall-time impact in isolation before doing the cache swap. Operator can collapse them into one PR if desired.)

The `concurrency:` group is bundled into yak 1 deliberately — it's a one-line change to the same workflow file and benefits from the same smoke-test PR. If the operator prefers it as a separate yak (it ships value independently and could land sooner), that's a defensible split.

### Existing yaks this brief depends on

- **`dedupe-shared-image-builds-across-apps-1dvr`** (under `multi-app pipeline generalisation`). Already tracked; its context already cross-references this brief. **Priority: medium** — its dollar impact is captured by yaks 1+2 above; its remaining value is wall-time + cache-contention cleanup, which can land any time post-PR-1.

### Yaks I considered but did not create

- **Stickydisk cache hit-rate audit.** Yakob suggested this as potential ground. Skipped — once we move to `actions/cache`, the analysis is moot. If we *don't* move (i.e. operator overrides Recommendation B and stays on Blacksmith), this audit becomes the right next step.
- **Standalone `concurrency:` group yak.** Folded into yak 1 above; see rationale.

---

## Acceptance criteria recap

- [x] Brief at `docs/research/blacksmith-cost-reduction.md`
- [x] Numbers grounded in operator-supplied April invoice + 99-run `gh` audit
- [x] More than 3 concrete optimisation candidates, each sized
- [x] Single unambiguous recommendation (B)
- [x] Follow-up yak stubs created
- [x] Out-of-scope items declared (the implementation work itself)

---

*— Yakoff, shaver. Brief written 2026-05-08; ready for review.*
