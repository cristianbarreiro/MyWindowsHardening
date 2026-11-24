---
name: design-safe-hardening-change
description: Designs, reviews or changes Windows security audit, hardening, rollback and validation profiles. Use whenever a task can alter firewall, Defender, SMB, NTLM, services, Registry, identity, encryption, networking, virtualization or endpoint policy.
---

# Design a safe hardening change

## 1. Classify the requested work

Choose and state one lifecycle stage:
- **Audit-only:** observe and report; no machine configuration changes.
- **Design-only:** document a candidate control and its evidence; no installer.
- **Implementation-ready:** code is complete but not yet validated on the target VM.
- **Runtime-validated:** tested on the exact declared Windows edition/build and topology with recorded evidence.
- **Deprecated:** retained for traceability but not recommended for new use.

Do not silently promote a design-only profile to implementation-ready or runtime-validated.

## 2. Establish scope and baseline

Record:
- Windows product, client/server role, edition, version, build/UBR and servicing channel.
- PowerShell version, privileges, relevant optional features/cmdlets and effective GPO/MDM policy.
- Network topology, VPN, domain, NAS, printers, file shares, remote access and dependent applications.
- Exact controls and objects owned by this profile.
- Baseline evidence, data sensitivity and recovery constraints.

Reject unsupported platforms before any mutation. Treat Windows 10, Windows 11, Windows Server roles and different builds as separate targets.

## 3. Threat model and alternatives

For every control document:
- Threat and attack path being reduced.
- Security benefit and assumptions.
- Compatibility and availability impact.
- Residual risk and bypass paths.
- Vendor-supported alternatives (especially patching/updating first).
- Why the change is necessary instead of leaving the system at its managed baseline.

Do not present a mitigation as a vulnerability fix. Avoid broad allow/deny changes where a narrow control is possible.

## 4. Mutation design gate

A mutation is not eligible for implementation until all items are defined:

1. Explicit opt-in and safe default (read-only by default).
2. Exact platform/build/edition allow-list and runtime capability detection.
3. Preflight of privileges, management ownership, dependencies, existing rules and current state.
4. Collision-safe backup of every value/object to be changed; preserve whether a Registry value or property was absent.
5. Transaction boundaries, error propagation and idempotence.
6. Ownership marker for created objects; never delete a foreign object merely because its name matches.
7. Rollback that validates the backup schema/platform, restores prior state and verifies the restored state.
8. Post-apply verification of effective configuration, not merely successful cmdlet exit.
9. Clear partial-failure behavior and an actionable recovery path.
10. Safe Pester tests for success, failure, repeated invocation, missing capabilities, foreign objects, incomplete backups and failed rollback.

If any gate is missing, keep the profile audit-only/design-only.

## 5. Implementation guidance

- Prefer supported PowerShell cmdlets and documented parameters.
- Detect optional capabilities; do not force unsupported Registry keys or parameters.
- Keep Audit, Validate and Report read-only.
- Separate profile-owned changes from baseline discovery.
- Preserve unrelated policy and the effective firewall state.
- Make required and optional controls explicit; an explicitly requested but unsupported control must abort before mutation.
- Log state transitions without exposing secrets or unnecessary endpoint details.
- Avoid automatic reboot, service disablement, broad port blocks or policy overrides unless separately justified and approved.

## 6. Validation strategy

Do not test an Apply/Restore path on the agent host. Use:
- Static AST tests and PSScriptAnalyzer.
- Mocked Pester tests for transaction logic and failure paths.
- Disposable VMs with snapshots for real endpoint behavior.
- A matrix containing supported and rejected builds/editions, standard/elevated sessions, domain/GPO/MDM state, VPN and representative dependent services.
- Before/after evidence and explicit rollback verification.

Record test host characteristics and exact commands. One successful test machine is not universal support.

## 7. Documentation contract

Update the profile README, scope, operations and validation documents. State:
- Objective, non-goals, supported matrix and status.
- Commands, privileges and prerequisites.
- Exact controls changed and unchanged.
- Preflight, backup location/schema, rollback and verification.
- Side effects, compatibility tests, known gaps and sources.
- Whether evidence is static, simulated or runtime.

Update the related OKF concepts and source provenance using the `maintain-okf-knowledge` skill. Do not mark untested controls as validated.
