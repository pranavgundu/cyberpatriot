#Requires -Version 5.1
# Dedicated Server entry point; shares the tested implementation, refuses workstations/DC apply.
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Apply,
    [ValidateSet('Inventory','Base','Passwords','Firewall','Defender','RDP','SMB','Audit','Updates','Users','Services')]
    [string[]]$Modules = @('Inventory','Base','Passwords','Firewall','Defender','RDP','SMB','Audit','Updates','Users','Services'),
    [string]$OutputDirectory
)
& (Join-Path $PSScriptRoot 'windows.ps1') -Profile Server @PSBoundParameters
