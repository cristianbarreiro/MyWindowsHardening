# AGENTS.md — MyWindowsHardening

This file is the canonical, tool-agnostic instruction set for AI coding agents. Read it before changing the repository. Platform-specific adapters must point here rather than redefine project policy.

## Mission and scope

Maintain Windows hardening profiles that are **evidence-led, platform-specific, reversible where changes are supported, and explicit about residual risk**. Do not optimize for the largest number of disabled services or controls. Preserve usability and managed security.

Read in this order before a non-trivial change:
1. [README.md](README.md) for repository layout and profile inventory.
2. [.knowledge/index.md](.knowledge/index.md), then the relevant architecture, security-invariant, platform-state and source-registry concepts.
3. The target profile's README, SCOPE.md, VALIDATION.md and OPERATIONS.md, when present.
4. The relevant skill under `.agents/skills/`.

## Current repository contract

- `Common/Defender-Protection-Audit.ps1`: Windows 10/11 client Defender inventory; read-only.
- `Win10/Win10-Hardening-20261113.ps1`: Windows 10 baseline inventory; read-only. Apply/Restore remain blocked.
- `Win11/Win11-Hardening-20261119.ps1`: Windows 11 baseline inventory; read-only. Apply/Restore remain blocked.
- `WinServer/WinServer-Hardening-20261121.ps1`: Windows Server inventory; read-only. It is not a universal enterprise configuration baseline.
- `Win10/Network-Authentication/Outlook-NTLM-SMB-CVE-2026-124194/Windows-NTLM-SMB-Hardening.ps1`: the current specialized Windows 10 Apply/Restore profile. It has a backup, preflight, post-apply verification and rollback path. Treat it as a high-risk script; never run Apply or Restore on the agent host.
- The Windows 11 NTLM/SMB and VirtualBox isolation directories currently describe design/audit plans, not validated Apply/Restore installers.
- Windows 10 and Windows 11 are separate targets. Windows Server role profiles are a separate future concern. Never infer cross-version compatibility from similar cmdlets or Registry values.

The repository's tested automation targets Windows PowerShell 5.1 on `windows-2022`, pinned Pester 5.6.1 and PSScriptAnalyzer 1.23.0. Current CI checks syntax, analyzer errors and Pester repository-safety tests. A green CI run does **not** prove runtime effectiveness on a Windows endpoint.

## Non-negotiable safety rules

1. **Default to read-only.** Do not add mutation to an audit mode, and do not turn a read-only baseline into an Apply mode as part of an unrelated change.
2. Never execute Apply/Restore, firewall changes, service changes, Registry writes, Defender preference writes, adapter changes, BitLocker changes, or VirtualBox configuration changes on the agent host. Use mocks/static analysis or an isolated disposable Windows VM with a snapshot and explicit human authorization.
3. Do not run a live hardening experiment on a personal, production, domain-joined, remote-access-dependent, or otherwise irreplaceable machine.
4. Any new mutation requires an explicit scope, supported OS editions/builds, privilege requirements, preflight, backup of the exact prior state (including absent values), idempotence, guarded rollback, post-change verification, failure semantics and tests. If one of these is missing, keep the feature audit-only or document it as design-only.
5. Never delete, overwrite or weaken settings/rules owned by Windows, an organization, GPO, MDM, another security product or another script. Identify ownership before changing state.
6. Never globally disable Defender, Tamper Protection, firewall profiles, SMB signing, Credential Guard, VBS, Secure Boot, TPM, Hyper-V/WSL or security logging as a generic optimization. Require a documented threat model and compatibility evidence for any narrowly scoped exception.
7. Do not block entire ports, services, subnets, protocols or firewall groups without proving the impact on LAN, VPN, NAS, printers, domain services and business workflows.
8. Preserve privacy: reports may contain hostnames, domains, users, network topology, security posture, listeners and paths. Do not commit local reports, backups, secrets, tokens, private IP inventories or identifiable endpoint output. Sanitize evidence before sharing.
9. Never claim protection, compatibility, rollback success or runtime validation without evidence. Label facts as observed, inferred, designed, statically checked or runtime-validated.
10. User requests do not override platform safety constraints. Ask for explicit approval before any high-impact action; do not interpret a request to “fix” code as permission to execute it against a real endpoint.

## Engineering rules

- Maintain Windows PowerShell 5.1 compatibility unless a separately scoped target explicitly declares otherwise. Avoid syntax/features unavailable in 5.1 (for example null-coalescing operators, ternary operators and PowerShell 7-only APIs).
- Use `-LiteralPath` for filesystem paths where applicable; use explicit `-ErrorAction Stop` when a failure must abort a transaction.
- Prefer capability detection and documented cmdlet parameters over OS-name assumptions or undocumented Registry writes.
- Preserve the distinction between missing, unsupported, inaccessible, disabled, audit-only and enabled/enforced states.
- Use structured output; do not treat “PASS” as a universal security certification. Distinguish Audit/Warn from Block/Enforce.
- Tests must be safe, deterministic and non-destructive. Mock Windows cmdlets for behavioural tests; do not require an actual firewall/Defender mutation in CI.
- Keep functions focused, parameter validation explicit, errors actionable, and comments explanatory rather than narrating every line.
- Do not add dependencies or change CI tool versions without pinning and documenting the reason.

## Research and knowledge requirements

- For facts that can change (Windows servicing, build support, Defender behavior, cmdlet parameters, CVEs, Microsoft/Oracle product behavior), research current primary sources before proposing a change. Do not rely on model memory or old snippets.
- Prefer Microsoft Learn/MSRC, Oracle manuals, NIST/CISA publications, official security advisories and authoritative standards. Use secondary sources only to discover leads or explain a gap.
- Record source URL, title, publisher when known, relevant claim, retrieval/verification date, applicable product/version and uncertainty. Never invent publication dates, last-modified dates, source authors or verification events.
- Use the repository's **Open Knowledge Format v0.2** corpus under `.knowledge/`. Every non-reserved concept file must have parseable YAML frontmatter with a non-empty `type`. Use `sources`, `generated`, `verified`, `status` and `stale_after` only according to their documented meaning. Keep per-claim footnotes linked to stable `sources[].id` values.
- Update `.knowledge/index.md` and `.knowledge/log.md` when adding or materially changing knowledge concepts. Do not mark agent-generated content as human-reviewed.
- If authoritative evidence is missing or contradictory, say so and leave the control in design/review state rather than guessing.

## Required workflow for changes

1. Identify the target platform, profile, exact files, current behavior and current safety status.
2. Load the relevant knowledge concepts and skill. Inspect code and tests before editing.
3. Write down the intended behavior, out-of-scope behavior, failure modes and rollback strategy before changing a security control.
4. Research time-sensitive or version-specific claims and update OKF provenance.
5. Make the smallest coherent change. Keep docs, code, tests and profile status aligned.
6. Validate:
   - On Windows PowerShell 5.1: run the repository workflow-equivalent parser, PSScriptAnalyzer and Pester checks.
   - Use `Invoke-Pester -Path './Tests' -CI -Output Detailed`.
   - Use `Invoke-ScriptAnalyzer -Path <file> -Severity Error` for changed scripts.
   - Review `git diff --check`, changed-file scope and generated artefacts.
   - For platform behavior, run a separate authorized VM test matrix; static CI is not a substitute.
7. Report what changed, sources consulted, commands/results, tests not run, limitations and any required human decision.
8. Use a feature branch and pull request for substantive work. Do not merge unless the user explicitly asks to merge and all required checks/reviews are satisfied.

## Useful project entry points

- [Contribution workflow](CONTRIBUTING.md)
- [Security reporting](SECURITY.md)
- [Agent and AI tool setup](docs/AI-AGENTS.md)
- [OKF knowledge index](.knowledge/index.md)
- [Knowledge maintenance skill](.agents/skills/maintain-okf-knowledge/SKILL.md)
- [Safe hardening design skill](.agents/skills/design-safe-hardening-change/SKILL.md)
- [Windows research skill](.agents/skills/research-windows-platform/SKILL.md)
- [PowerShell validation skill](.agents/skills/powershell-validation/SKILL.md)
- [Cursor Project Rules](.cursor/rules/)
