<#PSScriptInfo
.VERSION 1.0.0
.GUID 05a03d22-11a6-4114-8241-6e02a66d00fc
.AUTHOR Julian Pawlowski
.COMPANYNAME Workoho GmbH
.COPYRIGHT (c) 2024 Workoho GmbH. All rights reserved.
.TAGS
.LICENSEURI
.PROJECTURI
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS Common_0001__Connect-AzAccount.ps1
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>

<#
.SYNOPSIS
    Restores variables from Azure Automation account as environment variables

.DESCRIPTION
    Common runbook that can be used by other runbooks. It can not be started as an Azure Automation job directly.
#>

[CmdletBinding()]
Param()

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | ForEach-Object { $_.PSObject.Properties | ForEach-Object { $_.Name + ': ' + $_.Value } }) -join ', ') ---"

if ($env:AZURE_AUTOMATION_ResourceGroupName -and $env:AZURE_AUTOMATION_AccountName) {

    #region [COMMON] CONNECTIONS ---------------------------------------------------
    .\Common_0001__Connect-AzAccount.ps1 1> $null
    #endregion ---------------------------------------------------------------------

    $AutomationVariables = Get-AzAutomationVariable -ResourceGroupName $env:AZURE_AUTOMATION_ResourceGroupName -AutomationAccountName $env:AZURE_AUTOMATION_AccountName

    foreach ($AutomationVariable in $AutomationVariables) {
        Write-Verbose "Setting `$env:$($AutomationVariable.Name)"
        [Environment]::SetEnvironmentVariable($AutomationVariable.Name, $AutomationVariable.Value)
    }
}
else {
    Write-Verbose 'Not running in Azure Automation. Script environment variables must be set manually before local run.'
}

Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
