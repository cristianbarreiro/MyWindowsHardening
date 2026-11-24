---
trigger: model_decision
description: Load when researching Windows security, refreshing sources, editing .knowledge documents, or changing version/build/CVE/vendor-specific claims.
---

# Knowledge and source rules

Use the OKF v0.2 bundle under `.knowledge/` as the project's structured context. Read its root index and relevant concepts before changing a profile.

Research current, version-specific facts from primary sources (Microsoft Learn/MSRC, Oracle manuals, NIST/CISA and official standards). Record each source and which claim it supports. Separate observed repository facts from externally sourced facts and hypotheses.

Update concept provenance, generated/verification metadata, lifecycle state, bundle index and update log. Never invent source metadata or claim a check that was not performed. Follow `.agents/skills/maintain-okf-knowledge/SKILL.md`.
