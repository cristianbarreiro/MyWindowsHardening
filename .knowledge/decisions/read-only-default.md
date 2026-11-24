---
type: Architecture Decision
title: Read-only by default for general Windows baselines
description: Keep broad platform baselines read-only and require a separate, evidence-backed design gate for each mutation.
status: draft
generated:
  by: openai/gpt-6
  at: 2026-11-24T19:16:00Z
sources:
  - id: read-only-baseline
    resource: https://github.com/cristianbarreiro/MyWindowsHardening/blob/main/Win10/BASELINE.md
    title: Windows 10 baseline safety guarantees
  - id: win11-baseline
    resource: https://github.com/cristianbarreiro/MyWindowsHardening/blob/main/Win11/README.md
    title: Windows 11 baseline safety guarantees
  - id: server-audit
    resource: https://github.com/cristianbarreiro/MyWindowsHardening/blob/main/WinServer/README.md
    title: Windows Server auditor limits
  - id: repository-contract
    resource: https://github.com/cristianbarreiro/MyWindowsHardening/blob/main/AGENTS.md
    title: Canonical repository safety policy
---

# Context

The repository covers multiple Windows families, editions, builds, roles and network environments. A generic configuration script could weaken security, interrupt access or override managed policy when run outside its original test environment.

# Decision

Keep the general Windows 10, Windows 11 and Windows Server baselines strictly read-only. Do not add a generic Apply/Restore mode to these entry points.

A specialized profile may implement mutation only after it has its own platform scope, threat model, preflight, exact backup, ownership checks, idempotence, rollback, post-change verification and safe tests.

# Consequences

- Audit tools remain safe to run without administrative mutation privileges.
- The project can collect evidence before defining controls.
- Platform-specific installers remain isolated rather than chained automatically from general baselines.
- New controls require a higher review and validation bar, with a disposable VM for runtime testing.
- CI can detect some regression patterns but cannot certify runtime behavior on a real endpoint.

# Revisit when

The decision should be revisited only with concrete evidence, a scoped proposal, a tested recovery path and maintainer approval. Convenience, benchmark scores or a request to “apply everything” are not sufficient reasons to weaken this boundary.
