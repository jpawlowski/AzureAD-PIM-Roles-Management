<#PSScriptInfo
.VERSION 1.0.0
.GUID 2d55eb0b-3e2e-425a-a7de-5d12cbe5a149
.AUTHOR Julian Pawlowski
.COMPANYNAME Workoho GmbH
.COPYRIGHT (c) 2024 Workoho GmbH. All rights reserved.
.TAGS
.LICENSEURI
.PROJECTURI
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS Common__0000_Import-Modules.ps1
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>

<#
.SYNOPSIS
    Connect to Microsoft Exchange Online

.DESCRIPTION
    Common runbook that can be used by other runbooks. It can not be started as an Azure Automation job directly.

.PARAMETER Scopes

#>

[CmdletBinding()]
Param(
    [Parameter(mandatory = $true)]
    [String]$Organization
)

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | ForEach-Object { $_.PSObject.Properties | ForEach-Object { $_.Name + ': ' + $_.Value } }) -join ', ') ---"

#region [COMMON] ENVIRONMENT ---------------------------------------------------
.\Common__0000_Import-Modules.ps1 -Modules @(
    @{ Name = 'ExchangeOnlineManagement'; MinimumVersion = '3.0'; MaximumVersion = '3.65535' }
) 1> $null
#endregion ---------------------------------------------------------------------

$params = @{
    Organization = $Organization
    ShowBanner   = $false
    ShowProgress = $false
}

$Connection = Get-ConnectionInformation

if (
    ($Connection) -and
    (
        (($Connection | Where-Object Organization -eq $params.Organization).State -ne 'Connected') -or
        (($Connection | Where-Object Organization -eq $params.Organization).tokenStatus -ne 'Active')
    )
) {
    $Connection | Where-Object Organization -eq $params.Organization | ForEach-Object {
        Disconnect-ExchangeOnline `
            -ConnectionId $_.ConnectionId `
            -Confirm:$false `
            -InformationAction SilentlyContinue
    }
    $Connection = $null
}

if (-Not ($Connection)) {
    if ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
        $params.ManagedIdentity = $true
    }

    try {
        $OrigVerbosePreference = $global:VerbosePreference
        $global:VerbosePreference = 'SilentlyContinue'
        Write-Information 'Connecting to Exchange Online ...'
        Connect-ExchangeOnline @params 1> $null
        $global:VerbosePreference = $OrigVerbosePreference
    }
    catch {
        Throw "Failed to connect to Exchange Online"
    }
}

Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
