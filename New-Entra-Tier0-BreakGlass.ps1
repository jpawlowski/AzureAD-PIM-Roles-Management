<#
.SYNOPSIS
    Create Break Glass accounts, Break Glass group, and Break Glass admin unit for Microsoft Entra

.DESCRIPTION
    This script creates Break Glass accounts, a Break Glass group, and add them to a restricted Break Glass admin unit.
    The Break Glass group and accounts can then be excluded in Microsoft Entra Conditional Access policies to prevent lockout.

    Also see https://learn.microsoft.com/en-us/azure/active-directory/roles/security-emergency-access

.PARAMETER TenantId
    Microsoft Entra tenant ID. Otherwise implied from configuration files, $env:TenantId or $TenantId.

.PARAMETER UseDeviceCode
    Use device code authentication instead of a browser control.

.PARAMETER ConfigPath
    Folder path to configuration files in PS1 format. Default: './config/'.

.NOTES
    Filename: New-Entra-Tier0-BreakGlass.ps1
    Author: Julian Pawlowski
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

$LibFiles = @(
    'Common.functions.ps1'
    'Load.config.ps1'
    'New-Entra-Tier0-BreakGlass.function.ps1'
)
foreach ($FileName in $LibFiles) {
    if ($null -eq $FileName -or $FileName -eq '') { continue }
    $FilePath = Join-Path $(Join-Path $PSScriptRoot 'lib') $FileName
    if (Test-Path -Path $FilePath -PathType Leaf) {
        try {
            . $FilePath
        }
        catch {
            Throw "Error loading file: $_"
        }
    }
    else {
        Throw "File not found: $FilePath"
    }
}

$MgScopes += 'User.ReadWrite.All'
$MgScopes += 'Group.ReadWrite.All'
$MgScopes += 'AdministrativeUnit.ReadWrite.All'
$MgScopes += 'Directory.Write.Restricted'
$MgScopes += 'RoleManagement.ReadWrite.Directory'
$MgScopes += 'Policy.Read.All'
$MgScopes += 'Policy.ReadWrite.AuthenticationMethod'
$MgScopes += 'Policy.ReadWrite.ConditionalAccess'
$MgScopes += 'Application.Read.All'

Connect-MyMgGraph -Scopes $MgScopes
New-Entra-Tier0-BreakGlass $EntraCABreakGlass
