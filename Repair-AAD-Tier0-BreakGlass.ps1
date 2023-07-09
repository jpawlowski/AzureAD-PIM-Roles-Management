#Requires -Version 7.2
<#
.SYNOPSIS
    Validates and repairs existing Break Glass accounts, Break Glass group, and Break Glass admin unit for Azure AD
.DESCRIPTION
    This script validates Break Glass accounts, the Break Glass group, and their Break Glass admin unit.
    In case the expected configuration differs to the one from config files, it will be repaired to reflect the
    expected state.

    Also see https://learn.microsoft.com/en-us/azure/active-directory/roles/security-emergency-access
#>
[CmdletBinding()]
Param (
    [Parameter(HelpMessage = "Azure AD tenant ID.")]
    [string]$TenantId,
    [Parameter(HelpMessage = "Use device code authentication instead of a browser control.")]
    [switch]$UseDeviceCode,
    [Parameter(HelpMessage = "Folder path to configuration files in PS1 format. Default: './config/'.")]
    [string]$ConfigPath,
    [Parameter(HelpMessage = "Run script without user interaction. If PS session was started with -NonInteractive parameter, it will be inherited. Note that updates of Tier0 settings always requires manual user interaction.")]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$LibFiles = @(
    'Common.functions.ps1'
    'Load.config.ps1'
    'Test-AAD-Tier0-BreakGlass.function.ps1'
)
foreach ($FileName in $LibFiles) {
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

$ValidateBreakGlass = $true

Connect-MyMgGraph
Test-AAD-Tier0-BreakGlass
