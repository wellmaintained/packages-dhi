# 0005. Build Release Website at Pre-Release, Deploy from Artifact

Date: 2026-04-14

## Status

accepted

## Context

The release website is a Hugo static site that renders compliance data (SBOMs,
vulnerability scans, license information) for all images in an app-collection.
It needs access to the compliance artifacts and the Hugo binary.

Building the website at promotion time (when the pre-release flag is removed)
creates problems:

- The deploy workflow runs from the release tag's commit, which may not have
  the latest workflow code.
- Tool binaries (Hugo) must be extracted from DHI images on the deploy runner,
  requiring registry authentication and Docker setup.
- The deploy step becomes complex and fragile, coupling website generation with
  static site publishing.

## Decision

Build the release website during the pre-release workflow, where all compliance
artifacts are already available from the build step. Package the generated static
site as `release-website.tar.gz` and attach it to the GitHub release alongside
the compliance pack.

When the pre-release is promoted to a release, the deploy workflow downloads the
pre-built tarball from the release assets and publishes it to GitHub Pages. No
tool extraction, no Hugo build, no artifact assembly — just download and deploy.

## Consequences

- The deploy workflow is simple and fast: download a tarball, publish to Pages.
- No dependency on DHI tool images or registry auth at deploy time.
- The website content is frozen at pre-release creation. What you inspect in
  the pre-release is exactly what gets published.
- The pre-release workflow takes slightly longer (Hugo build added), but this
  runs once per merge, not per promotion attempt.
