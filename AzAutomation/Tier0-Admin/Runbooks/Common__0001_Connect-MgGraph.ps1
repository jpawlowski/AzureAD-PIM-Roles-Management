<#
.SYNOPSIS
    Connect to Microsoft Graph and validate available application scopes

.PARAMETER Scopes

.NOTES
    Original name: Common__0001_Connect-MgGraph.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
    Version: 0.9.0
#>

[CmdletBinding()]
Param(
    [Array]$Scopes
)

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name) ---"

#region [COMMON] ENVIRONMENT ---------------------------------------------------
.\Common__0000_Import-Modules.ps1 -Modules @(
    @{ Name = 'Microsoft.Graph.Authentication'; MinimumVersion = '2.0'; MaximumVersion = '2.65535' }
    @{ Name = 'Microsoft.Graph.Identity.SignIns'; MinimumVersion = '2.0'; MaximumVersion = '2.65535' }
) 1> $null
#endregion ---------------------------------------------------------------------

#region FUNCTIONS --------------------------------------------------------------
function Get-MgMissingScope ([Array]$Scopes) {
    $Missing = @()

    foreach ($Scope in $Scopes) {
        if ($WhatIfPreference -and ($Scope -like '*Write*')) {
            Write-Verbose "What If: Removed $Scope from required Microsoft Graph scopes"
            $Scopes.Remove($Scope)
        }
        elseif ($Scope -notin @((Get-MgContext).Scopes)) {
            $Missing += $Scope
        }
    }
    return $Missing
}
#endregion ---------------------------------------------------------------------

$params = @{
    NoWelcome    = $true
    ContextScope = 'Process'
}
if (-Not (Get-MgContext)) {
    if ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
        Write-Verbose 'Using system-assigned Managed Service Identity'
        $params.Identity = $true
    }
    elseif ($Scopes) {
        Write-Verbose 'Using interactive sign in'
        $params.Scopes = $Scopes
    }

    try {
        Write-Information 'Connecting to Microsoft Graph ...'
        Connect-MgGraph @params 1> $null
    }
    catch {
        Throw "Failed to connect to Microsoft Graph";
    }
}

$MissingScopes = Get-MgMissingScope -Scopes $Scopes

if ($MissingScopes) {
    if (
        ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) -or
        ((Get-MgContext).AuthType -ne 'Delegated')
    ) {
        Throw "Missing Microsoft Graph authorization scopes:`n`n$($MissingScopes -join "`n")"
    }

    if ($Scopes) { $params.Scopes = $Scopes }
    try {
        Write-Information 'Missing scopes, re-connecting to Microsoft Graph ...'
        Connect-MgGraph @params 1> $null
    }
    catch {
        Throw "Failed to connect to Microsoft Graph";
    }

    if (
        (-Not (Get-MgContext)) -or
        ((Get-MgMissingScope -Scopes $Scopes).Count -gt 0)
    ) {
        Throw "Missing Microsoft Graph authorization scopes:`n`n$($MissingScopes -join "`n")"
    }
}

Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
