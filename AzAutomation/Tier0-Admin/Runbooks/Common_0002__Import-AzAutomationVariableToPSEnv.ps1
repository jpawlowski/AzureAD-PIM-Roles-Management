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
Param(
    [Array]$Variable
)

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | & { process{$_.PSObject.Properties | & { process{$_.Name + ': ' + $_.Value} }} }) -join ', ') ---"
$StartupVariables = (Get-Variable | & { process { $_.Name } })      # Remember existing variables so we can cleanup ours at the end of the script

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
            $AutomationVariables = Get-AzAutomationVariable -ResourceGroupName $env:AZURE_AUTOMATION_ResourceGroupName -AutomationAccountName $env:AZURE_AUTOMATION_AccountName -Verbose:$false
        }
    }
    catch {
        Throw $_
    }

    $AutomationVariables | & {
        process {
            if (($null -ne $script:Variable) -and ($_.Name -notin $script:Variable)) { return }
            if ($_.Value.GetType().Name -ne 'String') {
                Write-Verbose "[COMMON]: - SKIPPING $($_.Name) because it is not a String but '$($_.GetType().Name)'"
                return
            }
            elseif ([string]::IsNullOrEmpty($_.Value)) {
                Write-Verbose "[COMMON]: - SKIPPING $($_.Name) because it has NullOrEmpty value"
                return
            }
            Write-Verbose "[COMMON]: - Setting `$env:$($_.Name)"
            [Environment]::SetEnvironmentVariable($_.Name, $_.Value)
        }
    }
}
else {
    Write-Verbose '[COMMON]: - Not running in Azure Automation. Script environment variables must be set manually before local run.'
}

Get-Variable | Where-Object { $StartupVariables -notcontains $_.Name } | & { process { Remove-Variable -Scope 0 -Name $_.Name -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -Verbose:$false -Debug:$false } }        # Delete variables created in this script to free up memory for tiny Azure Automation sandbox
Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
