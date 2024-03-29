<#PSScriptInfo
.VERSION 1.0.0
.GUID 05273e10-2a70-42aa-82d3-7881324beead
.AUTHOR Julian Pawlowski
.COMPANYNAME Workoho GmbH
.COPYRIGHT (c) 2024 Workoho GmbH. All rights reserved.
.TAGS
.LICENSEURI
.PROJECTURI
.ICONURI
.EXTERNALMODULEDEPENDENCIES Microsoft.Graph.Authentication,Microsoft.Graph.Identity.SignIns,Microsoft.Graph.Applications,Microsoft.Graph.Users
.REQUIREDSCRIPTS Common_0000__Import-Module.ps1
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>

<#
.SYNOPSIS
    Connect to Microsoft Graph and validate available application scopes

.DESCRIPTION
    Common runbook that can be used by other runbooks. It can not be started as an Azure Automation job directly.

.NOTES
    Provides detailled info about the current connection principal using the following environment variables:

    $env:MG_PRINCIPAL_TYPE          'Delegated' for interactive sessions, or 'Application' when using a Managed Identity.
    $env:MG_PRINCIPAL_ID            Object ID of the current principal connected to Microsoft Graph.
    $env:MG_PRINCIPAL_DISPLAYNAME   Display Name of the current principal connected to Microsoft Graph.
                                    In case of a System-Assigned Managed Identity, it is also the name of the Azure Automation account in use.

.PARAMETER Scopes

#>

[CmdletBinding()]
Param(
    [Array]$Scopes
)

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | & { process{$_.PSObject.Properties | & { process{$_.Name + ': ' + $_.Value} }} }) -join ', ') ---"
$StartupVariables = (Get-Variable | & { process { $_.Name } })      # Remember existing variables so we can cleanup ours at the end of the script

.\Common_0000__Import-Module.ps1 -Modules @(
    @{ Name = 'Microsoft.Graph.Authentication'; MinimumVersion = '2.0'; MaximumVersion = '2.65535' }
) 1> $null

function Get-MgMissingScope ([Array]$Scopes) {
    $MissingScopes = [System.Collections.ArrayList]::new()

    foreach ($Scope in $Scopes) {
        if ($WhatIfPreference -and ($Scope -like '*Write*')) {
            Write-Verbose "[COMMON]: - What If: Removed $Scope from required Microsoft Graph scopes"
            $null = $script:Scopes.Remove($Scope)
        }
        elseif ($Scope -notin @((Get-MgContext).Scopes)) {
            $null = $MissingScopes.Add($Scope)
        }
    }
    return $MissingScopes
}

$params = @{
    NoWelcome    = $true
    ContextScope = 'Process'
}
if (-Not (Get-MgContext)) {
    if ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
        Write-Verbose '[COMMON]: - Using system-assigned Managed Service Identity'
        $params.Identity = $true
    }
    elseif ($Scopes) {
        Write-Verbose '[COMMON]: - Using interactive sign in'
        $params.Scopes = $Scopes
    }

    try {
        Write-Information 'Connecting to Microsoft Graph ...' -InformationAction Continue
        Connect-MgGraph @params 1> $null
    }
    catch {
        Throw $_;
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
        Write-Information 'Missing scopes, re-connecting to Microsoft Graph ...' -InformationAction Continue
        Connect-MgGraph @params 1> $null
    }
    catch {
        Throw $_
    }

    if (
        (-Not (Get-MgContext)) -or
        ((Get-MgMissingScope -Scopes $Scopes).Count -gt 0)
    ) {
        Throw "Missing Microsoft Graph authorization scopes:`n`n$($MissingScopes -join "`n")"
    }
}

try {
    $Principal = $null

    if ((Get-Module).Name -match 'Microsoft.Graph.Beta') {
        if ((Get-MgContext).AuthType -eq 'Delegated') {
            .\Common_0000__Import-Module.ps1 -Modules @(
                @{ Name = 'Microsoft.Graph.Beta.Users'; MinimumVersion = '2.0'; MaximumVersion = '2.65535' }
            ) 1> $null

            [Environment]::SetEnvironmentVariable('MG_PRINCIPAL_TYPE', 'Delegated')
            $Principal = Get-MgBetaUser -UserId (Get-MgContext).Account -ErrorAction Stop -Verbose:$false
        }
        else {
            .\Common_0000__Import-Module.ps1 -Modules @(
                @{ Name = 'Microsoft.Graph.Beta.Applications'; MinimumVersion = '2.0'; MaximumVersion = '2.65535' }
            ) 1> $null

            [Environment]::SetEnvironmentVariable('MG_PRINCIPAL_TYPE', 'Application')
            $Principal = Get-MgBetaServicePrincipalByAppId -AppId (Get-MgContext).ClientId -ErrorAction Stop -Verbose:$false
        }
    }
    else {
        if ((Get-MgContext).AuthType -eq 'Delegated') {
            .\Common_0000__Import-Module.ps1 -Modules @(
                @{ Name = 'Microsoft.Graph.Users'; MinimumVersion = '2.0'; MaximumVersion = '2.65535' }
            ) 1> $null

            [Environment]::SetEnvironmentVariable('MG_PRINCIPAL_TYPE', 'Delegated')
            $Principal = Get-MgUser -UserId (Get-MgContext).Account -ErrorAction Stop -Verbose:$false
        }
        else {
            .\Common_0000__Import-Module.ps1 -Modules @(
                @{ Name = 'Microsoft.Graph.Applications'; MinimumVersion = '2.0'; MaximumVersion = '2.65535' }
            ) 1> $null

            [Environment]::SetEnvironmentVariable('MG_PRINCIPAL_TYPE', 'Application')
            $Principal = Get-MgServicePrincipalByAppId -AppId (Get-MgContext).ClientId -ErrorAction Stop -Verbose:$false
        }
    }

    [Environment]::SetEnvironmentVariable('MG_PRINCIPAL_ID', $Principal.Id)
    [Environment]::SetEnvironmentVariable('MG_PRINCIPAL_DISPLAYNAME', $Principal.DisplayName)
}
catch {
    Throw $_
}

Get-Variable | Where-Object { $StartupVariables -notcontains $_.Name } | & { process { Remove-Variable -Scope 0 -Name $_.Name -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -Verbose:$false -Debug:$false } }        # Delete variables created in this script to free up memory for tiny Azure Automation sandbox
Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
