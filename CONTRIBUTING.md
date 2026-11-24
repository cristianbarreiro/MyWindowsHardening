# Contributing to MyWindowsHardening

## Before starting

Read [AGENTS.md](AGENTS.md), [AI agent onboarding](docs/AI-AGENTS.md) and [.knowledge/index.md](.knowledge/index.md). Inspect the current script, tests and profile documentation before proposing a change.

## Change lifecycle

1. Create a focused feature branch.
2. Identify the exact Windows target (client/server role, edition, version, build/UBR and PowerShell runtime).
3. Classify the profile as audit-only, design-only, implementation-ready, runtime-validated or deprecated.
4. Research version-sensitive claims using primary sources and capture them in the OKF source registry.
5. Write scope, threats, compatibility and rollback expectations before implementing a mutation.
6. Implement the smallest cohesive change; update scripts, Pester tests, profile documentation and OKF context together.
7. Run the validation steps and open a pull request with evidence and limitations.

## Required evidence for a new security control

A control that changes a system needs:
- supported platform/build/edition matrix and runtime capability checks;
- explicit opt-in and read-only default;
- preflight checks and detection of external management/ownership;
- exact backup, preserving missing/unset values;
- idempotence and collision-safe resource ownership;
- rollback with backup validation and post-restore verification;
- post-apply verification of effective configuration;
- failure-path tests, including partial failures and foreign resources;
- documented residual risk and recovery steps.

Until every gate is met, keep it audit-only or design-only. Never label a control runtime-validated from static checks.

## PowerShell and tests

- Maintain Windows PowerShell 5.1 compatibility.
- CI runs on `windows-2022` with Pester 5.6.1 and PSScriptAnalyzer 1.23.0 pinned.
- Run the full test suite from the repository root:

```powershell
Invoke-Pester -Path './Tests' -CI -Output Detailed
```

- Run PSScriptAnalyzer for changed scripts with `-Severity Error`.
- Validate parsing with the Windows PowerShell 5.1 parser.
- Inspect the workflow result; do not treat a skipped, cancelled or missing job as success.
- Static checks do not replace endpoint validation in an isolated, disposable Windows VM.

Never test hardening by running Apply/Restore on your workstation or an AI agent host.

## Documentation and knowledge

Use the [maintain-okf-knowledge skill](.agents/skills/maintain-okf-knowledge/SKILL.md). Every non-reserved Markdown document under `.knowledge/` must follow the OKF v0.2 concept frontmatter contract. Update the appropriate index and `.knowledge/log.md`. Record real sources and verification events only.

Profile documentation should include objective, non-goals, platform scope, prerequisites, commands, exact changes, backup/rollback, validation evidence, known limitations and sources.

## Pull request checklist

- [ ] Scope and platform compatibility are explicit.
- [ ] No security mutation is executed on the author/agent host.
- [ ] Tests cover success and failure behavior without changing the host.
- [ ] Pester, parser and analyzer checks pass.
- [ ] User-visible documentation and OKF context agree with implementation.
- [ ] Sources are authoritative, current and attributed to supported claims.
- [ ] Reports/backups/secrets and private endpoint information are not committed.
- [ ] Runtime validation limitations are stated honestly.
