$repositoryRoot = Split-Path -Path $PSScriptRoot -Parent
$scriptRoots = @('Common', 'Win10', 'Win11', 'WinServer')
$scriptFiles = @(
    foreach ($root in $scriptRoots) {
        $fullRoot = Join-Path $repositoryRoot $root
        if (Test-Path -LiteralPath $fullRoot -PathType Container) {
            Get-ChildItem -LiteralPath $fullRoot -Filter '*.ps1' -File -Recurse
        }
    }
)

Describe 'PowerShell repository safety' {
    It 'all tracked platform scripts parse without syntax errors' {
        $parseFailures = New-Object System.Collections.Generic.List[string]

        foreach ($file in $scriptFiles) {
            $tokens = $null
            $parseErrors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile(
                $file.FullName,
                [ref]$tokens,
                [ref]$parseErrors
            )

            foreach ($parseError in $parseErrors) {
                $parseFailures.Add(('{0}:{1}: {2}' -f $file.FullName, $parseError.Extent.StartLineNumber, $parseError.Message))
            }
        }

        $parseFailures | Should -BeNullOrEmpty
    }

    It 'the shared Defender audit contains no system-configuration commands' {
        $defenderPath = Join-Path $repositoryRoot 'Common/Defender-Protection-Audit.ps1'
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $defenderPath,
            [ref]$tokens,
            [ref]$parseErrors
        )

        $parseErrors | Should -BeNullOrEmpty

        $forbiddenCommands = @(
            'Set-MpPreference', 'Add-MpPreference', 'Remove-MpPreference',
            'Set-NetFirewallProfile', 'Set-NetFirewallRule', 'New-NetFirewallRule', 'Remove-NetFirewallRule',
            'Set-Service', 'Start-Service', 'Stop-Service',
            'Set-ItemProperty', 'New-ItemProperty', 'Remove-ItemProperty',
            'Set-NetAdapter', 'Enable-NetAdapter', 'Disable-NetAdapter'
        )

        $commands = @($ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst]
        }, $true) | ForEach-Object { $_.GetCommandName() })

        $commands | Where-Object { $_ -in $forbiddenCommands } | Should -BeNullOrEmpty
    }

    It 'NTLM Apply has a verified rollback path and Restore protects foreign firewall rules' {
        $ntlmPath = Join-Path $repositoryRoot 'Win10/Network-Authentication/Outlook-NTLM-SMB-CVE-2026-124194/Windows-NTLM-SMB-Hardening.ps1'
        $content = Get-Content -LiteralPath $ntlmPath -Raw

        $content | Should -Match 'Restore-Baseline -Path \$backupDirectory'
        $content | Should -Match 'Rollback ejecutado y verificado'
        $content | Should -Match 'Test-ManagedFirewallRule'
        $content | Should -Match 'Restore incompleto o no verificado'
        $content | Should -Match 'Hay varios backups'
    }

    It 'general platform baselines keep Apply and Restore blocked' {
        $baselinePaths = @(
            'Win10/Win10-Hardening-20261113.ps1',
            'Win11/Win11-Hardening-20261119.ps1',
            'WinServer/WinServer-Hardening-20261121.ps1'
        )

        foreach ($relativePath in $baselinePaths) {
            $path = Join-Path $repositoryRoot $relativePath
            $content = Get-Content -LiteralPath $path -Raw
            $content | Should -Match 'if\s*\(\$Mode\s+-eq\s+\x27Apply\x27\s+-or\s+\$Mode\s+-eq\s+\x27Restore\x27\)'
        }
    }
}
