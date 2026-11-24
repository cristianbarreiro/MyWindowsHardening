---
name: maintain-okf-knowledge
description: Creates, researches, refreshes and validates the project's Open Knowledge Format v0.2 knowledge bundle. Use when changing source-dependent facts, Windows support matrices, CVE/security guidance, project architecture, design decisions or agent context.
---

# Maintain the OKF project knowledge bundle

## Purpose

Keep the repository context complete, portable and trustworthy so a new human or AI agent can understand the system without reconstructing the same research every time. The bundle is `.knowledge/`; the format is Markdown plus YAML frontmatter, not a proprietary database.

The pinned baseline is Open Knowledge Format (OKF) v0.2. Read the official specification linked in [the OKF source concept](../../../.knowledge/sources/okf-specification.md) before changing conventions.

## Consumer onboarding sequence

1. Open `.knowledge/index.md`.
2. Read `architecture.md`, `security-invariants.md` and `platform-state.md`.
3. Read the relevant concept and source documents for the target area.
4. Follow linked profile documentation and source references only as needed.
5. Treat unverified, draft or stale content as a lead, not as a current fact.

## When to update the bundle

Update knowledge when:
- a supported OS/build/edition, CVE status, vendor behavior, cmdlet capability, dependency or lifecycle date changes;
- a profile changes from design-only to implemented, validated or deprecated;
- an architectural/security invariant or decision changes;
- a test reveals a regression or a new limitation;
- new primary sources change the recommended approach.

Do not create knowledge entries for transient chat details or machine-specific sensitive output.

## Creating a concept

Every non-reserved Markdown concept file must start with parseable YAML frontmatter and a non-empty `type`. Use meaningful fields such as:

```yaml
---
type: Security Control
title: Example control
description: One-sentence summary.
status: draft
generated:
  by: openai/gpt-6
  at: 2026-11-24T19:00:00Z
sources:
  - id: vendor-doc
    resource: https://learn.microsoft.com/...
    title: Official vendor documentation
---
```

Only use metadata when it is true:
- `sources[].resource` must be a resolvable URL or bundle-relative path (or a clearly described scope).
- Assign stable `sources[].id` identifiers and refer to them with Markdown footnotes for claim-level provenance.
- `sources[].author`, `last_modified` and `usage_count` are optional. Never guess them.
- `generated.by` identifies the producer; `generated.at` is the last meaningful content change in ISO 8601 with an explicit UTC offset.
- `verified` records a real verification event. Use `human:<id>` only after actual human review; otherwise use a real process or tool actor that performed the check. Do not add a verification event merely because an agent generated the document.
- `status` may be `draft`, `stable` or `deprecated`. Draft unreviewed concepts and preserve deprecated concepts for history.
- `stale_after` is an absolute UTC instant after which the concept should be treated as stale. Use it for volatile facts with a stated refresh interval; do not use it as a fake upstream update date.

## Research and freshness

1. Use the `research-windows-platform` skill for current facts.
2. Prefer vendor/standards primary sources. Open the source and verify that it supports the claim and the exact release/build.
3. Store external source metadata in `.knowledge/sources/` and link from relevant concepts.
4. Note retrieval date separately from publisher's actual publication/modified date.
5. For fast-changing release/support matrices, choose a short freshness window (for example 30 days); for stable product manuals, use a longer one only if meaningful. When no defensible refresh interval exists, omit `stale_after` and explain the uncertainty.
6. When sources conflict, record the conflict and applicability; do not silently choose the most convenient claim.
7. Do not use search snippets, generated answers or community posts as the sole evidence for high-impact security claims.

## Updating a bundle

- Keep root `.knowledge/index.md` as the progressive-disclosure map; root index may declare `okf_version: "0.2"` and has no other frontmatter requirement.
- `index.md` and `log.md` are reserved filenames and are not concept docs. Follow their reserved structures; do not add concept frontmatter to them.
- Update the nearest index after adding/moving a concept.
- Append a date-grouped, newest-first entry to `.knowledge/log.md` (ISO `YYYY-MM-DD`).
- Use standard Markdown links; absolute bundle-root paths beginning with `/` are preferred.
- Keep concepts small and focused. Split platform matrices, decisions and source references when doing so improves retrieval.
- Retain unknown frontmatter keys when editing a concept; do not discard metadata from other OKF consumers.

## Review checklist

- [ ] Every changed concept has a valid `type` frontmatter field.
- [ ] All cited facts map to stable source IDs and actual inspected URLs.
- [ ] Generated and verification metadata is truthful.
- [ ] Staleness is explicit and not misleading.
- [ ] Index and update log reflect the change.
- [ ] Profile status agrees with code and runtime evidence.
- [ ] No private endpoint inventory, secrets or user identifiers entered the bundle.
- [ ] An agent entering the project can follow the index and load only the relevant context.
