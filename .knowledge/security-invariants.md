---
type: Security Policy
title: MyWindowsHardening security invariants
description: Mandatory safety constraints governing auditing, endpoint mutation, rollback and privacy.
status: draft
generated:
  by: openai/gpt-6
  at: 2026-11-24T19:16:00Z
stale_after: 2027-02-22T00:00:00Z
sources:
  - id: agent-contract
    resource: https://github.com/cristianbarreiro/MyWindowsHardening/blob/main/AGENTS.md
    title: Canonical agent safety contract
  - id: ntlm-profile
    resource: https://github.com/cristianbarreiro/MyWindowsHardening/blob/main/Win10/Network-Authentication/Outlook-NTLM-SMB-CVE-2026-124194/README.md
    title: Windows 10 NTLM/SMB profile operating and rollback documentation
  - id: defender-audit
    resource: https://github.com/cristianbarreiro/MyWindowsHardening/blob/main/Common/README.md
    title: Shared Defender audit scope and limitations
---

# Mandatory invariants

1. **Read-only is the default.** Audit, Validate and Report must not mutate endpoint configuration.
2. **No live host mutation by agents.** AI agents must not execute Apply/Restore or change firewall, service, Registry, Defender, adapters, BitLocker or VirtualBox settings on their own host.
3. **Explicit target scope.** Windows 10, Windows 11 and Windows Server roles/builds must be scoped separately.
4. **Preserve ownership.** Never delete or overwrite objects merely because their names match; prove that the profile owns them.
5. **Exact recovery.** A mutation requires backup of exact previous state (including absence), platform/schema checks, rollback and post-restore verification.
6. **Verify effective state.** Successful command invocation is not proof that the requested configuration took effect.
7. **No broad weakening.** Do not disable core protections or block broad ports/services/subnets to simplify tests or maximize a score.
8. **Report privacy.** Security reports may identify host, domain, users, adapters, network posture and listeners. Keep them local and sanitize before sharing.
9. **Evidence integrity.** Distinguish observed, inferred, designed, statically checked, mocked and runtime-validated results.

## Current profile-specific safety facts

- The general Windows 10/11 and Server baselines document Apply/Restore as blocked.
- The shared Defender auditor is read-only and intentionally omits the contents of exclusion lists from reports.
- The Windows 10 NTLM/SMB profile has a backup/preflight/verification/rollback design, but this does not authorize an AI agent to run it on the agent host.
- The Windows 11 NTLM/SMB and VirtualBox profiles remain design/audit material, not validated Apply/Restore installers.

See [platform state](platform-state.md) for the current profile classification and [the decision record](decisions/read-only-default.md) for rationale.
