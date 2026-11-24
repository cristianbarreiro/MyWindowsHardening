---
type: Format Specification
title: Open Knowledge Format v0.2
description: Upstream specification for agent-readable knowledge bundles with Markdown concepts and YAML frontmatter.
status: draft
generated:
  by: openai/gpt-6
  at: 2026-11-24T19:16:00Z
stale_after: 2027-02-22T00:00:00Z
sources:
  - id: googlecloud-okf-v02
    resource: https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md
    title: GoogleCloudPlatform knowledge-catalog — OKF specification
---

# Adopted version

This repository uses **Open Knowledge Format (OKF) v0.2** as its knowledge-bundle convention.[^googlecloud-okf-v02]

OKF v0.2 describes a directory tree of Markdown files with YAML frontmatter. Every non-reserved concept document must contain parseable frontmatter and a non-empty `type`. It defines optional provenance (`sources`), production (`generated`), verification (`verified`), lifecycle (`status`, `stale_after`) and cross-link conventions.[^googlecloud-okf-v02]

## Local bundle rules

- The root bundle directory is `.knowledge/`.
- The root [index](../index.md) declares `okf_version: "0.2"` and provides progressive disclosure.
- `index.md` and `log.md` are reserved filenames. They do not use concept frontmatter (except the root index's allowed `okf_version` declaration).
- All other Markdown files under the bundle require YAML frontmatter with a non-empty `type`.
- Use stable source IDs and footnotes to attribute claims.
- Do not invent source metadata or verification events.
- Keep indexes and update logs current.
- This repository uses only the OKF features needed for project context; it does not implement attested computations.

## Upstream source

The upstream specification is maintained in the GoogleCloudPlatform/knowledge-catalog repository. Re-check the upstream version before changing this contract or copying a newer specification. Do not treat community tutorials or third-party interpretations as normative.

[^googlecloud-okf-v02]: Open Knowledge Format v0.2, GoogleCloudPlatform/knowledge-catalog, https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md (accessed 2026-11-24).
