---
type: Research Policy
title: Source research, freshness and evidence policy
description: Rules for acquiring, evaluating, recording and refreshing technical evidence used by hardening profiles.
status: draft
generated:
  by: openai/gpt-6
  at: 2026-11-24T19:16:00Z
stale_after: 2027-02-22T00:00:00Z
sources:
  - id: official-source-registry
    resource: sources/index.md
    title: Curated source registry
  - id: okf-format
    resource: sources/okf-specification.md
    title: Open Knowledge Format v0.2
---

# Evidence hierarchy

1. **Normative and primary sources:** vendor product documentation, official release-health/lifecycle pages, security advisories, standards, RFCs and government guidance.
2. **Authoritative implementation evidence:** official code repositories, release notes, engineering posts and tests for the exact version.
3. **Independent research:** peer-reviewed work and reputable security research. Use for threat discovery and corroboration.
4. **Community discussion:** forums and issue threads. Use as leads and operational context, never as sole evidence for high-impact controls.

## Minimum source record

For each material technical claim, preserve:
- stable source ID;
- canonical URL or bundle-relative path;
- source title and publisher (if known);
- retrieval/verification date;
- exact product, version, edition or build applicability;
- the claim supported and material limitations;
- conflicting evidence or open questions.

Do not invent author names, publication/update dates, popularity counts or verification events. Search result snippets and generated summaries are not sources; inspect the underlying document.

## Freshness policy

- **High volatility** (release servicing, current builds, active advisories, current cmdlet behavior): re-check before each substantive change and set a short freshness window.
- **Medium volatility** (product manuals, supported options and security recommendations): re-check at least quarterly or when the product release changes.
- **Low volatility** (stable protocol concepts and long-lived design rationale): re-check when the relevant standard or vendor implementation changes.

Use `stale_after` as an absolute ISO 8601 UTC instant that marks the concept stale. It is a local refresh deadline, not a claim about when a source last changed.

## Conflicting or unavailable evidence

Record what each source actually says, applicability boundaries and why it conflicts. Do not collapse “not documented”, “not available in this edition”, “not observed” and “disabled” into the same result. If an implementation-critical fact cannot be established, retain a design-only/read-only state.

## Applying research

Research alone does not authorize mutation. Use [the safe hardening design skill](../.agents/skills/design-safe-hardening-change/SKILL.md) to evaluate preflight, ownership, backup, idempotence, rollback, validation and impact. Keep the external source, the design decision and local runtime evidence distinguishable.
