<#PSScriptInfo
.VERSION 1.0.0
.GUID 86fdceff-6855-4789-b621-9e12b25097f8
.AUTHOR Julian Pawlowski
.COMPANYNAME Workoho GmbH
.COPYRIGHT (c) 2024 Workoho GmbH. All rights reserved.
.TAGS
.LICENSEURI
.PROJECTURI
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>

<#
.SYNOPSIS
    Imports modules silently

.DESCRIPTION
    Common runbook that can be used by other runbooks. It can not be started as an Azure Automation job directly.
#>

[CmdletBinding()]
Param(
    [Parameter(mandatory = $true)]
    [AllowEmptyCollection()]
    [Array]$Modules
)

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }

# Works only when running locally
$OrigVerbosePreference = $VerbosePreference
$VerbosePreference = 'SilentlyContinue'

# Works only when running in Azure Automation sandbox
$OrigGlobalVerbosePreference = $global:VerbosePreference
$global:VerbosePreference = 'SilentlyContinue'

Import-Module PowerShellGet

$VerbosePreference = $OrigVerbosePreference
$global:VerbosePreference = $OrigGlobalVerbosePreference

Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | ForEach-Object { $_.PSObject.Properties | ForEach-Object { $_.Name + ': ' + $_.Value } }) -join ', ') ---" -Verbose

$VerbosePreference = 'SilentlyContinue'
$global:VerbosePreference = 'SilentlyContinue'

$Missing = @()

foreach ($Module in $Modules) {
    try {
        Write-Debug "Importing module $($Module.Name)"
        $Module.ErrorAction = 'Stop'
        Import-Module @Module
    }
    catch {
        $Missing += $_
    }
}

If ($Missing.Count -gt 0) {
    Throw $Missing
}

$global:VerbosePreference = $OrigGlobalVerbosePreference

Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
