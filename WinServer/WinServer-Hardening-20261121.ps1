#requires -Version 5.1
<#
.SYNOPSIS
    MyWindowsHardening - Windows Server enterprise baseline auditor.
.DESCRIPTION
    Read-only security and role inventory for Windows Server 2016, 2019,
    2022 and 2025. Generates JSON, CSV and TXT evidence reports.
    Apply and Restore are intentionally blocked in this bootstrap release.
.NOTES
    Project: MyWindowsHardening
    File: WinServer-Hardening-20261121.ps1
    Version: 0.1.0-bootstrap
    Compatibility: Windows PowerShell 5.1; Windows Server 2016+
    Execution: Read-only. No registry, policy, service, firewall or role changes.
#>
[CmdletBinding()]
param(
    [ValidateSet('Audit','Validate','Report','Apply','Restore')]
    [string]$Mode = 'Audit',
    [string]$OutputDirectory = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$script:ScriptVersion = '0.1.0-bootstrap'
$script:StartedAt = Get-Date
$script:Results = New-Object System.Collections.Generic.List[object]

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

function Test-CommandAvailable {
    param([string]$Name)
    return $null -ne (Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Test-IsAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Add-RegistryResult {
    param([string]$Name,[string]$Path,[string]$Property,[string]$Category='SecurityPolicy')
    try {
        $item = Get-ItemProperty -LiteralPath $Path -Name $Property -ErrorAction Stop
        Add-Result $Category $Name 'INFO' $item.$Property
    } catch {
        Add-Result $Category $Name 'INFO' 'Not configured / unavailable' $_.Exception.Message
    }
}

function Invoke-ServerAudit {
    Write-Host ''
    Write-Host 'MyWindowsHardening - Windows Server enterprise baseline' -ForegroundColor Cyan
    Write-Host ('Mode: {0} | Version: {1}' -f $Mode,$script:ScriptVersion)
    Write-Host 'READ ONLY - no system settings will be changed.' -ForegroundColor Green
    Write-Host ''

    $os = $null
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
        $build = [int]$cv.CurrentBuildNumber
        $ubr = if ($null -ne $cv.UBR) { [int]$cv.UBR } else { 0 }
        Add-Result 'System' 'Product' 'INFO' $os.Caption
        Add-Result 'System' 'Version' 'INFO' $cv.DisplayVersion
        Add-Result 'System' 'Build' 'INFO' ('{0}.{1}' -f $build,$ubr)
        Add-Result 'System' 'Edition' 'INFO' $cv.EditionID
        Add-Result 'System' 'Architecture' 'INFO' $os.OSArchitecture
        Add-Result 'System' 'Install date' 'INFO' $os.InstallDate
        Add-Result 'System' 'Last boot' 'INFO' $os.LastBootUpTime
        Add-Result 'System' 'Computer name' 'INFO' $env:COMPUTERNAME
        Add-Result 'System' 'Domain/workgroup' 'INFO' (Get-CimInstance Win32_ComputerSystem).Domain
        if ($os.ProductType -eq 1) {
            Add-Result 'Compatibility' 'Windows Server product type' 'FAIL' $os.ProductType 'Detected a client Windows installation; this profile is for Windows Server only.'
        } elseif ($os.ProductType -in @(2,3)) {
            Add-Result 'Compatibility' 'Windows Server product type' 'PASS' $os.ProductType '2=Domain Controller; 3=Member/standalone server.'
        } else {
            Add-Result 'Compatibility' 'Windows Server product type' 'REVIEW' $os.ProductType 'Unknown product type.'
        }
        $supportedBuilds = @(14393,17763,20348,26100)
        if ($build -in $supportedBuilds) {
            Add-Result 'Compatibility' 'Known Server generation build' 'PASS' $build 'Build maps to a Windows Server generation; verify edition and servicing lifecycle independently.'
        } else {
            Add-Result 'Compatibility' 'Known Server generation build' 'REVIEW' $build 'Build not in the explicit 2016/2019/2022/2025 reference list.'
        }
    } catch {
        Add-Result 'System' 'Operating system inventory' 'ERROR' $null $_.Exception.Message
    }

    Add-Result 'Execution' 'Administrator session' 'INFO' (Test-IsAdministrator) 'Read-only audit can run unelevated; elevated execution may expose more inventory.'

    # Firewall profiles and effective defaults.
    if (Test-CommandAvailable 'Get-NetFirewallProfile') {
        try {
            foreach ($p in (Get-NetFirewallProfile -PolicyStore ActiveStore)) {
                Add-Result 'Firewall' ($p.Name + ' enabled') $(if ($p.Enabled) {'PASS'} else {'REVIEW'}) $p.Enabled
                Add-Result 'Firewall' ($p.Name + ' inbound default') 'INFO' $p.DefaultInboundAction
                Add-Result 'Firewall' ($p.Name + ' outbound default') 'INFO' $p.DefaultOutboundAction
                Add-Result 'Firewall' ($p.Name + ' logging blocked') 'INFO' $p.LogBlocked
                Add-Result 'Firewall' ($p.Name + ' log path') 'INFO' $p.LogFileName
            }
        } catch { Add-Result 'Firewall' 'Profile inventory' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'Firewall' 'NetSecurity module' 'UNAVAILABLE' $null }

    # Microsoft Defender status; third-party AV and policy ownership require manual review.
    if (Test-CommandAvailable 'Get-MpComputerStatus') {
        try {
            $mp = Get-MpComputerStatus
            foreach ($c in @(
                @{Name='Antivirus enabled';Value=$mp.AntivirusEnabled},
                @{Name='Real-time protection';Value=$mp.RealTimeProtectionEnabled},
                @{Name='Behavior monitoring';Value=$mp.BehaviorMonitorEnabled},
                @{Name='IOAV protection';Value=$mp.IoavProtectionEnabled},
                @{Name='Network inspection';Value=$mp.NISEnabled},
                @{Name='Tamper protection';Value=$mp.IsTamperProtected},
                @{Name='Signature age days';Value=$mp.AntivirusSignatureAge}
            )) {
                $status = if ($c.Name -eq 'Signature age days') {
                    if ($null -ne $c.Value -and [int]$c.Value -le 3) {'PASS'} else {'REVIEW'}
                } elseif ($c.Value -eq $true) {'PASS'} elseif ($c.Value -eq $false) {'REVIEW'} else {'INFO'}
                Add-Result 'Defender' $c.Name $status $c.Value
            }
        } catch { Add-Result 'Defender' 'Status' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'Defender' 'Defender cmdlets' 'UNAVAILABLE' $null 'May be absent, disabled by policy, or managed by another endpoint security product.' }

    # Core security policy indicators; registry values are evidence, not proof of enforcement.
    Add-RegistryResult 'UAC EnableLUA' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'EnableLUA'
    Add-RegistryResult 'UAC admin consent behavior' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'ConsentPromptBehaviorAdmin'
    Add-RegistryResult 'LSA protection RunAsPPL' 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RunAsPPL'
    Add-RegistryResult 'Credential Guard LsaCfgFlags' 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'LsaCfgFlags'
    Add-RegistryResult 'VBS EnableVirtualizationBasedSecurity' 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' 'EnableVirtualizationBasedSecurity'
    Add-RegistryResult 'RDP deny connections fDenyTSConnections' 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections'
    Add-RegistryResult 'LAN Manager authentication level' 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'LmCompatibilityLevel'
    Add-RegistryResult 'NTLM outgoing restriction' 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0' 'RestrictSendingNTLMTraffic'
    Add-RegistryResult 'AutoRun policy' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoDriveTypeAutoRun'

    # SMB server/client posture. Do not disable SMB2/3 or change signing/encryption automatically.
    if (Test-CommandAvailable 'Get-SmbServerConfiguration') {
        try {
            $s = Get-SmbServerConfiguration
            foreach ($n in @('EnableSMB1Protocol','EnableSMB2Protocol','RequireSecuritySignature','EnableSecuritySignature','EncryptData','RejectUnencryptedAccess','EnableLeasing','EnableMultiChannel')) {
                if ($s.PSObject.Properties.Name -contains $n) { Add-Result 'SMBServer' $n 'INFO' $s.$n }
            }
        } catch { Add-Result 'SMBServer' 'Configuration' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'SMBServer' 'SMB server cmdlets' 'UNAVAILABLE' $null }
    if (Test-CommandAvailable 'Get-SmbClientConfiguration') {
        try {
            $s = Get-SmbClientConfiguration
            foreach ($n in @('EnableInsecureGuestLogons','RequireSecuritySignature','EnableSecuritySignature')) {
                if ($s.PSObject.Properties.Name -contains $n) { Add-Result 'SMBClient' $n 'INFO' $s.$n }
            }
        } catch { Add-Result 'SMBClient' 'Configuration' 'ERROR' $null $_.Exception.Message }
    }

    # Server roles and installed Windows features.
    if (Test-CommandAvailable 'Get-WindowsFeature') {
        try {
            foreach ($f in (Get-WindowsFeature | Where-Object { $_.Installed })) {
                Add-Result 'RolesFeatures' $f.Name 'INFO' $f.DisplayName
            }
        } catch { Add-Result 'RolesFeatures' 'Feature inventory' 'ERROR' $null $_.Exception.Message }
    } else {
        Add-Result 'RolesFeatures' 'ServerManager cmdlets' 'UNAVAILABLE' $null 'Get-WindowsFeature is normally available on Windows Server with ServerManager.'
    }

    # Domain Controller / directory service indicators.
    if (Test-CommandAvailable 'Get-ADDomain') {
        try {
            $domain = Get-ADDomain
            Add-Result 'ActiveDirectory' 'Domain DNS root' 'INFO' $domain.DNSRoot
            Add-Result 'ActiveDirectory' 'Domain mode' 'INFO' $domain.DomainMode
            Add-Result 'ActiveDirectory' 'PDC emulator' 'INFO' $domain.PDCEmulator
            Add-Result 'ActiveDirectory' 'RID master' 'INFO' $domain.RIDMaster
            Add-Result 'ActiveDirectory' 'Infrastructure master' 'INFO' $domain.InfrastructureMaster
        } catch { Add-Result 'ActiveDirectory' 'Domain query' 'UNAVAILABLE' $null $_.Exception.Message }
    } else { Add-Result 'ActiveDirectory' 'AD module' 'INFO' 'Not available' 'May not be a Domain Controller or RSAT AD module is not installed.' }

    # Services: inventory only. Role-aware interpretation is required before any change.
    foreach ($name in @('LanmanServer','LanmanWorkstation','WinDefend','MpsSvc','EventLog','W32Time','NTDS','DNS','DHCPServer','W3SVC','TermService','RemoteRegistry','Spooler','vmms','ClusSvc','MSSQLSERVER')) {
        try {
            $svc = Get-CimInstance -ClassName Win32_Service -Filter ("Name='{0}'" -f $name)
            if ($null -ne $svc) { Add-Result 'Services' $name 'INFO' ($svc.State + ' / ' + $svc.StartMode) }
        } catch { Add-Result 'Services' $name 'ERROR' $null $_.Exception.Message }
    }

    # Local Administrators membership; domain principals are preserved as names only.
    try {
        if (Test-CommandAvailable 'Get-LocalGroupMember') {
            foreach ($m in (Get-LocalGroupMember -Group 'Administrators' -ErrorAction Stop)) {
                Add-Result 'PrivilegedAccounts' 'Local Administrators member' 'REVIEW' ($m.Name + ' [' + $m.ObjectClass + ']') 'Review membership against approved privileged access and tiering policy.'
            }
        } else { Add-Result 'PrivilegedAccounts' 'Local group cmdlet' 'UNAVAILABLE' $null }
    } catch { Add-Result 'PrivilegedAccounts' 'Local Administrators membership' 'ERROR' $null $_.Exception.Message }

    # Network inventory: no ports or interfaces are changed.
    if (Test-CommandAvailable 'Get-NetAdapter') {
        try {
            foreach ($a in (Get-NetAdapter -Physical -ErrorAction Stop)) {
                Add-Result 'Network' ('Adapter ' + $a.Name) 'INFO' ($a.Status + ' / ' + $a.LinkSpeed)
            }
        } catch { Add-Result 'Network' 'Adapter inventory' 'ERROR' $null $_.Exception.Message }
    }
    if (Test-CommandAvailable 'Get-NetTCPConnection') {
        try {
            $listeners = @(Get-NetTCPConnection -State Listen -ErrorAction Stop)
            Add-Result 'NetworkExposure' 'Listening TCP endpoints count' 'INFO' $listeners.Count 'Review listeners against the server role and approved network flows.'
            foreach ($l in ($listeners | Select-Object -First 100)) {
                Add-Result 'NetworkExposure' 'TCP listener' 'REVIEW' ($l.LocalAddress + ':' + $l.LocalPort + ' PID=' + $l.OwningProcess)
            }
            if ($listeners.Count -gt 100) { Add-Result 'NetworkExposure' 'Listener listing truncated' 'INFO' $listeners.Count 'Only the first 100 endpoints are included.' }
        } catch { Add-Result 'NetworkExposure' 'TCP listener inventory' 'ERROR' $null $_.Exception.Message }
    }

    # Storage encryption and audit policy.
    if (Test-CommandAvailable 'Get-BitLockerVolume') {
        try {
            foreach ($v in (Get-BitLockerVolume -ErrorAction Stop)) {
                Add-Result 'Storage' ('BitLocker ' + $v.MountPoint) 'INFO' ($v.VolumeStatus + ' / ' + $v.ProtectionStatus)
            }
        } catch { Add-Result 'Storage' 'BitLocker inventory' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'Storage' 'BitLocker cmdlets' 'UNAVAILABLE' $null }
    if (Test-CommandAvailable 'auditpol.exe') {
        try {
            $audit = & auditpol.exe /get /category:* 2>&1
            Add-Result 'AuditPolicy' 'auditpol query' 'INFO' 'Collected' (($audit | Out-String).Trim())
        } catch { Add-Result 'AuditPolicy' 'auditpol query' 'ERROR' $null $_.Exception.Message }
    }

    # Pending reboot indicators are read-only and do not trigger a restart.
    $rebootPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )
    $pending = @($rebootPaths | Where-Object { Test-Path -LiteralPath $_ }).Count -gt 0
    Add-Result 'Maintenance' 'Pending reboot registry indicators' $(if ($pending) {'REVIEW'} else {'INFO'}) $pending 'This is a heuristic; validate with enterprise patch management tooling.'

    $script:Results | Format-Table -AutoSize -Wrap
    Write-Host ''
    Write-Host 'Status counts:' -ForegroundColor Cyan
    foreach ($statusName in @('PASS','REVIEW','FAIL','ERROR','INFO','UNAVAILABLE')) {
        $count = @($script:Results | Where-Object { $_.Status -eq $statusName }).Count
        Write-Host ('  {0,-12} {1,4}' -f $statusName,$count)
    }
}

function Save-AuditReport {
    param([string]$Directory)
    if ([string]::IsNullOrWhiteSpace($Directory)) {
        $Directory = Join-Path -Path $PSScriptRoot -ChildPath 'Reports'
    }
    if (-not (Test-Path -LiteralPath $Directory)) {
        New-Item -Path $Directory -ItemType Directory -Force | Out-Null
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $base = 'WinServer-Hardening-Audit-' + $stamp
    $metadata = [pscustomobject]@{
        Project = 'MyWindowsHardening'
        Platform = 'Windows Server'
        ScriptVersion = $script:ScriptVersion
        Mode = $Mode
        StartedAt = $script:StartedAt.ToString('o')
        FinishedAt = (Get-Date).ToString('o')
        ComputerName = $env:COMPUTERNAME
        ReadOnly = $true
        Results = @($script:Results)
    }
    $metadata | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $Directory ($base + '.json')) -Encoding UTF8
    $script:Results | Export-Csv -LiteralPath (Join-Path $Directory ($base + '.csv')) -NoTypeInformation -Encoding UTF8
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('MyWindowsHardening - Windows Server enterprise audit')
    $lines.Add(('Computer: {0}' -f $env:COMPUTERNAME))
    $lines.Add(('Generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
    $lines.Add('ReadOnly: True')
    $lines.Add('')
    foreach ($r in $script:Results) {
        $lines.Add(('[{0}] {1} / {2} = {3} {4}' -f $r.Status,$r.Category,$r.Name,$r.Value,$r.Details))
    }
    $lines | Set-Content -LiteralPath (Join-Path $Directory ($base + '.txt')) -Encoding UTF8
    Write-Host ''
    Write-Host ('Reports saved to: {0}' -f $Directory) -ForegroundColor Green
}

if ($Mode -eq 'Apply' -or $Mode -eq 'Restore') {
    throw ("Mode '{0}' is intentionally unavailable in bootstrap v{1}. This release is read-only; no system changes were made." -f $Mode,$script:ScriptVersion)
}

try {
    Invoke-ServerAudit
    Save-AuditReport -Directory $OutputDirectory
    $unsupported = @($script:Results | Where-Object { $_.Category -eq 'Compatibility' -and $_.Status -eq 'FAIL' }).Count -gt 0
    if ($unsupported) {
        Write-Warning 'This profile targets Windows Server; no changes were made.'
        exit 2
    }
    exit 0
} catch {
    Write-Error ("Audit failed: {0}" -f $_.Exception.Message)
    exit 1
}
