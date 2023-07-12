<#
.SYNOPSIS
    Validates and repairs existing Break Glass accounts, Break Glass group, and Break Glass admin unit for Microsoft Entra

.DESCRIPTION
    This script validates Break Glass accounts, the Break Glass group, and their Break Glass admin unit.
    In case the expected configuration differs to the one from config files, it will be repaired to reflect the
    expected state.

    Also see https://learn.microsoft.com/en-us/azure/active-directory/roles/security-emergency-access

.PARAMETER TenantId
    Microsoft Entra tenant ID. Otherwise implied from configuration files, $env:TenantId or $TenantId.

.PARAMETER UseDeviceCode
    Use device code authentication instead of a browser control.

.PARAMETER ConfigPath
    Folder path to configuration files in PS1 format. Default: './config/'.

.NOTES
    Filename: Repair-Entra-Tier0-BreakGlass.ps1
    Author: Julian Pawlowski
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

$LibFiles = @(
    'Common.functions.ps1'
    'Load.config.ps1'
    'Test-Entra-Tier0-BreakGlass.function.ps1'
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

Connect-MyMgGraph -Scopes $MgScopes
Test-Entra-Tier0-BreakGlass $EntraCABreakGlass
