<#
.SYNOPSIS
    Validates and repairs existing Break Glass accounts, Break Glass group, and Break Glass admin unit for Microsoft Entra

.DESCRIPTION
    This script validates Break Glass accounts, the Break Glass group, and their Break Glass admin unit.
    In case the expected configuration differs to the one from config files, it will be repaired to reflect the
    expected state.

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
    Filename: Repair-Entra-Tier0-BreakGlass.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
#>
#Requires -Version 7.2

[CmdletBinding(
    SupportsShouldProcess,
    ConfirmImpact = 'High'
)]
Param (
    [string]$TenantId,
    [switch]$UseDeviceCode,
    [string]$ConfigPath
)

$LibPath = $(Join-Path $PSScriptRoot 'lib')
try {
    . (Join-Path $LibPath 'Common.functions.ps1')
    . (Join-Path $LibPath 'Load.config.ps1')
    . (Join-Path $LibPath 'Test-Entra-Tier0-BreakGlass.function.ps1')
}
catch {
    Throw "Error loading file: $_"
}

Connect-MyMgGraph -Scopes $MgScopes
Test-Entra-Tier0-BreakGlass -Config $EntraTier0BreakGlass -Repair
