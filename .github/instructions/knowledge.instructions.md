---
applyTo: ".knowledge/**/*.md"
---

# Open Knowledge Format maintenance

- Conform to the pinned upstream Open Knowledge Format v0.2 specification referenced by `.knowledge/sources/okf-specification.md`.
- Every concept Markdown file (except reserved `index.md` and `log.md`) must start with YAML frontmatter containing a non-empty `type`.
- Use stable `sources[].id` values and footnotes for claim-level attribution. Record actual source URLs, not search-result snippets.
- Distinguish `generated` from `verified`. Do not claim human review unless a human actually reviewed the content.
- Use `status: draft` for unreviewed proposals; use `stale_after` only as an explicit freshness policy, not as a guessed source update date.
- Do not invent `author`, `last_modified`, `usage_count`, verification timestamps or source publication dates.
- Update the nearest `index.md` and `log.md` when the bundle changes. Keep index files free of frontmatter except the root bundle index's `okf_version`.
- Use plain Markdown and standard links; do not require a proprietary parser or an external service.
