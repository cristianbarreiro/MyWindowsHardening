---
type: Reference
title: Windows and virtualization platform source registry
description: Vendor-maintained sources for Windows servicing, Defender, SMB/NTLM, PowerShell and VirtualBox behavior.
status: draft
generated:
  by: openai/gpt-6
  at: 2026-11-24T19:16:00Z
stale_after: 2026-12-24T00:00:00Z
sources:
  - id: win10-release-health
    resource: https://learn.microsoft.com/en-us/windows/release-health/release-information
    title: Microsoft Learn — Windows 10 release information
  - id: win11-release-health
    resource: https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information
    title: Microsoft Learn — Windows 11 release information
  - id: win10-lifecycle
    resource: https://learn.microsoft.com/en-us/lifecycle/products/windows-10-home-and-pro
    title: Microsoft Lifecycle — Windows 10 Home and Pro
  - id: powershell-51
    resource: https://learn.microsoft.com/en-us/powershell/scripting/windows-powershell/windows-powershell-5.1
    title: Microsoft Learn — Windows PowerShell 5.1
  - id: psscriptanalyzer
    resource: https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/overview
    title: Microsoft Learn — PSScriptAnalyzer
  - id: smb-signing
    resource: https://learn.microsoft.com/en-us/windows-server/storage/file-server/smb-signing
    title: Microsoft Learn — SMB signing
  - id: smb-ntlm-blocking
    resource: https://learn.microsoft.com/en-us/windows-server/storage/file-server/smb-ntlm-blocking
    title: Microsoft Learn — Block NTLM connections on SMB
  - id: defender-cfa
    resource: https://learn.microsoft.com/en-us/defender-endpoint/controlled-folder-access
    title: Microsoft Learn — Controlled Folder Access
  - id: virtualbox-networking
    resource: https://www.virtualbox.org/manual/ch06.html
    title: Oracle VirtualBox User Manual — Networking
  - id: virtualbox-vboxmanage
    resource: https://www.virtualbox.org/manual/ch08.html#vboxmanage-modifyvm
    title: Oracle VirtualBox User Manual — VBoxManage modifyvm
---

# How to use these sources

The entries in the frontmatter are primary vendor documentation landing pages. They are not proof that a particular control is supported by every Windows edition, build or VirtualBox release.

For each implementation decision:
1. Open the relevant vendor page and identify the current section and supported versions.
2. Inspect any linked release notes, parameter reference or advisory for the exact behavior.
3. Capture the retrieval date and applicability in the relevant concept.
4. Confirm effective policy precedence (local, domain, MDM and security product) on the test device.
5. Use an isolated VM to verify behavior where the vendor documentation does not settle the operational question.

## Important boundaries

- Windows release-health pages change over time. Do not copy lifecycle/build facts into code comments or generic agent prompts without an explicit freshness date.
- A cmdlet's presence does not prove a parameter is supported on all target builds.
- SMB signing and NTLM-over-SMB controls must be checked against the exact server/client role and product versions involved.
- Defender Audit/Warn modes are not equivalent to Block/Enforce.
- VirtualBox NAT preserves outbound connectivity; it is not an air gap and must not be described as complete LAN isolation.

See [platform state](../platform-state.md) and the relevant profile documentation for this repository's current applicability.
