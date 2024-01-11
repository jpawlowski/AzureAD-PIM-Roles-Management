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
$StartupVariables = (Get-Variable | ForEach-Object { $_.Name })

if ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {

    #region [COMMON] CONNECTIONS ---------------------------------------------------
    .\Common_0001__Connect-AzAccount.ps1 1> $null
    #endregion ---------------------------------------------------------------------

    try {
        if ([string]::IsNullOrEmpty($env:AZURE_AUTOMATION_ResourceGroupName)) {
            Throw 'Missing environment variable $env:AZURE_AUTOMATION_ResourceGroupName'
        }
        elseif ([string]::IsNullOrEmpty($env:AZURE_AUTOMATION_AccountName)) {
            Throw 'Missing environment variable $env:AZURE_AUTOMATION_AccountName'
        }
        else {
            $AutomationVariables = Get-AzAutomationVariable -ResourceGroupName $env:AZURE_AUTOMATION_ResourceGroupName -AutomationAccountName $env:AZURE_AUTOMATION_AccountName
        }
    }
    catch {
        Throw $_
    }

    foreach ($AutomationVariable in $AutomationVariables) {
        if ($AutomationVariable.GetType().Name -ne 'String') {
            Write-Verbose "SKIPPING $($AutomationVariable.Name) because it is not a String but '$($AutomationVariable.GetType().Name)'"
            continue
        }
        elseif ([string]::IsNullOrEmpty($AutomationVariable.Value)) {
            Write-Verbose "SKIPPING $($AutomationVariable.Name) because it has NullOrEmpty value"
            continue
        }
        Write-Verbose "Setting `$env:$($AutomationVariable.Name)"
        [Environment]::SetEnvironmentVariable($AutomationVariable.Name, $AutomationVariable.Value)
    }
}
else {
    Write-Verbose 'Not running in Azure Automation. Script environment variables must be set manually before local run.'
}

Get-Variable | Where-Object { $StartupVariables -notcontains $_.Name } | ForEach-Object { Remove-Variable -Scope 0 -Name $_.Name -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -Verbose:$false -Debug:$false }
Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
