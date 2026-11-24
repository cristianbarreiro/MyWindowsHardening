# Security policy

## Scope

This repository contains defensive Windows security auditing and hardening material. It is not a guarantee that a device is secure and does not replace Windows/Office updates, organizational policy, endpoint detection, incident response or a formal security assessment.

## Reporting a vulnerability or unsafe behavior

Do not include passwords, access tokens, private keys, personal data, unredacted endpoint reports, internal network diagrams or exploitable details in a public issue.

For a suspected vulnerability in a script or profile, provide a minimal sanitized reproduction, affected file/commit, Windows edition/build, PowerShell version, observed result, expected result and whether the behavior is reproducible in a disposable VM. Use GitHub's private vulnerability reporting feature when available for sensitive findings.

## Maintainer response principles

- Reproduce safely and do not test on production or personal endpoints.
- Assess the effect on availability, authentication, networking, recovery and managed policy.
- Prefer read-only diagnostics and vendor-supported mitigations.
- Preserve backups and rollback evidence for any approved mutation.
- Do not publish sensitive host output or secrets.
- Document affected versions, severity rationale, mitigation, residual risk and validation evidence.

## Safety notice

Do not execute scripts with administrative privileges without inspecting their source and understanding their scope. Use an isolated test VM and snapshot for any change that affects endpoint configuration. The repository does not guarantee compatibility with every Windows edition, build, domain policy, security product, network topology or enterprise role.
