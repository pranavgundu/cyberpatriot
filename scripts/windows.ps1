#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [switch]$Apply,

    [ValidateSet('Auto', 'Workstation', 'Server')]
    [string]$Profile = 'Auto',

    [ValidateSet('Inventory', 'Base', 'Passwords', 'Firewall', 'Defender', 'RDP', 'SMB', 'Audit', 'Updates', 'Users', 'Services')]
    [string[]]$Modules = @(
        'Inventory', 'Base', 'Passwords', 'Firewall', 'Defender', 'RDP',
        'SMB', 'Audit', 'Updates', 'Users', 'Services'
    ),

    [string]$OutputDirectory
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:Controller = $PSCmdlet
$script:Failures = 0
$script:RegistryBackedUp = @{}


if ($env:OS -ne 'Windows_NT') {
    throw 'Windows only. No changes made.'
}

if (-not [Environment]::Is64BitProcess) {
    throw 'Run the 64-bit Windows PowerShell host.'
}

$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$isAdmin   = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$computer = Get-CimInstance Win32_ComputerSystem
$os       = Get-CimInstance Win32_OperatingSystem
$isDC     = ([int]$computer.DomainRole -in @(4, 5))
$isServer = ([int]$os.ProductType -ne 1)
$detected = if ($isServer) { 'Server' } else { 'Workstation' }

if ($Apply -and -not $isAdmin) {
    throw 'Run Apply in an elevated PowerShell window.'
}

if ($Apply -and $isDC) {
    throw 'Domain controllers are audit-only. Use role-specific domain policies; this script will not change them.'
}

if ($Profile -ne 'Auto' -and $Profile -ne $detected) {
    throw "Profile mismatch: detected $detected."
}


if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $env:TEMP ('CyberPatriot-' + [guid]::NewGuid().ToString('N'))
}

$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)

if (Test-Path -LiteralPath $OutputDirectory) {
    throw 'OutputDirectory must be a NEW directory to avoid overwriting backups.'
}

New-Item -ItemType Directory -Path $OutputDirectory -WhatIf:$false | Out-Null

$acl = New-Object System.Security.AccessControl.DirectorySecurity
$acl.SetAccessRuleProtection($true, $false)

$ownerSids = @(
    $identity.User,
    (New-Object Security.Principal.SecurityIdentifier('S-1-5-18')),
    (New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544'))
)

foreach ($sid in $ownerSids) {
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $sid, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'
    )
    $acl.AddAccessRule($rule)
}

Set-Acl -LiteralPath $OutputDirectory -AclObject $acl -WhatIf:$false
Start-Transcript -Path (Join-Path $OutputDirectory 'session.log') -Force -WhatIf:$false | Out-Null


function Confirm-Change([string]$Description) {
    if (-not $Apply) {
        Write-Host "AUDIT ONLY: $Description"
        return $false
    }

    if ($WhatIfPreference) {
        [void]$script:Controller.ShouldProcess($env:COMPUTERNAME, $Description)
        return $false
    }

    if ((Read-Host "$Description [type YES to apply]") -cne 'YES') {
        return $false
    }

    return $script:Controller.ShouldProcess($env:COMPUTERNAME, $Description)
}


function Test-RemoteSession {
    return [bool]($env:SESSIONNAME -like 'RDP*' -or (Get-Variable PSSenderInfo -ErrorAction SilentlyContinue))
}


function Invoke-Native([string]$Program, [string[]]$Arguments) {
    & $Program @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "$Program exited with code $LASTEXITCODE"
    }
}


function Backup-Registry([string]$Key) {
    if ($script:RegistryBackedUp.ContainsKey($Key)) {
        return
    }

    $native   = $Key -replace '^HKLM:\\', 'HKLM\'
    $filename = ($native -replace '[^A-Za-z0-9.-]', '_') + '.reg'
    $backup   = Join-Path $OutputDirectory $filename

    if (-not (Test-Path -LiteralPath $Key)) {
        Add-Content -Path (Join-Path $OutputDirectory 'originally-absent-registry-keys.txt') -Value $native
    }
    elseif (-not (Test-Path -LiteralPath $backup)) {
        Invoke-Native reg.exe @('export', $native, $backup, '/y')
    }

    $script:RegistryBackedUp[$Key] = $true
}


function Set-RegistryValue([string]$Key, [string]$Name, $Value, [string]$Type = 'DWord') {
    Backup-Registry $Key

    if (-not (Test-Path -LiteralPath $Key)) {
        New-Item -Path $Key -Force | Out-Null
    }

    New-ItemProperty -Path $Key -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
    Write-Host "$Key\$Name = $Value"
}


function Export-SecurityPolicy {
    $file = Join-Path $OutputDirectory 'security-policy-before.inf'

    if (Test-Path -LiteralPath $file) {
        return
    }

    Invoke-Native secedit.exe @(
        '/export',
        '/cfg', $file,
        '/areas', 'SECURITYPOLICY',
        '/log', (Join-Path $OutputDirectory 'secedit-export.log')
    )
}


function Show-Inventory {
    Write-Host "OS: $($os.Caption) $($os.Version)"
    Write-Host "Profile: $detected; domain controller: $isDC; domain joined: $($computer.PartOfDomain)"
    Write-Host 'Compare everything with THIS image README. Past usernames/programs are not automatic removal targets.'

    if (Get-Command Get-LocalUser -ErrorAction SilentlyContinue) {
        Get-LocalUser |
            Select-Object Name, Enabled, PasswordRequired, PasswordExpires, LastLogon, SID |
            Format-Table -AutoSize

        foreach ($sid in @('S-1-5-32-544', 'S-1-5-32-555')) {
            try {
                Get-LocalGroupMember -SID $sid |
                    Select-Object Name, SID, PrincipalSource |
                    Format-Table -AutoSize
            }
            catch {
                Write-Warning $_.Exception.Message
            }
        }
    }

    Get-CimInstance Win32_Service |
        Where-Object { $_.State -eq 'Running' -or $_.StartMode -eq 'Auto' } |
        Select-Object Name, State, StartMode, StartName, PathName |
        Format-Table -Wrap

    Get-NetTCPConnection -State Listen |
        Select-Object LocalAddress, LocalPort, OwningProcess |
        Sort-Object LocalPort |
        Format-Table -AutoSize

    Get-NetUDPEndpoint |
        Select-Object LocalAddress, LocalPort, OwningProcess |
        Sort-Object LocalPort |
        Format-Table -AutoSize

    Get-ScheduledTask |
        Select-Object TaskPath, TaskName, State |
        Format-Table -AutoSize

    $runKeys = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    )

    Get-ItemProperty $runKeys -ErrorAction SilentlyContinue | Format-List

    $uninstallKeys = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    foreach ($path in $uninstallKeys) {
        Get-ItemProperty $path -ErrorAction SilentlyContinue |
            Where-Object { $_.PSObject.Properties['DisplayName'] } |
            Select-Object DisplayName, DisplayVersion, Publisher |
            Sort-Object DisplayName |
            Format-Table -AutoSize
    }

    Write-Host 'Review media, browser history, authorized users, applications, startup items and scheduled tasks manually.'
    Write-Host 'No evidence is deleted.'
}


function Set-Base {
    $lsa       = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
    $system    = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
    $installer = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer'
    $explorer  = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
    $autoplay  = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'
    $assist    = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'
    $winlogon  = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'

    $settings = @(
        @($lsa,       'LimitBlankPasswordUse',      1),
        @($lsa,       'RestrictAnonymousSAM',       1),
        @($lsa,       'RestrictAnonymous',          1),
        @($lsa,       'EveryoneIncludesAnonymous',  0),
        @($lsa,       'NoLMHash',                   1),
        @($system,    'EnableLUA',                  1),
        @($system,    'ConsentPromptBehaviorAdmin', 5),
        @($system,    'PromptOnSecureDesktop',      1),
        @($system,    'DisableCAD',                 0),
        @($system,    'ShutdownWithoutLogon',       0),
        @($system,    'InactivityTimeoutSecs',      900),
        @($installer, 'AlwaysInstallElevated',      0),
        @($explorer,  'NoDriveTypeAutoRun',         255),
        @($explorer,  'NoAutorun',                  1),
        @($autoplay,  'NoAutoplayfornonVolume',     1),
        @($assist,    'fAllowToGetHelp',            0),
        @($assist,    'fAllowUnsolicited',          0)
    )

    foreach ($s in $settings) {
        $existing = Get-ItemProperty -LiteralPath $s[0] -Name $s[1] -ErrorAction SilentlyContinue
        $current  = if ($existing) { $existing.($s[1]) } else { '(not configured)' }

        Write-Host "$($s[1]): $current -> proposed $($s[2])"
    }

    if (-not (Confirm-Change 'Apply the displayed local-account/UAC/AutoRun/Remote Assistance/screen-lock baseline? README does not require those features?')) {
        return
    }

    foreach ($s in $settings) {
        Set-RegistryValue $s[0] $s[1] $s[2]
    }

    Set-RegistryValue $winlogon 'AutoAdminLogon' '0' 'String'

    Write-Host 'Existing plaintext autologon secrets are NOT deleted (may be forensic evidence).'
    Write-Host 'NoLMHash takes effect on subsequent password changes. Some settings require logoff/reboot.'
}


function Set-Passwords {
    Invoke-Native net.exe @('accounts')

    Write-Host 'Proposed LOCAL policy: min length 12, complexity, history 24, age 1/90, lockout 10 failures for 15 minutes (reset 15).'
    Write-Host 'These are generic defaults, not season-specific keys. Domain accounts remain governed by domain policy.'

    if (-not (Confirm-Change 'Do these exact password/lockout values match the README? Apply to local policy (no existing passwords changed)?')) {
        return
    }

    Export-SecurityPolicy

    $inf = @'
[Unicode]
Unicode=yes
[Version]
signature="$CHICAGO$"
Revision=1
[System Access]
MinimumPasswordAge = 1
MaximumPasswordAge = 90
MinimumPasswordLength = 12
PasswordComplexity = 1
PasswordHistorySize = 24
ClearTextPassword = 0
LockoutBadCount = 10
ResetLockoutCount = 15
LockoutDuration = 15
'@

    $cfg = Join-Path $OutputDirectory 'proposed-password-policy.inf'
    Set-Content -LiteralPath $cfg -Value $inf -Encoding Unicode

    Invoke-Native secedit.exe @(
        '/configure',
        '/db', (Join-Path $OutputDirectory 'policy.sdb'),
        '/cfg', $cfg,
        '/areas', 'SECURITYPOLICY',
        '/log', (Join-Path $OutputDirectory 'secedit-apply.log')
    )

    Invoke-Native net.exe @('accounts')
}


function Set-Firewall {
    Get-NetFirewallProfile |
        Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction |
        Format-Table

    if (-not $Apply) {
        return
    }

    if ($WhatIfPreference) {
        [void](Confirm-Change 'Enable all firewall profiles; inbound block/outbound allow; preserve existing allow rules; log dropped packets.')
        return
    }

    if (Test-RemoteSession) {
        Write-Warning 'Use the VM console for firewall changes. Remote session detected; skipped.'
        return
    }

    if (-not (Confirm-Change 'VM CONSOLE confirmed, all required ports known? Enable all firewall profiles with inbound block/outbound allow, preserving existing rules?')) {
        return
    }

    $ports = (Read-Host 'Required inbound ports separated by spaces, e.g. 22/tcp 3389/tcp; blank = none').Trim()
    $rules = @()

    if ($ports) {
        foreach ($port in ($ports -split '\s+')) {
            if ($port -notmatch '^(\d{1,5})/(tcp|udp)$') {
                throw "Invalid port: $port. Firewall unchanged."
            }

            $number = [int]$Matches[1]

            if ($number -lt 1 -or $number -gt 65535) {
                throw "Invalid port: $port. Firewall unchanged."
            }

            $rules += [pscustomobject]@{
                Port     = $number
                Protocol = $Matches[2].ToUpperInvariant()
            }
        }
    }

    Invoke-Native netsh.exe @('advfirewall', 'export', (Join-Path $OutputDirectory 'firewall-before.wfw'))

    foreach ($r in $rules) {
        $name = "CyberPatriot-Required-$($r.Protocol)-$($r.Port)"

        if (Get-NetFirewallRule -Name $name -ErrorAction SilentlyContinue) {
            Write-Warning "Existing rule $name preserved; inspect its scope/action manually."
            continue
        }

        $ruleParams = @{
            Name        = $name
            DisplayName = $name
            Group       = 'CyberPatriot opt-in rules'
            Direction   = 'Inbound'
            Action      = 'Allow'
            Protocol    = $r.Protocol
            LocalPort   = $r.Port
            Profile     = 'Any'
        }

        New-NetFirewallRule @ruleParams | Out-Null
    }

    $profileParams = @{
        Profile               = 'Domain', 'Private', 'Public'
        Enabled               = 'True'
        DefaultInboundAction  = 'Block'
        DefaultOutboundAction = 'Allow'
        LogBlocked            = 'True'
        LogMaxSizeKilobytes   = 16384
    }

    Set-NetFirewallProfile @profileParams

    Write-Host 'Existing inbound allow rules still apply; inspect overly broad rules.'
    Write-Host 'No reset/block-all-inbound override was used.'
}


function Set-Defender {
    if (-not (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue)) {
        Write-Warning 'Defender cmdlets unavailable. Verify installed antivirus manually.'
        return
    }

    $statusFields = @(
        'AMServiceEnabled',
        'AntivirusEnabled',
        'RealTimeProtectionEnabled',
        'AntivirusSignatureLastUpdated',
        'IsTamperProtected'
    )

    $preferenceFields = @(
        'DisableRealtimeMonitoring',
        'DisableBehaviorMonitoring',
        'DisableIOAVProtection',
        'DisableScriptScanning',
        'DisableArchiveScanning',
        'PUAProtection',
        'ExclusionPath',
        'ExclusionProcess',
        'ExclusionExtension'
    )

    Get-MpComputerStatus | Select-Object $statusFields | Format-List
    Get-MpPreference | Select-Object $preferenceFields | Format-List

    if (Confirm-Change 'Enable Defender real-time/behavior/download/script/archive scanning and PUA protection (confirm no required alternate antivirus)?') {
        Get-MpPreference | Export-Clixml (Join-Path $OutputDirectory 'defender-before.xml')

        $mpParams = @{
            DisableRealtimeMonitoring = $false
            DisableBehaviorMonitoring = $false
            DisableIOAVProtection     = $false
            DisableScriptScanning     = $false
            DisableArchiveScanning    = $false
            PUAProtection             = 'Enabled'
        }

        Set-MpPreference @mpParams

        Write-Host 'Tamper protection, central policy or third-party AV may prevent this.'
        Write-Host 'Existing exclusions are review-only; verify effective status.'
    }

    if (Confirm-Change 'Update Defender signatures now (network access; no automatic full scan/quarantine requested)?') {
        Update-MpSignature
    }
}


function Set-RDP {
    $serverKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
    $rdpKey    = Join-Path $serverKey 'WinStations\RDP-Tcp'
    $rdpFields = @('UserAuthentication', 'SecurityLayer', 'MinEncryptionLevel')

    Get-ItemProperty -LiteralPath $serverKey -Name fDenyTSConnections |
        Format-List fDenyTSConnections

    Get-ItemProperty -LiteralPath $rdpKey -Name $rdpFields -ErrorAction SilentlyContinue |
        Format-List $rdpFields

    if (-not (Test-Path -LiteralPath $rdpKey)) {
        Write-Warning 'RDP host configuration unavailable.'
        return
    }

    if (Confirm-Change 'Require NLA, TLS security layer and high encryption for RDP (does NOT enable RDP or change its firewall rules)?') {
        Set-RegistryValue $rdpKey 'UserAuthentication' 1
        Set-RegistryValue $rdpKey 'SecurityLayer' 2
        Set-RegistryValue $rdpKey 'MinEncryptionLevel' 3
    }

    if (Test-RemoteSession) {
        Write-Warning 'Remote session: disabling RDP is not offered.'
        return
    }

    if (Confirm-Change 'ONLY IF README forbids RDP and you are at the VM console: disable inbound RDP?') {
        Set-RegistryValue $serverKey 'fDenyTSConnections' 1
    }
}


function Set-SMB {
    if (-not (Get-Command Get-SmbServerConfiguration -ErrorAction SilentlyContinue)) {
        Write-Warning 'SMB cmdlets unavailable.'
        return
    }

    Get-SmbServerConfiguration |
        Select-Object EnableSMB1Protocol, EnableSMB2Protocol, EnableSecuritySignature, RequireSecuritySignature, EncryptData |
        Format-List

    Get-SmbClientConfiguration |
        Select-Object EnableSecuritySignature, RequireSecuritySignature |
        Format-List

    Write-Host 'Server profile preserves shares/SMB2/SMB3; no blanket service removal.'
    Write-Host 'SMB1-only or unsigned clients may stop working.'

    if (Confirm-Change 'README permits disabling SMB1 and requiring SMB signing? Apply without deleting shares or forcing encryption?') {
        Get-SmbServerConfiguration | Export-Clixml (Join-Path $OutputDirectory 'smb-server-before.xml')
        Get-SmbClientConfiguration | Export-Clixml (Join-Path $OutputDirectory 'smb-client-before.xml')

        Set-SmbServerConfiguration -EnableSMB1Protocol $false -EnableSecuritySignature $true -RequireSecuritySignature $true -Force
        Set-SmbClientConfiguration -EnableSecuritySignature $true -RequireSecuritySignature $true -Confirm:$false

        Set-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' 'AllowInsecureGuestAuth' 0
    }

    Write-Host 'The SMB1 optional client feature is NOT uninstalled automatically; review Windows features manually.'
}


function Set-Audit {
    $subcategories = [ordered]@{
        'Logon'                     = '0CCE9215'
        'Logoff'                    = '0CCE9216'
        'Account Lockout'           = '0CCE9217'
        'Credential Validation'     = '0CCE923F'
        'User Account Management'   = '0CCE9235'
        'Security Group Management' = '0CCE9237'
        'Audit Policy Change'       = '0CCE922F'
        'Process Creation'          = '0CCE922B'
    }

    Invoke-Native auditpol.exe @('/get', '/category:*')

    if (-not (Confirm-Change 'Enable advanced success/failure audit for logon/logoff/lockout, credential validation, account/group management, audit-policy change and process creation; enlarge Security log to 64 MiB?')) {
        return
    }

    Invoke-Native auditpol.exe @('/backup', ('/file:' + (Join-Path $OutputDirectory 'audit-before.csv')))

    & wevtutil.exe gl Security | Set-Content (Join-Path $OutputDirectory 'security-log-before.txt')

    if ($LASTEXITCODE -ne 0) {
        throw 'Could not back up Security log settings.'
    }

    Set-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'SCENoApplyLegacyAuditPolicy' 1

    foreach ($entry in $subcategories.GetEnumerator()) {
        $guid = '{' + $entry.Value + '-69AE-11D9-BED3-505054503030}'

        Write-Host "Auditing: $($entry.Key)"
        Invoke-Native auditpol.exe @('/set', "/subcategory:$guid", '/success:enable', '/failure:enable')
    }

    Invoke-Native wevtutil.exe @('sl', 'Security', '/ms:67108864')

    Write-Host 'Existing events retained. Command-line capture was not enabled (it can log secrets).'
}


function Set-Updates {
    $key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'

    Write-Host 'Review Windows Update and installed browser/application versions. No third-party package manager is installed.'

    Get-Service wuauserv, BITS -ErrorAction SilentlyContinue |
        Select-Object Name, Status, StartType |
        Format-Table

    Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue | Format-List

    if ($computer.PartOfDomain) {
        Write-Warning 'Domain joined: automatic-update policy changes skipped to preserve WSUS/management. Use approved update channel.'
        return
    }

    if (Confirm-Change 'Enable automatic update checking/download with notify-before-install (AUOptions 3); keep existing WSUS/source configuration?') {
        Set-RegistryValue $key 'NoAutoUpdate' 0
        Set-RegistryValue $key 'AUOptions' 3

        Write-Host 'wuauserv/BITS trigger-start behavior is preserved.'
        Write-Host 'Install approved OS/app updates manually; no reboot requested.'
    }

    if (Confirm-Change 'Search Windows Update for missing software updates and list titles (network access; no installation)?') {
        $session  = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $result   = $searcher.Search("IsInstalled=0 and IsHidden=0 and Type='Software'")

        $result.Updates | ForEach-Object { Write-Host $_.Title }

        Write-Host 'Review/install via Windows Update or your approved channel.'
        Write-Host 'No drivers, feature upgrades or applications installed by this script.'
    }
}


function Set-Users {
    if (-not (Get-Command Get-LocalUser -ErrorAction SilentlyContinue)) {
        Write-Warning 'Local account cmdlets unavailable.'
        return
    }

    Get-LocalUser |
        Select-Object Name, Enabled, PasswordRequired, SID |
        Format-Table -AutoSize

    if (Confirm-Change 'README does not require Guest: disable the built-in local Guest account (identified by SID, not localized name)?') {
        $guest = Get-LocalUser | Where-Object { $_.SID.Value -match '-501$' }

        if ($guest) {
            $guest | Export-Clixml (Join-Path $OutputDirectory 'guest-before.xml')
            $guest | Disable-LocalUser
        }
    }

    if (-not $Apply -or $WhatIfPreference) {
        return
    }

    $name = Read-Host 'ONE unauthorized LOCAL account to disable (blank = skip; no account files deleted)'

    if (-not $name) {
        return
    }

    $user = Get-LocalUser -Name $name

    $isCurrentUser = ($user.SID -eq $identity.User)
    $isBuiltIn     = ($user.SID.Value -match '-(500|501|503|504)$')

    if ($isCurrentUser -or $isBuiltIn) {
        throw 'Current and built-in/system accounts are protected; review manually.'
    }

    $adminSids = @(Get-LocalGroupMember -SID 'S-1-5-32-544' | ForEach-Object { $_.SID.Value })

    if ($user.SID.Value -in $adminSids) {
        $enabledLocalAdmins = @(Get-LocalUser | Where-Object { $_.Enabled -and $_.SID.Value -in $adminSids })

        if ($enabledLocalAdmins.Count -le 1) {
            throw 'Refusing to disable the last enabled local administrator. Verify another working local admin login first.'
        }
    }

    if (Confirm-Change "README confirms $name is unauthorized and NOT needed for service/scoring access? Disable it (existing sessions are not terminated)?") {
        $user | Export-Clixml (Join-Path $OutputDirectory 'disabled-account-before.xml')
        $user | Disable-LocalUser
    }

    Write-Host 'Administrator/group membership, new accounts and password resets require manual README review; they are never guessed.'
}


function Set-Services {
    $candidates = @(
        'TlntSvr',
        'FTPSVC',
        'RemoteRegistry',
        'SSDPSRV',
        'upnphost',
        'W3SVC',
        'Spooler',
        'RemoteAccess',
        'SNMP',
        'SharedAccess'
    )

    Get-Service -Name $candidates -ErrorAction SilentlyContinue |
        Select-Object Name, DisplayName, Status, StartType |
        Format-Table -AutoSize

    Write-Host 'These are REVIEW candidates, NOT necessarily prohibited.'
    Write-Host 'Print/IIS/FTP/routing may be required, especially on Server.'

    if (-not $Apply -or $WhatIfPreference) {
        return
    }

    $name = Read-Host 'ONE README-prohibited service name from the displayed list to disable (blank = skip)'

    if (-not $name) {
        return
    }

    if ($name -notin $candidates) {
        throw 'Not an allowlisted review candidate; handle manually.'
    }

    $svc = Get-Service -Name $name

    if ($svc.DependentServices | Where-Object { $_.Status -eq 'Running' }) {
        throw 'Running dependent services detected; handle manually.'
    }

    if (Confirm-Change "README confirms $name is NOT required by service roles or scoring? Stop and disable?") {
        Get-CimInstance Win32_Service -Filter ("Name='" + $name + "'") |
            Export-Clixml (Join-Path $OutputDirectory ('service-' + $name + '-before.xml'))

        Stop-Service -Name $name
        Set-Service -Name $name -StartupType Disabled
    }
}


try {
    Write-Host "CyberPatriot helper | $(Get-Date -Format o) | $detected | Apply=$Apply | WhatIf=$WhatIfPreference"
    Write-Host "Private logs/backups: $OutputDirectory"

    if ($computer.PartOfDomain) {
        Write-Warning 'Domain policy can override local settings. Do not bypass policy or alter domain identities.'
    }

    if ($Apply -and -not $WhatIfPreference) {
        $ready = Read-Host 'Read README, complete forensics, snapshot VM, confirm scripts permitted? Type READY'

        if ($ready -cne 'READY') {
            throw 'Cancelled before hardening.'
        }
    }

    foreach ($module in $Modules) {
        Write-Host "`n========== $module =========="

        try {
            switch ($module) {
                'Inventory' { Show-Inventory }
                'Base'      { Set-Base }
                'Passwords' { Set-Passwords }
                'Firewall'  { Set-Firewall }
                'Defender'  { Set-Defender }
                'RDP'       { Set-RDP }
                'SMB'       { Set-SMB }
                'Audit'     { Set-Audit }
                'Updates'   { Set-Updates }
                'Users'     { Set-Users }
                'Services'  { Set-Services }
            }
        }
        catch {
            $script:Failures++
            Write-Warning "$module FAILED: $($_.Exception.Message)"
        }
    }

    Write-Host "Finished with $script:Failures failed module(s). Verify effective settings, scoring and required services. No automatic reboot."
    Write-Host 'Backups are NOT a complete rollback: registry imports do not remove newly created values;'
    Write-Host 'service/user/package changes need separate recovery or a VM snapshot.'
}
finally {
    Stop-Transcript | Out-Null
}

if ($script:Failures -gt 0) {
    throw "$script:Failures module(s) failed; inspect session.log."
}
