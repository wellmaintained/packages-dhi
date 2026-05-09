# 0016. Multi-app CI architecture

Date: 2026-05-09

## Status

proposed

## Context

ADR-0015 established that each parallel-supported version-line is its own
app under `apps/<app>/`. The 2026-05-04 senaite restructure landed four:
`sbomify-current`, `senaite-1.3`, `senaite-2.3`, `senaite-current`. CI did
not follow. `build.yml` and `quality-gate.yml` had `apps/sbomify/`
hardcoded throughout, so the senaite apps shipped to the source tree with
zero CI signal — no build, no compliance pack, no SBOM, no scan. That gap
is the immediate trigger for this work.

Three other forces converge on the same workflow files:

1. **Cost.** The 2026-05-08 brief in `docs/research/blacksmith-cost-reduction.md`
   audited the org's April Blacksmith bill. Of the $102.01 net total, $76
   (75%) was sticky-disk storage, not compute. `packages-dhi` is a public
   repository — vanilla GitHub-hosted runners are free with no minute cap.
   Today only `build.yml` runs on Blacksmith; everything else is already
   on `ubuntu-latest`. Migrating the last holdout off Blacksmith and
   replacing `useblacksmith/stickydisk` with `actions/cache` is essentially
   a $50–80/month line item we can delete.

2. **Concurrent-PR contamination.** When senaite apps started building in
   CI for the first time, the shared `python-2.7` base — declared as a
   custom image in three of the four apps' `app-images.yaml` — was pushed
   under a moving `:dev` tag. Two concurrent PRs touching shared paths
   would clobber each other's `:dev` between the build and the consumer
   pull. We need a per-PR identity for shared images that downstream apps
   can pin to.

3. **Reusability.** With three senaite apps each declaring `python-2.7`,
   a naive per-app workflow rebuilds python-2.7 three times per
   shared-path PR. The cost is real, the customer-visible signal is
   worse: it tells consumers we don't treat shared images as shared.

A `/simplify` review on PR #24 surfaced seven findings — one high, four
medium, two low — about workflow duplication and a subtle race condition
in the handoff-tag computation when GitHub Actions populates `github.sha`
with the merge-commit SHA on `pull_request` events. The architecture
below absorbs all seven.

## Decision

Replace per-app build/quality-gate workflows with a single umbrella
workflow that fans out by matrix, builds shared images once per PR, and
pushes a per-PR handoff tag that downstream consumers reference via a
`__HANDOFF_TAG__` placeholder. Seven pillars, each with a clear job to
do.

### 1. Umbrella workflow with matrix-on-uses fan-out

`.github/workflows/build.yml` is the single entry point. It runs
`scripts/resolve-affected-apps`, conditionally fans out to a
`shared-images` matrix job, then fans out to an `app-builds` matrix that
calls `_app-build.yml` once per affected app via `uses:` — GitHub
Actions' matrix-on-reusable-workflow form. `quality-gate.yml` triggers
via `workflow_run` on Build success and downloads the
`affected-apps.json` artifact to drive its own matrix. Adding a fifth
app is dropping a directory under `apps/`; zero workflow code changes.

### 2. Vanilla GitHub-hosted runners with `actions/cache`

`runs-on: ubuntu-latest` everywhere. The tool cache is keyed on
`hashFiles('common/tool-versions.yaml')` via `actions/cache@v4`, pinned
SHA. No Blacksmith, no stickydisk volumes billing $0.50/GB-month. The
stickydisk tradeoff was a cache-hit rate and a wall-clock improvement;
neither matters at our PR cadence, and the bill was the dominant signal.

### 3. Build-once-per-PR shared images via handoff tag

Shared images — those whose `definition` field points under
`common/images/` — are built exactly once per umbrella run, by the
shared-images job. Each gets pushed under two tags: the durable
`:component_tag` (`<image>-<version>-<sha7>`, the existing component
identity) plus a per-PR `:pr-${sha7}` handoff tag.

The sha7 is the **PR head SHA**, not the merge SHA. This matters in two
places. First, the merge SHA changes every time the PR rebases on main,
breaking `_app-pre-release.yml`'s `gh run list ... headSha | startswith("${SHA7}")`
lookup. Second, GitHub Actions sets `github.sha` to the merge SHA on
`pull_request` events; left to its default, `ci/mod.just::_component-tag`
would compute a tag the rest of the chain cannot find. We pass the head
SHA explicitly via `SHA7_OVERRIDE` so every recipe in the chain agrees.

Downstream `prod.yaml` files reference shared images by a literal
`__HANDOFF_TAG__` placeholder that `scripts/build-image` substitutes at
build time. This is forced by DHI's manifest model: the DHI CLI reads
the YAML structurally before `--build-arg` can take effect, so we
cannot parameterise the reference any later than the YAML on disk. It
is not a clean answer, and we capture it as a tradeoff (§Trade-offs).

### 4. Per-app config separation

`apps/<app>/release.yaml` carries `tag_prefix` and `primary_image`,
read at runtime by `yq` from `apps/${inputs.app}/release.yaml`. They
were previously `workflow_call` inputs on `_app-pre-release.yml`,
forcing every per-app caller to repeat them. The data lives with the
app it describes; the workflow asks the app what its config is.

### 5. Idempotent CI helpers

`ci/mod.just`'s `_component-tag` recipe accepts an optional sha7
positional argument with `$SHA7_OVERRIDE` env fallback, so the same
recipe works whether invoked from a shell, the Justfile chain, or a
CI step that needs to override the merge-commit SHA. `digest-pin-update.yml`
writes its apps list to `$GITHUB_ENV` as `APPS=...` for bash variable
expansion — defence-in-depth against template injection through
workflow_dispatch inputs.

### 6. Build pipeline consolidation via composite action

`.github/actions/build-image-and-attest/action.yml` wraps `just ci build`
(which already pushes the component tag, signs, and attests SBOM +
provenance when `CI=true`) plus the optional `:pr-${sha7}` push. Before
this consolidation, the workflow-level `Push to GHCR` and `Sign image`
and `Attest SBOM` steps duplicated work the just chain was already
doing, producing **two** cosign signatures and two attestation entries
per component tag. The compliance signal now is unambiguous: one
signature, one SBOM attestation, one provenance attestation per
component tag.

### 7. Affected-apps resolver

`scripts/resolve-affected-apps` (159 lines, bash) takes a base SHA and
head SHA, diffs the tree, path-matches against each app's claim, and
emits three JSON outputs: `apps`, `shared-images` (the deduped union of
shared images those affected apps consume, paired with a representative
real consumer so the just chain can resolve `apps/${APP}/app-images.yaml`),
and `shared-needed` (boolean). The output also uploads as the
`affected-apps` artifact, which `quality-gate.yml` downloads via
`actions/download-artifact@v4` with `run-id` to drive its matrix
across workflow runs.

### Relation to other ADRs

- **ADR-0015 (Version-Line App Naming with `-current` Sliding Pointer)** —
  the *naming* convention is unchanged. This ADR delivers the CI
  plumbing that ADR-0015 implies but does not specify: how four apps
  share build infrastructure without proliferating per-app workflow
  files. The trade-off ADR-0015 flagged ("common base images need an
  explicit policy for what stays shared") is partially answered by
  Pillar 3's handoff tag.
- **ADR-0002 (Build-Once Promotion Pipeline)** — the build-once
  invariant continues to hold per component. Pillar 3 extends it to
  shared bases: python-2.7 builds once per PR, and three downstream
  senaite apps consume the same artefact via the handoff tag.

## Consequences

### Benefits

- All four apps now have CI signal. Senaite builds, scans, and
  compliance packs are first-class.
- Adding a fifth app is a directory drop. Workflow code does not grow
  with the app count.
- Shared images build once per PR, not once per consumer. python-2.7's
  4-vCPU compile is no longer billed three times.
- The compliance signal per component tag is now unambiguous: one
  cosign signature, one SBOM attestation, one provenance attestation.
- `packages-dhi`'s share of the Blacksmith bill goes to zero. Estimated
  saving: $25–40/month for this repo; the rest of the org's $102 bill
  remains until `wellmaintained/packages` migrates separately.

### Trade-offs

- The `__HANDOFF_TAG__` placeholder is a textual hack forced by DHI's
  manifest model. A proper answer would parameterise the image reference
  through `--build-arg`, which DHI does not currently support at the
  YAML-read stage. Documented here so future maintainers know the
  constraint, not the choice, drives the design.
- Branch protection rules referencing the old per-app check names
  (`build-sbomify-current`, `quality-gate-sbomify-current`, etc.) need
  updating to the new umbrella names (`Build`, `Quality Gate`).
- Artifact names now namespace by app: `stock-dhi-attestations` →
  `stock-dhi-attestations-${app}`; `custom-${image}-attestations` →
  `custom-${app}-${image}-attestations`. Anyone consuming these names
  externally needs the rename.
- `actions/cache` has a 10 GB per-repo limit and 7-day eviction. Neither
  is a real constraint for our workload today; if we add a fifth heavy
  shared image we should re-measure.

### Future considerations

- A `concurrency:` group on `build.yml`
  (`group: ${{ github.workflow }}-${{ github.ref }}`,
  `cancel-in-progress: true`) to bound runaway fan-out on
  shared-path PRs. Out of scope for the bundle that introduces the
  architecture; tracked as a follow-up yak.
- python-2.7 published as a versioned wellmaintained product with its
  own release lifecycle and CalVer tag, rather than a per-PR shared
  dependency. Discussed in PR #24's review; deferred until the senaite
  lines stabilise.
- A dedicated ADR for the `__HANDOFF_TAG__` placeholder approach,
  capturing the DHI-manifest constraint that forces it. This ADR
  mentions the choice; a deeper one could explore whether to push for
  a DHI feature request, vendor a forked DHI CLI, or live with the
  placeholder long-term.

## Alternatives considered

- **Per-app workflows without an umbrella.** Rejected. The shared-image
  problem multiplies linearly with app count; python-2.7 would build
  three times per shared-path PR.
- **Build-arg parameterisation of shared image references.** Rejected
  for now. DHI reads the manifest YAML structurally before `--build-arg`
  takes effect, so the substitution must happen on the file on disk.
  Re-evaluate if upstream DHI ships a templating hook.
- **python-2.7 as a separately-released product with its own version
  pin.** Deferred. The architectural move is sound; the timing is not.
  Captured as a follow-up yak.

## References

- PR #24 — workflow generalisation bundle (the change this ADR documents).
- `docs/research/blacksmith-cost-reduction.md` — cost evidence and
  vanilla-GHA migration recommendation.
- ADR-0015 — version-line app naming convention this CI architecture serves.
- `.github/workflows/build.yml` — umbrella workflow.
- `.github/workflows/_app-build.yml` — per-app reusable build.
- `.github/workflows/quality-gate.yml` — cross-workflow-run quality gate.
- `.github/actions/build-image-and-attest/action.yml` — composite build action.
- `scripts/resolve-affected-apps` — affected-apps + shared-images resolver.
