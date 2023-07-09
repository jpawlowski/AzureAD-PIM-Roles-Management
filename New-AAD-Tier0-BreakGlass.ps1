#Requires -Version 7.2
<#
.SYNOPSIS
    Create Break Glass accounts, Break Glass group, and Break Glass admin unit for Azure AD
.DESCRIPTION
    This script creates Break Glass accounts, a Break Glass group, and add them to a restricted Break Glass admin unit.
    The Break Glass group and accounts can then be excluded in Azure AD Conditional Access policies to prevent lockout.

    Also see https://learn.microsoft.com/en-us/azure/active-directory/roles/security-emergency-access
#>
[CmdletBinding()]
Param (
    [Parameter(HelpMessage = "Azure AD tenant ID.")]
    [string]$TenantId,
    [Parameter(HelpMessage = "Use device code authentication instead of a browser control.")]
    [switch]$UseDeviceCode,
    [Parameter(HelpMessage = "Folder path to configuration files in PS1 format. Default: './config/'.")]
    [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'

$LibFiles = @(
    'Common.functions.ps1'
    'Load.config.ps1'
    'New-AAD-Tier0-BreakGlass.function.ps1'
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

$title = 'Break Glass Account + Break Glass Group creation'
$message = 'Do you confirm to create new Break Glass Accounts and Break Glass Group if they are not existing?'
$result = $host.ui.PromptForChoice($title, $message, $choices, 1)
switch ($result) {
    0 {
        Write-Output ' Yes: Starting Break Glass creation now'
        Write-Output ''

        $MgScopes += 'User.ReadWrite.All'
        $MgScopes += 'Group.ReadWrite.All'
        $MgScopes += 'AdministrativeUnit.ReadWrite.All'
        $MgScopes += 'Directory.Write.Restricted'
        $MgScopes += 'RoleManagement.ReadWrite.Directory'

        Connect-MyMgGraph
        New-AAD-Tier0-BreakGlass
    }
    * {
        Write-Output ' Aborting command.'
    }
}
