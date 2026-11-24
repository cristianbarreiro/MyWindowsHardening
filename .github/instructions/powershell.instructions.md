---
applyTo: "**/*.ps1"
---

# PowerShell script instructions

- Target Windows PowerShell 5.1 unless the owning profile explicitly documents another runtime.
- Before editing, identify platform/build checks, script mode, read/write behavior, backup flow and current tests.
- Keep audit/report code read-only. Do not add hidden mutations to Audit, Validate or Report.
- Detect cmdlet/parameter availability at runtime; do not assume cross-build support.
- Use explicit error handling and verify every security mutation. A warning is not a successful transaction.
- A reversible change must preserve exact prior state, including absent values and rule ownership. Do not remove foreign firewall rules.
- Never run Apply or Restore on the coding agent's machine. Mock commands in tests.
- Add/update Pester coverage and keep static guards for the high-risk behaviors.
- Run syntax parsing, PSScriptAnalyzer Error severity and Pester. Report any runtime VM testing separately.
