#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Apply,

    [ValidateSet('Inventory', 'Base', 'Passwords', 'Firewall', 'Defender', 'RDP', 'SMB', 'Audit', 'Updates', 'Users', 'Services')]
    [string[]]$Modules = @(
        'Inventory', 'Base', 'Passwords', 'Firewall', 'Defender', 'RDP',
        'SMB', 'Audit', 'Updates', 'Users', 'Services'
    ),

    [string]$OutputDirectory
)

$windowsScript = Join-Path $PSScriptRoot 'windows.ps1'

& $windowsScript -Profile Server @PSBoundParameters
