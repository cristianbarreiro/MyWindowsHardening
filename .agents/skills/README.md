# Portable agent skills

These project-scoped skills use the open Agent Skills folder convention. They live in `.agents/skills/<skill-name>/SKILL.md` so compatible agents can discover a single maintained copy.

| Skill | Use it for |
|---|---|
| [research-windows-platform](research-windows-platform/SKILL.md) | Researching current Windows, Defender, SMB, NTLM, VirtualBox, servicing and vulnerability facts. |
| [design-safe-hardening-change](design-safe-hardening-change/SKILL.md) | Designing or changing an audit/apply/restore security profile. |
| [powershell-validation](powershell-validation/SKILL.md) | Static analysis, PowerShell 5.1 compatibility, safe Pester tests and CI triage. |
| [maintain-okf-knowledge](maintain-okf-knowledge/SKILL.md) | Building, refreshing and validating the project's OKF context bundle. |

Skills define workflows; `AGENTS.md` and Antigravity rules define persistent invariants. Load only the skill relevant to the task and follow the canonical repository contract.
