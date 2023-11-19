<#
.SYNOPSIS
    Create Break Glass accounts, Break Glass group, and Break Glass admin unit for Microsoft Entra

.DESCRIPTION
    This script creates Break Glass accounts, a Break Glass group, and add them to a restricted Break Glass admin unit.
    The Break Glass group and accounts can then be excluded in Microsoft Entra Conditional Access policies to prevent lockout.

    Also see https://learn.microsoft.com/en-us/azure/active-directory/roles/security-emergency-access

.PARAMETER TenantId
    Microsoft Entra tenant ID. Otherwise implied from configuration files or $env:AZURE_TENANT_ID.

.PARAMETER UseDeviceCode
    Use device code authentication instead of a browser control.

.PARAMETER ConfigPath
    Folder path to configuration files in PS1 format. Default: './config/'.

.LINK
    https://github.com/jpawlowski/AzureAD-PIM-Roles-Management

.NOTES
    Filename: New-Entra-Tier0-BreakGlass.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
#>
#Requires -Version 7.2

[CmdletBinding(
    SupportsShouldProcess,
    ConfirmImpact = 'High'
)]
Param (
    [Parameter(HelpMessage = "Microsoft Entra tenant ID.")]
    [string]$TenantId,

    [Parameter(HelpMessage = "Use device code authentication instead of a browser control.")]
    [switch]$UseDeviceCode,

    [Parameter(HelpMessage = "Folder path to configuration files in PS1 format. Default: './config/'.")]
    [string]$ConfigPath
)

$LibPath = $(Join-Path $PSScriptRoot 'lib')
try {
    . (Join-Path $LibPath 'Common.functions.ps1')
    . (Join-Path $LibPath 'Load.config.ps1')
    . (Join-Path $LibPath 'New-Entra-Tier0-BreakGlass.function.ps1')
}
catch {
    Throw "Error loading file: $_"
}

Connect-MyMgGraph -Scopes $MgScopes -TenantId $TenantId
New-Entra-Tier0-BreakGlass -Config $EntraTier0BreakGlass
