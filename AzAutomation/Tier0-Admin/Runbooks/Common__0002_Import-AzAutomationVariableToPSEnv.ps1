<#
.SYNOPSIS
    Restores variables from Azure Automation account as environment variables

.NOTES
    Original name: Common__0002_Add-AzAutomationVariableToPSEnv.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
    Version: 1.0.0
#>

#Requires -Version 5.1

[CmdletBinding()]
Param()

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name) ---"

if ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {

    #region [COMMON] CONNECTIONS ---------------------------------------------------
    .\Common__0001_Connect-AzAccount.ps1 1> $null
    #endregion ---------------------------------------------------------------------

    $AA = Get-AzAutomationAccount
    $AutomationVariable = Get-AzAutomationVariable -ResourceGroupName $AA.ResourceGroupName -AutomationAccountName $AA.AutomationAccountName

    foreach ($Item in $AutomationVariable) {
        Write-Verbose "Setting `$env:$($item.Name)"
        [Environment]::SetEnvironmentVariable($item.Name, $Item.Value)
    }
}
else {
    Write-Verbose 'Not running in Azure Automation. Script environment variables must be set manually before local run.'
}

Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
