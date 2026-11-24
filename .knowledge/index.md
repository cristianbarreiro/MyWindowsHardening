---
okf_version: "0.2"
---

# MyWindowsHardening — knowledge bundle

This bundle is the maintained project context for humans and AI agents. It uses Open Knowledge Format v0.2: Markdown concepts with YAML frontmatter, explicit sources, lifecycle and verification metadata. See [the pinned format specification](sources/okf-specification.md).

## Start here

- [Project architecture](architecture.md) — repository boundaries, directories and CI contract.
- [Security invariants](security-invariants.md) — safety rules that must survive every change.
- [Platform and profile state](platform-state.md) — what is read-only, design-only or currently implemented.
- [Research policy](research-policy.md) — evidence hierarchy, freshness and source handling.
- [Decision: read-only by default](decisions/read-only-default.md) — why general baselines must not mutate endpoints by default.

## Sources

- [Official and normative source registry](sources/index.md) — vendor documentation and standards.
- [OKF v0.2 specification](sources/okf-specification.md) — schema, provenance, lifecycle and index rules.
- [AI agent customization references](sources/ai-agent-ecosystem.md) — current Antigravity and Copilot entry points.
- [Windows and virtualization references](sources/windows-platform.md) — Microsoft and Oracle source links.

## Maintenance

Read the [OKF maintenance skill](../.agents/skills/maintain-okf-knowledge/SKILL.md) before editing this bundle. The [update log](log.md) records changes newest first. Concepts marked `draft` are intentionally unreviewed; concepts without a `verified` field have not been formally verified. A consumer should refresh any concept whose `stale_after` instant has passed.
