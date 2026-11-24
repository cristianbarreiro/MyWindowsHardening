---
name: powershell-validation
description: Validates and tests Windows PowerShell 5.1 scripts using parser checks, PSScriptAnalyzer, Pester and GitHub Actions. Use after changing PowerShell code, tests, workflows or when diagnosing CI failures.
---

# PowerShell validation workflow

## Repository toolchain

The CI workflow `.github/workflows/powershell-syntax-validation.yml` runs on `windows-2022` using Windows PowerShell 5.1 and pins:
- Pester 5.6.1
- PSScriptAnalyzer 1.23.0

Do not silently upgrade these versions. Propose and test toolchain changes independently.

## Safe validation order

1. Inspect the diff and identify every changed script, test and workflow.
2. Run syntax parsing with the Windows PowerShell 5.1 parser across `Common`, `Win10`, `Win11`, `WinServer` and `Tests`.
3. Run PSScriptAnalyzer with `-Severity Error` across every repository script.
4. Run the full suite:
   ```powershell
   Invoke-Pester -Path './Tests' -CI -Output Detailed
   ```
5. Review warnings, skipped tests, changed paths and generated artefacts. Never report a skipped or unrun check as a pass.
6. Check formatting/whitespace with `git diff --check`.
7. For any behavior requiring Windows, create a separate authorized disposable VM plan; static tests cannot prove that a control works on the endpoint.

## Useful command fragments

Windows PowerShell 5.1 syntax parse:

```powershell
$files = Get-ChildItem -Path 'Common','Win10','Win11','WinServer','Tests' -Filter '*.ps1' -Recurse -File
foreach ($file in $files) {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName, [ref]$tokens, [ref]$errors
    )
    if ($errors.Count -gt 0) {
        throw ("Syntax error in {0}: {1}" -f $file.FullName, ($errors -join '; '))
    }
}
```

Analyzer:

```powershell
$files = Get-ChildItem -Path 'Common','Win10','Win11','WinServer','Tests' -Filter '*.ps1' -Recurse -File
$diagnostics = @($files | ForEach-Object {
    Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error -ErrorAction Stop
})
if ($diagnostics.Count -gt 0) { $diagnostics | Format-List; throw 'PSScriptAnalyzer errors found.' }
```

## Test design

- Prefer AST inspection and mocked cmdlets over invoking real security changes.
- Assert that read-only auditors contain no configuration-changing commands.
- Assert general baseline Apply/Restore remains blocked until an approved design gate is met.
- Exercise absent file paths and required inputs explicitly; required repository assets should fail clearly rather than silently skip.
- For transaction code, test backup integrity, exact restoration, foreign firewall-rule preservation, idempotence, unsupported options and incomplete rollback.
- Avoid brittle source-text tests for implementation details when behavior can be tested with mocks; retain static checks for critical guardrails that are otherwise hard to exercise safely.

## CI failure triage

1. Identify failed job and exact step; fetch logs instead of guessing.
2. Reproduce in the same Windows PowerShell 5.1 runtime and pinned module versions.
3. Distinguish parse failures, analyzer diagnostics, test failures and environment/network problems.
4. Make the smallest fix, add a regression test and rerun all relevant checks.
5. If CI cannot be run locally, state that GitHub Actions is the source of truth and report its final run conclusion.

## Non-negotiable restriction

Never validate a hardening feature by running Apply/Restore against the developer or agent host. Do not disable Defender, firewall, security policy, a service or a network interface merely to make a test pass.
