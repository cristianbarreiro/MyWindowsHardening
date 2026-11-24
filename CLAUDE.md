# Instructions for Claude Code

Read [AGENTS.md](AGENTS.md) first. It is the canonical, tool-agnostic instruction set for this repository.

Then read [.knowledge/index.md](.knowledge/index.md), the target profile documentation and the relevant portable Agent Skill under `.agents/skills/<skill-name>/SKILL.md`.

Do not maintain a separate policy here. If this file and `AGENTS.md` appear to differ, `AGENTS.md` is the source of truth. Preserve all safety constraints, especially read-only defaults and the prohibition on running live Apply/Restore operations on the agent host.
