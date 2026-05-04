# 0012. Layer Python 2.7 on debian13 Base

Date: 2026-05-03

## Status

proposed

## Context

ADR-0011 commits to building CPython 2.7 from canonical sources. That
decision is silent on what rootfs the resulting binary runs against,
who patches the system shared libraries it links to, and how the
attribution flows into the SBOM.

A heritage Python build still needs a current operating environment.
CPython 2.7 dynamically links against `libssl`, `libsqlite3`,
`libffi`, `libreadline`, `libncurses`, `zlib`, `libbz2`, `liblzma`,
`libgdbm`, and a handful of others (see `dhi.yaml:30-46`). Each of
those carries its own CVE stream. If we shipped a rootfs as old as
the runtime, every system-level CVE landed against debian
8/9/jessie/buster would land against us. That is exactly the
maintenance treadmill the demo is supposed to argue against.

The repo's existing pattern, established in ADR-0001, is to layer
custom images on top of DHI's hardened base. DHI patches the system
libraries, ships an SBOM and VEX for the rootfs, and provides a
build frontend that pins the rootfs by digest. Custom images get the
DHI layer's patch cadence "for free".

For Python 2.7, this means:

- **Runtime base = debian13.** Selected implicitly by the build
  syntax header `# syntax=dhi.io/build:2-debian13` at the top of the
  image YAML. The frontend version is `2`; `debian13` pins the
  rootfs that the no-`uses:` (top-level) build phase produces.
- **Builder base = `dhi.io/python:3.14-debian13-dev`.** Used as a
  *generic* build host, not as the runtime — DHI does not catalog a
  `python:2.7-debian13-dev` image (verified 2026-05-03 via
  `bin/crane manifest`). The Python 3.14 builder gives us a
  debian13-aligned compile environment with `build-essential` and
  the `-dev` headers we need (`libssl-dev`, `libsqlite3-dev`, etc).
  The Python 3 host interpreter is incidental — only `gcc`, `make`,
  and the dev headers are used.

The runtime image's vendor annotation is `wellmaintained` (the layer
*we* own), even though every system package below it carries DHI's
attestations. The OCI annotations distinguish: the image's vendor
records who owns the *layer being published*; the SBOM's component
list records who supplied each constituent. Both views are needed.

## Decision

**Layer the custom Python 2.7 build on top of `dhi.io/build:2-debian13`
and use `dhi.io/python:3.14-debian13-dev` as the builder host.**

In `common/images/python-2.7/dhi.yaml`:

```yaml
# syntax=dhi.io/build:2-debian13          # ← runtime rootfs (implicit)
# ...
contents:
  packages:                                # runtime debs (debian13 t64)
    - libssl3t64
    - libsqlite3-0
    - ...
  builds:
    - name: cpython-build
      uses: dhi.io/python:3.14-debian13-dev@sha256:...   # ← builder (digest-pinned)
      contents:
        packages:                          # build-time debs
          - build-essential
          - libssl-dev
          - ...
```

The runtime image's annotations declare the layer's owner explicitly:

```yaml
annotations:
  org.opencontainers.image.vendor: wellmaintained
  org.opencontainers.image.licenses: PSF-2.0
  org.opencontainers.image.source: https://github.com/wellmaintained/packages-dhi
```

DHI's debian13 rootfs ships its own SBOM and VEX as OCI attestations.
Those attestations are extracted into `artifacts/python-2.7/` by the
existing `extract-dhi-attestations` flow, alongside the
wellmaintained-authored attestations for the Python layer itself.
Consumers see *both*: DHI's analysis of the system libraries plus
wellmaintained's analysis of CPython.

### Layer attribution table

The release-website renders this attribution explicitly (see
`apps/senaite/release-website/`). The split for the heritage stack is:

| Layer                              | Owner          | Patch cadence              | Evidence                            |
|------------------------------------|----------------|----------------------------|-------------------------------------|
| debian13 rootfs + system libraries | DHI            | DHI's standard cadence     | `vex.dhi.json`, DHI SLSA provenance |
| CPython 2.7.18 + patch series      | wellmaintained | wellmaintained engineers   | `python-2.7.vex.json`, this repo's patches/ + CVE-LOG |
| Plone 5.2 + SENAITE 2.0.0          | upstream pinned| upstream (no patches today)| `senaite-lims.vex.json`, app-images.lock.yaml |
| Deployment composition             | wellmaintained | wellmaintained engineers   | `apps/senaite/deployments/`         |

### Relation to other ADRs

- **ADR-0001 (Adopt DHI as Base Image Foundation)** — this ADR
  applies the layered model from 0001 to a heritage runtime. Nothing
  in 0001 changes; the implementation just demonstrates that the
  layering works for an EOL language as well as for current ones.
- **ADR-0011 (Build Python 2.7 from canonical sources)** — describes
  *what* we build; this ADR describes *what we build it on top of*.

## Consequences

### Benefits

- **System-library CVEs are DHI's problem.** OpenSSL, glibc,
  zlib, libsqlite — every patch DHI ships for debian13 lands in
  the next pull of the rootfs. We do not maintain debian13.
- **Per-layer attestation.** The SPDX SBOM for the Python 2.7 image
  has CPython as a component (with our PSF-2.0 license attribution)
  and the debian-package list (with DHI's deb purls and the t64
  qualifiers debian13 introduced for the year-2038 transition). A
  consumer can answer "who patches OpenSSL on this image?" by
  inspecting the SBOM — DHI's `vex.dhi.json` covers it.
- **Matches the existing pattern.** Sbomify-app and minio both layer
  on `dhi.io/build:2-debian13`; senaite's python-2.7 follows the
  same recipe. Tooling that already knows how to extract and render
  the layered attestations works without modification.

### Trade-offs

- **debian13 is newer than CPython 2.7 expected.** The t64 transition
  in debian13 renamed several runtime libraries (`libssl3` →
  `libssl3t64`, `libreadline8` → `libreadline8t64`, etc.) to handle
  64-bit `time_t` on 32-bit architectures. CPython 2.7 itself was
  written when these transitions were not in scope, but the
  packages we link against on debian13 are the t64 variants. This
  is documented inline in `dhi.yaml`. There is a tiny risk that some
  obscure stdlib path probes for the pre-t64 sonames; we have not
  hit it in builds so far.
- **Builder is Python 3, runtime is Python 2.** The `python:3.14`
  builder image carries a Python 3 interpreter in `/usr/local/bin`.
  We use it only as a build host; the configure/make steps are
  shell. The runtime image does not include Python 3 — it only
  copies `/opt/python-2.7` from the builder via the `outputs:`
  block.
- **Conditional on DHI continuing to ship debian13.** When DHI
  rolls debian13 forward to debian14, this image needs a
  pin update and a fresh SBOM extraction. ADR-0001 already covers
  the maintenance pattern; mentioning it here so the heritage
  story does not look like an exception to the rule.

### Future considerations

- **`-dev` variant of python-2.7.** If a downstream image ever needs
  a builder image *with Python 2.7 preinstalled* (e.g. for
  compiling Python 2 C extensions in a separate stage), we would
  need to publish a sibling image (`python-2.7-dev`). The current
  senaite-lims build does not require it — the LIMS image's
  `uses:` pin can resolve to the runtime python-2.7. The orientation
  notes (§9 Q3) recommend two manifest entries rather than a
  variant-emitting build if the need ever arises.
- **DHI cataloging python-2.7-debian13-dev.** Unlikely (DHI's
  catalog targets currently-supported runtimes), but if it ever
  ships, switching the builder pin would be a one-line change with
  no semantic difference for downstream images. Worth a one-time
  re-check of the catalog as part of any major bump.
- **Pull-through of DHI's `vex.dhi.json` into the python-2.7 SBOM
  view.** Today consumers must look at *two* VEX files
  (DHI's `vex.dhi.json` and our `python-2.7.vex.json`) to see the
  full vulnerability picture. ADR-0009's "future considerations"
  already tracks the inheritance question generally; this ADR adds
  a heritage-specific motivation for it.
