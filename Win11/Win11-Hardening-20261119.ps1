#requires -Version 5.1
<#
.SYNOPSIS
    MyWindowsHardening - Windows 11 baseline auditor (read-only).
.DESCRIPTION
    Collects Windows 11 security, platform and configuration facts.
    Audit, Validate and Report are read-only. Apply and Restore are deliberately
    blocked until each future control has a reviewed backup, compatibility
    contract, rollback procedure and platform-specific validation.
.NOTES
    Project: MyWindowsHardening
    File: Win11-Hardening-20261119.ps1
    Version: 0.2.0-readonly
    Compatibility: Windows 11 client, Windows PowerShell 5.1
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
$script:ScriptVersion = '0.2.0-readonly'
$script:UnsupportedClient = $false
$script:SystemInventoryFailed = $false
$script:ServicingExpired = $false

function Add-Result {
    param(
        [ValidateSet('System', 'Compatibility', 'Servicing', 'Execution', 'Firewall', 'Defender', 'WindowsSecurity', 'PlatformSecurity', 'SMB', 'Services', 'Network', 'Storage', 'DeliveryOptimization', 'Reporting')]
        [string]$Category,
        [string]$Name,
        [ValidateSet('PASS', 'REVIEW', 'FAIL', 'ERROR', 'INFO', 'UNAVAILABLE')]
        [string]$Status,
        [AllowNull()][object]$Value,
        [string]$Details = ''
    )

    $script:Results.Add([pscustomobject]@{
        Category = $Category
        Name     = $Name
        Status   = $Status
        Value    = if ($null -eq $Value) { $null } else { [string]$Value }
        Details  = $Details
    }) | Out-Null
}

function Test-CommandAvailable {
    param([Parameter(Mandatory = $true)][string]$Name)
    return $null -ne (Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Test-IsAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Add-RegistryResult {
    param(
        [string]$Name,
        [string]$Path,
        [string]$Property,
        [string]$Category = 'WindowsSecurity'
    )

    try {
        if (-not (Test-Path -LiteralPath $Path -ErrorAction Stop)) {
            Add-Result -Category $Category -Name $Name -Status 'INFO' -Value 'Key not present' -Details 'This is an inventory indicator, not proof that the related protection is disabled.'
            return
        }

        $item = Get-ItemProperty -LiteralPath $Path -Name $Property -ErrorAction Stop
        $value = $item.PSObject.Properties[$Property].Value
        Add-Result -Category $Category -Name $Name -Status 'INFO' -Value $value -Details 'Registry indicator only; effective policy and runtime state may differ.'
    }
    catch {
        if ($_.Exception -is [System.Management.Automation.PSArgumentException] -or
            $_.FullyQualifiedErrorId -match 'PropertyNotFound|PathNotFound') {
            Add-Result -Category $Category -Name $Name -Status 'INFO' -Value 'Not configured locally' -Details 'A missing local value does not exclude policy from MDM, Group Policy or a platform default.'
        }
        else {
            Add-Result -Category $Category -Name $Name -Status 'UNAVAILABLE' -Value $null -Details $_.Exception.Message
        }
    }
}

function Get-WindowsServicingInfo {
    param(
        [string]$DisplayVersion,
        [string]$EditionId
    )

    $endDate = $null
    $basis = ''
    $note = ''

    $homeProPattern = '^(Core|CoreN|CoreSingleLanguage|CoreCountrySpecific|Professional|ProfessionalN|ProfessionalSingleLanguage|ProfessionalCountrySpecific|ProfessionalWorkstation|ProfessionalWorkstationN|ProfessionalEducation|ProfessionalEducationN)$'
    $enterpriseEducationPattern = '^(Enterprise|EnterpriseN|Education|EducationN|IoTEnterprise)$'

    switch ($DisplayVersion) {
        '23H2' {
            if ($EditionId -match $homeProPattern) {
                $endDate = [datetime]'2025-11-11'
                $basis = '23H2 Home/Pro family'
            }
            elseif ($EditionId -match '^(Enterprise|EnterpriseN|Education|EducationN)$') {
                $endDate = [datetime]'2026-11-10'
                $basis = '23H2 Enterprise/Education'
            }
        }
        '24H2' {
            if ($EditionId -match $homeProPattern) {
                $endDate = [datetime]'2026-10-13'
                $basis = '24H2 Home/Pro family'
            }
            elseif ($EditionId -match '^(Enterprise|EnterpriseN|Education|EducationN|IoTEnterprise)$') {
                $endDate = [datetime]'2027-10-12'
                $basis = '24H2 Enterprise/Education/IoT Enterprise'
            }
            elseif ($EditionId -eq 'EnterpriseS') {
                $endDate = [datetime]'2029-10-09'
                $basis = 'Windows 11 Enterprise LTSC 2024'
            }
            elseif ($EditionId -eq 'IoTEnterpriseS') {
                $endDate = [datetime]'2034-10-10'
                $basis = 'Windows 11 IoT Enterprise LTSC 2024'
            }
        }
        '25H2' {
            if ($EditionId -match $homeProPattern) {
                $endDate = [datetime]'2027-10-12'
                $basis = '25H2 Home/Pro family'
            }
            elseif ($EditionId -match $enterpriseEducationPattern) {
                $endDate = [datetime]'2028-10-10'
                $basis = '25H2 Enterprise/Education/IoT Enterprise'
            }
        }
        '26H1' {
            if ($EditionId -match $homeProPattern) {
                $endDate = [datetime]'2028-03-14'
                $basis = '26H1 Home/Pro family'
            }
            elseif ($EditionId -match '^(Enterprise|EnterpriseN|Education|EducationN)$') {
                $endDate = [datetime]'2029-03-13'
                $basis = '26H1 Enterprise/Education'
            }
            if ($EditionId -eq 'IoTEnterprise' -or $EditionId -eq 'IoTEnterpriseS') {
                $note = 'Microsoft lists IoT Enterprise as unsupported for Windows 11 26H1.'
            }
            else {
                $note = '26H1 is intended for selected new devices and is not offered as an in-place feature update from 24H2 or 25H2.'
            }
        }
        '26H2' {
            if ($EditionId -match $homeProPattern) {
                $endDate = [datetime]'2028-10-10'
                $basis = '26H2 Home/Pro family'
            }
            elseif ($EditionId -match $enterpriseEducationPattern) {
                $endDate = [datetime]'2029-10-09'
                $basis = '26H2 Enterprise/Education/IoT Enterprise'
            }
        }
    }

    return [pscustomobject]@{
        EndDate = $endDate
        Basis   = $basis
        Note    = $note
    }
}

function Invoke-ReadOnlyAudit {
    Write-Host ''
    Write-Host 'MyWindowsHardening - Windows 11 baseline audit' -ForegroundColor Cyan
    Write-Host ('Mode: {0} | Version: {1}' -f $Mode, $script:ScriptVersion)
    Write-Host 'READ ONLY - no system settings will be changed.' -ForegroundColor Green
    Write-Host ''

    $os = $null
    $cv = $null

    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $cv = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop

        $build = [int]$cv.CurrentBuildNumber
        $ubr = if ($null -ne $cv.UBR) { [int]$cv.UBR } else { 0 }
        $displayVersion = [string]$cv.DisplayVersion
        $editionId = [string]$cv.EditionID

        Add-Result -Category 'System' -Name 'Product' -Status 'INFO' -Value $os.Caption
        Add-Result -Category 'System' -Name 'DisplayVersion' -Status 'INFO' -Value $displayVersion
        Add-Result -Category 'System' -Name 'Build' -Status 'INFO' -Value ('{0}.{1}' -f $build, $ubr)
        Add-Result -Category 'System' -Name 'Edition' -Status 'INFO' -Value $editionId
        Add-Result -Category 'System' -Name 'OS architecture' -Status 'INFO' -Value $os.OSArchitecture

        if ([int]$os.ProductType -ne 1 -or $build -lt 22000) {
            $script:UnsupportedClient = $true
            Add-Result -Category 'Compatibility' -Name 'Windows 11 client' -Status 'FAIL' -Value $false -Details 'This auditor targets Windows 11 client builds 22000 and later; Windows Server and Windows 10 are excluded.'
        }
        else {
            Add-Result -Category 'Compatibility' -Name 'Windows 11 client' -Status 'PASS' -Value $true
        }

        $servicing = Get-WindowsServicingInfo -DisplayVersion $displayVersion -EditionId $editionId
        if ($null -eq $servicing.EndDate) {
            Add-Result -Category 'Servicing' -Name 'Windows feature release support' -Status 'REVIEW' -Value 'Manual verification required' -Details ('No servicing mapping is defined for DisplayVersion={0}, EditionID={1}. Check the current Microsoft lifecycle page. {2}' -f $displayVersion, $editionId, $servicing.Note)
        }
        elseif ((Get-Date).Date -gt $servicing.EndDate.Date) {
            $script:ServicingExpired = $true
            Add-Result -Category 'Servicing' -Name 'Windows feature release support' -Status 'FAIL' -Value 'End of updates' -Details ('{0}; Microsoft end-of-updates date: {1:yyyy-MM-dd}. Upgrade to a supported release.' -f $servicing.Basis, $servicing.EndDate)
        }
        else {
            Add-Result -Category 'Servicing' -Name 'Windows feature release support' -Status 'PASS' -Value 'Within published servicing lifecycle' -Details ('{0}; Microsoft end-of-updates date: {1:yyyy-MM-dd}. {2}' -f $servicing.Basis, $servicing.EndDate, $servicing.Note)
        }
    }
    catch {
        $script:SystemInventoryFailed = $true
        Add-Result -Category 'System' -Name 'Operating system inventory' -Status 'ERROR' -Value $null -Details $_.Exception.Message
    }

    Add-Result -Category 'Execution' -Name 'Administrator session' -Status 'INFO' -Value (Test-IsAdministrator) -Details 'Elevation is not required for this read-only audit. Some inventories may be unavailable in a restricted session.'

    if (Test-CommandAvailable 'Get-NetFirewallProfile') {
        try {
            foreach ($profile in (Get-NetFirewallProfile -PolicyStore ActiveStore -ErrorAction Stop)) {
                $status = if ($profile.Enabled) { 'PASS' } else { 'REVIEW' }
                Add-Result -Category 'Firewall' -Name ($profile.Name + ' enabled') -Status $status -Value $profile.Enabled
                Add-Result -Category 'Firewall' -Name ($profile.Name + ' inbound default') -Status 'INFO' -Value $profile.DefaultInboundAction
                Add-Result -Category 'Firewall' -Name ($profile.Name + ' outbound default') -Status 'INFO' -Value $profile.DefaultOutboundAction
                Add-Result -Category 'Firewall' -Name ($profile.Name + ' blocked logging') -Status 'INFO' -Value $profile.LogBlocked
            }
        }
        catch {
            Add-Result -Category 'Firewall' -Name 'Profile inventory' -Status 'ERROR' -Value $null -Details $_.Exception.Message
        }
    }
    else {
        Add-Result -Category 'Firewall' -Name 'NetSecurity cmdlets' -Status 'UNAVAILABLE' -Value $null
    }

    if (Test-CommandAvailable 'Get-MpComputerStatus') {
        try {
            $mp = Get-MpComputerStatus -ErrorAction Stop
            $checks = @(
                @{ Name = 'Antivirus enabled'; Value = $mp.AntivirusEnabled },
                @{ Name = 'Real-time protection'; Value = $mp.RealTimeProtectionEnabled },
                @{ Name = 'Behavior monitoring'; Value = $mp.BehaviorMonitorEnabled },
                @{ Name = 'IOAV protection'; Value = $mp.IoavProtectionEnabled },
                @{ Name = 'Network inspection'; Value = $mp.NISEnabled },
                @{ Name = 'Tamper protection'; Value = $mp.IsTamperProtected },
                @{ Name = 'Antivirus signatures age (days)'; Value = $mp.AntivirusSignatureAge },
                @{ Name = 'Antivirus signature last updated'; Value = $mp.AntivirusSignatureLastUpdated },
                @{ Name = 'Antivirus engine version'; Value = $mp.AMEngineVersion },
                @{ Name = 'Antivirus signature version'; Value = $mp.AntivirusSignatureVersion }
            )

            foreach ($check in $checks) {
                if ($check.Name -like '*age*' -or $check.Name -like '*last updated*' -or $check.Name -like '*version*') {
                    $status = 'INFO'
                }
                elseif ($check.Value -eq $true) {
                    $status = 'PASS'
                }
                elseif ($check.Value -eq $false) {
                    $status = 'REVIEW'
                }
                else {
                    $status = 'UNAVAILABLE'
                }

                Add-Result -Category 'Defender' -Name $check.Name -Status $status -Value $check.Value
            }
        }
        catch {
            Add-Result -Category 'Defender' -Name 'Status' -Status 'ERROR' -Value $null -Details $_.Exception.Message
        }
    }
    else {
        Add-Result -Category 'Defender' -Name 'Defender cmdlets' -Status 'UNAVAILABLE' -Value $null
    }

    Add-RegistryResult -Name 'VBS configured' -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' -Property 'EnableVirtualizationBasedSecurity'
    Add-RegistryResult -Name 'Credential Guard configured' -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Property 'LsaCfgFlags'
    Add-RegistryResult -Name 'LSA protection (RunAsPPL)' -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Property 'RunAsPPL'
    Add-RegistryResult -Name 'UAC EnableLUA' -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Property 'EnableLUA'
    Add-RegistryResult -Name 'UAC consent behavior' -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Property 'ConsentPromptBehaviorAdmin'
    Add-RegistryResult -Name 'SmartScreen Explorer policy' -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Property 'SmartScreenEnabled'
    Add-RegistryResult -Name 'AutoRun policy' -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Property 'NoDriveTypeAutoRun'
    Add-RegistryResult -Name 'RDP deny connections policy' -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Property 'fDenyTSConnections'

    try {
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        Add-Result -Category 'PlatformSecurity' -Name 'Hypervisor present' -Status 'INFO' -Value $computerSystem.HypervisorPresent -Details 'A present hypervisor does not by itself prove that VBS or Memory Integrity is enabled.'
    }
    catch {
        Add-Result -Category 'PlatformSecurity' -Name 'Hypervisor status' -Status 'UNAVAILABLE' -Value $null -Details $_.Exception.Message
    }

    if (Test-CommandAvailable 'Confirm-SecureBootUEFI') {
        try {
            $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop
            $status = if ($secureBoot) { 'PASS' } else { 'REVIEW' }
            Add-Result -Category 'PlatformSecurity' -Name 'Secure Boot' -Status $status -Value $secureBoot
        }
        catch {
            Add-Result -Category 'PlatformSecurity' -Name 'Secure Boot' -Status 'UNAVAILABLE' -Value $null -Details 'Unavailable on legacy BIOS, unsupported firmware, or restricted sessions.'
        }
    }
    else {
        Add-Result -Category 'PlatformSecurity' -Name 'Secure Boot cmdlet' -Status 'UNAVAILABLE' -Value $null
    }

    if (Test-CommandAvailable 'Get-Tpm') {
        try {
            $tpm = Get-Tpm -ErrorAction Stop
            Add-Result -Category 'PlatformSecurity' -Name 'TPM present' -Status $(if ($tpm.TpmPresent) { 'PASS' } else { 'REVIEW' }) -Value $tpm.TpmPresent
            Add-Result -Category 'PlatformSecurity' -Name 'TPM ready' -Status $(if ($tpm.TpmReady) { 'PASS' } else { 'REVIEW' }) -Value $tpm.TpmReady
            Add-Result -Category 'PlatformSecurity' -Name 'TPM enabled' -Status 'INFO' -Value $tpm.TpmEnabled
        }
        catch {
            Add-Result -Category 'PlatformSecurity' -Name 'TPM inventory' -Status 'UNAVAILABLE' -Value $null -Details $_.Exception.Message
        }
    }
    else {
        Add-Result -Category 'PlatformSecurity' -Name 'TPM cmdlets' -Status 'UNAVAILABLE' -Value $null
    }

    try {
        $deviceGuard = Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction Stop
        Add-Result -Category 'PlatformSecurity' -Name 'Device Guard security services configured' -Status 'INFO' -Value ($deviceGuard.SecurityServicesConfigured -join ',')
        Add-Result -Category 'PlatformSecurity' -Name 'Device Guard security services running' -Status 'INFO' -Value ($deviceGuard.SecurityServicesRunning -join ',')
        Add-Result -Category 'PlatformSecurity' -Name 'VBS status (0=off, 1=configured, 2=running)' -Status 'INFO' -Value $deviceGuard.VirtualizationBasedSecurityStatus
        Add-Result -Category 'PlatformSecurity' -Name 'Available security properties' -Status 'INFO' -Value ($deviceGuard.AvailableSecurityProperties -join ',')
    }
    catch {
        Add-Result -Category 'PlatformSecurity' -Name 'Device Guard WMI inventory' -Status 'UNAVAILABLE' -Value $null -Details $_.Exception.Message
    }

    if (Test-CommandAvailable 'Get-SmbClientConfiguration') {
        try {
            $smbClient = Get-SmbClientConfiguration -ErrorAction Stop
            foreach ($propertyName in @('RequireSecuritySignature', 'EnableSecuritySignature', 'EnableInsecureGuestLogons', 'RequireEncryption', 'BlockNTLM')) {
                $property = $smbClient.PSObject.Properties[$propertyName]
                if ($null -ne $property) {
                    Add-Result -Category 'SMB' -Name ('Client ' + $propertyName) -Status 'INFO' -Value $property.Value
                }
            }
        }
        catch {
            Add-Result -Category 'SMB' -Name 'Client configuration' -Status 'ERROR' -Value $null -Details $_.Exception.Message
        }
    }
    else {
        Add-Result -Category 'SMB' -Name 'Client cmdlets' -Status 'UNAVAILABLE' -Value $null
    }

    if (Test-CommandAvailable 'Get-SmbServerConfiguration') {
        try {
            $smbServer = Get-SmbServerConfiguration -ErrorAction Stop
            foreach ($propertyName in @('EnableSMB1Protocol', 'EnableSMB2Protocol', 'EnableSecuritySignature', 'RequireSecuritySignature', 'EnableEncryptData')) {
                $property = $smbServer.PSObject.Properties[$propertyName]
                if ($null -ne $property) {
                    Add-Result -Category 'SMB' -Name ('Server ' + $propertyName) -Status 'INFO' -Value $property.Value
                }
            }
        }
        catch {
            Add-Result -Category 'SMB' -Name 'Server configuration' -Status 'ERROR' -Value $null -Details $_.Exception.Message
        }
    }
    else {
        Add-Result -Category 'SMB' -Name 'Server cmdlets' -Status 'UNAVAILABLE' -Value $null
    }

    $serviceNames = @(
        'LanmanServer', 'LanmanWorkstation', 'FDResPub', 'fdPHost',
        'SSDPSRV', 'upnphost', 'WlanSvc', 'DoSvc', 'Spooler',
        'SharedAccess', 'vmcompute', 'vmms', 'WslService', 'Sense',
        'WinDefend', 'wscsvc', 'RemoteRegistry', 'TermService'
    )

    foreach ($serviceName in $serviceNames) {
        try {
            $service = Get-CimInstance -ClassName Win32_Service -Filter ("Name='{0}'" -f $serviceName) -ErrorAction Stop
            if ($null -ne $service) {
                Add-Result -Category 'Services' -Name $serviceName -Status 'INFO' -Value ($service.State + ' / ' + $service.StartMode)
            }
            else {
                Add-Result -Category 'Services' -Name $serviceName -Status 'UNAVAILABLE' -Value 'Not installed'
            }
        }
        catch {
            Add-Result -Category 'Services' -Name $serviceName -Status 'UNAVAILABLE' -Value $null -Details $_.Exception.Message
        }
    }

    if (Test-CommandAvailable 'Get-NetAdapter') {
        try {
            foreach ($adapter in (Get-NetAdapter -IncludeHidden -ErrorAction Stop)) {
                Add-Result -Category 'Network' -Name ('Adapter: ' + $adapter.Name) -Status 'INFO' -Value ($adapter.Status + ' / ' + $adapter.InterfaceDescription)
            }
        }
        catch {
            Add-Result -Category 'Network' -Name 'Adapter inventory' -Status 'ERROR' -Value $null -Details $_.Exception.Message
        }
    }
    else {
        Add-Result -Category 'Network' -Name 'NetAdapter cmdlets' -Status 'UNAVAILABLE' -Value $null
    }

    if (Test-CommandAvailable 'Get-NetConnectionProfile') {
        try {
            foreach ($profile in (Get-NetConnectionProfile -ErrorAction Stop)) {
                Add-Result -Category 'Network' -Name ('Profile: ' + $profile.Name) -Status 'INFO' -Value ($profile.NetworkCategory + ' / ' + $profile.InterfaceAlias)
            }
        }
        catch {
            Add-Result -Category 'Network' -Name 'Connection profile inventory' -Status 'ERROR' -Value $null -Details $_.Exception.Message
        }
    }
    else {
        Add-Result -Category 'Network' -Name 'Connection profile cmdlets' -Status 'UNAVAILABLE' -Value $null
    }

    if (Test-CommandAvailable 'Get-BitLockerVolume') {
        try {
            foreach ($volume in (Get-BitLockerVolume -ErrorAction Stop)) {
                Add-Result -Category 'Storage' -Name ('BitLocker: ' + $volume.MountPoint) -Status 'INFO' -Value ($volume.VolumeStatus + ' / ' + $volume.ProtectionStatus)
            }
        }
        catch {
            Add-Result -Category 'Storage' -Name 'BitLocker inventory' -Status 'ERROR' -Value $null -Details $_.Exception.Message
        }
    }
    else {
        Add-Result -Category 'Storage' -Name 'BitLocker cmdlets' -Status 'UNAVAILABLE' -Value $null -Details 'Availability depends on edition, hardware and optional management components.'
    }

    if (Test-CommandAvailable 'Get-DOConfig') {
        try {
            $deliveryOptimization = Get-DOConfig -ErrorAction Stop
            Add-Result -Category 'DeliveryOptimization' -Name 'DownloadMode' -Status 'INFO' -Value $deliveryOptimization.DODownloadMode
        }
        catch {
            Add-Result -Category 'DeliveryOptimization' -Name 'Configuration query' -Status 'ERROR' -Value $null -Details $_.Exception.Message
        }
    }
    else {
        Add-Result -Category 'DeliveryOptimization' -Name 'Get-DOConfig cmdlet' -Status 'UNAVAILABLE' -Value $null
    }

    $script:Results | Format-Table -AutoSize -Wrap
    Write-Host ''
    Write-Host 'Status counts:' -ForegroundColor Cyan
    foreach ($statusName in @('PASS', 'REVIEW', 'FAIL', 'ERROR', 'INFO', 'UNAVAILABLE')) {
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
    $base = 'Win11-Hardening-Audit-{0}-{1}' -f $stamp, $suffix
    $json = Join-Path $Directory ($base + '.json')
    $csv = Join-Path $Directory ($base + '.csv')
    $txt = Join-Path $Directory ($base + '.txt')

    $metadata = [pscustomobject]@{
        Project         = 'MyWindowsHardening'
        ScriptVersion   = $script:ScriptVersion
        Mode            = $Mode
        StartedAt       = $script:StartedAt.ToString('o')
        FinishedAt      = (Get-Date).ToString('o')
        ComputerName    = $env:COMPUTERNAME
        ReadOnly        = $true
        Results         = @($script:Results)
    }

    $metadata | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $json -Encoding UTF8 -ErrorAction Stop
    $script:Results | Export-Csv -LiteralPath $csv -NoTypeInformation -Encoding UTF8 -ErrorAction Stop

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('MyWindowsHardening - Windows 11 Audit')
    $lines.Add(('Computer: {0}' -f $env:COMPUTERNAME))
    $lines.Add(('Generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
    $lines.Add(('ScriptVersion: {0}' -f $script:ScriptVersion))
    $lines.Add('ReadOnly: True')
    $lines.Add('')
    foreach ($result in $script:Results) {
        $lines.Add(('[{0}] {1} / {2} = {3} {4}' -f $result.Status, $result.Category, $result.Name, $result.Value, $result.Details))
    }
    $lines | Set-Content -LiteralPath $txt -Encoding UTF8 -ErrorAction Stop

    Write-Host ''
    Write-Host 'Reports saved:' -ForegroundColor Green
    Write-Host $json
    Write-Host $csv
    Write-Host $txt
}

if ($Mode -eq 'Apply' -or $Mode -eq 'Restore') {
    throw ("Mode '{0}' is intentionally unavailable in {1}. This release is read-only; no system settings were changed." -f $Mode, $script:ScriptVersion)
}

try {
    Invoke-ReadOnlyAudit
    Save-AuditReport -Directory $OutputDirectory

    if ($script:SystemInventoryFailed) {
        Write-Warning 'The system inventory was incomplete; inspect ERROR and UNAVAILABLE results.'
        exit 1
    }

    if ($script:UnsupportedClient -or $script:ServicingExpired) {
        Write-Warning 'The system is outside the supported client scope or its feature release has reached end of updates.'
        exit 2
    }

    exit 0
}
catch {
    Write-Error ("Audit or report generation failed: {0}" -f $_.Exception.Message)
    exit 1
}
