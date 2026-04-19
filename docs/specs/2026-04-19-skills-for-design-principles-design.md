# Skills for Design Principles

Date: 2026-04-19

## Context

The `packages-dhi` repo has eight Architecture Decision Records that capture
significant design choices — base image strategy, pipeline shape, SBOM
authority, local/CI parity, tooling packaging. ADRs record **why** a decision
was made, but they are passive documents. A new change that violates one is
not automatically surfaced.

The goal is to encode these principles as Claude Code skills so that any
work on the repo routes through the relevant principle before the change
is proposed. Eventually the portable principles will be extracted and
reused in sibling projects (e.g. a Chainguard-based variant, or a
different application atop the same pipeline).

## Decision

Create a two-tier set of skills alongside the ADRs. Tier 1 skills capture
ecosystem-agnostic principles that any container pipeline project can
reuse. Tier 2 skills capture the specific mechanisms that apply those
principles in `packages-dhi`.

### Tier 1 — Common principles (portable)

| Skill | Captures |
|---|---|
| `common-build-once-promotion` | Build artefacts once on PR, promote via metadata tags, never rebuild downstream |
| `common-unified-compliance-output` | One command produces the artefact and all its compliance outputs |
| `common-deploy-from-artifact` | Build deployables at the pre-release moment; deploy downloads and publishes |
| `common-local-ci-parity` | Same tools, versions, scripts locally and in CI; spec+lock versioning (binary and uvx variants); CI adds orchestration, never replaces build logic |
| `common-authoritative-sboms` | SBOMs derive from the build itself; conversion preserves relationships |
| `common-sbom-enrichment` | Enrich after conversion; keep the raw build-time SBOM unchanged |

### Tier 2 — Specific mechanisms (packages-dhi)

| Skill | Captures |
|---|---|
| `dhi-base-images` | Prefer stock DHI (pinned digest + attestation extraction); custom via DHI YAML frontend with `docker-scout` SBOM generator; `protobom/sbom-convert` for SPDX→CycloneDX |
| `sbomify-action-enrichment` | sbomify-action invoked via uvx with `--sbom-file --enrich --no-upload`, running on CycloneDX |

### Carve-out rules

- **ADR-0003 and ADR-0007 are split.** The principles ("SBOMs have one
  authoritative source derived from the build"; "enrich after convert,
  preserve the raw") live in Tier 1. The mechanisms (docker-scout,
  protobom/sbom-convert, sbomify-action) live in Tier 2. A Chainguard
  sibling can keep the Tier 1 skills and swap Tier 2.
- **ADR-0008 (uvx) is absorbed by `common-local-ci-parity`.** Both
  express the same intent — pin tool versions and run them identically
  locally and in CI. The uvx variant is one concrete shape of the
  spec+lock pattern.

## Layout

```
packages-dhi/
├── docs/adr/                           # existing ADRs (unchanged)
├── .claude/
│   ├── principles.md                   # always-on manifest
│   └── skills/
│       ├── common-build-once-promotion/SKILL.md
│       ├── common-unified-compliance-output/SKILL.md
│       ├── common-deploy-from-artifact/SKILL.md
│       ├── common-local-ci-parity/SKILL.md
│       ├── common-authoritative-sboms/SKILL.md
│       ├── common-sbom-enrichment/SKILL.md
│       ├── dhi-base-images/SKILL.md
│       └── sbomify-action-enrichment/SKILL.md
└── CLAUDE.md                           # adds `@.claude/principles.md`
```

All skills live in `packages-dhi/.claude/skills/` initially. The `common-`
prefix marks Tier 1 skills and makes the later extraction to a plugin a
simple `git mv` glob.

## Firing model

A hybrid of always-on context and semantic triggers.

**Always-on manifest.** `packages-dhi/.claude/principles.md` is ~30 lines
— one bullet per principle with a pointer to the named skill. It is
imported by `packages-dhi/CLAUDE.md` via `@.claude/principles.md` so it
loads every session. Claude learns that the principles exist without
loading their full content.

```markdown
# Pipeline Design Principles

When work touches the build, compliance, or deploy pipeline, these
principles apply. If the current task relates to one of them, invoke
the named skill for the full rules.

- **Build once, promote via metadata.** Artefacts are built on PR,
  promoted by adding tags. Never rebuilt downstream.
  → `common-build-once-promotion`

- **One command, all compliance outputs.** Image + SBOMs + scans +
  provenance in a single invocation. No partial states.
  → `common-unified-compliance-output`

- **Deploy is an artefact consumer, not a builder.** Build deployables
  at pre-release; deploy downloads and publishes.
  → `common-deploy-from-artifact`

- **Local = CI.** Same tools, versions, scripts. Spec+lock versioning.
  CI adds orchestration, never replaces build logic.
  → `common-local-ci-parity`

- **SBOMs derive from the build.** Single source of truth via build
  attestations; conversion preserves relationships.
  → `common-authoritative-sboms`

- **Enrich after conversion, keep the raw.** Enrichment runs on the
  converted format; the build's raw SBOM stays unchanged.
  → `common-sbom-enrichment`
```

**Skill body loading.** The full `SKILL.md` loads when Claude decides
the task matches the skill's `description`. Descriptions enumerate
realistic trigger phrases and file patterns.

## Skill content shape

Each skill file is 50–150 lines. The shape is consistent so Claude
applies it mechanically.

**Tier 1 template:**

```markdown
---
name: common-<name>
description: Use when <triggers>. Principle: <one-sentence essence>.
---

# <Skill Name>

## The Principle
<2-3 sentences. The thing that is always true.>

## When This Applies
<Concrete scenarios that should invoke this skill.>

## Rules
<Numbered imperatives.>

## Common Violations
<Anti-patterns to watch for, each with reasoning.>
```

**Tier 2 template:**

```markdown
---
name: <specific-name>
description: Use when <triggers specific to this mechanism>.
---

# <Skill Name>

## The Mechanism
<What concrete approach this skill captures.>

## Implements
<Reference to the common- skill(s) this is an implementation of.>

## Files / Tools Involved
<Concrete paths, tool names, shim locations.>

## Procedure
<Step-by-step for the most common operation.>
```

### Cross-reference direction

Tier 2 points up to Tier 1 by name. Tier 1 does not point down. A
common skill stands alone — portable, ecosystem-agnostic, reusable in
any sibling project regardless of which mechanism implements it.

### No ADR references inside skills

Skills are self-contained. The ADRs can cite skills ("skill
`common-local-ci-parity` captures this principle"), but the reverse
dependency is avoided so that the common skills remain portable without
dragging their originating ADRs along.

## Validation

**Light validation now.** After the skills are written, a smoke test in
a throwaway `packages-dhi/` session issues 8–10 realistic prompts and
checks which skills Claude invokes. Descriptions get tuned for any
skill that fails to fire for its intended prompts.

**Deferred.** No hook-based enforcement. No automatic ADR↔skill sync.
Formal eval harnesses (via `skill-creator`) only if drift becomes
observable in real PRs.

## Extraction path (future)

When a second project needs these principles:

1. Create a plugin (provisional name `pipeline-principles`) with a
   `skills/` directory and a `principles.md` at its root.
2. `git mv packages-dhi/.claude/skills/common-* <plugin>/skills/`
3. `git mv packages-dhi/.claude/principles.md <plugin>/principles.md`
4. Replace the import in `packages-dhi/CLAUDE.md` with the plugin path.
5. Any new project installs the plugin, imports the manifest, and adds
   its own Tier 2 skills in-repo.

No skill content needs to change. The design decisions that make this
mechanical:

- The `common-` prefix makes step 2 a glob.
- Tier 1 does not reference Tier 2, so nothing breaks when Tier 2 is
  left behind.
- Skills do not cite ADRs, so no dead links after extraction.

## Consequences

- Claude is aware of the project's design principles from session
  start without loading the full content of every skill.
- Principle violations surface during the change rather than during
  review. The skill provides the rule and the common-violation list;
  Claude raises it before proposing code.
- Extraction to a plugin is bounded work — rename, move, re-import.
  No skill rewrite.
- Skills must be maintained when the principle they encode changes.
  The ADR remains the stable historical record; the skill is the
  operational interpretation and may drift forward ahead of an ADR
  update. This decoupling is intentional.
- A project that installs the plugin but does not want one of the
  principles must edit the imported manifest locally or override the
  skill. This is an acceptable friction cost for the shared case.
