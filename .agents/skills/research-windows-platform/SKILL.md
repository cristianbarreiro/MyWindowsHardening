---
name: research-windows-platform
description: Researches current Windows client and Server security behavior, servicing, Defender, SMB/NTLM, PowerShell cmdlets, VirtualBox isolation and CVEs using primary sources. Use before making version-specific security claims, adding controls, or updating compatibility matrices.
---

# Research Windows platform behavior

## Goal

Produce a small, auditable evidence set for the exact product/version/build/edition and deployment context. Research informs design; it does not authorize changes to an endpoint.

## Procedure

1. **Define the claim and scope.** Record the exact OS product, edition, release/build/UBR, PowerShell runtime, role, management plane (local/GPO/MDM), hardware/firmware and dependent services. Mark unknown values as unknown.
2. **Inspect repository evidence.** Read the relevant `.knowledge/` concepts and profile documents. Separate observed project facts from externally sourced facts.
3. **Search primary sources first.**
   - Windows behavior, PowerShell cmdlets and servicing: Microsoft Learn, Windows release health, lifecycle and official PowerShell docs.
   - Security vulnerabilities and patches: MSRC security update guide, CVE records and vendor security advisories.
   - VirtualBox: Oracle VirtualBox manual and release notes.
   - General controls: NIST publications, CISA guidance and recognized standards. Check the exact revision/date.
   - Use reputable secondary research only to identify leads or explain disagreements; do not let it overrule an applicable vendor source without evidence.
4. **Verify version applicability.** Open the documentation, inspect the relevant section, and verify command parameters, supported editions/builds, prerequisites, effective policy precedence and limitations. Do not infer support from a command's existence in a different build.
5. **Cross-check high-impact claims.** For changes to authentication, firewall, Defender, SMB, remote access, identity, encryption or virtualization, seek a second authoritative source or a directly documented test. If unavailable, state the evidence gap.
6. **Record provenance in OKF.** Add or update `.knowledge/sources/` and the relevant concept. Include source URL, title, publisher when known, retrieval date, applicable version, claim supported and uncertainty. Add stable source IDs and claim-level footnotes. Only record `last_modified` when the publisher supplies an actual update timestamp.
7. **Set an honest lifecycle.** Mark a concept `draft` where claims are incomplete; set `stale_after` for volatile material using the project's refresh policy. Do not claim a runtime test or human review that did not happen.
8. **Summarize the evidence.** For each proposed control, provide: source-supported behavior, compatible scope, impact, preconditions, known side effects, alternatives, evidence confidence and remaining unknowns.

## Source quality

| Class | Typical examples | Treatment |
|---|---|---|
| A — primary / normative | Vendor docs, official advisories, RFCs, NIST/CISA standards and publications | Preferred basis for implementation and support claims |
| B — authoritative implementation evidence | Official source code, tests, changelogs, official engineering posts | Useful to validate details; check the relevant release/version |
| C — independent research | Peer-reviewed papers, reputable security research, well-maintained technical analysis | Corroboration and threat discovery; check date and reproducibility |
| D — community | Forums, Q&A, issue comments and social posts | Leads and operational anecdotes only; never sole basis for high-impact changes |

Search-result snippets are discovery aids, not evidence. Cite the page actually inspected.

## Output template

- **Question / decision:**
- **Target scope:**
- **Sources checked:** title, publisher, URL, retrieval date, applicable release.
- **Findings:** claim → evidence/source ID.
- **Conflicts or gaps:**
- **Operational impact and residual risk:**
- **Recommended disposition:** keep read-only / design-only / test in VM / eligible for implementation review.
- **OKF files updated:**

## Stop conditions

Stop short of recommending Apply when version applicability, effective policy ownership, required backup semantics, dependencies or rollback behavior are unknown. Report what evidence is needed next instead of filling gaps with assumptions.
