---
trigger: glob
description: PowerShell 5.1 compatibility, safe mutation, validation and testing requirements for repository scripts.
globs: "**/*.ps1"
---

# PowerShell rules

- Keep Windows PowerShell 5.1 compatibility.
- Read the owning profile's documentation before changing code.
- Audit/Validate/Report modes must remain read-only.
- Do not execute Apply or Restore on the agent host.
- Guard optional cmdlets and parameters; fail before mutation if required preconditions cannot be proven.
- Never use broad firewall/service/Registry changes. Preserve foreign state and exact backups.
- Add safe Pester tests and run parser, PSScriptAnalyzer and Pester checks.
- See `AGENTS.md` and `.agents/skills/powershell-validation/SKILL.md`.
