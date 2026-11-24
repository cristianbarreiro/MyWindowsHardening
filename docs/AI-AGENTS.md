# AI agent onboarding and compatibility

This repository maintains **one canonical policy** and **one shared knowledge corpus**. Tool-specific files are thin adapters; do not let agent instructions drift into competing versions.

## Canonical context

Start at the repository root:

1. `AGENTS.md` — mandatory engineering, security and workflow rules.
2. `.knowledge/index.md` — progressive-disclosure map for the project's OKF v0.2 context.
3. The target platform/profile documentation.
4. The relevant skill at `.agents/skills/<skill-name>/SKILL.md`.

The `.knowledge/` folder is a local, version-controlled knowledge bundle. Its source registry identifies official documentation; concepts record what is known about the repository, platform compatibility, security invariants and decisions.

## Supported agent entry points

| Tool / agent family | Files in this repository | Purpose |
|---|---|---|
| General coding agents and OpenAI Codex-style agents | Root `AGENTS.md` | Tool-agnostic canonical rules and onboarding |
| Google Antigravity / Gemini | Root `AGENTS.md`, `GEMINI.md`, `.agents/rules/*.md`, `.agents/skills/*/SKILL.md` | Workspace rules and portable skills |
| GitHub Copilot | `.github/copilot-instructions.md`, `.github/instructions/*.instructions.md`, root `AGENTS.md`, `.agents/skills/*/SKILL.md` | Repository-wide and file-scoped instructions, skills |
| Cursor | Root `AGENTS.md`, `.cursor/rules/*.mdc`, `.agents/skills/*/SKILL.md` | Canonical instructions, scoped Project Rules and portable skills |
| Claude Code | Root `CLAUDE.md`, `.agents/skills/*/SKILL.md` | Entry point delegates to canonical rules |
| Other tools | `AGENTS.md` and the shared `.agents/skills/` directory where supported | Use the canonical instruction file; configure a small adapter only when a tool requires a different discovery path |

Tool support changes over time. Verify each product's official documentation before adding more adapters or claiming that a file is automatically loaded. If a tool does not discover `.agents/skills`, instruct it to open the selected `SKILL.md` explicitly rather than copying divergent versions into multiple directories.

## Rules vs. skills vs. knowledge

- **Rules** are persistent constraints: safe defaults, platform boundaries and invariants. They belong in `AGENTS.md` and scoped tool adapters such as Antigravity rules, Cursor Project Rules and Copilot instructions.
- **Skills** are reusable, task-specific workflows that agents load when relevant: research, hardening design, PowerShell validation and OKF maintenance.
- **OKF concepts** are the factual project memory: architecture, profile state, evidence, sources, decisions, lifecycle and provenance.
- **Prompts** are task templates, not durable policy. Do not store essential safety requirements only in a prompt.

## How to choose a skill

| Task | Skill |
|---|---|
| Updating a Windows build/support claim, Defender behavior, SMB/NTLM, CVE or VirtualBox fact | [research-windows-platform](../.agents/skills/research-windows-platform/SKILL.md) |
| Designing or modifying a security control, Apply/Restore, backup or rollback | [design-safe-hardening-change](../.agents/skills/design-safe-hardening-change/SKILL.md) |
| Editing PowerShell, Pester or CI | [powershell-validation](../.agents/skills/powershell-validation/SKILL.md) |
| Adding/updating source-backed context, decisions or platform matrices | [maintain-okf-knowledge](../.agents/skills/maintain-okf-knowledge/SKILL.md) |

Load only the relevant skill(s); avoid injecting the full knowledge base into every task.

## Context completeness protocol

Before a substantive change:
1. Identify the affected profile and exact platform scope.
2. Read the matching OKF concepts and follow their links to sources.
3. Check whether the relevant source is stale or the claim is version-sensitive.
4. Re-search primary sources when needed; update provenance and the source registry.
5. Update the profile docs, OKF concepts and index/log together.
6. Validate the documentation and tests; clearly identify facts that remain unknown.

An agent should not assume that repository documents are current merely because they are committed. The OKF `status`, `verified` and `stale_after` metadata exist so the consumer can distinguish draft, unverified and stale context.

## External references

- [AGENTS.md convention](https://agents.md/)
- [GitHub Copilot custom instructions](https://docs.github.com/en/copilot/concepts/prompting-and-context/custom-instructions)
- [GitHub Copilot agent skills](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills)
- [Google Antigravity rules](https://antigravity.google/docs/rules/)
- [Google Antigravity skills](https://antigravity.google/docs/skills/)
- [Cursor Project Rules](https://cursor.com/docs/rules)
- [Cursor Agent Skills](https://cursor.com/docs/skills)
- [Open Knowledge Format v0.2](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md)
