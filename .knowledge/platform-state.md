---
type: Platform Matrix
title: Windows platform and profile state
description: Current repository support scope and lifecycle classification, separated by Windows family and profile.
status: draft
generated:
  by: openai/gpt-6
  at: 2026-11-24T19:16:00Z
stale_after: 2026-12-24T00:00:00Z
sources:
  - id: root-readme
    resource: https://github.com/cristianbarreiro/MyWindowsHardening/blob/main/README.md
    title: Repository profile inventory
  - id: win10-overview
    resource: https://github.com/cristianbarreiro/MyWindowsHardening/blob/main/Win10/README.md
    title: Windows 10 scope and profiles
  - id: win11-overview
    resource: https://github.com/cristianbarreiro/MyWindowsHardening/blob/main/Win11/README.md
    title: Windows 11 scope and profiles
  - id: server-overview
    resource: https://github.com/cristianbarreiro/MyWindowsHardening/blob/main/WinServer/README.md
    title: Windows Server auditor scope
  - id: windows-release-health
    resource: /sources/windows-platform.md
    title: Official Windows release and lifecycle references
---

# Current repository state

This matrix records repository implementation status, not a claim that every profile is suitable for deployment.

| Platform / area | Repository status | Important boundary |
|---|---|---|
| Common Defender audit | Audit-only | Windows 10/11 client; no Defender, firewall, service or Registry changes |
| Windows 10 general baseline | Audit-only | Windows 10 client; Apply/Restore blocked |
| Windows 10 NTLM/SMB | Implemented specialized profile; validate per target | Windows 10 22H2 build 19045 scope; preflight, backups, post-apply checks and rollback are documented |
| Windows 10 VirtualBox/Kali isolation | Documented configuration validated on one host | Not a generic installer; evidence is tied to one recorded host/topology |
| Windows 11 general baseline | Audit-only | Windows 11 client; Apply/Restore blocked |
| Windows 11 NTLM/SMB | Design-only | No validated Apply/Restore installer |
| Windows 11 VirtualBox/Kali isolation | Design-only | Practical validation on Windows 11 is pending |
| Windows Server general audit | Audit-only | Initial inventory for selected Server versions; not a role-specific hardening baseline |

## Version and lifecycle discipline

- Technical compatibility does not imply that a Windows release is still serviced.
- Re-check the applicable Windows release-health/lifecycle source before stating that a version is supported or current.
- Re-check Microsoft/Oracle documentation before changing assumptions about cmdlets, Defender properties, SMB behavior or VirtualBox networking.
- Never preserve time-sensitive lifecycle dates in an agent prompt as if they were permanent facts; maintain them here with sources and a freshness deadline.

## Evidence labels

Use these labels consistently:
- **Observed** — directly inspected on a named test environment, with sanitized evidence.
- **Designed** — specified in documentation but not implemented.
- **Implemented** — code exists; no claim of runtime effectiveness is implied.
- **Static-tested** — parser, analyzer or static test passed.
- **Mock-tested** — behavior exercised using deterministic test doubles.
- **Runtime-validated** — tested on the exact documented OS/build/edition/topology, including rollback where applicable.
- **Unknown** — evidence is missing or inconclusive.

## Refresh trigger

This concept becomes stale after 2026-12-24T00:00:00Z. Revisit the platform docs, vendor release-health pages and actual repository state before relying on it beyond that point.
