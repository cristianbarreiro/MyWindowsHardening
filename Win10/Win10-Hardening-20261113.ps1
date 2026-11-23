#requires -Version 5.1
<#
.SYNOPSIS
    MyWindowsHardening - Windows 10 baseline auditor (read-only bootstrap).
.DESCRIPTION
    Collects a bounded set of Windows security and configuration facts.
    This initial release DOES NOT change system configuration.
    Apply/Restore modes are intentionally unavailable until each control has
    a reviewed backup, compatibility contract, and rollback procedure.
.NOTES
    Project: MyWindowsHardening
    File: Win10-Hardening-20261113.ps1
    Initial release: 2026-11-13
    Compatibility: Windows 10 client, Windows PowerShell 5.1
#>
[CmdletBinding()]
param(
    [ValidateSet('Audit', 'Validate', 'Report', 'Apply', 'Restore')]
    [string]$Mode = 'Audit',
    [string]$OutputDirectory = ''
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$script:Results = New-Object System.Collections.Generic.List[object]
$script:StartedAt = Get-Date
$script:ScriptVersion = '0.1.1-bootstrap'

function Add-Result {
    param(
        [string]$Category,
        [string]$Name,
        [string]$Status,
        [AllowNull()][object]$Value,
        [string]$Details = ''
    )
    $script:Results.Add([pscustomobject]@{
        Category = $Category
        Name = $Name
        Status = $Status
        Value = if ($null -eq $Value) { $null } else { [string]$Value }
        Details = $Details
    }) | Out-Null
}
function Test-IsAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}
function Test-CommandAvailable {
    param([string]$Name)
    return $null -ne (Get-Command -Name $Name -ErrorAction SilentlyContinue)
}
function Invoke-ReadOnlyAudit {
    Write-Host ''
    Write-Host 'MyWindowsHardening - Windows 10 baseline audit' -ForegroundColor Cyan
    Write-Host ('Mode: {0} | Version: {1}' -f $Mode, $script:ScriptVersion)
    Write-Host 'READ ONLY - no system settings will be changed.' -ForegroundColor Green
    Write-Host ''

    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $cv = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
        $build = [int]$cv.CurrentBuildNumber
        Add-Result 'System' 'Product' 'INFO' $os.Caption
        Add-Result 'System' 'Version' 'INFO' $cv.DisplayVersion
        Add-Result 'System' 'Build' 'INFO' ('{0}.{1}' -f $build, $cv.UBR)
        if ($os.ProductType -ne 1 -or $build -lt 10240 -or $build -ge 22000) {
            Add-Result 'Compatibility' 'Windows 10 client' 'FAIL' $false 'This script targets Windows 10 client only.'
        } else {
            Add-Result 'Compatibility' 'Windows 10 client' 'PASS' $true
        }
        if ($build -lt 19045) {
            Add-Result 'Compatibility' 'Windows 10 22H2 baseline' 'REVIEW' $build 'Older builds need separate compatibility and support review.'
        } else {
            Add-Result 'Compatibility' 'Windows 10 22H2 baseline' 'INFO' $build 'Verify cumulative updates and ESU separately.'
        }
    } catch {
        Add-Result 'System' 'Operating system inventory' 'ERROR' $null $_.Exception.Message
    }
    Add-Result 'Execution' 'Administrator session' 'INFO' (Test-IsAdministrator) 'Elevation is not required for this read-only audit.'

    if (Test-CommandAvailable 'Get-NetFirewallProfile') {
        try {
            foreach ($p in (Get-NetFirewallProfile -PolicyStore ActiveStore)) {
                $status = if ($p.Enabled) { 'PASS' } else { 'REVIEW' }
                Add-Result 'Firewall' ($p.Name + ' enabled') $status $p.Enabled
                Add-Result 'Firewall' ($p.Name + ' inbound default') 'INFO' $p.DefaultInboundAction
                Add-Result 'Firewall' ($p.Name + ' outbound default') 'INFO' $p.DefaultOutboundAction
                Add-Result 'Firewall' ($p.Name + ' blocked logging') 'INFO' $p.LogBlocked
            }
        } catch { Add-Result 'Firewall' 'Inventory' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'Firewall' 'NetSecurity cmdlets' 'UNAVAILABLE' $null }

    if (Test-CommandAvailable 'Get-MpComputerStatus') {
        try {
            $mp = Get-MpComputerStatus
            $checks = @(
                @{Name='Antivirus enabled';Value=$mp.AntivirusEnabled},
                @{Name='Real-time protection';Value=$mp.RealTimeProtectionEnabled},
                @{Name='Behavior monitoring';Value=$mp.BehaviorMonitorEnabled},
                @{Name='IOAV protection';Value=$mp.IoavProtectionEnabled},
                @{Name='Network inspection';Value=$mp.NISEnabled},
                @{Name='Tamper protection';Value=$mp.IsTamperProtected}
            )
            foreach ($c in $checks) {
                $status = if ($c.Value -eq $true) {'PASS'} elseif ($c.Value -eq $false) {'REVIEW'} else {'INFO'}
                Add-Result 'Defender' $c.Name $status $c.Value
            }
        } catch { Add-Result 'Defender' 'Status' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'Defender' 'Defender cmdlets' 'UNAVAILABLE' $null }

    if (Test-CommandAvailable 'Get-SmbClientConfiguration') {
        try {
            $s = Get-SmbClientConfiguration
            Add-Result 'SMB' 'Client RequireSecuritySignature' 'INFO' $s.RequireSecuritySignature
            Add-Result 'SMB' 'Client EnableSecuritySignature' 'INFO' $s.EnableSecuritySignature
            Add-Result 'SMB' 'Client EnableInsecureGuestLogons' 'INFO' $s.EnableInsecureGuestLogons
        } catch { Add-Result 'SMB' 'Client configuration' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'SMB' 'Client cmdlets' 'UNAVAILABLE' $null }

    if (Test-CommandAvailable 'Get-SmbServerConfiguration') {
        try {
            $s = Get-SmbServerConfiguration
            Add-Result 'SMB' 'Server EnableSMB1Protocol' 'INFO' $s.EnableSMB1Protocol
            Add-Result 'SMB' 'Server EnableSMB2Protocol' 'INFO' $s.EnableSMB2Protocol
            Add-Result 'SMB' 'Server RequireSecuritySignature' 'INFO' $s.RequireSecuritySignature
        } catch { Add-Result 'SMB' 'Server configuration' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'SMB' 'Server cmdlets' 'UNAVAILABLE' $null }

    foreach ($n in @('LanmanServer','LanmanWorkstation','FDResPub','fdPHost','SSDPSRV','upnphost','WlanSvc','DoSvc','Spooler','SharedAccess','vmcompute','WslService')) {
        try {
            $s = Get-CimInstance -ClassName Win32_Service -Filter ("Name='{0}'" -f $n)
            if ($null -ne $s) { Add-Result 'Services' $n 'INFO' ($s.State + ' / ' + $s.StartMode) }
        } catch { Add-Result 'Services' $n 'ERROR' $null $_.Exception.Message }
    }

    if (Test-CommandAvailable 'Get-NetAdapter') {
        try {
            foreach ($a in (Get-NetAdapter -IncludeHidden -ErrorAction Stop)) {
                Add-Result 'Network' ('Adapter: ' + $a.Name) 'INFO' ($a.Status + ' / ' + $a.InterfaceDescription)
            }
        } catch { Add-Result 'Network' 'Adapter inventory' 'ERROR' $null $_.Exception.Message }
    }
    if (Test-CommandAvailable 'Get-NetConnectionProfile') {
        try {
            foreach ($p in (Get-NetConnectionProfile -ErrorAction Stop)) {
                Add-Result 'Network' ('Profile: ' + $p.Name) 'INFO' ($p.NetworkCategory + ' / ' + $p.InterfaceAlias)
            }
        } catch { Add-Result 'Network' 'Profile inventory' 'ERROR' $null $_.Exception.Message }
    }

    if (Test-CommandAvailable 'Get-BitLockerVolume') {
        try {
            foreach ($v in (Get-BitLockerVolume -ErrorAction Stop)) {
                Add-Result 'Storage' ('BitLocker: ' + $v.MountPoint) 'INFO' ($v.VolumeStatus + ' / ' + $v.ProtectionStatus)
            }
        } catch { Add-Result 'Storage' 'BitLocker inventory' 'ERROR' $null $_.Exception.Message }
    } else {
        Add-Result 'Storage' 'BitLocker cmdlets' 'UNAVAILABLE' $null 'Availability depends on Windows edition and device capabilities.'
    }

    if (Test-CommandAvailable 'Get-DOConfig') {
        try {
            $d = Get-DOConfig
            Add-Result 'DeliveryOptimization' 'DownloadMode' 'INFO' $d.DODownloadMode
        } catch { Add-Result 'DeliveryOptimization' 'Configuration query' 'ERROR' $null $_.Exception.Message }
    } else {
        Add-Result 'DeliveryOptimization' 'Get-DOConfig cmdlet' 'UNAVAILABLE' $null
    }

    $script:Results | Format-Table -AutoSize -Wrap
    Write-Host ''
    Write-Host 'Status counts:' -ForegroundColor Cyan
    foreach ($statusName in @('PASS','REVIEW','FAIL','ERROR','INFO','UNAVAILABLE')) {
        $count = @($script:Results | Where-Object { $_.Status -eq $statusName }).Count
        Write-Host ('  {0,-12} {1,4}' -f $statusName, $count)
    }
}
function Save-AuditReport {
    param([string]$Directory)
    if ([string]::IsNullOrWhiteSpace($Directory)) {
        $Directory = Join-Path -Path $PSScriptRoot -ChildPath 'Reports'
    }
    if (Test-Path -LiteralPath $Directory -PathType Leaf) {
        throw ("The report path exists as a file, not a directory: {0}" -f $Directory)
    }
    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
        New-Item -Path $Directory -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $suffix = [guid]::NewGuid().ToString('N').Substring(0, 6)
    $base = 'Win10-Hardening-Audit-{0}-{1}' -f $stamp, $suffix
    $json = Join-Path $Directory ($base + '.json')
    $csv = Join-Path $Directory ($base + '.csv')
    $txt = Join-Path $Directory ($base + '.txt')
    $metadata = [pscustomobject]@{
        Project='MyWindowsHardening'
        ScriptVersion=$script:ScriptVersion
        Mode=$Mode
        StartedAt=$script:StartedAt.ToString('o')
        FinishedAt=(Get-Date).ToString('o')
        ComputerName=$env:COMPUTERNAME
        ReadOnly=$true
        Results=@($script:Results)
    }
    $metadata | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $json -Encoding UTF8
    $script:Results | Export-Csv -LiteralPath $csv -NoTypeInformation -Encoding UTF8
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('MyWindowsHardening - Windows 10 Audit')
    $lines.Add(('Computer: {0}' -f $env:COMPUTERNAME))
    $lines.Add(('Generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
    $lines.Add(('ScriptVersion: {0}' -f $script:ScriptVersion))
    $lines.Add('ReadOnly: True')
    $lines.Add('')
    foreach ($r in $script:Results) {
        $lines.Add(('[{0}] {1} / {2} = {3} {4}' -f $r.Status,$r.Category,$r.Name,$r.Value,$r.Details))
    }
    $lines | Set-Content -LiteralPath $txt -Encoding UTF8
    Write-Host ''
    Write-Host 'Reports saved:' -ForegroundColor Green
    Write-Host $json
    Write-Host $csv
    Write-Host $txt
    Write-Warning 'Reports include device, network and security posture details. Protect them and sanitize them before sharing.'
}

if ($Mode -eq 'Apply' -or $Mode -eq 'Restore') {
    throw ("Mode '{0}' is intentionally unavailable in bootstrap v{1}. This release is read-only; no system changes were made." -f $Mode,$script:ScriptVersion)
}
try {
    Invoke-ReadOnlyAudit
    Save-AuditReport -Directory $OutputDirectory
    $unsupported = @($script:Results | Where-Object {$_.Category -eq 'Compatibility' -and $_.Status -eq 'FAIL'}).Count -gt 0
    if ($unsupported) {
        Write-Warning 'System is outside the supported Windows 10 client scope.'
        exit 2
    }
    exit 0
} catch {
    Write-Error ("Audit failed: {0}" -f $_.Exception.Message)
    exit 1
}
