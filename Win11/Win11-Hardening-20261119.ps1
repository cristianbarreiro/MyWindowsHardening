#requires -Version 5.1
<#
.SYNOPSIS
    MyWindowsHardening - Windows 11 baseline auditor (read-only bootstrap).
.DESCRIPTION
    Collects Windows 11 security, platform and configuration facts.
    This initial release is strictly read-only. Apply and Restore are unavailable
    until every control has a reviewed backup, compatibility contract and rollback.
.NOTES
    Project: MyWindowsHardening
    File: Win11-Hardening-20261119.ps1
    Initial release: 2026-11-19
    Compatibility: Windows 11 client (build 22000+), Windows PowerShell 5.1
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
$script:ScriptVersion = '0.1.0-bootstrap'

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

function Add-RegistryResult {
    param(
        [string]$Name,
        [string]$Path,
        [string]$Property,
        [string]$Category = 'WindowsSecurity'
    )
    try {
        $item = Get-ItemProperty -LiteralPath $Path -Name $Property -ErrorAction Stop
        $value = $item.$Property
        Add-Result $Category $Name 'INFO' $value
    } catch [System.Management.Automation.ItemNotFoundException] {
        Add-Result $Category $Name 'INFO' 'Not configured / key unavailable'
    } catch {
        Add-Result $Category $Name 'UNAVAILABLE' $null $_.Exception.Message
    }
}

function Invoke-ReadOnlyAudit {
    Write-Host ''
    Write-Host 'MyWindowsHardening - Windows 11 baseline audit' -ForegroundColor Cyan
    Write-Host ('Mode: {0} | Version: {1}' -f $Mode, $script:ScriptVersion)
    Write-Host 'READ ONLY - no system settings will be changed.' -ForegroundColor Green
    Write-Host ''

    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $cv = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
        $build = [int]$cv.CurrentBuildNumber
        $ubr = if ($null -ne $cv.UBR) { [int]$cv.UBR } else { 0 }
        Add-Result 'System' 'Product' 'INFO' $os.Caption
        Add-Result 'System' 'DisplayVersion' 'INFO' $cv.DisplayVersion
        Add-Result 'System' 'Build' 'INFO' ('{0}.{1}' -f $build, $ubr)
        Add-Result 'System' 'Edition' 'INFO' $cv.EditionID
        Add-Result 'System' 'OS architecture' 'INFO' $os.OSArchitecture
        if ($os.ProductType -ne 1 -or $build -lt 22000) {
            Add-Result 'Compatibility' 'Windows 11 client' 'FAIL' $false 'This script targets Windows 11 client builds 22000 and later; Windows Server is excluded.'
        } else {
            Add-Result 'Compatibility' 'Windows 11 client' 'PASS' $true
        }
        if ($build -lt 26100) {
            Add-Result 'Compatibility' 'Windows 11 24H2 baseline' 'REVIEW' $build 'Older Windows 11 releases are supported for inventory, but feature availability differs.'
        } else {
            Add-Result 'Compatibility' 'Windows 11 24H2-or-later build' 'INFO' $build 'Confirm servicing status and current cumulative updates separately.'
        }
        # Servicing support is edition- and release-specific. This is separate
        # from script compatibility: an older build can be inventoried but no
        # longer receive security updates. Refresh these dates when Microsoft
        # updates its Windows release-health and lifecycle documentation.
        $edition = [string]$cv.EditionID
        $version = [string]$cv.DisplayVersion
        $servicingEnd = $null
        $servicingBasis = ''
        switch ($version) {
            '23H2' {
                if ($edition -match '^(Enterprise|Education)
    } catch {
        Add-Result 'System' 'Operating system inventory' 'ERROR' $null $_.Exception.Message
    }

    Add-Result 'Execution' 'Administrator session' 'INFO' (Test-IsAdministrator) 'Elevation is not required for this read-only audit.'

    # Windows Defender Firewall
    if (Test-CommandAvailable 'Get-NetFirewallProfile') {
        try {
            foreach ($p in (Get-NetFirewallProfile -PolicyStore ActiveStore)) {
                $status = if ($p.Enabled) { 'PASS' } else { 'REVIEW' }
                Add-Result 'Firewall' ($p.Name + ' enabled') $status $p.Enabled
                Add-Result 'Firewall' ($p.Name + ' inbound default') 'INFO' $p.DefaultInboundAction
                Add-Result 'Firewall' ($p.Name + ' outbound default') 'INFO' $p.DefaultOutboundAction
                Add-Result 'Firewall' ($p.Name + ' blocked logging') 'INFO' $p.LogBlocked
            }
        } catch { Add-Result 'Firewall' 'Profile inventory' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'Firewall' 'NetSecurity cmdlets' 'UNAVAILABLE' $null }

    # Microsoft Defender
    if (Test-CommandAvailable 'Get-MpComputerStatus') {
        try {
            $mp = Get-MpComputerStatus
            $checks = @(
                @{Name='Antivirus enabled';Value=$mp.AntivirusEnabled},
                @{Name='Real-time protection';Value=$mp.RealTimeProtectionEnabled},
                @{Name='Behavior monitoring';Value=$mp.BehaviorMonitorEnabled},
                @{Name='IOAV protection';Value=$mp.IoavProtectionEnabled},
                @{Name='Network inspection';Value=$mp.NISEnabled},
                @{Name='Tamper protection';Value=$mp.IsTamperProtected},
                @{Name='Antivirus signatures age (days)';Value=$mp.AntivirusSignatureAge}
            )
            foreach ($c in $checks) {
                $status = if ($c.Value -eq $true) { 'PASS' } elseif ($c.Value -eq $false) { 'REVIEW' } else { 'INFO' }
                if ($c.Name -like '*age*') { $status = if ([int]$c.Value -le 3) { 'PASS' } else { 'REVIEW' } }
                Add-Result 'Defender' $c.Name $status $c.Value
            }
        } catch { Add-Result 'Defender' 'Status' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'Defender' 'Defender cmdlets' 'UNAVAILABLE' $null }

    # Windows 11 platform protections and security policy indicators.
    Add-RegistryResult 'VBS configured' 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' 'EnableVirtualizationBasedSecurity'
    Add-RegistryResult 'Credential Guard configured' 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'LsaCfgFlags'
    Add-RegistryResult 'LSA protection (RunAsPPL)' 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RunAsPPL'
    Add-RegistryResult 'UAC EnableLUA' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'EnableLUA'
    Add-RegistryResult 'UAC consent behavior' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'ConsentPromptBehaviorAdmin'
    Add-RegistryResult 'SmartScreen Explorer policy' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' 'SmartScreenEnabled'
    Add-RegistryResult 'AutoRun policy' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoDriveTypeAutoRun'
    Add-RegistryResult 'RDP deny connections policy' 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections'

    try {
        if (Test-CommandAvailable 'Get-CimInstance') {
            $cs = Get-CimInstance -ClassName Win32_ComputerSystem
            Add-Result 'PlatformSecurity' 'Hypervisor present' 'INFO' $cs.HypervisorPresent 'A present hypervisor does not by itself prove VBS or Memory Integrity is enabled.'
        }
    } catch { Add-Result 'PlatformSecurity' 'Hypervisor status' 'ERROR' $null $_.Exception.Message }

    try {
        if (Test-CommandAvailable 'Confirm-SecureBootUEFI') {
            $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop
            Add-Result 'PlatformSecurity' 'Secure Boot' $(if ($secureBoot) { 'PASS' } else { 'REVIEW' }) $secureBoot
        }
    } catch {
        Add-Result 'PlatformSecurity' 'Secure Boot' 'UNAVAILABLE' $null 'May be unavailable on legacy BIOS, unsupported firmware, or restricted sessions.'
    }

    try {
        if (Test-CommandAvailable 'Get-Tpm') {
            $tpm = Get-Tpm
            Add-Result 'PlatformSecurity' 'TPM present' $(if ($tpm.TpmPresent) { 'PASS' } else { 'REVIEW' }) $tpm.TpmPresent
            Add-Result 'PlatformSecurity' 'TPM ready' $(if ($tpm.TpmReady) { 'PASS' } else { 'REVIEW' }) $tpm.TpmReady
            Add-Result 'PlatformSecurity' 'TPM enabled' 'INFO' $tpm.TpmEnabled
        }
    } catch { Add-Result 'PlatformSecurity' 'TPM inventory' 'ERROR' $null $_.Exception.Message }

    try {
        $dg = Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction Stop
        Add-Result 'PlatformSecurity' 'Device Guard security services configured' 'INFO' ($dg.SecurityServicesConfigured -join ',')
        Add-Result 'PlatformSecurity' 'Device Guard security services running' 'INFO' ($dg.SecurityServicesRunning -join ',')
        Add-Result 'PlatformSecurity' 'Virtualization-based security status (0=off, 1=configured, 2=running)' 'INFO' $dg.VirtualizationBasedSecurityStatus
        Add-Result 'PlatformSecurity' 'Available security properties' 'INFO' ($dg.AvailableSecurityProperties -join ',')
    } catch { Add-Result 'PlatformSecurity' 'Device Guard WMI inventory' 'UNAVAILABLE' $null $_.Exception.Message }

    # SMB configuration: record actual platform capabilities; do not assume defaults.
    if (Test-CommandAvailable 'Get-SmbClientConfiguration') {
        try {
            $s = Get-SmbClientConfiguration
            Add-Result 'SMB' 'Client RequireSecuritySignature' 'INFO' $s.RequireSecuritySignature
            Add-Result 'SMB' 'Client EnableSecuritySignature' 'INFO' $s.EnableSecuritySignature
            Add-Result 'SMB' 'Client EnableInsecureGuestLogons' 'INFO' $s.EnableInsecureGuestLogons
            if ($s.PSObject.Properties.Name -contains 'RequireEncryption') {
                Add-Result 'SMB' 'Client RequireEncryption' 'INFO' $s.RequireEncryption
            }
        } catch { Add-Result 'SMB' 'Client configuration' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'SMB' 'Client cmdlets' 'UNAVAILABLE' $null }

    if (Test-CommandAvailable 'Get-SmbServerConfiguration') {
        try {
            $s = Get-SmbServerConfiguration
            Add-Result 'SMB' 'Server EnableSMB1Protocol' 'INFO' $s.EnableSMB1Protocol
            Add-Result 'SMB' 'Server EnableSMB2Protocol' 'INFO' $s.EnableSMB2Protocol
            Add-Result 'SMB' 'Server RequireSecuritySignature' 'INFO' $s.RequireSecuritySignature
            Add-Result 'SMB' 'Server EnableEncryptData' 'INFO' $s.EnableEncryptData
        } catch { Add-Result 'SMB' 'Server configuration' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'SMB' 'Server cmdlets' 'UNAVAILABLE' $null }

    # Service inventory only. No service is started, stopped or reconfigured.
    foreach ($n in @('LanmanServer','LanmanWorkstation','FDResPub','fdPHost','SSDPSRV','upnphost','WlanSvc','DoSvc','Spooler','SharedAccess','vmcompute','vmms','WslService','Sense','WinDefend','wscsvc','RemoteRegistry','TermService')) {
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
        } catch { Add-Result 'Storage' 'Inventory' 'ERROR' $null $_.Exception.Message }
    } else {
        Add-Result 'Storage' 'BitLocker cmdlets' 'UNAVAILABLE' $null 'Availability depends on edition, hardware and optional management components.'
    }

    if (Test-CommandAvailable 'Get-DOConfig') {
        try {
            $d = Get-DOConfig
            Add-Result 'DeliveryOptimization' 'DownloadMode' 'INFO' $d.DODownloadMode
        } catch { Add-Result 'DeliveryOptimization' 'Configuration query' 'ERROR' $null $_.Exception.Message }
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
    if (-not (Test-Path -LiteralPath $Directory)) {
        New-Item -Path $Directory -ItemType Directory -Force | Out-Null
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $base = 'Win11-Hardening-Audit-' + $stamp
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
    $lines.Add('MyWindowsHardening - Windows 11 Audit')
    $lines.Add(('Computer: {0}' -f $env:COMPUTERNAME))
    $lines.Add(('Generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
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
}

if ($Mode -eq 'Apply' -or $Mode -eq 'Restore') {
    throw ("Mode '{0}' is intentionally unavailable in bootstrap v{1}. This release is read-only; no system changes were made." -f $Mode,$script:ScriptVersion)
}

try {
    Invoke-ReadOnlyAudit
    Save-AuditReport -Directory $OutputDirectory
    $unsupported = @($script:Results | Where-Object {
        ($_.Category -eq 'Compatibility' -or $_.Category -eq 'Servicing') -and $_.Status -eq 'FAIL'
    }).Count -gt 0
    if ($unsupported) {
        Write-Warning 'System is outside the supported Windows 11 client scope or its feature release has reached end of updates.'
        exit 2
    }
    exit 0
} catch {
    Write-Error ("Audit failed: {0}" -f $_.Exception.Message)
    exit 1
}
) { $servicingEnd = [datetime]'2026-11-10'; $servicingBasis = '23H2 Enterprise/Education' }
                elseif ($edition -match '^(Core|CoreN|Professional|ProfessionalN|ProfessionalWorkstation|ProfessionalEducation)
    } catch {
        Add-Result 'System' 'Operating system inventory' 'ERROR' $null $_.Exception.Message
    }

    Add-Result 'Execution' 'Administrator session' 'INFO' (Test-IsAdministrator) 'Elevation is not required for this read-only audit.'

    # Windows Defender Firewall
    if (Test-CommandAvailable 'Get-NetFirewallProfile') {
        try {
            foreach ($p in (Get-NetFirewallProfile -PolicyStore ActiveStore)) {
                $status = if ($p.Enabled) { 'PASS' } else { 'REVIEW' }
                Add-Result 'Firewall' ($p.Name + ' enabled') $status $p.Enabled
                Add-Result 'Firewall' ($p.Name + ' inbound default') 'INFO' $p.DefaultInboundAction
                Add-Result 'Firewall' ($p.Name + ' outbound default') 'INFO' $p.DefaultOutboundAction
                Add-Result 'Firewall' ($p.Name + ' blocked logging') 'INFO' $p.LogBlocked
            }
        } catch { Add-Result 'Firewall' 'Profile inventory' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'Firewall' 'NetSecurity cmdlets' 'UNAVAILABLE' $null }

    # Microsoft Defender
    if (Test-CommandAvailable 'Get-MpComputerStatus') {
        try {
            $mp = Get-MpComputerStatus
            $checks = @(
                @{Name='Antivirus enabled';Value=$mp.AntivirusEnabled},
                @{Name='Real-time protection';Value=$mp.RealTimeProtectionEnabled},
                @{Name='Behavior monitoring';Value=$mp.BehaviorMonitorEnabled},
                @{Name='IOAV protection';Value=$mp.IoavProtectionEnabled},
                @{Name='Network inspection';Value=$mp.NISEnabled},
                @{Name='Tamper protection';Value=$mp.IsTamperProtected},
                @{Name='Antivirus signatures age (days)';Value=$mp.AntivirusSignatureAge}
            )
            foreach ($c in $checks) {
                $status = if ($c.Value -eq $true) { 'PASS' } elseif ($c.Value -eq $false) { 'REVIEW' } else { 'INFO' }
                if ($c.Name -like '*age*') { $status = if ([int]$c.Value -le 3) { 'PASS' } else { 'REVIEW' } }
                Add-Result 'Defender' $c.Name $status $c.Value
            }
        } catch { Add-Result 'Defender' 'Status' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'Defender' 'Defender cmdlets' 'UNAVAILABLE' $null }

    # Windows 11 platform protections and security policy indicators.
    Add-RegistryResult 'VBS configured' 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' 'EnableVirtualizationBasedSecurity'
    Add-RegistryResult 'Credential Guard configured' 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'LsaCfgFlags'
    Add-RegistryResult 'LSA protection (RunAsPPL)' 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RunAsPPL'
    Add-RegistryResult 'UAC EnableLUA' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'EnableLUA'
    Add-RegistryResult 'UAC consent behavior' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'ConsentPromptBehaviorAdmin'
    Add-RegistryResult 'SmartScreen Explorer policy' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' 'SmartScreenEnabled'
    Add-RegistryResult 'AutoRun policy' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoDriveTypeAutoRun'
    Add-RegistryResult 'RDP deny connections policy' 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections'

    try {
        if (Test-CommandAvailable 'Get-CimInstance') {
            $cs = Get-CimInstance -ClassName Win32_ComputerSystem
            Add-Result 'PlatformSecurity' 'Hypervisor present' 'INFO' $cs.HypervisorPresent 'A present hypervisor does not by itself prove VBS or Memory Integrity is enabled.'
        }
    } catch { Add-Result 'PlatformSecurity' 'Hypervisor status' 'ERROR' $null $_.Exception.Message }

    try {
        if (Test-CommandAvailable 'Confirm-SecureBootUEFI') {
            $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop
            Add-Result 'PlatformSecurity' 'Secure Boot' $(if ($secureBoot) { 'PASS' } else { 'REVIEW' }) $secureBoot
        }
    } catch {
        Add-Result 'PlatformSecurity' 'Secure Boot' 'UNAVAILABLE' $null 'May be unavailable on legacy BIOS, unsupported firmware, or restricted sessions.'
    }

    try {
        if (Test-CommandAvailable 'Get-Tpm') {
            $tpm = Get-Tpm
            Add-Result 'PlatformSecurity' 'TPM present' $(if ($tpm.TpmPresent) { 'PASS' } else { 'REVIEW' }) $tpm.TpmPresent
            Add-Result 'PlatformSecurity' 'TPM ready' $(if ($tpm.TpmReady) { 'PASS' } else { 'REVIEW' }) $tpm.TpmReady
            Add-Result 'PlatformSecurity' 'TPM enabled' 'INFO' $tpm.TpmEnabled
        }
    } catch { Add-Result 'PlatformSecurity' 'TPM inventory' 'ERROR' $null $_.Exception.Message }

    try {
        $dg = Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction Stop
        Add-Result 'PlatformSecurity' 'Device Guard security services configured' 'INFO' ($dg.SecurityServicesConfigured -join ',')
        Add-Result 'PlatformSecurity' 'Device Guard security services running' 'INFO' ($dg.SecurityServicesRunning -join ',')
        Add-Result 'PlatformSecurity' 'Virtualization-based security status (0=off, 1=configured, 2=running)' 'INFO' $dg.VirtualizationBasedSecurityStatus
        Add-Result 'PlatformSecurity' 'Available security properties' 'INFO' ($dg.AvailableSecurityProperties -join ',')
    } catch { Add-Result 'PlatformSecurity' 'Device Guard WMI inventory' 'UNAVAILABLE' $null $_.Exception.Message }

    # SMB configuration: record actual platform capabilities; do not assume defaults.
    if (Test-CommandAvailable 'Get-SmbClientConfiguration') {
        try {
            $s = Get-SmbClientConfiguration
            Add-Result 'SMB' 'Client RequireSecuritySignature' 'INFO' $s.RequireSecuritySignature
            Add-Result 'SMB' 'Client EnableSecuritySignature' 'INFO' $s.EnableSecuritySignature
            Add-Result 'SMB' 'Client EnableInsecureGuestLogons' 'INFO' $s.EnableInsecureGuestLogons
            if ($s.PSObject.Properties.Name -contains 'RequireEncryption') {
                Add-Result 'SMB' 'Client RequireEncryption' 'INFO' $s.RequireEncryption
            }
        } catch { Add-Result 'SMB' 'Client configuration' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'SMB' 'Client cmdlets' 'UNAVAILABLE' $null }

    if (Test-CommandAvailable 'Get-SmbServerConfiguration') {
        try {
            $s = Get-SmbServerConfiguration
            Add-Result 'SMB' 'Server EnableSMB1Protocol' 'INFO' $s.EnableSMB1Protocol
            Add-Result 'SMB' 'Server EnableSMB2Protocol' 'INFO' $s.EnableSMB2Protocol
            Add-Result 'SMB' 'Server RequireSecuritySignature' 'INFO' $s.RequireSecuritySignature
            Add-Result 'SMB' 'Server EnableEncryptData' 'INFO' $s.EnableEncryptData
        } catch { Add-Result 'SMB' 'Server configuration' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'SMB' 'Server cmdlets' 'UNAVAILABLE' $null }

    # Service inventory only. No service is started, stopped or reconfigured.
    foreach ($n in @('LanmanServer','LanmanWorkstation','FDResPub','fdPHost','SSDPSRV','upnphost','WlanSvc','DoSvc','Spooler','SharedAccess','vmcompute','vmms','WslService','Sense','WinDefend','wscsvc','RemoteRegistry','TermService')) {
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
        } catch { Add-Result 'Storage' 'Inventory' 'ERROR' $null $_.Exception.Message }
    } else {
        Add-Result 'Storage' 'BitLocker cmdlets' 'UNAVAILABLE' $null 'Availability depends on edition, hardware and optional management components.'
    }

    if (Test-CommandAvailable 'Get-DOConfig') {
        try {
            $d = Get-DOConfig
            Add-Result 'DeliveryOptimization' 'DownloadMode' 'INFO' $d.DODownloadMode
        } catch { Add-Result 'DeliveryOptimization' 'Configuration query' 'ERROR' $null $_.Exception.Message }
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
    if (-not (Test-Path -LiteralPath $Directory)) {
        New-Item -Path $Directory -ItemType Directory -Force | Out-Null
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $base = 'Win11-Hardening-Audit-' + $stamp
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
    $lines.Add('MyWindowsHardening - Windows 11 Audit')
    $lines.Add(('Computer: {0}' -f $env:COMPUTERNAME))
    $lines.Add(('Generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
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
}

if ($Mode -eq 'Apply' -or $Mode -eq 'Restore') {
    throw ("Mode '{0}' is intentionally unavailable in bootstrap v{1}. This release is read-only; no system changes were made." -f $Mode,$script:ScriptVersion)
}

try {
    Invoke-ReadOnlyAudit
    Save-AuditReport -Directory $OutputDirectory
    $unsupported = @($script:Results | Where-Object { $_.Category -eq 'Compatibility' -and $_.Status -eq 'FAIL' }).Count -gt 0
    if ($unsupported) {
        Write-Warning 'System is outside the supported Windows 11 client scope.'
        exit 2
    }
    exit 0
} catch {
    Write-Error ("Audit failed: {0}" -f $_.Exception.Message)
    exit 1
}
) { $servicingEnd = [datetime]'2025-11-11'; $servicingBasis = '23H2 Home/Pro family' }
            }
            '24H2' {
                if ($edition -eq 'EnterpriseS') { $servicingEnd = [datetime]'2029-10-09'; $servicingBasis = 'Enterprise LTSC 2024' }
                elseif ($edition -eq 'IoTEnterpriseS') { $servicingEnd = [datetime]'2034-10-10'; $servicingBasis = 'IoT Enterprise LTSC 2024' }
                elseif ($edition -match '^(Enterprise|Education)
    } catch {
        Add-Result 'System' 'Operating system inventory' 'ERROR' $null $_.Exception.Message
    }

    Add-Result 'Execution' 'Administrator session' 'INFO' (Test-IsAdministrator) 'Elevation is not required for this read-only audit.'

    # Windows Defender Firewall
    if (Test-CommandAvailable 'Get-NetFirewallProfile') {
        try {
            foreach ($p in (Get-NetFirewallProfile -PolicyStore ActiveStore)) {
                $status = if ($p.Enabled) { 'PASS' } else { 'REVIEW' }
                Add-Result 'Firewall' ($p.Name + ' enabled') $status $p.Enabled
                Add-Result 'Firewall' ($p.Name + ' inbound default') 'INFO' $p.DefaultInboundAction
                Add-Result 'Firewall' ($p.Name + ' outbound default') 'INFO' $p.DefaultOutboundAction
                Add-Result 'Firewall' ($p.Name + ' blocked logging') 'INFO' $p.LogBlocked
            }
        } catch { Add-Result 'Firewall' 'Profile inventory' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'Firewall' 'NetSecurity cmdlets' 'UNAVAILABLE' $null }

    # Microsoft Defender
    if (Test-CommandAvailable 'Get-MpComputerStatus') {
        try {
            $mp = Get-MpComputerStatus
            $checks = @(
                @{Name='Antivirus enabled';Value=$mp.AntivirusEnabled},
                @{Name='Real-time protection';Value=$mp.RealTimeProtectionEnabled},
                @{Name='Behavior monitoring';Value=$mp.BehaviorMonitorEnabled},
                @{Name='IOAV protection';Value=$mp.IoavProtectionEnabled},
                @{Name='Network inspection';Value=$mp.NISEnabled},
                @{Name='Tamper protection';Value=$mp.IsTamperProtected},
                @{Name='Antivirus signatures age (days)';Value=$mp.AntivirusSignatureAge}
            )
            foreach ($c in $checks) {
                $status = if ($c.Value -eq $true) { 'PASS' } elseif ($c.Value -eq $false) { 'REVIEW' } else { 'INFO' }
                if ($c.Name -like '*age*') { $status = if ([int]$c.Value -le 3) { 'PASS' } else { 'REVIEW' } }
                Add-Result 'Defender' $c.Name $status $c.Value
            }
        } catch { Add-Result 'Defender' 'Status' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'Defender' 'Defender cmdlets' 'UNAVAILABLE' $null }

    # Windows 11 platform protections and security policy indicators.
    Add-RegistryResult 'VBS configured' 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' 'EnableVirtualizationBasedSecurity'
    Add-RegistryResult 'Credential Guard configured' 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'LsaCfgFlags'
    Add-RegistryResult 'LSA protection (RunAsPPL)' 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RunAsPPL'
    Add-RegistryResult 'UAC EnableLUA' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'EnableLUA'
    Add-RegistryResult 'UAC consent behavior' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'ConsentPromptBehaviorAdmin'
    Add-RegistryResult 'SmartScreen Explorer policy' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' 'SmartScreenEnabled'
    Add-RegistryResult 'AutoRun policy' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoDriveTypeAutoRun'
    Add-RegistryResult 'RDP deny connections policy' 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections'

    try {
        if (Test-CommandAvailable 'Get-CimInstance') {
            $cs = Get-CimInstance -ClassName Win32_ComputerSystem
            Add-Result 'PlatformSecurity' 'Hypervisor present' 'INFO' $cs.HypervisorPresent 'A present hypervisor does not by itself prove VBS or Memory Integrity is enabled.'
        }
    } catch { Add-Result 'PlatformSecurity' 'Hypervisor status' 'ERROR' $null $_.Exception.Message }

    try {
        if (Test-CommandAvailable 'Confirm-SecureBootUEFI') {
            $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop
            Add-Result 'PlatformSecurity' 'Secure Boot' $(if ($secureBoot) { 'PASS' } else { 'REVIEW' }) $secureBoot
        }
    } catch {
        Add-Result 'PlatformSecurity' 'Secure Boot' 'UNAVAILABLE' $null 'May be unavailable on legacy BIOS, unsupported firmware, or restricted sessions.'
    }

    try {
        if (Test-CommandAvailable 'Get-Tpm') {
            $tpm = Get-Tpm
            Add-Result 'PlatformSecurity' 'TPM present' $(if ($tpm.TpmPresent) { 'PASS' } else { 'REVIEW' }) $tpm.TpmPresent
            Add-Result 'PlatformSecurity' 'TPM ready' $(if ($tpm.TpmReady) { 'PASS' } else { 'REVIEW' }) $tpm.TpmReady
            Add-Result 'PlatformSecurity' 'TPM enabled' 'INFO' $tpm.TpmEnabled
        }
    } catch { Add-Result 'PlatformSecurity' 'TPM inventory' 'ERROR' $null $_.Exception.Message }

    try {
        $dg = Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction Stop
        Add-Result 'PlatformSecurity' 'Device Guard security services configured' 'INFO' ($dg.SecurityServicesConfigured -join ',')
        Add-Result 'PlatformSecurity' 'Device Guard security services running' 'INFO' ($dg.SecurityServicesRunning -join ',')
        Add-Result 'PlatformSecurity' 'Virtualization-based security status (0=off, 1=configured, 2=running)' 'INFO' $dg.VirtualizationBasedSecurityStatus
        Add-Result 'PlatformSecurity' 'Available security properties' 'INFO' ($dg.AvailableSecurityProperties -join ',')
    } catch { Add-Result 'PlatformSecurity' 'Device Guard WMI inventory' 'UNAVAILABLE' $null $_.Exception.Message }

    # SMB configuration: record actual platform capabilities; do not assume defaults.
    if (Test-CommandAvailable 'Get-SmbClientConfiguration') {
        try {
            $s = Get-SmbClientConfiguration
            Add-Result 'SMB' 'Client RequireSecuritySignature' 'INFO' $s.RequireSecuritySignature
            Add-Result 'SMB' 'Client EnableSecuritySignature' 'INFO' $s.EnableSecuritySignature
            Add-Result 'SMB' 'Client EnableInsecureGuestLogons' 'INFO' $s.EnableInsecureGuestLogons
            if ($s.PSObject.Properties.Name -contains 'RequireEncryption') {
                Add-Result 'SMB' 'Client RequireEncryption' 'INFO' $s.RequireEncryption
            }
        } catch { Add-Result 'SMB' 'Client configuration' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'SMB' 'Client cmdlets' 'UNAVAILABLE' $null }

    if (Test-CommandAvailable 'Get-SmbServerConfiguration') {
        try {
            $s = Get-SmbServerConfiguration
            Add-Result 'SMB' 'Server EnableSMB1Protocol' 'INFO' $s.EnableSMB1Protocol
            Add-Result 'SMB' 'Server EnableSMB2Protocol' 'INFO' $s.EnableSMB2Protocol
            Add-Result 'SMB' 'Server RequireSecuritySignature' 'INFO' $s.RequireSecuritySignature
            Add-Result 'SMB' 'Server EnableEncryptData' 'INFO' $s.EnableEncryptData
        } catch { Add-Result 'SMB' 'Server configuration' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'SMB' 'Server cmdlets' 'UNAVAILABLE' $null }

    # Service inventory only. No service is started, stopped or reconfigured.
    foreach ($n in @('LanmanServer','LanmanWorkstation','FDResPub','fdPHost','SSDPSRV','upnphost','WlanSvc','DoSvc','Spooler','SharedAccess','vmcompute','vmms','WslService','Sense','WinDefend','wscsvc','RemoteRegistry','TermService')) {
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
        } catch { Add-Result 'Storage' 'Inventory' 'ERROR' $null $_.Exception.Message }
    } else {
        Add-Result 'Storage' 'BitLocker cmdlets' 'UNAVAILABLE' $null 'Availability depends on edition, hardware and optional management components.'
    }

    if (Test-CommandAvailable 'Get-DOConfig') {
        try {
            $d = Get-DOConfig
            Add-Result 'DeliveryOptimization' 'DownloadMode' 'INFO' $d.DODownloadMode
        } catch { Add-Result 'DeliveryOptimization' 'Configuration query' 'ERROR' $null $_.Exception.Message }
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
    if (-not (Test-Path -LiteralPath $Directory)) {
        New-Item -Path $Directory -ItemType Directory -Force | Out-Null
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $base = 'Win11-Hardening-Audit-' + $stamp
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
    $lines.Add('MyWindowsHardening - Windows 11 Audit')
    $lines.Add(('Computer: {0}' -f $env:COMPUTERNAME))
    $lines.Add(('Generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
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
}

if ($Mode -eq 'Apply' -or $Mode -eq 'Restore') {
    throw ("Mode '{0}' is intentionally unavailable in bootstrap v{1}. This release is read-only; no system changes were made." -f $Mode,$script:ScriptVersion)
}

try {
    Invoke-ReadOnlyAudit
    Save-AuditReport -Directory $OutputDirectory
    $unsupported = @($script:Results | Where-Object { $_.Category -eq 'Compatibility' -and $_.Status -eq 'FAIL' }).Count -gt 0
    if ($unsupported) {
        Write-Warning 'System is outside the supported Windows 11 client scope.'
        exit 2
    }
    exit 0
} catch {
    Write-Error ("Audit failed: {0}" -f $_.Exception.Message)
    exit 1
}
) { $servicingEnd = [datetime]'2027-10-12'; $servicingBasis = '24H2 Enterprise/Education' }
                elseif ($edition -match '^(Core|CoreN|Professional|ProfessionalN|ProfessionalWorkstation|ProfessionalEducation)
    } catch {
        Add-Result 'System' 'Operating system inventory' 'ERROR' $null $_.Exception.Message
    }

    Add-Result 'Execution' 'Administrator session' 'INFO' (Test-IsAdministrator) 'Elevation is not required for this read-only audit.'

    # Windows Defender Firewall
    if (Test-CommandAvailable 'Get-NetFirewallProfile') {
        try {
            foreach ($p in (Get-NetFirewallProfile -PolicyStore ActiveStore)) {
                $status = if ($p.Enabled) { 'PASS' } else { 'REVIEW' }
                Add-Result 'Firewall' ($p.Name + ' enabled') $status $p.Enabled
                Add-Result 'Firewall' ($p.Name + ' inbound default') 'INFO' $p.DefaultInboundAction
                Add-Result 'Firewall' ($p.Name + ' outbound default') 'INFO' $p.DefaultOutboundAction
                Add-Result 'Firewall' ($p.Name + ' blocked logging') 'INFO' $p.LogBlocked
            }
        } catch { Add-Result 'Firewall' 'Profile inventory' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'Firewall' 'NetSecurity cmdlets' 'UNAVAILABLE' $null }

    # Microsoft Defender
    if (Test-CommandAvailable 'Get-MpComputerStatus') {
        try {
            $mp = Get-MpComputerStatus
            $checks = @(
                @{Name='Antivirus enabled';Value=$mp.AntivirusEnabled},
                @{Name='Real-time protection';Value=$mp.RealTimeProtectionEnabled},
                @{Name='Behavior monitoring';Value=$mp.BehaviorMonitorEnabled},
                @{Name='IOAV protection';Value=$mp.IoavProtectionEnabled},
                @{Name='Network inspection';Value=$mp.NISEnabled},
                @{Name='Tamper protection';Value=$mp.IsTamperProtected},
                @{Name='Antivirus signatures age (days)';Value=$mp.AntivirusSignatureAge}
            )
            foreach ($c in $checks) {
                $status = if ($c.Value -eq $true) { 'PASS' } elseif ($c.Value -eq $false) { 'REVIEW' } else { 'INFO' }
                if ($c.Name -like '*age*') { $status = if ([int]$c.Value -le 3) { 'PASS' } else { 'REVIEW' } }
                Add-Result 'Defender' $c.Name $status $c.Value
            }
        } catch { Add-Result 'Defender' 'Status' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'Defender' 'Defender cmdlets' 'UNAVAILABLE' $null }

    # Windows 11 platform protections and security policy indicators.
    Add-RegistryResult 'VBS configured' 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' 'EnableVirtualizationBasedSecurity'
    Add-RegistryResult 'Credential Guard configured' 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'LsaCfgFlags'
    Add-RegistryResult 'LSA protection (RunAsPPL)' 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RunAsPPL'
    Add-RegistryResult 'UAC EnableLUA' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'EnableLUA'
    Add-RegistryResult 'UAC consent behavior' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'ConsentPromptBehaviorAdmin'
    Add-RegistryResult 'SmartScreen Explorer policy' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' 'SmartScreenEnabled'
    Add-RegistryResult 'AutoRun policy' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoDriveTypeAutoRun'
    Add-RegistryResult 'RDP deny connections policy' 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections'

    try {
        if (Test-CommandAvailable 'Get-CimInstance') {
            $cs = Get-CimInstance -ClassName Win32_ComputerSystem
            Add-Result 'PlatformSecurity' 'Hypervisor present' 'INFO' $cs.HypervisorPresent 'A present hypervisor does not by itself prove VBS or Memory Integrity is enabled.'
        }
    } catch { Add-Result 'PlatformSecurity' 'Hypervisor status' 'ERROR' $null $_.Exception.Message }

    try {
        if (Test-CommandAvailable 'Confirm-SecureBootUEFI') {
            $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop
            Add-Result 'PlatformSecurity' 'Secure Boot' $(if ($secureBoot) { 'PASS' } else { 'REVIEW' }) $secureBoot
        }
    } catch {
        Add-Result 'PlatformSecurity' 'Secure Boot' 'UNAVAILABLE' $null 'May be unavailable on legacy BIOS, unsupported firmware, or restricted sessions.'
    }

    try {
        if (Test-CommandAvailable 'Get-Tpm') {
            $tpm = Get-Tpm
            Add-Result 'PlatformSecurity' 'TPM present' $(if ($tpm.TpmPresent) { 'PASS' } else { 'REVIEW' }) $tpm.TpmPresent
            Add-Result 'PlatformSecurity' 'TPM ready' $(if ($tpm.TpmReady) { 'PASS' } else { 'REVIEW' }) $tpm.TpmReady
            Add-Result 'PlatformSecurity' 'TPM enabled' 'INFO' $tpm.TpmEnabled
        }
    } catch { Add-Result 'PlatformSecurity' 'TPM inventory' 'ERROR' $null $_.Exception.Message }

    try {
        $dg = Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction Stop
        Add-Result 'PlatformSecurity' 'Device Guard security services configured' 'INFO' ($dg.SecurityServicesConfigured -join ',')
        Add-Result 'PlatformSecurity' 'Device Guard security services running' 'INFO' ($dg.SecurityServicesRunning -join ',')
        Add-Result 'PlatformSecurity' 'Virtualization-based security status (0=off, 1=configured, 2=running)' 'INFO' $dg.VirtualizationBasedSecurityStatus
        Add-Result 'PlatformSecurity' 'Available security properties' 'INFO' ($dg.AvailableSecurityProperties -join ',')
    } catch { Add-Result 'PlatformSecurity' 'Device Guard WMI inventory' 'UNAVAILABLE' $null $_.Exception.Message }

    # SMB configuration: record actual platform capabilities; do not assume defaults.
    if (Test-CommandAvailable 'Get-SmbClientConfiguration') {
        try {
            $s = Get-SmbClientConfiguration
            Add-Result 'SMB' 'Client RequireSecuritySignature' 'INFO' $s.RequireSecuritySignature
            Add-Result 'SMB' 'Client EnableSecuritySignature' 'INFO' $s.EnableSecuritySignature
            Add-Result 'SMB' 'Client EnableInsecureGuestLogons' 'INFO' $s.EnableInsecureGuestLogons
            if ($s.PSObject.Properties.Name -contains 'RequireEncryption') {
                Add-Result 'SMB' 'Client RequireEncryption' 'INFO' $s.RequireEncryption
            }
        } catch { Add-Result 'SMB' 'Client configuration' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'SMB' 'Client cmdlets' 'UNAVAILABLE' $null }

    if (Test-CommandAvailable 'Get-SmbServerConfiguration') {
        try {
            $s = Get-SmbServerConfiguration
            Add-Result 'SMB' 'Server EnableSMB1Protocol' 'INFO' $s.EnableSMB1Protocol
            Add-Result 'SMB' 'Server EnableSMB2Protocol' 'INFO' $s.EnableSMB2Protocol
            Add-Result 'SMB' 'Server RequireSecuritySignature' 'INFO' $s.RequireSecuritySignature
            Add-Result 'SMB' 'Server EnableEncryptData' 'INFO' $s.EnableEncryptData
        } catch { Add-Result 'SMB' 'Server configuration' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'SMB' 'Server cmdlets' 'UNAVAILABLE' $null }

    # Service inventory only. No service is started, stopped or reconfigured.
    foreach ($n in @('LanmanServer','LanmanWorkstation','FDResPub','fdPHost','SSDPSRV','upnphost','WlanSvc','DoSvc','Spooler','SharedAccess','vmcompute','vmms','WslService','Sense','WinDefend','wscsvc','RemoteRegistry','TermService')) {
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
        } catch { Add-Result 'Storage' 'Inventory' 'ERROR' $null $_.Exception.Message }
    } else {
        Add-Result 'Storage' 'BitLocker cmdlets' 'UNAVAILABLE' $null 'Availability depends on edition, hardware and optional management components.'
    }

    if (Test-CommandAvailable 'Get-DOConfig') {
        try {
            $d = Get-DOConfig
            Add-Result 'DeliveryOptimization' 'DownloadMode' 'INFO' $d.DODownloadMode
        } catch { Add-Result 'DeliveryOptimization' 'Configuration query' 'ERROR' $null $_.Exception.Message }
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
    if (-not (Test-Path -LiteralPath $Directory)) {
        New-Item -Path $Directory -ItemType Directory -Force | Out-Null
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $base = 'Win11-Hardening-Audit-' + $stamp
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
    $lines.Add('MyWindowsHardening - Windows 11 Audit')
    $lines.Add(('Computer: {0}' -f $env:COMPUTERNAME))
    $lines.Add(('Generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
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
}

if ($Mode -eq 'Apply' -or $Mode -eq 'Restore') {
    throw ("Mode '{0}' is intentionally unavailable in bootstrap v{1}. This release is read-only; no system changes were made." -f $Mode,$script:ScriptVersion)
}

try {
    Invoke-ReadOnlyAudit
    Save-AuditReport -Directory $OutputDirectory
    $unsupported = @($script:Results | Where-Object { $_.Category -eq 'Compatibility' -and $_.Status -eq 'FAIL' }).Count -gt 0
    if ($unsupported) {
        Write-Warning 'System is outside the supported Windows 11 client scope.'
        exit 2
    }
    exit 0
} catch {
    Write-Error ("Audit failed: {0}" -f $_.Exception.Message)
    exit 1
}
) { $servicingEnd = [datetime]'2026-10-13'; $servicingBasis = '24H2 Home/Pro family' }
            }
            '25H2' {
                if ($edition -match '^(Enterprise|Education)
    } catch {
        Add-Result 'System' 'Operating system inventory' 'ERROR' $null $_.Exception.Message
    }

    Add-Result 'Execution' 'Administrator session' 'INFO' (Test-IsAdministrator) 'Elevation is not required for this read-only audit.'

    # Windows Defender Firewall
    if (Test-CommandAvailable 'Get-NetFirewallProfile') {
        try {
            foreach ($p in (Get-NetFirewallProfile -PolicyStore ActiveStore)) {
                $status = if ($p.Enabled) { 'PASS' } else { 'REVIEW' }
                Add-Result 'Firewall' ($p.Name + ' enabled') $status $p.Enabled
                Add-Result 'Firewall' ($p.Name + ' inbound default') 'INFO' $p.DefaultInboundAction
                Add-Result 'Firewall' ($p.Name + ' outbound default') 'INFO' $p.DefaultOutboundAction
                Add-Result 'Firewall' ($p.Name + ' blocked logging') 'INFO' $p.LogBlocked
            }
        } catch { Add-Result 'Firewall' 'Profile inventory' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'Firewall' 'NetSecurity cmdlets' 'UNAVAILABLE' $null }

    # Microsoft Defender
    if (Test-CommandAvailable 'Get-MpComputerStatus') {
        try {
            $mp = Get-MpComputerStatus
            $checks = @(
                @{Name='Antivirus enabled';Value=$mp.AntivirusEnabled},
                @{Name='Real-time protection';Value=$mp.RealTimeProtectionEnabled},
                @{Name='Behavior monitoring';Value=$mp.BehaviorMonitorEnabled},
                @{Name='IOAV protection';Value=$mp.IoavProtectionEnabled},
                @{Name='Network inspection';Value=$mp.NISEnabled},
                @{Name='Tamper protection';Value=$mp.IsTamperProtected},
                @{Name='Antivirus signatures age (days)';Value=$mp.AntivirusSignatureAge}
            )
            foreach ($c in $checks) {
                $status = if ($c.Value -eq $true) { 'PASS' } elseif ($c.Value -eq $false) { 'REVIEW' } else { 'INFO' }
                if ($c.Name -like '*age*') { $status = if ([int]$c.Value -le 3) { 'PASS' } else { 'REVIEW' } }
                Add-Result 'Defender' $c.Name $status $c.Value
            }
        } catch { Add-Result 'Defender' 'Status' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'Defender' 'Defender cmdlets' 'UNAVAILABLE' $null }

    # Windows 11 platform protections and security policy indicators.
    Add-RegistryResult 'VBS configured' 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' 'EnableVirtualizationBasedSecurity'
    Add-RegistryResult 'Credential Guard configured' 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'LsaCfgFlags'
    Add-RegistryResult 'LSA protection (RunAsPPL)' 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RunAsPPL'
    Add-RegistryResult 'UAC EnableLUA' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'EnableLUA'
    Add-RegistryResult 'UAC consent behavior' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'ConsentPromptBehaviorAdmin'
    Add-RegistryResult 'SmartScreen Explorer policy' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' 'SmartScreenEnabled'
    Add-RegistryResult 'AutoRun policy' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoDriveTypeAutoRun'
    Add-RegistryResult 'RDP deny connections policy' 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections'

    try {
        if (Test-CommandAvailable 'Get-CimInstance') {
            $cs = Get-CimInstance -ClassName Win32_ComputerSystem
            Add-Result 'PlatformSecurity' 'Hypervisor present' 'INFO' $cs.HypervisorPresent 'A present hypervisor does not by itself prove VBS or Memory Integrity is enabled.'
        }
    } catch { Add-Result 'PlatformSecurity' 'Hypervisor status' 'ERROR' $null $_.Exception.Message }

    try {
        if (Test-CommandAvailable 'Confirm-SecureBootUEFI') {
            $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop
            Add-Result 'PlatformSecurity' 'Secure Boot' $(if ($secureBoot) { 'PASS' } else { 'REVIEW' }) $secureBoot
        }
    } catch {
        Add-Result 'PlatformSecurity' 'Secure Boot' 'UNAVAILABLE' $null 'May be unavailable on legacy BIOS, unsupported firmware, or restricted sessions.'
    }

    try {
        if (Test-CommandAvailable 'Get-Tpm') {
            $tpm = Get-Tpm
            Add-Result 'PlatformSecurity' 'TPM present' $(if ($tpm.TpmPresent) { 'PASS' } else { 'REVIEW' }) $tpm.TpmPresent
            Add-Result 'PlatformSecurity' 'TPM ready' $(if ($tpm.TpmReady) { 'PASS' } else { 'REVIEW' }) $tpm.TpmReady
            Add-Result 'PlatformSecurity' 'TPM enabled' 'INFO' $tpm.TpmEnabled
        }
    } catch { Add-Result 'PlatformSecurity' 'TPM inventory' 'ERROR' $null $_.Exception.Message }

    try {
        $dg = Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction Stop
        Add-Result 'PlatformSecurity' 'Device Guard security services configured' 'INFO' ($dg.SecurityServicesConfigured -join ',')
        Add-Result 'PlatformSecurity' 'Device Guard security services running' 'INFO' ($dg.SecurityServicesRunning -join ',')
        Add-Result 'PlatformSecurity' 'Virtualization-based security status (0=off, 1=configured, 2=running)' 'INFO' $dg.VirtualizationBasedSecurityStatus
        Add-Result 'PlatformSecurity' 'Available security properties' 'INFO' ($dg.AvailableSecurityProperties -join ',')
    } catch { Add-Result 'PlatformSecurity' 'Device Guard WMI inventory' 'UNAVAILABLE' $null $_.Exception.Message }

    # SMB configuration: record actual platform capabilities; do not assume defaults.
    if (Test-CommandAvailable 'Get-SmbClientConfiguration') {
        try {
            $s = Get-SmbClientConfiguration
            Add-Result 'SMB' 'Client RequireSecuritySignature' 'INFO' $s.RequireSecuritySignature
            Add-Result 'SMB' 'Client EnableSecuritySignature' 'INFO' $s.EnableSecuritySignature
            Add-Result 'SMB' 'Client EnableInsecureGuestLogons' 'INFO' $s.EnableInsecureGuestLogons
            if ($s.PSObject.Properties.Name -contains 'RequireEncryption') {
                Add-Result 'SMB' 'Client RequireEncryption' 'INFO' $s.RequireEncryption
            }
        } catch { Add-Result 'SMB' 'Client configuration' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'SMB' 'Client cmdlets' 'UNAVAILABLE' $null }

    if (Test-CommandAvailable 'Get-SmbServerConfiguration') {
        try {
            $s = Get-SmbServerConfiguration
            Add-Result 'SMB' 'Server EnableSMB1Protocol' 'INFO' $s.EnableSMB1Protocol
            Add-Result 'SMB' 'Server EnableSMB2Protocol' 'INFO' $s.EnableSMB2Protocol
            Add-Result 'SMB' 'Server RequireSecuritySignature' 'INFO' $s.RequireSecuritySignature
            Add-Result 'SMB' 'Server EnableEncryptData' 'INFO' $s.EnableEncryptData
        } catch { Add-Result 'SMB' 'Server configuration' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'SMB' 'Server cmdlets' 'UNAVAILABLE' $null }

    # Service inventory only. No service is started, stopped or reconfigured.
    foreach ($n in @('LanmanServer','LanmanWorkstation','FDResPub','fdPHost','SSDPSRV','upnphost','WlanSvc','DoSvc','Spooler','SharedAccess','vmcompute','vmms','WslService','Sense','WinDefend','wscsvc','RemoteRegistry','TermService')) {
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
        } catch { Add-Result 'Storage' 'Inventory' 'ERROR' $null $_.Exception.Message }
    } else {
        Add-Result 'Storage' 'BitLocker cmdlets' 'UNAVAILABLE' $null 'Availability depends on edition, hardware and optional management components.'
    }

    if (Test-CommandAvailable 'Get-DOConfig') {
        try {
            $d = Get-DOConfig
            Add-Result 'DeliveryOptimization' 'DownloadMode' 'INFO' $d.DODownloadMode
        } catch { Add-Result 'DeliveryOptimization' 'Configuration query' 'ERROR' $null $_.Exception.Message }
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
    if (-not (Test-Path -LiteralPath $Directory)) {
        New-Item -Path $Directory -ItemType Directory -Force | Out-Null
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $base = 'Win11-Hardening-Audit-' + $stamp
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
    $lines.Add('MyWindowsHardening - Windows 11 Audit')
    $lines.Add(('Computer: {0}' -f $env:COMPUTERNAME))
    $lines.Add(('Generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
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
}

if ($Mode -eq 'Apply' -or $Mode -eq 'Restore') {
    throw ("Mode '{0}' is intentionally unavailable in bootstrap v{1}. This release is read-only; no system changes were made." -f $Mode,$script:ScriptVersion)
}

try {
    Invoke-ReadOnlyAudit
    Save-AuditReport -Directory $OutputDirectory
    $unsupported = @($script:Results | Where-Object { $_.Category -eq 'Compatibility' -and $_.Status -eq 'FAIL' }).Count -gt 0
    if ($unsupported) {
        Write-Warning 'System is outside the supported Windows 11 client scope.'
        exit 2
    }
    exit 0
} catch {
    Write-Error ("Audit failed: {0}" -f $_.Exception.Message)
    exit 1
}
) { $servicingEnd = [datetime]'2028-10-10'; $servicingBasis = '25H2 Enterprise/Education' }
                elseif ($edition -match '^(Core|CoreN|Professional|ProfessionalN|ProfessionalWorkstation|ProfessionalEducation)
    } catch {
        Add-Result 'System' 'Operating system inventory' 'ERROR' $null $_.Exception.Message
    }

    Add-Result 'Execution' 'Administrator session' 'INFO' (Test-IsAdministrator) 'Elevation is not required for this read-only audit.'

    # Windows Defender Firewall
    if (Test-CommandAvailable 'Get-NetFirewallProfile') {
        try {
            foreach ($p in (Get-NetFirewallProfile -PolicyStore ActiveStore)) {
                $status = if ($p.Enabled) { 'PASS' } else { 'REVIEW' }
                Add-Result 'Firewall' ($p.Name + ' enabled') $status $p.Enabled
                Add-Result 'Firewall' ($p.Name + ' inbound default') 'INFO' $p.DefaultInboundAction
                Add-Result 'Firewall' ($p.Name + ' outbound default') 'INFO' $p.DefaultOutboundAction
                Add-Result 'Firewall' ($p.Name + ' blocked logging') 'INFO' $p.LogBlocked
            }
        } catch { Add-Result 'Firewall' 'Profile inventory' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'Firewall' 'NetSecurity cmdlets' 'UNAVAILABLE' $null }

    # Microsoft Defender
    if (Test-CommandAvailable 'Get-MpComputerStatus') {
        try {
            $mp = Get-MpComputerStatus
            $checks = @(
                @{Name='Antivirus enabled';Value=$mp.AntivirusEnabled},
                @{Name='Real-time protection';Value=$mp.RealTimeProtectionEnabled},
                @{Name='Behavior monitoring';Value=$mp.BehaviorMonitorEnabled},
                @{Name='IOAV protection';Value=$mp.IoavProtectionEnabled},
                @{Name='Network inspection';Value=$mp.NISEnabled},
                @{Name='Tamper protection';Value=$mp.IsTamperProtected},
                @{Name='Antivirus signatures age (days)';Value=$mp.AntivirusSignatureAge}
            )
            foreach ($c in $checks) {
                $status = if ($c.Value -eq $true) { 'PASS' } elseif ($c.Value -eq $false) { 'REVIEW' } else { 'INFO' }
                if ($c.Name -like '*age*') { $status = if ([int]$c.Value -le 3) { 'PASS' } else { 'REVIEW' } }
                Add-Result 'Defender' $c.Name $status $c.Value
            }
        } catch { Add-Result 'Defender' 'Status' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'Defender' 'Defender cmdlets' 'UNAVAILABLE' $null }

    # Windows 11 platform protections and security policy indicators.
    Add-RegistryResult 'VBS configured' 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' 'EnableVirtualizationBasedSecurity'
    Add-RegistryResult 'Credential Guard configured' 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'LsaCfgFlags'
    Add-RegistryResult 'LSA protection (RunAsPPL)' 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RunAsPPL'
    Add-RegistryResult 'UAC EnableLUA' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'EnableLUA'
    Add-RegistryResult 'UAC consent behavior' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'ConsentPromptBehaviorAdmin'
    Add-RegistryResult 'SmartScreen Explorer policy' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' 'SmartScreenEnabled'
    Add-RegistryResult 'AutoRun policy' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoDriveTypeAutoRun'
    Add-RegistryResult 'RDP deny connections policy' 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections'

    try {
        if (Test-CommandAvailable 'Get-CimInstance') {
            $cs = Get-CimInstance -ClassName Win32_ComputerSystem
            Add-Result 'PlatformSecurity' 'Hypervisor present' 'INFO' $cs.HypervisorPresent 'A present hypervisor does not by itself prove VBS or Memory Integrity is enabled.'
        }
    } catch { Add-Result 'PlatformSecurity' 'Hypervisor status' 'ERROR' $null $_.Exception.Message }

    try {
        if (Test-CommandAvailable 'Confirm-SecureBootUEFI') {
            $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop
            Add-Result 'PlatformSecurity' 'Secure Boot' $(if ($secureBoot) { 'PASS' } else { 'REVIEW' }) $secureBoot
        }
    } catch {
        Add-Result 'PlatformSecurity' 'Secure Boot' 'UNAVAILABLE' $null 'May be unavailable on legacy BIOS, unsupported firmware, or restricted sessions.'
    }

    try {
        if (Test-CommandAvailable 'Get-Tpm') {
            $tpm = Get-Tpm
            Add-Result 'PlatformSecurity' 'TPM present' $(if ($tpm.TpmPresent) { 'PASS' } else { 'REVIEW' }) $tpm.TpmPresent
            Add-Result 'PlatformSecurity' 'TPM ready' $(if ($tpm.TpmReady) { 'PASS' } else { 'REVIEW' }) $tpm.TpmReady
            Add-Result 'PlatformSecurity' 'TPM enabled' 'INFO' $tpm.TpmEnabled
        }
    } catch { Add-Result 'PlatformSecurity' 'TPM inventory' 'ERROR' $null $_.Exception.Message }

    try {
        $dg = Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction Stop
        Add-Result 'PlatformSecurity' 'Device Guard security services configured' 'INFO' ($dg.SecurityServicesConfigured -join ',')
        Add-Result 'PlatformSecurity' 'Device Guard security services running' 'INFO' ($dg.SecurityServicesRunning -join ',')
        Add-Result 'PlatformSecurity' 'Virtualization-based security status (0=off, 1=configured, 2=running)' 'INFO' $dg.VirtualizationBasedSecurityStatus
        Add-Result 'PlatformSecurity' 'Available security properties' 'INFO' ($dg.AvailableSecurityProperties -join ',')
    } catch { Add-Result 'PlatformSecurity' 'Device Guard WMI inventory' 'UNAVAILABLE' $null $_.Exception.Message }

    # SMB configuration: record actual platform capabilities; do not assume defaults.
    if (Test-CommandAvailable 'Get-SmbClientConfiguration') {
        try {
            $s = Get-SmbClientConfiguration
            Add-Result 'SMB' 'Client RequireSecuritySignature' 'INFO' $s.RequireSecuritySignature
            Add-Result 'SMB' 'Client EnableSecuritySignature' 'INFO' $s.EnableSecuritySignature
            Add-Result 'SMB' 'Client EnableInsecureGuestLogons' 'INFO' $s.EnableInsecureGuestLogons
            if ($s.PSObject.Properties.Name -contains 'RequireEncryption') {
                Add-Result 'SMB' 'Client RequireEncryption' 'INFO' $s.RequireEncryption
            }
        } catch { Add-Result 'SMB' 'Client configuration' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'SMB' 'Client cmdlets' 'UNAVAILABLE' $null }

    if (Test-CommandAvailable 'Get-SmbServerConfiguration') {
        try {
            $s = Get-SmbServerConfiguration
            Add-Result 'SMB' 'Server EnableSMB1Protocol' 'INFO' $s.EnableSMB1Protocol
            Add-Result 'SMB' 'Server EnableSMB2Protocol' 'INFO' $s.EnableSMB2Protocol
            Add-Result 'SMB' 'Server RequireSecuritySignature' 'INFO' $s.RequireSecuritySignature
            Add-Result 'SMB' 'Server EnableEncryptData' 'INFO' $s.EnableEncryptData
        } catch { Add-Result 'SMB' 'Server configuration' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'SMB' 'Server cmdlets' 'UNAVAILABLE' $null }

    # Service inventory only. No service is started, stopped or reconfigured.
    foreach ($n in @('LanmanServer','LanmanWorkstation','FDResPub','fdPHost','SSDPSRV','upnphost','WlanSvc','DoSvc','Spooler','SharedAccess','vmcompute','vmms','WslService','Sense','WinDefend','wscsvc','RemoteRegistry','TermService')) {
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
        } catch { Add-Result 'Storage' 'Inventory' 'ERROR' $null $_.Exception.Message }
    } else {
        Add-Result 'Storage' 'BitLocker cmdlets' 'UNAVAILABLE' $null 'Availability depends on edition, hardware and optional management components.'
    }

    if (Test-CommandAvailable 'Get-DOConfig') {
        try {
            $d = Get-DOConfig
            Add-Result 'DeliveryOptimization' 'DownloadMode' 'INFO' $d.DODownloadMode
        } catch { Add-Result 'DeliveryOptimization' 'Configuration query' 'ERROR' $null $_.Exception.Message }
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
    if (-not (Test-Path -LiteralPath $Directory)) {
        New-Item -Path $Directory -ItemType Directory -Force | Out-Null
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $base = 'Win11-Hardening-Audit-' + $stamp
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
    $lines.Add('MyWindowsHardening - Windows 11 Audit')
    $lines.Add(('Computer: {0}' -f $env:COMPUTERNAME))
    $lines.Add(('Generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
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
}

if ($Mode -eq 'Apply' -or $Mode -eq 'Restore') {
    throw ("Mode '{0}' is intentionally unavailable in bootstrap v{1}. This release is read-only; no system changes were made." -f $Mode,$script:ScriptVersion)
}

try {
    Invoke-ReadOnlyAudit
    Save-AuditReport -Directory $OutputDirectory
    $unsupported = @($script:Results | Where-Object { $_.Category -eq 'Compatibility' -and $_.Status -eq 'FAIL' }).Count -gt 0
    if ($unsupported) {
        Write-Warning 'System is outside the supported Windows 11 client scope.'
        exit 2
    }
    exit 0
} catch {
    Write-Error ("Audit failed: {0}" -f $_.Exception.Message)
    exit 1
}
) { $servicingEnd = [datetime]'2027-10-12'; $servicingBasis = '25H2 Home/Pro family' }
            }
            '26H1' {
                if ($edition -match '^(Enterprise|Education)
    } catch {
        Add-Result 'System' 'Operating system inventory' 'ERROR' $null $_.Exception.Message
    }

    Add-Result 'Execution' 'Administrator session' 'INFO' (Test-IsAdministrator) 'Elevation is not required for this read-only audit.'

    # Windows Defender Firewall
    if (Test-CommandAvailable 'Get-NetFirewallProfile') {
        try {
            foreach ($p in (Get-NetFirewallProfile -PolicyStore ActiveStore)) {
                $status = if ($p.Enabled) { 'PASS' } else { 'REVIEW' }
                Add-Result 'Firewall' ($p.Name + ' enabled') $status $p.Enabled
                Add-Result 'Firewall' ($p.Name + ' inbound default') 'INFO' $p.DefaultInboundAction
                Add-Result 'Firewall' ($p.Name + ' outbound default') 'INFO' $p.DefaultOutboundAction
                Add-Result 'Firewall' ($p.Name + ' blocked logging') 'INFO' $p.LogBlocked
            }
        } catch { Add-Result 'Firewall' 'Profile inventory' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'Firewall' 'NetSecurity cmdlets' 'UNAVAILABLE' $null }

    # Microsoft Defender
    if (Test-CommandAvailable 'Get-MpComputerStatus') {
        try {
            $mp = Get-MpComputerStatus
            $checks = @(
                @{Name='Antivirus enabled';Value=$mp.AntivirusEnabled},
                @{Name='Real-time protection';Value=$mp.RealTimeProtectionEnabled},
                @{Name='Behavior monitoring';Value=$mp.BehaviorMonitorEnabled},
                @{Name='IOAV protection';Value=$mp.IoavProtectionEnabled},
                @{Name='Network inspection';Value=$mp.NISEnabled},
                @{Name='Tamper protection';Value=$mp.IsTamperProtected},
                @{Name='Antivirus signatures age (days)';Value=$mp.AntivirusSignatureAge}
            )
            foreach ($c in $checks) {
                $status = if ($c.Value -eq $true) { 'PASS' } elseif ($c.Value -eq $false) { 'REVIEW' } else { 'INFO' }
                if ($c.Name -like '*age*') { $status = if ([int]$c.Value -le 3) { 'PASS' } else { 'REVIEW' } }
                Add-Result 'Defender' $c.Name $status $c.Value
            }
        } catch { Add-Result 'Defender' 'Status' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'Defender' 'Defender cmdlets' 'UNAVAILABLE' $null }

    # Windows 11 platform protections and security policy indicators.
    Add-RegistryResult 'VBS configured' 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' 'EnableVirtualizationBasedSecurity'
    Add-RegistryResult 'Credential Guard configured' 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'LsaCfgFlags'
    Add-RegistryResult 'LSA protection (RunAsPPL)' 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RunAsPPL'
    Add-RegistryResult 'UAC EnableLUA' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'EnableLUA'
    Add-RegistryResult 'UAC consent behavior' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'ConsentPromptBehaviorAdmin'
    Add-RegistryResult 'SmartScreen Explorer policy' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' 'SmartScreenEnabled'
    Add-RegistryResult 'AutoRun policy' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoDriveTypeAutoRun'
    Add-RegistryResult 'RDP deny connections policy' 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections'

    try {
        if (Test-CommandAvailable 'Get-CimInstance') {
            $cs = Get-CimInstance -ClassName Win32_ComputerSystem
            Add-Result 'PlatformSecurity' 'Hypervisor present' 'INFO' $cs.HypervisorPresent 'A present hypervisor does not by itself prove VBS or Memory Integrity is enabled.'
        }
    } catch { Add-Result 'PlatformSecurity' 'Hypervisor status' 'ERROR' $null $_.Exception.Message }

    try {
        if (Test-CommandAvailable 'Confirm-SecureBootUEFI') {
            $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop
            Add-Result 'PlatformSecurity' 'Secure Boot' $(if ($secureBoot) { 'PASS' } else { 'REVIEW' }) $secureBoot
        }
    } catch {
        Add-Result 'PlatformSecurity' 'Secure Boot' 'UNAVAILABLE' $null 'May be unavailable on legacy BIOS, unsupported firmware, or restricted sessions.'
    }

    try {
        if (Test-CommandAvailable 'Get-Tpm') {
            $tpm = Get-Tpm
            Add-Result 'PlatformSecurity' 'TPM present' $(if ($tpm.TpmPresent) { 'PASS' } else { 'REVIEW' }) $tpm.TpmPresent
            Add-Result 'PlatformSecurity' 'TPM ready' $(if ($tpm.TpmReady) { 'PASS' } else { 'REVIEW' }) $tpm.TpmReady
            Add-Result 'PlatformSecurity' 'TPM enabled' 'INFO' $tpm.TpmEnabled
        }
    } catch { Add-Result 'PlatformSecurity' 'TPM inventory' 'ERROR' $null $_.Exception.Message }

    try {
        $dg = Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction Stop
        Add-Result 'PlatformSecurity' 'Device Guard security services configured' 'INFO' ($dg.SecurityServicesConfigured -join ',')
        Add-Result 'PlatformSecurity' 'Device Guard security services running' 'INFO' ($dg.SecurityServicesRunning -join ',')
        Add-Result 'PlatformSecurity' 'Virtualization-based security status (0=off, 1=configured, 2=running)' 'INFO' $dg.VirtualizationBasedSecurityStatus
        Add-Result 'PlatformSecurity' 'Available security properties' 'INFO' ($dg.AvailableSecurityProperties -join ',')
    } catch { Add-Result 'PlatformSecurity' 'Device Guard WMI inventory' 'UNAVAILABLE' $null $_.Exception.Message }

    # SMB configuration: record actual platform capabilities; do not assume defaults.
    if (Test-CommandAvailable 'Get-SmbClientConfiguration') {
        try {
            $s = Get-SmbClientConfiguration
            Add-Result 'SMB' 'Client RequireSecuritySignature' 'INFO' $s.RequireSecuritySignature
            Add-Result 'SMB' 'Client EnableSecuritySignature' 'INFO' $s.EnableSecuritySignature
            Add-Result 'SMB' 'Client EnableInsecureGuestLogons' 'INFO' $s.EnableInsecureGuestLogons
            if ($s.PSObject.Properties.Name -contains 'RequireEncryption') {
                Add-Result 'SMB' 'Client RequireEncryption' 'INFO' $s.RequireEncryption
            }
        } catch { Add-Result 'SMB' 'Client configuration' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'SMB' 'Client cmdlets' 'UNAVAILABLE' $null }

    if (Test-CommandAvailable 'Get-SmbServerConfiguration') {
        try {
            $s = Get-SmbServerConfiguration
            Add-Result 'SMB' 'Server EnableSMB1Protocol' 'INFO' $s.EnableSMB1Protocol
            Add-Result 'SMB' 'Server EnableSMB2Protocol' 'INFO' $s.EnableSMB2Protocol
            Add-Result 'SMB' 'Server RequireSecuritySignature' 'INFO' $s.RequireSecuritySignature
            Add-Result 'SMB' 'Server EnableEncryptData' 'INFO' $s.EnableEncryptData
        } catch { Add-Result 'SMB' 'Server configuration' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'SMB' 'Server cmdlets' 'UNAVAILABLE' $null }

    # Service inventory only. No service is started, stopped or reconfigured.
    foreach ($n in @('LanmanServer','LanmanWorkstation','FDResPub','fdPHost','SSDPSRV','upnphost','WlanSvc','DoSvc','Spooler','SharedAccess','vmcompute','vmms','WslService','Sense','WinDefend','wscsvc','RemoteRegistry','TermService')) {
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
        } catch { Add-Result 'Storage' 'Inventory' 'ERROR' $null $_.Exception.Message }
    } else {
        Add-Result 'Storage' 'BitLocker cmdlets' 'UNAVAILABLE' $null 'Availability depends on edition, hardware and optional management components.'
    }

    if (Test-CommandAvailable 'Get-DOConfig') {
        try {
            $d = Get-DOConfig
            Add-Result 'DeliveryOptimization' 'DownloadMode' 'INFO' $d.DODownloadMode
        } catch { Add-Result 'DeliveryOptimization' 'Configuration query' 'ERROR' $null $_.Exception.Message }
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
    if (-not (Test-Path -LiteralPath $Directory)) {
        New-Item -Path $Directory -ItemType Directory -Force | Out-Null
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $base = 'Win11-Hardening-Audit-' + $stamp
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
    $lines.Add('MyWindowsHardening - Windows 11 Audit')
    $lines.Add(('Computer: {0}' -f $env:COMPUTERNAME))
    $lines.Add(('Generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
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
}

if ($Mode -eq 'Apply' -or $Mode -eq 'Restore') {
    throw ("Mode '{0}' is intentionally unavailable in bootstrap v{1}. This release is read-only; no system changes were made." -f $Mode,$script:ScriptVersion)
}

try {
    Invoke-ReadOnlyAudit
    Save-AuditReport -Directory $OutputDirectory
    $unsupported = @($script:Results | Where-Object { $_.Category -eq 'Compatibility' -and $_.Status -eq 'FAIL' }).Count -gt 0
    if ($unsupported) {
        Write-Warning 'System is outside the supported Windows 11 client scope.'
        exit 2
    }
    exit 0
} catch {
    Write-Error ("Audit failed: {0}" -f $_.Exception.Message)
    exit 1
}
) { $servicingEnd = [datetime]'2029-03-13'; $servicingBasis = '26H1 Enterprise/Education' }
                elseif ($edition -match '^(Core|CoreN|Professional|ProfessionalN|ProfessionalWorkstation|ProfessionalEducation)
    } catch {
        Add-Result 'System' 'Operating system inventory' 'ERROR' $null $_.Exception.Message
    }

    Add-Result 'Execution' 'Administrator session' 'INFO' (Test-IsAdministrator) 'Elevation is not required for this read-only audit.'

    # Windows Defender Firewall
    if (Test-CommandAvailable 'Get-NetFirewallProfile') {
        try {
            foreach ($p in (Get-NetFirewallProfile -PolicyStore ActiveStore)) {
                $status = if ($p.Enabled) { 'PASS' } else { 'REVIEW' }
                Add-Result 'Firewall' ($p.Name + ' enabled') $status $p.Enabled
                Add-Result 'Firewall' ($p.Name + ' inbound default') 'INFO' $p.DefaultInboundAction
                Add-Result 'Firewall' ($p.Name + ' outbound default') 'INFO' $p.DefaultOutboundAction
                Add-Result 'Firewall' ($p.Name + ' blocked logging') 'INFO' $p.LogBlocked
            }
        } catch { Add-Result 'Firewall' 'Profile inventory' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'Firewall' 'NetSecurity cmdlets' 'UNAVAILABLE' $null }

    # Microsoft Defender
    if (Test-CommandAvailable 'Get-MpComputerStatus') {
        try {
            $mp = Get-MpComputerStatus
            $checks = @(
                @{Name='Antivirus enabled';Value=$mp.AntivirusEnabled},
                @{Name='Real-time protection';Value=$mp.RealTimeProtectionEnabled},
                @{Name='Behavior monitoring';Value=$mp.BehaviorMonitorEnabled},
                @{Name='IOAV protection';Value=$mp.IoavProtectionEnabled},
                @{Name='Network inspection';Value=$mp.NISEnabled},
                @{Name='Tamper protection';Value=$mp.IsTamperProtected},
                @{Name='Antivirus signatures age (days)';Value=$mp.AntivirusSignatureAge}
            )
            foreach ($c in $checks) {
                $status = if ($c.Value -eq $true) { 'PASS' } elseif ($c.Value -eq $false) { 'REVIEW' } else { 'INFO' }
                if ($c.Name -like '*age*') { $status = if ([int]$c.Value -le 3) { 'PASS' } else { 'REVIEW' } }
                Add-Result 'Defender' $c.Name $status $c.Value
            }
        } catch { Add-Result 'Defender' 'Status' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'Defender' 'Defender cmdlets' 'UNAVAILABLE' $null }

    # Windows 11 platform protections and security policy indicators.
    Add-RegistryResult 'VBS configured' 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' 'EnableVirtualizationBasedSecurity'
    Add-RegistryResult 'Credential Guard configured' 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'LsaCfgFlags'
    Add-RegistryResult 'LSA protection (RunAsPPL)' 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RunAsPPL'
    Add-RegistryResult 'UAC EnableLUA' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'EnableLUA'
    Add-RegistryResult 'UAC consent behavior' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'ConsentPromptBehaviorAdmin'
    Add-RegistryResult 'SmartScreen Explorer policy' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' 'SmartScreenEnabled'
    Add-RegistryResult 'AutoRun policy' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoDriveTypeAutoRun'
    Add-RegistryResult 'RDP deny connections policy' 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections'

    try {
        if (Test-CommandAvailable 'Get-CimInstance') {
            $cs = Get-CimInstance -ClassName Win32_ComputerSystem
            Add-Result 'PlatformSecurity' 'Hypervisor present' 'INFO' $cs.HypervisorPresent 'A present hypervisor does not by itself prove VBS or Memory Integrity is enabled.'
        }
    } catch { Add-Result 'PlatformSecurity' 'Hypervisor status' 'ERROR' $null $_.Exception.Message }

    try {
        if (Test-CommandAvailable 'Confirm-SecureBootUEFI') {
            $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop
            Add-Result 'PlatformSecurity' 'Secure Boot' $(if ($secureBoot) { 'PASS' } else { 'REVIEW' }) $secureBoot
        }
    } catch {
        Add-Result 'PlatformSecurity' 'Secure Boot' 'UNAVAILABLE' $null 'May be unavailable on legacy BIOS, unsupported firmware, or restricted sessions.'
    }

    try {
        if (Test-CommandAvailable 'Get-Tpm') {
            $tpm = Get-Tpm
            Add-Result 'PlatformSecurity' 'TPM present' $(if ($tpm.TpmPresent) { 'PASS' } else { 'REVIEW' }) $tpm.TpmPresent
            Add-Result 'PlatformSecurity' 'TPM ready' $(if ($tpm.TpmReady) { 'PASS' } else { 'REVIEW' }) $tpm.TpmReady
            Add-Result 'PlatformSecurity' 'TPM enabled' 'INFO' $tpm.TpmEnabled
        }
    } catch { Add-Result 'PlatformSecurity' 'TPM inventory' 'ERROR' $null $_.Exception.Message }

    try {
        $dg = Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction Stop
        Add-Result 'PlatformSecurity' 'Device Guard security services configured' 'INFO' ($dg.SecurityServicesConfigured -join ',')
        Add-Result 'PlatformSecurity' 'Device Guard security services running' 'INFO' ($dg.SecurityServicesRunning -join ',')
        Add-Result 'PlatformSecurity' 'Virtualization-based security status (0=off, 1=configured, 2=running)' 'INFO' $dg.VirtualizationBasedSecurityStatus
        Add-Result 'PlatformSecurity' 'Available security properties' 'INFO' ($dg.AvailableSecurityProperties -join ',')
    } catch { Add-Result 'PlatformSecurity' 'Device Guard WMI inventory' 'UNAVAILABLE' $null $_.Exception.Message }

    # SMB configuration: record actual platform capabilities; do not assume defaults.
    if (Test-CommandAvailable 'Get-SmbClientConfiguration') {
        try {
            $s = Get-SmbClientConfiguration
            Add-Result 'SMB' 'Client RequireSecuritySignature' 'INFO' $s.RequireSecuritySignature
            Add-Result 'SMB' 'Client EnableSecuritySignature' 'INFO' $s.EnableSecuritySignature
            Add-Result 'SMB' 'Client EnableInsecureGuestLogons' 'INFO' $s.EnableInsecureGuestLogons
            if ($s.PSObject.Properties.Name -contains 'RequireEncryption') {
                Add-Result 'SMB' 'Client RequireEncryption' 'INFO' $s.RequireEncryption
            }
        } catch { Add-Result 'SMB' 'Client configuration' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'SMB' 'Client cmdlets' 'UNAVAILABLE' $null }

    if (Test-CommandAvailable 'Get-SmbServerConfiguration') {
        try {
            $s = Get-SmbServerConfiguration
            Add-Result 'SMB' 'Server EnableSMB1Protocol' 'INFO' $s.EnableSMB1Protocol
            Add-Result 'SMB' 'Server EnableSMB2Protocol' 'INFO' $s.EnableSMB2Protocol
            Add-Result 'SMB' 'Server RequireSecuritySignature' 'INFO' $s.RequireSecuritySignature
            Add-Result 'SMB' 'Server EnableEncryptData' 'INFO' $s.EnableEncryptData
        } catch { Add-Result 'SMB' 'Server configuration' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'SMB' 'Server cmdlets' 'UNAVAILABLE' $null }

    # Service inventory only. No service is started, stopped or reconfigured.
    foreach ($n in @('LanmanServer','LanmanWorkstation','FDResPub','fdPHost','SSDPSRV','upnphost','WlanSvc','DoSvc','Spooler','SharedAccess','vmcompute','vmms','WslService','Sense','WinDefend','wscsvc','RemoteRegistry','TermService')) {
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
        } catch { Add-Result 'Storage' 'Inventory' 'ERROR' $null $_.Exception.Message }
    } else {
        Add-Result 'Storage' 'BitLocker cmdlets' 'UNAVAILABLE' $null 'Availability depends on edition, hardware and optional management components.'
    }

    if (Test-CommandAvailable 'Get-DOConfig') {
        try {
            $d = Get-DOConfig
            Add-Result 'DeliveryOptimization' 'DownloadMode' 'INFO' $d.DODownloadMode
        } catch { Add-Result 'DeliveryOptimization' 'Configuration query' 'ERROR' $null $_.Exception.Message }
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
    if (-not (Test-Path -LiteralPath $Directory)) {
        New-Item -Path $Directory -ItemType Directory -Force | Out-Null
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $base = 'Win11-Hardening-Audit-' + $stamp
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
    $lines.Add('MyWindowsHardening - Windows 11 Audit')
    $lines.Add(('Computer: {0}' -f $env:COMPUTERNAME))
    $lines.Add(('Generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
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
}

if ($Mode -eq 'Apply' -or $Mode -eq 'Restore') {
    throw ("Mode '{0}' is intentionally unavailable in bootstrap v{1}. This release is read-only; no system changes were made." -f $Mode,$script:ScriptVersion)
}

try {
    Invoke-ReadOnlyAudit
    Save-AuditReport -Directory $OutputDirectory
    $unsupported = @($script:Results | Where-Object { $_.Category -eq 'Compatibility' -and $_.Status -eq 'FAIL' }).Count -gt 0
    if ($unsupported) {
        Write-Warning 'System is outside the supported Windows 11 client scope.'
        exit 2
    }
    exit 0
} catch {
    Write-Error ("Audit failed: {0}" -f $_.Exception.Message)
    exit 1
}
) { $servicingEnd = [datetime]'2028-03-14'; $servicingBasis = '26H1 Home/Pro family' }
            }
            '26H2' {
                if ($edition -match '^(Enterprise|Education)
    } catch {
        Add-Result 'System' 'Operating system inventory' 'ERROR' $null $_.Exception.Message
    }

    Add-Result 'Execution' 'Administrator session' 'INFO' (Test-IsAdministrator) 'Elevation is not required for this read-only audit.'

    # Windows Defender Firewall
    if (Test-CommandAvailable 'Get-NetFirewallProfile') {
        try {
            foreach ($p in (Get-NetFirewallProfile -PolicyStore ActiveStore)) {
                $status = if ($p.Enabled) { 'PASS' } else { 'REVIEW' }
                Add-Result 'Firewall' ($p.Name + ' enabled') $status $p.Enabled
                Add-Result 'Firewall' ($p.Name + ' inbound default') 'INFO' $p.DefaultInboundAction
                Add-Result 'Firewall' ($p.Name + ' outbound default') 'INFO' $p.DefaultOutboundAction
                Add-Result 'Firewall' ($p.Name + ' blocked logging') 'INFO' $p.LogBlocked
            }
        } catch { Add-Result 'Firewall' 'Profile inventory' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'Firewall' 'NetSecurity cmdlets' 'UNAVAILABLE' $null }

    # Microsoft Defender
    if (Test-CommandAvailable 'Get-MpComputerStatus') {
        try {
            $mp = Get-MpComputerStatus
            $checks = @(
                @{Name='Antivirus enabled';Value=$mp.AntivirusEnabled},
                @{Name='Real-time protection';Value=$mp.RealTimeProtectionEnabled},
                @{Name='Behavior monitoring';Value=$mp.BehaviorMonitorEnabled},
                @{Name='IOAV protection';Value=$mp.IoavProtectionEnabled},
                @{Name='Network inspection';Value=$mp.NISEnabled},
                @{Name='Tamper protection';Value=$mp.IsTamperProtected},
                @{Name='Antivirus signatures age (days)';Value=$mp.AntivirusSignatureAge}
            )
            foreach ($c in $checks) {
                $status = if ($c.Value -eq $true) { 'PASS' } elseif ($c.Value -eq $false) { 'REVIEW' } else { 'INFO' }
                if ($c.Name -like '*age*') { $status = if ([int]$c.Value -le 3) { 'PASS' } else { 'REVIEW' } }
                Add-Result 'Defender' $c.Name $status $c.Value
            }
        } catch { Add-Result 'Defender' 'Status' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'Defender' 'Defender cmdlets' 'UNAVAILABLE' $null }

    # Windows 11 platform protections and security policy indicators.
    Add-RegistryResult 'VBS configured' 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' 'EnableVirtualizationBasedSecurity'
    Add-RegistryResult 'Credential Guard configured' 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'LsaCfgFlags'
    Add-RegistryResult 'LSA protection (RunAsPPL)' 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RunAsPPL'
    Add-RegistryResult 'UAC EnableLUA' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'EnableLUA'
    Add-RegistryResult 'UAC consent behavior' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'ConsentPromptBehaviorAdmin'
    Add-RegistryResult 'SmartScreen Explorer policy' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' 'SmartScreenEnabled'
    Add-RegistryResult 'AutoRun policy' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoDriveTypeAutoRun'
    Add-RegistryResult 'RDP deny connections policy' 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections'

    try {
        if (Test-CommandAvailable 'Get-CimInstance') {
            $cs = Get-CimInstance -ClassName Win32_ComputerSystem
            Add-Result 'PlatformSecurity' 'Hypervisor present' 'INFO' $cs.HypervisorPresent 'A present hypervisor does not by itself prove VBS or Memory Integrity is enabled.'
        }
    } catch { Add-Result 'PlatformSecurity' 'Hypervisor status' 'ERROR' $null $_.Exception.Message }

    try {
        if (Test-CommandAvailable 'Confirm-SecureBootUEFI') {
            $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop
            Add-Result 'PlatformSecurity' 'Secure Boot' $(if ($secureBoot) { 'PASS' } else { 'REVIEW' }) $secureBoot
        }
    } catch {
        Add-Result 'PlatformSecurity' 'Secure Boot' 'UNAVAILABLE' $null 'May be unavailable on legacy BIOS, unsupported firmware, or restricted sessions.'
    }

    try {
        if (Test-CommandAvailable 'Get-Tpm') {
            $tpm = Get-Tpm
            Add-Result 'PlatformSecurity' 'TPM present' $(if ($tpm.TpmPresent) { 'PASS' } else { 'REVIEW' }) $tpm.TpmPresent
            Add-Result 'PlatformSecurity' 'TPM ready' $(if ($tpm.TpmReady) { 'PASS' } else { 'REVIEW' }) $tpm.TpmReady
            Add-Result 'PlatformSecurity' 'TPM enabled' 'INFO' $tpm.TpmEnabled
        }
    } catch { Add-Result 'PlatformSecurity' 'TPM inventory' 'ERROR' $null $_.Exception.Message }

    try {
        $dg = Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction Stop
        Add-Result 'PlatformSecurity' 'Device Guard security services configured' 'INFO' ($dg.SecurityServicesConfigured -join ',')
        Add-Result 'PlatformSecurity' 'Device Guard security services running' 'INFO' ($dg.SecurityServicesRunning -join ',')
        Add-Result 'PlatformSecurity' 'Virtualization-based security status (0=off, 1=configured, 2=running)' 'INFO' $dg.VirtualizationBasedSecurityStatus
        Add-Result 'PlatformSecurity' 'Available security properties' 'INFO' ($dg.AvailableSecurityProperties -join ',')
    } catch { Add-Result 'PlatformSecurity' 'Device Guard WMI inventory' 'UNAVAILABLE' $null $_.Exception.Message }

    # SMB configuration: record actual platform capabilities; do not assume defaults.
    if (Test-CommandAvailable 'Get-SmbClientConfiguration') {
        try {
            $s = Get-SmbClientConfiguration
            Add-Result 'SMB' 'Client RequireSecuritySignature' 'INFO' $s.RequireSecuritySignature
            Add-Result 'SMB' 'Client EnableSecuritySignature' 'INFO' $s.EnableSecuritySignature
            Add-Result 'SMB' 'Client EnableInsecureGuestLogons' 'INFO' $s.EnableInsecureGuestLogons
            if ($s.PSObject.Properties.Name -contains 'RequireEncryption') {
                Add-Result 'SMB' 'Client RequireEncryption' 'INFO' $s.RequireEncryption
            }
        } catch { Add-Result 'SMB' 'Client configuration' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'SMB' 'Client cmdlets' 'UNAVAILABLE' $null }

    if (Test-CommandAvailable 'Get-SmbServerConfiguration') {
        try {
            $s = Get-SmbServerConfiguration
            Add-Result 'SMB' 'Server EnableSMB1Protocol' 'INFO' $s.EnableSMB1Protocol
            Add-Result 'SMB' 'Server EnableSMB2Protocol' 'INFO' $s.EnableSMB2Protocol
            Add-Result 'SMB' 'Server RequireSecuritySignature' 'INFO' $s.RequireSecuritySignature
            Add-Result 'SMB' 'Server EnableEncryptData' 'INFO' $s.EnableEncryptData
        } catch { Add-Result 'SMB' 'Server configuration' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'SMB' 'Server cmdlets' 'UNAVAILABLE' $null }

    # Service inventory only. No service is started, stopped or reconfigured.
    foreach ($n in @('LanmanServer','LanmanWorkstation','FDResPub','fdPHost','SSDPSRV','upnphost','WlanSvc','DoSvc','Spooler','SharedAccess','vmcompute','vmms','WslService','Sense','WinDefend','wscsvc','RemoteRegistry','TermService')) {
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
        } catch { Add-Result 'Storage' 'Inventory' 'ERROR' $null $_.Exception.Message }
    } else {
        Add-Result 'Storage' 'BitLocker cmdlets' 'UNAVAILABLE' $null 'Availability depends on edition, hardware and optional management components.'
    }

    if (Test-CommandAvailable 'Get-DOConfig') {
        try {
            $d = Get-DOConfig
            Add-Result 'DeliveryOptimization' 'DownloadMode' 'INFO' $d.DODownloadMode
        } catch { Add-Result 'DeliveryOptimization' 'Configuration query' 'ERROR' $null $_.Exception.Message }
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
    if (-not (Test-Path -LiteralPath $Directory)) {
        New-Item -Path $Directory -ItemType Directory -Force | Out-Null
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $base = 'Win11-Hardening-Audit-' + $stamp
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
    $lines.Add('MyWindowsHardening - Windows 11 Audit')
    $lines.Add(('Computer: {0}' -f $env:COMPUTERNAME))
    $lines.Add(('Generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
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
}

if ($Mode -eq 'Apply' -or $Mode -eq 'Restore') {
    throw ("Mode '{0}' is intentionally unavailable in bootstrap v{1}. This release is read-only; no system changes were made." -f $Mode,$script:ScriptVersion)
}

try {
    Invoke-ReadOnlyAudit
    Save-AuditReport -Directory $OutputDirectory
    $unsupported = @($script:Results | Where-Object { $_.Category -eq 'Compatibility' -and $_.Status -eq 'FAIL' }).Count -gt 0
    if ($unsupported) {
        Write-Warning 'System is outside the supported Windows 11 client scope.'
        exit 2
    }
    exit 0
} catch {
    Write-Error ("Audit failed: {0}" -f $_.Exception.Message)
    exit 1
}
) { $servicingEnd = [datetime]'2029-10-09'; $servicingBasis = '26H2 Enterprise/Education' }
                elseif ($edition -match '^(Core|CoreN|Professional|ProfessionalN|ProfessionalWorkstation|ProfessionalEducation)
    } catch {
        Add-Result 'System' 'Operating system inventory' 'ERROR' $null $_.Exception.Message
    }

    Add-Result 'Execution' 'Administrator session' 'INFO' (Test-IsAdministrator) 'Elevation is not required for this read-only audit.'

    # Windows Defender Firewall
    if (Test-CommandAvailable 'Get-NetFirewallProfile') {
        try {
            foreach ($p in (Get-NetFirewallProfile -PolicyStore ActiveStore)) {
                $status = if ($p.Enabled) { 'PASS' } else { 'REVIEW' }
                Add-Result 'Firewall' ($p.Name + ' enabled') $status $p.Enabled
                Add-Result 'Firewall' ($p.Name + ' inbound default') 'INFO' $p.DefaultInboundAction
                Add-Result 'Firewall' ($p.Name + ' outbound default') 'INFO' $p.DefaultOutboundAction
                Add-Result 'Firewall' ($p.Name + ' blocked logging') 'INFO' $p.LogBlocked
            }
        } catch { Add-Result 'Firewall' 'Profile inventory' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'Firewall' 'NetSecurity cmdlets' 'UNAVAILABLE' $null }

    # Microsoft Defender
    if (Test-CommandAvailable 'Get-MpComputerStatus') {
        try {
            $mp = Get-MpComputerStatus
            $checks = @(
                @{Name='Antivirus enabled';Value=$mp.AntivirusEnabled},
                @{Name='Real-time protection';Value=$mp.RealTimeProtectionEnabled},
                @{Name='Behavior monitoring';Value=$mp.BehaviorMonitorEnabled},
                @{Name='IOAV protection';Value=$mp.IoavProtectionEnabled},
                @{Name='Network inspection';Value=$mp.NISEnabled},
                @{Name='Tamper protection';Value=$mp.IsTamperProtected},
                @{Name='Antivirus signatures age (days)';Value=$mp.AntivirusSignatureAge}
            )
            foreach ($c in $checks) {
                $status = if ($c.Value -eq $true) { 'PASS' } elseif ($c.Value -eq $false) { 'REVIEW' } else { 'INFO' }
                if ($c.Name -like '*age*') { $status = if ([int]$c.Value -le 3) { 'PASS' } else { 'REVIEW' } }
                Add-Result 'Defender' $c.Name $status $c.Value
            }
        } catch { Add-Result 'Defender' 'Status' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'Defender' 'Defender cmdlets' 'UNAVAILABLE' $null }

    # Windows 11 platform protections and security policy indicators.
    Add-RegistryResult 'VBS configured' 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' 'EnableVirtualizationBasedSecurity'
    Add-RegistryResult 'Credential Guard configured' 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'LsaCfgFlags'
    Add-RegistryResult 'LSA protection (RunAsPPL)' 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RunAsPPL'
    Add-RegistryResult 'UAC EnableLUA' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'EnableLUA'
    Add-RegistryResult 'UAC consent behavior' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'ConsentPromptBehaviorAdmin'
    Add-RegistryResult 'SmartScreen Explorer policy' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' 'SmartScreenEnabled'
    Add-RegistryResult 'AutoRun policy' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoDriveTypeAutoRun'
    Add-RegistryResult 'RDP deny connections policy' 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections'

    try {
        if (Test-CommandAvailable 'Get-CimInstance') {
            $cs = Get-CimInstance -ClassName Win32_ComputerSystem
            Add-Result 'PlatformSecurity' 'Hypervisor present' 'INFO' $cs.HypervisorPresent 'A present hypervisor does not by itself prove VBS or Memory Integrity is enabled.'
        }
    } catch { Add-Result 'PlatformSecurity' 'Hypervisor status' 'ERROR' $null $_.Exception.Message }

    try {
        if (Test-CommandAvailable 'Confirm-SecureBootUEFI') {
            $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop
            Add-Result 'PlatformSecurity' 'Secure Boot' $(if ($secureBoot) { 'PASS' } else { 'REVIEW' }) $secureBoot
        }
    } catch {
        Add-Result 'PlatformSecurity' 'Secure Boot' 'UNAVAILABLE' $null 'May be unavailable on legacy BIOS, unsupported firmware, or restricted sessions.'
    }

    try {
        if (Test-CommandAvailable 'Get-Tpm') {
            $tpm = Get-Tpm
            Add-Result 'PlatformSecurity' 'TPM present' $(if ($tpm.TpmPresent) { 'PASS' } else { 'REVIEW' }) $tpm.TpmPresent
            Add-Result 'PlatformSecurity' 'TPM ready' $(if ($tpm.TpmReady) { 'PASS' } else { 'REVIEW' }) $tpm.TpmReady
            Add-Result 'PlatformSecurity' 'TPM enabled' 'INFO' $tpm.TpmEnabled
        }
    } catch { Add-Result 'PlatformSecurity' 'TPM inventory' 'ERROR' $null $_.Exception.Message }

    try {
        $dg = Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction Stop
        Add-Result 'PlatformSecurity' 'Device Guard security services configured' 'INFO' ($dg.SecurityServicesConfigured -join ',')
        Add-Result 'PlatformSecurity' 'Device Guard security services running' 'INFO' ($dg.SecurityServicesRunning -join ',')
        Add-Result 'PlatformSecurity' 'Virtualization-based security status (0=off, 1=configured, 2=running)' 'INFO' $dg.VirtualizationBasedSecurityStatus
        Add-Result 'PlatformSecurity' 'Available security properties' 'INFO' ($dg.AvailableSecurityProperties -join ',')
    } catch { Add-Result 'PlatformSecurity' 'Device Guard WMI inventory' 'UNAVAILABLE' $null $_.Exception.Message }

    # SMB configuration: record actual platform capabilities; do not assume defaults.
    if (Test-CommandAvailable 'Get-SmbClientConfiguration') {
        try {
            $s = Get-SmbClientConfiguration
            Add-Result 'SMB' 'Client RequireSecuritySignature' 'INFO' $s.RequireSecuritySignature
            Add-Result 'SMB' 'Client EnableSecuritySignature' 'INFO' $s.EnableSecuritySignature
            Add-Result 'SMB' 'Client EnableInsecureGuestLogons' 'INFO' $s.EnableInsecureGuestLogons
            if ($s.PSObject.Properties.Name -contains 'RequireEncryption') {
                Add-Result 'SMB' 'Client RequireEncryption' 'INFO' $s.RequireEncryption
            }
        } catch { Add-Result 'SMB' 'Client configuration' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'SMB' 'Client cmdlets' 'UNAVAILABLE' $null }

    if (Test-CommandAvailable 'Get-SmbServerConfiguration') {
        try {
            $s = Get-SmbServerConfiguration
            Add-Result 'SMB' 'Server EnableSMB1Protocol' 'INFO' $s.EnableSMB1Protocol
            Add-Result 'SMB' 'Server EnableSMB2Protocol' 'INFO' $s.EnableSMB2Protocol
            Add-Result 'SMB' 'Server RequireSecuritySignature' 'INFO' $s.RequireSecuritySignature
            Add-Result 'SMB' 'Server EnableEncryptData' 'INFO' $s.EnableEncryptData
        } catch { Add-Result 'SMB' 'Server configuration' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'SMB' 'Server cmdlets' 'UNAVAILABLE' $null }

    # Service inventory only. No service is started, stopped or reconfigured.
    foreach ($n in @('LanmanServer','LanmanWorkstation','FDResPub','fdPHost','SSDPSRV','upnphost','WlanSvc','DoSvc','Spooler','SharedAccess','vmcompute','vmms','WslService','Sense','WinDefend','wscsvc','RemoteRegistry','TermService')) {
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
        } catch { Add-Result 'Storage' 'Inventory' 'ERROR' $null $_.Exception.Message }
    } else {
        Add-Result 'Storage' 'BitLocker cmdlets' 'UNAVAILABLE' $null 'Availability depends on edition, hardware and optional management components.'
    }

    if (Test-CommandAvailable 'Get-DOConfig') {
        try {
            $d = Get-DOConfig
            Add-Result 'DeliveryOptimization' 'DownloadMode' 'INFO' $d.DODownloadMode
        } catch { Add-Result 'DeliveryOptimization' 'Configuration query' 'ERROR' $null $_.Exception.Message }
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
    if (-not (Test-Path -LiteralPath $Directory)) {
        New-Item -Path $Directory -ItemType Directory -Force | Out-Null
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $base = 'Win11-Hardening-Audit-' + $stamp
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
    $lines.Add('MyWindowsHardening - Windows 11 Audit')
    $lines.Add(('Computer: {0}' -f $env:COMPUTERNAME))
    $lines.Add(('Generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
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
}

if ($Mode -eq 'Apply' -or $Mode -eq 'Restore') {
    throw ("Mode '{0}' is intentionally unavailable in bootstrap v{1}. This release is read-only; no system changes were made." -f $Mode,$script:ScriptVersion)
}

try {
    Invoke-ReadOnlyAudit
    Save-AuditReport -Directory $OutputDirectory
    $unsupported = @($script:Results | Where-Object { $_.Category -eq 'Compatibility' -and $_.Status -eq 'FAIL' }).Count -gt 0
    if ($unsupported) {
        Write-Warning 'System is outside the supported Windows 11 client scope.'
        exit 2
    }
    exit 0
} catch {
    Write-Error ("Audit failed: {0}" -f $_.Exception.Message)
    exit 1
}
) { $servicingEnd = [datetime]'2028-10-10'; $servicingBasis = '26H2 Home/Pro family' }
            }
        }

        if ($null -eq $servicingEnd) {
            Add-Result 'Servicing' 'Windows feature release support' 'REVIEW' $version ('No lifecycle mapping for EditionID {0}; verify directly with Microsoft.' -f $edition)
        } elseif ((Get-Date).Date -gt $servicingEnd.Date) {
            Add-Result 'Servicing' 'Windows feature release support' 'FAIL' 'End of updates' ('{0}; Microsoft end-of-updates date: {1:yyyy-MM-dd}. Upgrade to a supported release.' -f $servicingBasis,$servicingEnd)
        } else {
            Add-Result 'Servicing' 'Windows feature release support' 'PASS' 'Within published servicing lifecycle' ('{0}; Microsoft end-of-updates date: {1:yyyy-MM-dd}.' -f $servicingBasis,$servicingEnd)
        }
    } catch {
        Add-Result 'System' 'Operating system inventory' 'ERROR' $null $_.Exception.Message
    }

    Add-Result 'Execution' 'Administrator session' 'INFO' (Test-IsAdministrator) 'Elevation is not required for this read-only audit.'

    # Windows Defender Firewall
    if (Test-CommandAvailable 'Get-NetFirewallProfile') {
        try {
            foreach ($p in (Get-NetFirewallProfile -PolicyStore ActiveStore)) {
                $status = if ($p.Enabled) { 'PASS' } else { 'REVIEW' }
                Add-Result 'Firewall' ($p.Name + ' enabled') $status $p.Enabled
                Add-Result 'Firewall' ($p.Name + ' inbound default') 'INFO' $p.DefaultInboundAction
                Add-Result 'Firewall' ($p.Name + ' outbound default') 'INFO' $p.DefaultOutboundAction
                Add-Result 'Firewall' ($p.Name + ' blocked logging') 'INFO' $p.LogBlocked
            }
        } catch { Add-Result 'Firewall' 'Profile inventory' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'Firewall' 'NetSecurity cmdlets' 'UNAVAILABLE' $null }

    # Microsoft Defender
    if (Test-CommandAvailable 'Get-MpComputerStatus') {
        try {
            $mp = Get-MpComputerStatus
            $checks = @(
                @{Name='Antivirus enabled';Value=$mp.AntivirusEnabled},
                @{Name='Real-time protection';Value=$mp.RealTimeProtectionEnabled},
                @{Name='Behavior monitoring';Value=$mp.BehaviorMonitorEnabled},
                @{Name='IOAV protection';Value=$mp.IoavProtectionEnabled},
                @{Name='Network inspection';Value=$mp.NISEnabled},
                @{Name='Tamper protection';Value=$mp.IsTamperProtected},
                @{Name='Antivirus signatures age (days)';Value=$mp.AntivirusSignatureAge}
            )
            foreach ($c in $checks) {
                $status = if ($c.Value -eq $true) { 'PASS' } elseif ($c.Value -eq $false) { 'REVIEW' } else { 'INFO' }
                if ($c.Name -like '*age*') { $status = if ([int]$c.Value -le 3) { 'PASS' } else { 'REVIEW' } }
                Add-Result 'Defender' $c.Name $status $c.Value
            }
        } catch { Add-Result 'Defender' 'Status' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'Defender' 'Defender cmdlets' 'UNAVAILABLE' $null }

    # Windows 11 platform protections and security policy indicators.
    Add-RegistryResult 'VBS configured' 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' 'EnableVirtualizationBasedSecurity'
    Add-RegistryResult 'Credential Guard configured' 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'LsaCfgFlags'
    Add-RegistryResult 'LSA protection (RunAsPPL)' 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RunAsPPL'
    Add-RegistryResult 'UAC EnableLUA' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'EnableLUA'
    Add-RegistryResult 'UAC consent behavior' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'ConsentPromptBehaviorAdmin'
    Add-RegistryResult 'SmartScreen Explorer policy' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' 'SmartScreenEnabled'
    Add-RegistryResult 'AutoRun policy' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoDriveTypeAutoRun'
    Add-RegistryResult 'RDP deny connections policy' 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections'

    try {
        if (Test-CommandAvailable 'Get-CimInstance') {
            $cs = Get-CimInstance -ClassName Win32_ComputerSystem
            Add-Result 'PlatformSecurity' 'Hypervisor present' 'INFO' $cs.HypervisorPresent 'A present hypervisor does not by itself prove VBS or Memory Integrity is enabled.'
        }
    } catch { Add-Result 'PlatformSecurity' 'Hypervisor status' 'ERROR' $null $_.Exception.Message }

    try {
        if (Test-CommandAvailable 'Confirm-SecureBootUEFI') {
            $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop
            Add-Result 'PlatformSecurity' 'Secure Boot' $(if ($secureBoot) { 'PASS' } else { 'REVIEW' }) $secureBoot
        }
    } catch {
        Add-Result 'PlatformSecurity' 'Secure Boot' 'UNAVAILABLE' $null 'May be unavailable on legacy BIOS, unsupported firmware, or restricted sessions.'
    }

    try {
        if (Test-CommandAvailable 'Get-Tpm') {
            $tpm = Get-Tpm
            Add-Result 'PlatformSecurity' 'TPM present' $(if ($tpm.TpmPresent) { 'PASS' } else { 'REVIEW' }) $tpm.TpmPresent
            Add-Result 'PlatformSecurity' 'TPM ready' $(if ($tpm.TpmReady) { 'PASS' } else { 'REVIEW' }) $tpm.TpmReady
            Add-Result 'PlatformSecurity' 'TPM enabled' 'INFO' $tpm.TpmEnabled
        }
    } catch { Add-Result 'PlatformSecurity' 'TPM inventory' 'ERROR' $null $_.Exception.Message }

    try {
        $dg = Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction Stop
        Add-Result 'PlatformSecurity' 'Device Guard security services configured' 'INFO' ($dg.SecurityServicesConfigured -join ',')
        Add-Result 'PlatformSecurity' 'Device Guard security services running' 'INFO' ($dg.SecurityServicesRunning -join ',')
        Add-Result 'PlatformSecurity' 'Virtualization-based security status (0=off, 1=configured, 2=running)' 'INFO' $dg.VirtualizationBasedSecurityStatus
        Add-Result 'PlatformSecurity' 'Available security properties' 'INFO' ($dg.AvailableSecurityProperties -join ',')
    } catch { Add-Result 'PlatformSecurity' 'Device Guard WMI inventory' 'UNAVAILABLE' $null $_.Exception.Message }

    # SMB configuration: record actual platform capabilities; do not assume defaults.
    if (Test-CommandAvailable 'Get-SmbClientConfiguration') {
        try {
            $s = Get-SmbClientConfiguration
            Add-Result 'SMB' 'Client RequireSecuritySignature' 'INFO' $s.RequireSecuritySignature
            Add-Result 'SMB' 'Client EnableSecuritySignature' 'INFO' $s.EnableSecuritySignature
            Add-Result 'SMB' 'Client EnableInsecureGuestLogons' 'INFO' $s.EnableInsecureGuestLogons
            if ($s.PSObject.Properties.Name -contains 'RequireEncryption') {
                Add-Result 'SMB' 'Client RequireEncryption' 'INFO' $s.RequireEncryption
            }
        } catch { Add-Result 'SMB' 'Client configuration' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'SMB' 'Client cmdlets' 'UNAVAILABLE' $null }

    if (Test-CommandAvailable 'Get-SmbServerConfiguration') {
        try {
            $s = Get-SmbServerConfiguration
            Add-Result 'SMB' 'Server EnableSMB1Protocol' 'INFO' $s.EnableSMB1Protocol
            Add-Result 'SMB' 'Server EnableSMB2Protocol' 'INFO' $s.EnableSMB2Protocol
            Add-Result 'SMB' 'Server RequireSecuritySignature' 'INFO' $s.RequireSecuritySignature
            Add-Result 'SMB' 'Server EnableEncryptData' 'INFO' $s.EnableEncryptData
        } catch { Add-Result 'SMB' 'Server configuration' 'ERROR' $null $_.Exception.Message }
    } else { Add-Result 'SMB' 'Server cmdlets' 'UNAVAILABLE' $null }

    # Service inventory only. No service is started, stopped or reconfigured.
    foreach ($n in @('LanmanServer','LanmanWorkstation','FDResPub','fdPHost','SSDPSRV','upnphost','WlanSvc','DoSvc','Spooler','SharedAccess','vmcompute','vmms','WslService','Sense','WinDefend','wscsvc','RemoteRegistry','TermService')) {
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
        } catch { Add-Result 'Storage' 'Inventory' 'ERROR' $null $_.Exception.Message }
    } else {
        Add-Result 'Storage' 'BitLocker cmdlets' 'UNAVAILABLE' $null 'Availability depends on edition, hardware and optional management components.'
    }

    if (Test-CommandAvailable 'Get-DOConfig') {
        try {
            $d = Get-DOConfig
            Add-Result 'DeliveryOptimization' 'DownloadMode' 'INFO' $d.DODownloadMode
        } catch { Add-Result 'DeliveryOptimization' 'Configuration query' 'ERROR' $null $_.Exception.Message }
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
    if (-not (Test-Path -LiteralPath $Directory)) {
        New-Item -Path $Directory -ItemType Directory -Force | Out-Null
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $base = 'Win11-Hardening-Audit-' + $stamp
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
    $lines.Add('MyWindowsHardening - Windows 11 Audit')
    $lines.Add(('Computer: {0}' -f $env:COMPUTERNAME))
    $lines.Add(('Generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
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
}

if ($Mode -eq 'Apply' -or $Mode -eq 'Restore') {
    throw ("Mode '{0}' is intentionally unavailable in bootstrap v{1}. This release is read-only; no system changes were made." -f $Mode,$script:ScriptVersion)
}

try {
    Invoke-ReadOnlyAudit
    Save-AuditReport -Directory $OutputDirectory
    $unsupported = @($script:Results | Where-Object { $_.Category -eq 'Compatibility' -and $_.Status -eq 'FAIL' }).Count -gt 0
    if ($unsupported) {
        Write-Warning 'System is outside the supported Windows 11 client scope.'
        exit 2
    }
    exit 0
} catch {
    Write-Error ("Audit failed: {0}" -f $_.Exception.Message)
    exit 1
}
