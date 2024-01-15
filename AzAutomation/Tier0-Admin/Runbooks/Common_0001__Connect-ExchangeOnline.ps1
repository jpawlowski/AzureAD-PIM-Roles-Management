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
.REQUIREDSCRIPTS Common_0000__Import-Module.ps1
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
    [String]$Organization,

    [Array]$CommandName
)

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | & { process{$_.PSObject.Properties | & { process{$_.Name + ': ' + $_.Value} }} }) -join ', ') ---"
$StartupVariables = (Get-Variable | & { process { $_.Name } })      # Remember existing variables so we can cleanup ours at the end of the script

#region [COMMON] ENVIRONMENT ---------------------------------------------------
.\Common_0000__Import-Module.ps1 -Modules @(
    @{ Name = 'ExchangeOnlineManagement'; MinimumVersion = '3.4'; MaximumVersion = '3.65535' }
) 1> $null
#endregion ---------------------------------------------------------------------

$params = @{
    Organization = $Organization
    ShowBanner   = $false
    ShowProgress = $false
}

$Connection = $null

try {
    $Connection = Get-ConnectionInformation -ErrorAction Stop
}
catch {
    Write-Output '' 1> $null
}

if (
    ($Connection) -and
    (
        (($Connection | Where-Object Organization -eq $params.Organization).State -ne 'Connected') -or
        (($Connection | Where-Object Organization -eq $params.Organization).tokenStatus -ne 'Active')
    )
) {
    $Connection | Where-Object Organization -eq $params.Organization | ForEach-Object {
        try {
            Disconnect-ExchangeOnline `
                -ConnectionId $_.ConnectionId `
                -Confirm:$false `
                -InformationAction SilentlyContinue `
                -ErrorAction Stop 1> $null
        }
        catch {
            Write-Output '' 1> $null
        }
    }
    $Connection = $null
}

if (-Not ($Connection)) {
    if ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
        $params.ManagedIdentity = $true
        $params.SkipLoadingCmdletHelp = $true
        $params.SkipLoadingFormatData = $true
    }

    if ($CommandName) {
        $params.CommandName = $CommandName
    }
    elseif ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
        Write-Warning '[COMMON]: - Loading all Exchange Online commands. For improved memory consumption, consider adding -CommandName parameter with only required commands to be loaded.'
    }

    try {
        $OrigVerbosePreference = $global:VerbosePreference
        $global:VerbosePreference = 'SilentlyContinue'
        Write-Information 'Connecting to Exchange Online ...' -InformationAction Continue
        Connect-ExchangeOnline @params 1> $null
        $global:VerbosePreference = $OrigVerbosePreference
    }
    catch {
        Throw $_
    }
}

Get-Variable | Where-Object { $StartupVariables -notcontains $_.Name } | & { process { Remove-Variable -Scope 0 -Name $_.Name -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -Verbose:$false -Debug:$false } }        # Delete variables created in this script to free up memory for tiny Azure Automation sandbox
Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
