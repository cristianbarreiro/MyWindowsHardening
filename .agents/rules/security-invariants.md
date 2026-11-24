---
trigger: always_on
description: Non-negotiable safety invariants for Windows hardening, PowerShell changes and endpoint operations in this repository.
---

# Security invariants

Follow `AGENTS.md` as canonical policy. These constraints are always active:

- Prefer read-only audit. Do not make general baselines writable as an incidental change.
- Never execute Apply/Restore, service/firewall/Registry/Defender/BitLocker/adapter/VirtualBox mutations on the agent host.
- Treat Windows 10, Windows 11 and each Windows Server role/version as separate targets.
- Never remove external/managed rules or silently replace policy owned by GPO, MDM, Windows or another product.
- A mutation must have explicit scope, supported builds/editions, preflight, exact backup, idempotence, guarded rollback, post-change verification and tests.
- Do not weaken core protections to silence warnings or pass tests.
- Preserve evidence privacy; never commit endpoint reports, backups, secrets or identifying topology data.
- Do not claim runtime validation from static analysis or CI.
