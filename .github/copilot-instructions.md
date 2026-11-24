# GitHub Copilot — repository instructions

Use [`AGENTS.md`](../AGENTS.md) as the canonical project contract. Read it before making changes; do not create a conflicting second policy.

Before a non-trivial task, read `.knowledge/index.md` and the relevant profile documentation. Load the matching Agent Skill from `.agents/skills/` (the shared skill directory is intentionally portable across compatible agents).

Critical constraints:
- Preserve Windows PowerShell 5.1 compatibility and the current CI tool versions.
- All general Windows 10/11 and Server baselines and the shared Defender auditor are read-only. Do not enable Apply/Restore in them.
- The specialized Windows 10 NTLM/SMB profile is high impact. Never execute Apply/Restore on the workspace host; use safe mocks/static tests or an authorized disposable VM.
- Do not assume Windows 10, Windows 11 and Windows Server controls are interchangeable.
- Any security mutation needs explicit scope, build/edition support, preflight, exact backup, idempotence, safe rollback, post-change verification and tests.
- Do not weaken Defender, firewall, SMB, VBS, Credential Guard, Secure Boot, TPM, Hyper-V/WSL or managed policy to make a test pass.
- Research version-sensitive claims in primary sources and record provenance in the OKF v0.2 corpus under `.knowledge/`.
- Keep observed facts, design proposals, static checks and runtime validation distinct.
- Run the Pester suite and the PowerShell 5.1 parser/PSScriptAnalyzer checks for relevant changes. State clearly when runtime VM validation was not performed.

Useful commands (run from repository root on a Windows PowerShell 5.1 runner):
```powershell
Invoke-Pester -Path './Tests' -CI -Output Detailed
Invoke-ScriptAnalyzer -Path <changed-script.ps1> -Severity Error
```

Prefer a focused feature branch and pull request. Do not merge unless the user explicitly requests it and checks are green.
