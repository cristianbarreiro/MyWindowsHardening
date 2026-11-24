#requires -Version 5.1
<#
.SYNOPSIS
    MyWindowsHardening - Microsoft Defender protection audit for Windows 10/11.
.DESCRIPTION
    Read-only inventory of Microsoft Defender Antivirus, protection modes,
    ASR rule actions, and exclusion counts. Does not change Defender settings.
.NOTES
    Version: 0.1.0-readonly
    Platform: Windows 10/11 client; Windows PowerShell 5.1
    Report files may disclose security posture and must be protected.
#>
[CmdletBinding()]
param(
    [ValidateSet('Audit', 'Report')]
    [string]$Mode = 'Audit',
    [string]$OutputDirectory = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$script:ScriptVersion = '0.1.0-readonly'
$script:StartedAt = Get-Date
$script:Results = New-Object System.Collections.Generic.List[object]
$script:SystemInventoryFailed = $false

function Add-Result {
    param(
        [string]$Category,
        [string]$Name,
        [ValidateSet('PASS', 'REVIEW', 'FAIL', 'ERROR', 'INFO', 'UNAVAILABLE')]
        [string]$Status,
        [AllowNull()][object]$Value,
        [string]$EvidenceSource = '',
        [string]$Details = ''
    )

    $script:Results.Add([pscustomobject]@{
        Category = $Category
        Name = $Name
        Status = $Status
        Value = if ($null -eq $Value) { $null } elseif ($Value -is [array]) { $Value -join ', ' } else { [string]$Value }
        EvidenceSource = $EvidenceSource
        Details = $Details
    }) | Out-Null
}

function Test-CommandAvailable {
    param([Parameter(Mandatory = $true)][string]$Name)
    return $null -ne (Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Get-ObjectPropertyValue {
    param(
        [AllowNull()][object]$InputObject,
        [Parameter(Mandatory = $true)][string]$PropertyName
    )

    if ($null -eq $InputObject) {
        return $null
    }

    $property = $InputObject.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Add-BooleanResult {
    param(
        [string]$Category,
        [string]$Name,
        [AllowNull()][object]$Value,
        [string]$EvidenceSource,
        [string]$Details = ''
    )

    if ($null -eq $Value) {
        Add-Result $Category $Name 'UNAVAILABLE' $null $EvidenceSource 'Property was not exposed by this platform or Defender version.'
    }
    elseif ([bool]$Value) {
        Add-Result $Category $Name 'PASS' $true $EvidenceSource $Details
    }
    else {
        Add-Result $Category $Name 'REVIEW' $false $EvidenceSource $Details
    }
}

function Add-DisabledFlagResult {
    param(
        [object]$Preferences,
        [string]$PropertyName,
        [string]$DisplayName
    )

    $value = Get-ObjectPropertyValue -InputObject $Preferences -PropertyName $PropertyName
    if ($null -eq $value) {
        Add-Result 'DefenderPreferences' $DisplayName 'UNAVAILABLE' $null 'Get-MpPreference' 'Preference is not exposed on this Windows/Defender version.'
    }
    elseif ([bool]$value) {
        Add-Result 'DefenderPreferences' $DisplayName 'REVIEW' $true 'Get-MpPreference' 'The corresponding protection-disable flag is set.'
    }
    else {
        Add-Result 'DefenderPreferences' $DisplayName 'PASS' $false 'Get-MpPreference' 'The corresponding protection-disable flag is not set.'
    }
}

function Add-ProtectionModeResult {
    param(
        [object]$Preferences,
        [string]$PropertyName,
        [string]$DisplayName
    )

    $value = Get-ObjectPropertyValue -InputObject $Preferences -PropertyName $PropertyName
    if ($null -eq $value) {
        Add-Result 'DefenderPreferences' $DisplayName 'UNAVAILABLE' $null 'Get-MpPreference' 'Preference is not exposed on this Windows/Defender version.'
        return
    }

    switch ([string]$value) {
        '1' { Add-Result 'DefenderPreferences' $DisplayName 'PASS' 'Enabled / Block' 'Get-MpPreference' 'Protection is enabled in enforcement mode.'; return }
        '2' { Add-Result 'DefenderPreferences' $DisplayName 'INFO' 'Audit' 'Get-MpPreference' 'Audit mode records detections but does not enforce the block.'; return }
        '0' { Add-Result 'DefenderPreferences' $DisplayName 'REVIEW' 'Disabled' 'Get-MpPreference' 'Protection is disabled.'; return }
        default { Add-Result 'DefenderPreferences' $DisplayName 'REVIEW' $value 'Get-MpPreference' 'Unknown or platform-specific mode; verify against the installed Defender version.' }
    }
}

function Add-AsrRuleResults {
    param([object]$Preferences)

    $ids = @(Get-ObjectPropertyValue -InputObject $Preferences -PropertyName 'AttackSurfaceReductionRules_Ids')
    $actions = @(Get-ObjectPropertyValue -InputObject $Preferences -PropertyName 'AttackSurfaceReductionRules_Actions')

    if ($ids.Count -eq 0 -and $actions.Count -eq 0) {
        Add-Result 'ASR' 'Configured rules' 'INFO' 0 'Get-MpPreference' 'No configured ASR rule pairs were returned. This is not a recommendation to enable every rule.'
        return
    }

    if ($ids.Count -ne $actions.Count) {
        Add-Result 'ASR' 'Rule ID/action array consistency' 'REVIEW' ("IDs={0}; Actions={1}" -f $ids.Count, $actions.Count) 'Get-MpPreference' 'The arrays have different lengths; individual mappings may be incomplete.'
    }

    $count = [Math]::Min($ids.Count, $actions.Count)
    for ($index = 0; $index -lt $count; $index++) {
        $action = [string]$actions[$index]
        $status = 'REVIEW'
        $meaning = 'Unrecognized action; review the local Defender version.'

        switch -Regex ($action) {
            '^(1|Enabled)$' { $status = 'PASS'; $meaning = 'Block mode'; break }
            '^(2|AuditMode|Audit)$' { $status = 'INFO'; $meaning = 'Audit mode; detections are not blocked'; break }
            '^(0|Disabled)$' { $status = 'REVIEW'; $meaning = 'Disabled'; break }
            '^(5|NotConfigured)$' { $status = 'INFO'; $meaning = 'Not configured'; break }
            '^(6|Warn)$' { $status = 'INFO'; $meaning = 'Warn mode'; break }
        }

        Add-Result 'ASR' ("Rule {0}" -f $ids[$index]) $status $action 'Get-MpPreference' $meaning
    }
}

function Add-ExclusionInventory {
    param([object]$Preferences)

    $exclusionProperties = @(
        @{ Property = 'ExclusionPath'; Name = 'Antivirus path exclusions' },
        @{ Property = 'ExclusionProcess'; Name = 'Antivirus process exclusions' },
        @{ Property = 'ExclusionExtension'; Name = 'Antivirus extension exclusions' },
        @{ Property = 'AttackSurfaceReductionOnlyExclusions'; Name = 'ASR-only exclusions' },
        @{ Property = 'ControlledFolderAccessAllowedApplications'; Name = 'Controlled Folder Access allowed applications' },
        @{ Property = 'ControlledFolderAccessProtectedFolders'; Name = 'Additional Controlled Folder Access protected folders' }
    )

    foreach ($entry in $exclusionProperties) {
        $value = Get-ObjectPropertyValue -InputObject $Preferences -PropertyName $entry.Property
        if ($null -eq $value) {
            Add-Result 'Exclusions' $entry.Name 'UNAVAILABLE' $null 'Get-MpPreference' 'Property is not exposed by this Defender version.'
            continue
        }

        $count = @($value).Count
        $status = if ($count -gt 0 -and $entry.Property -notlike '*ProtectedFolders') { 'REVIEW' } else { 'INFO' }
        $details = if ($count -gt 0 -and $entry.Property -notlike '*ProtectedFolders') {
            'Count only; paths and executable names are intentionally omitted from reports. Review each entry locally.'
        } else {
            'Count only; individual paths are not copied into the report.'
        }
        Add-Result 'Exclusions' $entry.Name $status $count 'Get-MpPreference' $details
    }
}

function Invoke-DefenderAudit {
    Write-Host ''
    Write-Host 'MyWindowsHardening - Microsoft Defender protection audit' -ForegroundColor Cyan
    Write-Host ('Mode: {0} | Version: {1}' -f $Mode, $script:ScriptVersion)
    Write-Host 'READ ONLY - no Defender settings will be changed.' -ForegroundColor Green
    Write-Host ''

    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $cv = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
        $build = [int]$cv.CurrentBuildNumber
        $platform = if ($build -ge 22000) { 'Windows 11' } else { 'Windows 10' }

        Add-Result 'System' 'Product' 'INFO' $os.Caption 'Win32_OperatingSystem'
        Add-Result 'System' 'Platform' 'INFO' $platform 'Win32_OperatingSystem / CurrentVersion'
        Add-Result 'System' 'Edition' 'INFO' $cv.EditionID 'CurrentVersion'
        Add-Result 'System' 'DisplayVersion' 'INFO' $cv.DisplayVersion 'CurrentVersion'
        Add-Result 'System' 'Build' 'INFO' ('{0}.{1}' -f $build, $cv.UBR) 'CurrentVersion'

        if ($os.ProductType -ne 1 -or $build -lt 10240 -or $build -ge 22000 -and $platform -ne 'Windows 11') {
            Add-Result 'Compatibility' 'Windows client platform' 'FAIL' $false 'Win32_OperatingSystem' 'This auditor supports Windows 10/11 client editions only.'
            $script:SystemInventoryFailed = $true
        }
        else {
            Add-Result 'Compatibility' 'Windows client platform' 'PASS' $true 'Win32_OperatingSystem'
        }
    }
    catch {
        Add-Result 'System' 'Operating system inventory' 'ERROR' $null 'CIM / Registry' $_.Exception.Message
        $script:SystemInventoryFailed = $true
    }

    if (-not (Test-CommandAvailable 'Get-MpComputerStatus')) {
        Add-Result 'Defender' 'Get-MpComputerStatus cmdlet' 'UNAVAILABLE' $null 'Get-Command' 'Defender PowerShell module or command is unavailable in this session.'
    }
    else {
        try {
            $status = Get-MpComputerStatus -ErrorAction Stop
            foreach ($item in @(
                @{ Property = 'AMServiceEnabled'; Name = 'Antimalware service enabled' },
                @{ Property = 'AntivirusEnabled'; Name = 'Antivirus enabled' },
                @{ Property = 'RealTimeProtectionEnabled'; Name = 'Real-time protection' },
                @{ Property = 'BehaviorMonitorEnabled'; Name = 'Behavior monitoring' },
                @{ Property = 'IoavProtectionEnabled'; Name = 'IOAV protection' },
                @{ Property = 'OnAccessProtectionEnabled'; Name = 'On-access protection' },
                @{ Property = 'IsTamperProtected'; Name = 'Tamper Protection' }
            )) {
                $value = Get-ObjectPropertyValue -InputObject $status -PropertyName $item.Property
                Add-BooleanResult 'Defender' $item.Name $value 'Get-MpComputerStatus' 'False may be expected when another security product or an organization-managed policy owns protection.'
            }

            foreach ($item in @(
                @{ Property = 'AMRunningMode'; Name = 'Antimalware running mode' },
                @{ Property = 'AMEngineVersion'; Name = 'Antimalware engine version' },
                @{ Property = 'AMProductVersion'; Name = 'Antimalware platform version' },
                @{ Property = 'AntivirusSignatureVersion'; Name = 'Antivirus signature version' },
                @{ Property = 'AntivirusSignatureAge'; Name = 'Antivirus signature age (days)' },
                @{ Property = 'AntivirusSignatureLastUpdated'; Name = 'Antivirus signatures last updated' }
            )) {
                $value = Get-ObjectPropertyValue -InputObject $status -PropertyName $item.Property
                $detail = if ($item.Property -eq 'AntivirusSignatureAge') {
                    'Informational only; compare with the organization update policy and connectivity conditions.'
                } else { '' }

                $resultStatus = 'INFO'
                if ($item.Property -eq 'AMRunningMode' -and
                    $null -ne $value -and [string]$value -notmatch 'Normal') {
                    $resultStatus = 'REVIEW'
                    $detail = 'A passive or alternative running mode may be intentional; verify the active endpoint security product.'
                }
                Add-Result 'Defender' $item.Name $resultStatus $value 'Get-MpComputerStatus' $detail
            }
        }
        catch {
            Add-Result 'Defender' 'Antimalware status query' 'ERROR' $null 'Get-MpComputerStatus' $_.Exception.Message
        }
    }

    if (-not (Test-CommandAvailable 'Get-MpPreference')) {
        Add-Result 'DefenderPreferences' 'Get-MpPreference cmdlet' 'UNAVAILABLE' $null 'Get-Command' 'Defender preference cmdlet is unavailable in this session.'
    }
    else {
        try {
            $preferences = Get-MpPreference -ErrorAction Stop

            foreach ($item in @(
                @{ Property = 'DisableRealtimeMonitoring'; Name = 'Real-time monitoring disable flag' },
                @{ Property = 'DisableBehaviorMonitoring'; Name = 'Behavior monitoring disable flag' },
                @{ Property = 'DisableIOAVProtection'; Name = 'IOAV disable flag' },
                @{ Property = 'DisableScriptScanning'; Name = 'Script scanning disable flag' }
            )) {
                Add-DisabledFlagResult -Preferences $preferences -PropertyName $item.Property -DisplayName $item.Name
            }

            Add-ProtectionModeResult -Preferences $preferences -PropertyName 'PUAProtection' -DisplayName 'Potentially unwanted application protection'
            Add-ProtectionModeResult -Preferences $preferences -PropertyName 'EnableControlledFolderAccess' -DisplayName 'Controlled Folder Access'
            Add-ProtectionModeResult -Preferences $preferences -PropertyName 'EnableNetworkProtection' -DisplayName 'Network Protection'

            foreach ($item in @(
                @{ Property = 'MAPSReporting'; Name = 'Cloud-delivered protection reporting preference' },
                @{ Property = 'SubmitSamplesConsent'; Name = 'Automatic sample submission preference' }
            )) {
                $value = Get-ObjectPropertyValue -InputObject $preferences -PropertyName $item.Property
                Add-Result 'DefenderPreferences' $item.Name 'INFO' $value 'Get-MpPreference' 'Informational privacy/configuration setting; no universal value is imposed.'
            }

            Add-AsrRuleResults -Preferences $preferences
            Add-ExclusionInventory -Preferences $preferences
        }
        catch {
            Add-Result 'DefenderPreferences' 'Preference inventory' 'ERROR' $null 'Get-MpPreference' $_.Exception.Message
        }
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
    $suffix = [guid]::NewGuid().ToString('N').Substring(0, 8)
    $base = 'Defender-Protection-Audit-{0}-{1}' -f $stamp, $suffix
    $metadata = [pscustomobject]@{
        Project = 'MyWindowsHardening'
        ReportSchemaVersion = 1
        ScriptVersion = $script:ScriptVersion
        Mode = $Mode
        StartedAt = $script:StartedAt.ToString('o')
        FinishedAt = (Get-Date).ToString('o')
        ComputerName = $env:COMPUTERNAME
        ReadOnly = $true
        Results = @($script:Results)
    }

    $metadata | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $Directory ($base + '.json')) -Encoding UTF8 -ErrorAction Stop
    $script:Results | Export-Csv -LiteralPath (Join-Path $Directory ($base + '.csv')) -NoTypeInformation -Encoding UTF8 -ErrorAction Stop

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('MyWindowsHardening - Microsoft Defender protection audit')
    $lines.Add(('Computer: {0}' -f $env:COMPUTERNAME))
    $lines.Add(('Generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
    $lines.Add(('ScriptVersion: {0}' -f $script:ScriptVersion))
    $lines.Add('ReadOnly: True')
    $lines.Add('')
    foreach ($result in $script:Results) {
        $lines.Add(('[{0}] {1} / {2} = {3} {4}' -f $result.Status, $result.Category, $result.Name, $result.Value, $result.Details))
    }
    $lines | Set-Content -LiteralPath (Join-Path $Directory ($base + '.txt')) -Encoding UTF8 -ErrorAction Stop

    Write-Host ''
    Write-Host 'Reports saved:' -ForegroundColor Green
    Write-Host (Join-Path $Directory ($base + '.json'))
    Write-Host (Join-Path $Directory ($base + '.csv'))
    Write-Host (Join-Path $Directory ($base + '.txt'))
    Write-Warning 'Reports disclose endpoint protection posture. Protect the files and sanitize host/network identifiers before sharing.'
}

try {
    Invoke-DefenderAudit
    if ($Mode -eq 'Report' -or -not [string]::IsNullOrWhiteSpace($OutputDirectory)) {
        Save-AuditReport -Directory $OutputDirectory
    }

    if ($script:SystemInventoryFailed) {
        Write-Warning 'System inventory failed or the platform is unsupported.'
        exit 1
    }
    exit 0
}
catch {
    Write-Error ("Defender audit or report generation failed: {0}" -f $_.Exception.Message)
    exit 1
}
