---
type: Reference
title: AI coding agent customization sources
description: Official documentation for portable instructions, Antigravity rules and skills, Cursor, and GitHub Copilot repository customization.
status: draft
generated:
  by: openai/gpt-6
  at: 2026-11-24T19:16:00Z
stale_after: 2027-02-22T00:00:00Z
sources:
  - id: agentsmd-home
    resource: https://agents.md/
    title: AGENTS.md — project instructions for coding agents
  - id: github-copilot-instructions
    resource: https://docs.github.com/en/copilot/concepts/prompting-and-context/custom-instructions
    title: GitHub Copilot custom instructions
  - id: github-copilot-skill
    resource: https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills
    title: GitHub Copilot agent skills
  - id: antigravity-rules
    resource: https://antigravity.google/docs/rules/
    title: Google Antigravity rules
  - id: antigravity-skills
    resource: https://antigravity.google/docs/skills/
    title: Google Antigravity agent skills
  - id: cursor-rules
    resource: https://cursor.com/docs/rules
    title: Cursor Project Rules and AGENTS.md support
  - id: cursor-skills
    resource: https://cursor.com/docs/skills
    title: Cursor Agent Skills
  - id: vscode-skills
    resource: https://code.visualstudio.com/docs/agent-customization/agent-skills
    title: Visual Studio Code agent skills
---

# Portable instruction model

This repository uses `AGENTS.md` as its central, tool-agnostic instruction document. The project also includes lightweight adapters for tools that document their own instruction discovery paths.

The AGENTS.md site describes the file as a predictable Markdown home for agent-specific build, test and convention guidance.[^agentsmd-home]

## GitHub Copilot

GitHub documents repository-wide instructions at `.github/copilot-instructions.md`, path-specific instruction files under `.github/instructions/` and agent instructions such as `AGENTS.md`.[^github-copilot-instructions] GitHub also documents agent skills as folders containing `SKILL.md` and optional supporting resources, with repository-level locations including `.agents/skills/`.[^github-copilot-skill]

## Antigravity

Antigravity documents workspace rules in `AGENTS.md`, `GEMINI.md` and `.agents/rules/`. Rule files support activation modes such as `always_on`, `model_decision` and `glob`; glob rules need a `globs` field.[^antigravity-rules] Its skill convention uses a directory containing `SKILL.md`, with workspace skills under `.agents/skills/`.[^antigravity-skills]

## Cursor

Cursor supports root and nested `AGENTS.md` files as a plain-Markdown instruction option. It also supports Project Rules in `.cursor/rules/` using `.mdc` files with frontmatter properties such as `description`, `globs` and `alwaysApply`.[^cursor-rules] Cursor documents automatic discovery of Agent Skills from `.agents/skills/` as well as its own `.cursor/skills/` location.[^cursor-skills]

The repository keeps the portable skills in `.agents/skills/` and only adds concise Cursor rule adapters. This avoids duplicating skill implementations or maintaining separate, divergent copies.

## VS Code and other compatible agents

Visual Studio Code documents Agent Skills as reusable capabilities loaded on demand and distinguishes them from always-on instructions.[^vscode-skills] Other agent surfaces may use different defaults or feature subsets. Verify current official documentation before relying on automatic discovery.

## Local compatibility decision

- Keep one canonical policy in root `AGENTS.md`.
- Store reusable workflows once in `.agents/skills/`.
- Use Antigravity rules and Cursor Project Rules for scoped or conditional constraints.
- Use Copilot's documented instruction paths as thin adapters.
- Use `CLAUDE.md` and `GEMINI.md` as entry points, not duplicate policy stores.
- Update this source concept when official discovery paths or skill compatibility change.

[^agentsmd-home]: AGENTS.md, https://agents.md/ (accessed 2026-11-24).
[^github-copilot-instructions]: GitHub Docs, Custom instructions for GitHub Copilot, https://docs.github.com/en/copilot/concepts/prompting-and-context/custom-instructions (accessed 2026-11-24).
[^github-copilot-skill]: GitHub Docs, Adding agent skills for GitHub Copilot, https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills (accessed 2026-11-24).
[^antigravity-rules]: Google Antigravity Docs, Rules, https://antigravity.google/docs/rules/ (accessed 2026-11-24).
[^antigravity-skills]: Google Antigravity Docs, Agent Skills, https://antigravity.google/docs/skills/ (accessed 2026-11-24).
[^cursor-rules]: Cursor Docs, Rules and AGENTS.md, https://cursor.com/docs/rules (accessed 2026-11-24).
[^cursor-skills]: Cursor Docs, Agent Skills, https://cursor.com/docs/skills (accessed 2026-11-24).
[^vscode-skills]: Visual Studio Code Docs, Agent Skills, https://code.visualstudio.com/docs/agent-customization/agent-skills (accessed 2026-11-24).
