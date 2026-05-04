# Version-line criteria for app separation

## Summary

- **CRA treats a "substantially modified" version as a new product.** That is the load-bearing legal hook for treating a version-line as its own deployable. (CRA Art. 3(40), Recital 38, Art. 13.)
- **Each version "placed on the market" must have its own declared support period.** Article 13(8) lets a manufacturer consolidate vulnerability handling on the latest version *only when users can upgrade for free and without changing their environment*. Where the upgrade is not free-and-frictionless, the version-lines must be supported as separate products.
- **SBOM formats (CycloneDX, SPDX, NTIA) are per-build, per-version artefacts.** Component name + version is the universal identity primitive; a single SBOM document does not describe a range of versions, so per-version-line packaging is the format-native shape.
- **Industry OSS practice — Postgres, Python, Java LTS, Ubuntu/Debian/RHEL — all treat major lines as parallel, independently supported products** with separate repositories, separate vulnerability streams, and separate end-of-life clocks.
- **The decision rule that falls out of the evidence: a minor warrants its own app when *any* of (a) breaking ABI/API/runtime change, (b) the upgrade is not free-and-frictionless under CRA Art. 13(8), (c) the dependency closure (and therefore the VEX surface) changes materially, or (d) revalidation/recertification is required for the customer base.** Patches almost never; majors almost always; minors only when one of the four triggers fires.

## Findings

### CRA

The Cyber Resilience Act (Regulation (EU) 2024/2847) is the most relevant compliance frame for this question because it is the regulation that *explicitly* makes versioning a legal status. Article 3(40) defines a "substantial modification" as a change to a product with digital elements that "affects [its] compliance with the essential cybersecurity requirements" or alters its intended use. Recital 38 then establishes the consequence: a substantially modified product is treated as **a new product** for the purposes of the CRA — a fresh conformity assessment, a fresh CE marking, a fresh declaration of conformity. So the CRA does not ask "is this a new version?" — it asks "is this a substantially modified product?", and answers that with the full apparatus of new-product compliance ([EUR-Lex 2024/2847](https://eur-lex.europa.eu/eli/reg/2024/2847/oj/eng); [Streamlex Article 13 commentary](https://streamlex.eu/articles/cra-en-art-13/)).

Article 13 nails down the manufacturer-side mechanics. Manufacturers must determine and declare a **support period** for each product placed on the market — a minimum of five years, longer if the product's expected use is longer. During the support period the manufacturer must handle vulnerabilities (Annex I Part II) and provide security updates ([Cyber Resilience Act FAQ — Support Period, Sarah Fluchs](https://fluchsfriction.medium.com/cyber-resilience-act-faq-support-period-c9713f1ce7ed); [HeroDevs CRA blog](https://www.herodevs.com/blog-posts/cra-reporting-obligations-start-september-2026-what-eol-dependencies-mean-for-your-compliance)). Crucially for the version-line question, Article 13(8) contains an explicit consolidation clause: *"Where a manufacturer has placed subsequent substantially modified versions of a software product on the market, that manufacturer may ensure compliance with the essential cybersecurity requirement set out in Part II, point (2), of Annex I only for the version that it has last placed on the market, provided that the users of the versions that were previously placed on the market have access to the version last placed on the market free of charge and do not incur additional costs to adjust the hardware and software environment in which they use the original version of that product."* ([CRA text Art. 13](https://www.european-cyber-resilience-act.com/Cyber_Resilience_Act_Article_13.html)).

That clause is the legal pivot for this whole question. It is permissive — the manufacturer *may* consolidate — but the precondition is a free, frictionless upgrade path. If users of v1 cannot move to v2 without paying, without changing their hardware, or without changing their software environment, then v1 and v2 must each be brought into compliance separately. In packaging terms, that means each version-line carries its own SBOM, its own VEX, its own conformity assessment, and its own declaration of conformity. Annex I Part I (essential product cybersecurity properties — secure-by-default, data minimisation, vulnerability disclosure) and Annex I Part II (vulnerability handling processes — SBOM, coordinated disclosure, security updates) attach to that compliant unit ([digital-strategy.ec.europa.eu — CRA summary](https://digital-strategy.ec.europa.eu/en/policies/cra-summary); [Streamlex Annex I](https://streamlex.eu/annexes/cra-en-annex-i/)).

The Commission's first draft guidance (Nov 2025) reinforces case-by-case assessment: a software update is substantial if it introduces new or increased cybersecurity risks that were not addressed in the original risk assessment ([Linklaters: Commission issues first draft guidance](https://techinsights.linklaters.com/post/102mmlo/eu-cyber-resilience-act-commission-issues-first-draft-guidance-10-key-points-y); [Addleshaw Goddard briefing](https://www.addleshawgoddard.com/en/insights/insights-briefings/2026/technology/eu-cyber-resilience-act-european-commission-publishes-draft-guidance-clarify-key-obligations/)). This is the operational test the team must apply per minor: did this minor introduce risk that was not in scope of the prior version's risk assessment? If yes, it is a substantial modification — and operationally a new app.

### Other compliance regimes

**NIS2** (Directive (EU) 2022/2555) frames the question one level up. Article 21 obliges essential and important entities to manage supply-chain risk including the relationships between the entity and its direct suppliers ([NIS-2 Article 21](https://www.nis-2-directive.com/NIS_2_Directive_Article_21.html); [digital-strategy.ec.europa.eu — NIS2](https://digital-strategy.ec.europa.eu/en/policies/nis2-directive)). The directive itself does not specify SBOM mechanics, but the practical implementation pattern — and the Commission's own guidance — is per-version SBOM management so vulnerabilities can be tracked against the deployed version ([Sonatype on NIS2 vulnerability handling](https://www.sonatype.com/blog/vulnerability-handling-requirements-for-nis2-compliance); [Anchore: NIS2 + SBOMs](https://anchore.com/sbom/nis2-compliance-and-sboms/)). NIS2 reinforces, but does not by itself dictate, version-line separation.

**US Executive Order 14028 + NIST SP 800-218 (SSDF v1.1)** explicitly tie SBOMs to releases. Practice PS.3.2 ("Collect, safeguard, maintain, and share provenance data for all components of each software release") expects provenance and SBOM data per release ([NIST SP 800-218 final](https://csrc.nist.gov/pubs/sp/800/218/final); [NIST 800-218 PDF](https://nvlpubs.nist.gov/nistpubs/specialpublications/nist.sp.800-218.pdf)). The "release" granularity is the SSDF default. The framework is silent on whether two releases that share most code should be one product or two — that is delegated to the producer's own packaging — but it firmly establishes that SBOM identity is at release granularity, not at "product family" granularity. NIST's accompanying SBOM guidance under EO 14028 reiterates that SBOMs must be regenerated whenever the product changes ([NIST: Software Security in Supply Chains](https://www.nist.gov/itl/executive-order-14028-improving-nations-cybersecurity/software-security-supply-chains-software-1)).

**ISO/IEC 27001:2022 and 27002:2022** require change management (Annex A 8.32) and supplier-relationship security (5.19–5.23) but do not prescribe a version-line model. They reinforce that *changes must be assessed* — which is the same change-impact lens the CRA applies. The standards are compatible with either packaging choice; they raise the cost of an undocumented version-line transition.

**ISO/IEC 17025** is directly relevant to the SENAITE customer base (testing and calibration laboratories). The 2025 edition explicitly addresses software validation, digital data integrity, and the impact of software changes ([ISO/IEC 17025 standard page](https://www.iso.org/standard/66912.html); [Method of Software Validation reference](https://www.demarcheiso17025.com/document/Method%20of%20Software%20Validation.pdf); [ScisPot ISO 17025 guide](https://www.scispot.com/blog/iso-17025-compliance-guide-requirements-software-best-practices)). The validation guidance language — *"when a new version of the software product is taken into use, the effect on the existing system should be carefully analyzed and the degree of revalidation decided"* — establishes a customer-side cost ceiling on minor upgrades. Labs running an accredited LIMS will not silently absorb a minor that changes the calculation engine, the audit-trail format, or the data model. From the lab's perspective, *any* version that crosses the revalidation threshold is a new product.

### SBOM formats

**CycloneDX** (current spec v1.6, with v1.7 in development) anchors identity at the component level. Every component in the BOM has a `name` and `version`, plus an optional `bom-ref` that uniquely identifies it within the document. The metadata.component field describes the *subject* of the BOM — the thing the BOM is *about* — and is itself a single component with a single version ([CycloneDX Specification Overview](https://cyclonedx.org/specification/overview/); [CycloneDX 1.5 JSON Reference](https://cyclonedx.org/docs/1.5/json/)). VEX in CycloneDX expresses vulnerability applicability through `vulnerabilities[].affects[].ref` (pointing to a `bom-ref`) and `versions[]` (specific versions or vers-ranges like `vers:semver/>=2.0.0|<5.0.0`) ([CycloneDX VEX capability page](https://cyclonedx.org/capabilities/vex/); [CISA VEX use cases bom-examples](https://github.com/CycloneDX/bom-examples/blob/master/VEX/CISA-Use-Cases/Case-4/vex.json)). So while a single VEX *statement* can span versions, a CycloneDX BOM *document* describes one specific build of one specific version. Parallel-supported version-lines therefore produce parallel BOMs.

**SPDX 3.0.1** uses the same fundamental shape ([SPDX 3.0.1 spec](https://spdx.github.io/spdx-spec/v3.0.1/); [SPDX-NTIA HOWTO](https://spdx.github.io/spdx-ntia-sbom-howto/)). Each `Package` has a `versionInfo`. The document has a single root element (in 2.x: `DocumentDescribes`; in 3.0: the SPDX Element relationships) anchoring the SBOM to one specific build. There is no concept of "this SBOM applies to versions X through Y" in either 2.x or 3.0. SPDX, like CycloneDX, expects per-version SBOMs.

**NTIA Minimum Elements (2021)** fix this even more concretely. The seven baseline data fields are Supplier Name, Component Name, Component Version, Component Identifiers (e.g. CPE/PURL), Dependency Relationship, Author, and Timestamp ([NTIA report PDF](https://www.ntia.gov/sites/default/files/publications/sbom_minimum_elements_report_0.pdf); [NTIA 2021 minimum elements page](https://www.ntia.gov/report/2021/minimum-elements-software-bill-materials-sbom)). The 2025 CISA refresh keeps the same per-version-instance posture ([2025 CISA SBOM Minimum Elements draft](https://www.cisa.gov/sites/default/files/2025-08/2025_CISA_SBOM_Minimum_Elements.pdf)). Together: every authoritative SBOM standard treats version as a primary identity field that is part of the SBOM's primary key. Version-lines that diverge in deps inevitably produce different SBOMs — the format forces the question.

### Industry practice

OSS projects that have operated parallel-supported version-lines for years have converged on a consistent pattern: **major version = independent product**.

PostgreSQL supports each major for five years from initial release; majors are released roughly annually; minors share a backwards-compatible on-disk format; major upgrades require pg_upgrade or dump/reload ([PostgreSQL Versioning Policy](https://www.postgresql.org/support/versioning/); [endoflife.date Postgres](https://endoflife.date/postgresql)). Each major has its own source branch, minor-release stream, and security advisories. Postgres 14 and 17 are operationally separate products that share an upstream.

Python does the same. Each minor (3.x) gets ~5 years of support — ~2 full bug-fix, ~3 security-only ([Status of Python versions](https://devguide.python.org/versions/); [endoflife.date Python](https://endoflife.date/python)). Five minors run in parallel at any time. Java's LTS model is even more explicit: Java 8, 11, 17, 21, and 25 receive concurrent quarterly updates from Oracle and Red Hat ([Oracle Java SE Support Roadmap](https://www.oracle.com/java/technologies/java-se-support-roadmap.html); [Red Hat OpenJDK lifecycle](https://access.redhat.com/articles/1299013)). Each LTS has its own toolchain, backport policy, and security stream. Linux distros do the same at the OS level — Ubuntu LTS releases each live in their own apt repos with independent EOL clocks ([Ubuntu release cycle](https://ubuntu.com/about/release-cycle)).

The signal across all four ecosystems: **once a version-line is in parallel support, it gets its own everything** — source branch, build, repository, SBOM stream, EOL clock. The structural separation pattern is the *default*, and it kicks in at major-version boundaries.

## Recommended criteria

### When a version-line gets its own app (rule)

**A version-line warrants its own deployable app when *any one* of the following is true:**

1. **Breaking ABI/API/runtime change.** Different language runtime version (e.g. Python 2 → Python 3), different framework major (e.g. Plone 4 → 5), different database schema version that requires a non-trivial migration, or any change that breaks user code or operator scripts. *Evidence:* CRA Art. 3(40)/Recital 38 substantial modification; SemVer convention.

2. **Upgrade is not free-and-frictionless under CRA Art. 13(8).** If users would have to pay, change hardware, swap out a runtime, or migrate data manually, the upgrade fails the Article 13(8) test and the version-lines must be supported in parallel. *Evidence:* CRA Art. 13(8) consolidation precondition.

3. **Dependency closure (and therefore VEX surface) changes materially.** When the SBOM for v(N) and v(N+1) share less than ~80% of their direct dependency closure, vulnerabilities tracked against one will not apply cleanly to the other. Operators need separate VEX statements; conflating them produces noisy or false advisories. *Evidence:* CycloneDX/SPDX/NTIA per-version SBOM model; per-version VEX practice.

4. **Customer revalidation/recertification is required.** For customers under ISO 17025 (labs), GxP (life sciences), or sectoral certification regimes, a version-line that crosses the revalidation threshold *is already a separate product from the customer's perspective*. Packaging it separately matches the customer's mental model and audit trail. *Evidence:* ISO/IEC 17025:2025 software validation guidance; lab QA practice.

**Default behaviour for the version axis:**

- **Patch (e.g. 1.3.4 → 1.3.5):** never a new app. Patches by SemVer convention are bug-fix-only, do not change the dep closure, and are always meant to be drop-in. If a patch *did* trigger any of the four criteria, the version was mis-numbered.
- **Major (e.g. 1.x → 2.x):** almost always a new app. By convention a major is allowed to break things, and in OSS practice it always does. The four criteria are typically all triggered simultaneously.
- **Minor (e.g. 1.3 → 1.4):** judgement call against the four criteria. The operator's hunch — "new app only if it contains breaking changes" — maps directly to criterion 1. The framework adds three more triggers that catch breaking changes hidden in deps, in upgrade economics, and in customer obligations.

### Application to senaite (1.3 vs 2.0)

The evidence strongly supports treating SENAITE 1.3 and 2.0 as separate apps.

- **Criterion 1 (breaking runtime).** SENAITE 1.3 runs on Plone 4.3.18; SENAITE 2.x runs on Plone 5.2 ([senaite.lims 1.3 PyPI](https://pypi.org/project/senaite.lims/1.3.0/); [SENAITE 2.x P8 upgrade guide](https://github.com/senaite/senaite.core/blob/2.x/P8_UPGRADE_GUIDE.md)). The whole framework underneath the LIMS is different. **Triggered.**
- **Criterion 2 (upgrade friction).** Migrating from 1.x to 2.0 requires the official "Senaite 1 to 2 Configuration Migration" tooling and a Plone upgrade pass before the SENAITE upgrade itself ([bikalims.org migration guide](https://www.bikalims.org/manual/technical/senaite-1-to-2-configuration-migration)). That is plainly not free-and-frictionless under CRA Art. 13(8). **Triggered.**
- **Criterion 3 (VEX surface).** The Plone 4.3 stack and the Plone 5.2 stack share almost nothing at the dependency level. Vulnerabilities in the Plone 4.3 dep tree do not apply to 2.x and vice versa. **Triggered.**
- **Criterion 4 (revalidation).** Lab customers running an accredited LIMS will fully revalidate when crossing a Plone major. ISO 17025 effectively forces them to. **Triggered.**

All four criteria fire. SENAITE 1.3 and SENAITE 2.0 should each be their own app (`apps/senaite-1.3`, `apps/senaite-2.0`). This is not a stylistic choice — it is what the regulations and the standards demand the moment a customer asks for a CRA-aligned SBOM.

### Application to sbomify (CalVer 26.x)

CalVer (sbomify uses 25.x, 26.x, …) interacts with the four criteria differently from SemVer.

A CalVer "major" (the year) is a release-cadence artifact, not a semantic promise. CalVer projects can ship a fully compatible 26.0 from a 25.x predecessor, or they can ship a breaking 26.0 — the version number alone does not say. So the four-criteria test applies *unchanged*: 26.x gets its own app if and only if at least one criterion fires.

In practice CalVer projects tend to publish per-year support windows ([CalVer site](https://calver.org/); [SemVer vs CalVer SensioLabs](https://sensiolabs.com/blog/2025/semantic-vs-calendar-versioning)) and announce EOL on the previous year, which usually means a per-year app boundary aligns naturally with the project's own support model. For sbomify specifically, the operational guideline is:

- 26.0 → 26.x is the same app (minors within a calendar year stay together unless a criterion fires).
- 25.x → 26.x is a separate app *if* the year-jump introduced any breaking change, runtime swap, or material dep change. If it did not — i.e. 26.0 is a non-breaking carryover from 25.x — they can stay in one app, with the year just incrementing the version number.

The default disposition for CalVer projects with a consistent yearly support window is therefore **one app per calendar major**, mirroring how Python or Postgres treat their majors. Only confirm by checking criterion 1 against the changelog before committing.

## Open questions / convention picks

- **What counts as "material dep change" in criterion 3?** The 80% direct-dep overlap threshold is a convention, not a derivation. A more rigorous version would compare CVE applicability set sizes, but that is more expensive to compute. *Convention pick: ~80% direct-dep overlap; revisit if it produces nuisance splits.*
- **Beta/RC versions during a major transition.** The CRA's "placed on the market" language excludes beta/RC, so they do not strictly need their own app from a compliance standpoint. *Convention pick: keep betas inside the target major's app until GA, then they become the canonical version.*
- **Long-tailed legacy support.** SENAITE 1.3 may need to live for years after 2.x is canonical. The CRA permits this with "public software archive" semantics provided users are warned ([CRA Art. 13 commentary](https://streamlex.eu/articles/cra-en-art-13/)). The app-per-version-line model already supports this — old apps stay in the manifest, just on a longer cadence.
- **Cross-minor SBOM/VEX deduplication.** If two minors within an app share 95% of their deps, do we ship two SBOMs or one? The format answer is two (per-version), but the *publication* answer might be one with version ranges in VEX. *Convention pick: always emit per-version SBOMs (format-native); allow VEX statements to span ranges where the analysis genuinely applies to multiple versions.*
- **The "metadata only" sub-case.** SENAITE 1.3.3+ became a metadata-only package — it pins versions of other packages but adds no code. That is structurally different from a normal release. *Convention pick: treat metadata-only releases as patches within the same app; the SBOM still differs (different pins) but the criteria do not fire.*

## References

- [Regulation (EU) 2024/2847 — Cyber Resilience Act, EUR-Lex](https://eur-lex.europa.eu/eli/reg/2024/2847/oj/eng)
- [CRA Article 13 (manufacturer obligations) — Streamlex commentary](https://streamlex.eu/articles/cra-en-art-13/)
- [CRA Article 13 text — european-cyber-resilience-act.com](https://www.european-cyber-resilience-act.com/Cyber_Resilience_Act_Article_13.html)
- [CRA Annex I — Streamlex](https://streamlex.eu/annexes/cra-en-annex-i/)
- [Cyber Resilience Act summary — European Commission](https://digital-strategy.ec.europa.eu/en/policies/cra-summary)
- [Cyber Resilience Act FAQ: Support Period — Sarah Fluchs](https://fluchsfriction.medium.com/cyber-resilience-act-faq-support-period-c9713f1ce7ed)
- [European Commission first draft CRA guidance — Linklaters summary](https://techinsights.linklaters.com/post/102mmlo/eu-cyber-resilience-act-commission-issues-first-draft-guidance-10-key-points-y)
- [European Commission first draft CRA guidance — Addleshaw Goddard briefing](https://www.addleshawgoddard.com/en/insights/insights-briefings/2026/technology/eu-cyber-resilience-act-european-commission-publishes-draft-guidance-clarify-key-obligations/)
- [HeroDevs: CRA reporting obligations & EOL dependencies](https://www.herodevs.com/blog-posts/cra-reporting-obligations-start-september-2026-what-eol-dependencies-mean-for-your-compliance)
- [NIS2 Directive — European Commission](https://digital-strategy.ec.europa.eu/en/policies/nis2-directive)
- [NIS-2 Article 21 (risk-management measures)](https://www.nis-2-directive.com/NIS_2_Directive_Article_21.html)
- [Sonatype: NIS2 vulnerability handling requirements](https://www.sonatype.com/blog/vulnerability-handling-requirements-for-nis2-compliance)
- [Anchore: NIS2 compliance and SBOMs](https://anchore.com/sbom/nis2-compliance-and-sboms/)
- [NIST SP 800-218 SSDF v1.1 — final](https://csrc.nist.gov/pubs/sp/800/218/final)
- [NIST SP 800-218 SSDF v1.1 — PDF](https://nvlpubs.nist.gov/nistpubs/specialpublications/nist.sp.800-218.pdf)
- [NIST: Software Security in Supply Chains (EO 14028)](https://www.nist.gov/itl/executive-order-14028-improving-nations-cybersecurity/software-security-supply-chains-software-1)
- [ISO/IEC 17025:2017 — General requirements for testing and calibration laboratories](https://www.iso.org/standard/66912.html)
- [Method of Software Validation under ISO 17025 — demarcheiso17025.com](https://www.demarcheiso17025.com/document/Method%20of%20Software%20Validation.pdf)
- [ScisPot ISO 17025 compliance guide 2026](https://www.scispot.com/blog/iso-17025-compliance-guide-requirements-software-best-practices)
- [CycloneDX Specification Overview](https://cyclonedx.org/specification/overview/)
- [CycloneDX 1.5 JSON Reference](https://cyclonedx.org/docs/1.5/json/)
- [CycloneDX VEX capability page](https://cyclonedx.org/capabilities/vex/)
- [CycloneDX bom-examples — VEX CISA Use Cases Case 4](https://github.com/CycloneDX/bom-examples/blob/master/VEX/CISA-Use-Cases/Case-4/vex.json)
- [SPDX Specification 3.0.1](https://spdx.github.io/spdx-spec/v3.0.1/)
- [SPDX–NTIA SBOM HOWTO](https://spdx.github.io/spdx-ntia-sbom-howto/)
- [NTIA Minimum Elements For an SBOM (2021)](https://www.ntia.gov/report/2021/minimum-elements-software-bill-materials-sbom)
- [NTIA Minimum Elements PDF](https://www.ntia.gov/sites/default/files/publications/sbom_minimum_elements_report_0.pdf)
- [2025 CISA SBOM Minimum Elements (draft)](https://www.cisa.gov/sites/default/files/2025-08/2025_CISA_SBOM_Minimum_Elements.pdf)
- [PostgreSQL Versioning Policy](https://www.postgresql.org/support/versioning/)
- [endoflife.date — PostgreSQL](https://endoflife.date/postgresql)
- [Status of Python versions — devguide](https://devguide.python.org/versions/)
- [endoflife.date — Python](https://endoflife.date/python)
- [Oracle Java SE Support Roadmap](https://www.oracle.com/java/technologies/java-se-support-roadmap.html)
- [Red Hat OpenJDK Lifecycle and Support Policy](https://access.redhat.com/articles/1299013)
- [Ubuntu release cycle](https://ubuntu.com/about/release-cycle)
- [SENAITE 1.3 → 2.0 migration guide (Bika)](https://www.bikalims.org/manual/technical/senaite-1-to-2-configuration-migration)
- [SENAITE 2.x P8 upgrade guide (Plone 5 → Plone 8)](https://github.com/senaite/senaite.core/blob/2.x/P8_UPGRADE_GUIDE.md)
- [senaite.lims 1.3.0 — PyPI](https://pypi.org/project/senaite.lims/1.3.0/)
- [CalVer — Calendar Versioning](https://calver.org/)
- [SemVer vs CalVer — SensioLabs](https://sensiolabs.com/blog/2025/semantic-vs-calendar-versioning)
