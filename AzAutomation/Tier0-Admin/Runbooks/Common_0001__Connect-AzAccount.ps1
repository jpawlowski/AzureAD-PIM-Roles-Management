<#PSScriptInfo
.VERSION 1.0.0
.GUID 1dc765c0-4922-4142-a945-13206df25f13
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
    Connect to Azure using either a Managed Service Identity, or an interactive session

.DESCRIPTION
    Common runbook that can be used by other runbooks. It can not be started as an Azure Automation job directly.

.NOTES
    Provides detailled info about the current Azure Automation Account using the following environment variables:

    $env:AZURE_AUTOMATION_SubscriptionId
    $env:AZURE_AUTOMATION_ResourceGroupName
    $env:AZURE_AUTOMATION_AccountName
    $env:AZURE_AUTOMATION_IDENTITY_PrincipalId
    $env:AZURE_AUTOMATION_IDENTITY_TenantId
    $env:AZURE_AUTOMATION_IDENTITY_Type
    $env:AZURE_AUTOMATION_RUNBOOK_Name
    $env:AZURE_AUTOMATION_RUNBOOK_CreationTime
    $env:AZURE_AUTOMATION_RUNBOOK_LastModifiedTime
    $env:AZURE_AUTOMATION_RUNBOOK_JOB_CreationTime
    $env:AZURE_AUTOMATION_RUNBOOK_JOB_StartTime
#>

[CmdletBinding()]
Param(
    $Tenant,
    $Subscription
)

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | & { process{$_.PSObject.Properties | & { process{$_.Name + ': ' + $_.Value} }} }) -join ', ') ---"
$StartupVariables = (Get-Variable | & { process { $_.Name } })      # Remember existing variables so we can cleanup ours at the end of the script

#region [COMMON] ENVIRONMENT ---------------------------------------------------
.\Common_0000__Import-Module.ps1 -Modules @(
    @{ Name = 'Az.Accounts'; MinimumVersion = '2.8'; MaximumVersion = '2.65535' }
) 1> $null
#endregion ---------------------------------------------------------------------

if (-Not (Get-AzContext)) {
    $Context = $null
    $params = @{
        Scope = 'Process'
    }

    if ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
        Write-Verbose '[COMMON]: - Using system-assigned Managed Service Identity'
        $params.Identity = $true
    }
    else {
        Write-Verbose '[COMMON]: - Using interactive sign in'
    }

    try {
        Write-Information 'Connecting to Microsoft Azure ...' -InformationAction Continue
        if ($Tenant) { $params.Tenant = $Tenant }
        if ($Subscription) { $params.Subscription = $Subscription }
        $Context = (Connect-AzAccount @params).context

        $Context = Set-AzContext -SubscriptionName $Context.Subscription -DefaultProfile $Context

        if ($params.Identity -eq $true) {
            Write-Verbose '[COMMON]: - Running in Azure Automation - Generating connection environment variables'

            if ($env:MG_PRINCIPAL_DISPLAYNAME) {
                #region [COMMON] ENVIRONMENT ---------------------------------------------------
                .\Common_0000__Import-Module.ps1 -Modules @(
                    @{ Name = 'Az.Automation'; MinimumVersion = '1.7'; MaximumVersion = '1.65535' }
                ) 1> $null
                #endregion ---------------------------------------------------------------------

                $AzAutomationAccount = Get-AzAutomationAccount -DefaultProfile $Context -ErrorAction Stop -Verbose:$false | Where-Object { $_.AutomationAccountName -eq $env:MG_PRINCIPAL_DISPLAYNAME }
                if ($AzAutomationAccount) {
                    Write-Verbose '[COMMON]: - Retrievedd Automation Account details'
                    [Environment]::SetEnvironmentVariable('AZURE_AUTOMATION_SubscriptionId', $AzAutomationAccount.SubscriptionId)
                    [Environment]::SetEnvironmentVariable('AZURE_AUTOMATION_ResourceGroupName', $AzAutomationAccount.ResourceGroupName)
                    [Environment]::SetEnvironmentVariable('AZURE_AUTOMATION_AccountName', $AzAutomationAccount.AutomationAccountName)
                    [Environment]::SetEnvironmentVariable('AZURE_AUTOMATION_IDENTITY_PrincipalId', $AzAutomationAccount.Identity.PrincipalId)
                    [Environment]::SetEnvironmentVariable('AZURE_AUTOMATION_IDENTITY_TenantId', $AzAutomationAccount.Identity.TenantId)
                    [Environment]::SetEnvironmentVariable('AZURE_AUTOMATION_IDENTITY_Type', $AzAutomationAccount.Identity.Type)

                    if ($PSPrivateMetadata.JobId) {

                        $AzAutomationJob = Get-AzAutomationJob -DefaultProfile $Context -ResourceGroupName $AzAutomationAccount.ResourceGroupName -AutomationAccountName $AzAutomationAccount.AutomationAccountName -Id $PSPrivateMetadata.JobId -ErrorAction Stop -Verbose:$false
                        if ($AzAutomationJob) {
                            Write-Verbose '[COMMON]: - Retrievedd Automation Job details'
                            [Environment]::SetEnvironmentVariable('AZURE_AUTOMATION_RUNBOOK_Name', $AzAutomationJob.RunbookName)
                            [Environment]::SetEnvironmentVariable('AZURE_AUTOMATION_RUNBOOK_JOB_CreationTime', $AzAutomationJob.CreationTime.ToUniversalTime())
                            [Environment]::SetEnvironmentVariable('AZURE_AUTOMATION_RUNBOOK_JOB_StartTime', $AzAutomationJob.StartTime.ToUniversalTime())

                            $AzAutomationRunbook = Get-AzAutomationRunbook -DefaultProfile $Context -ResourceGroupName $AzAutomationAccount.ResourceGroupName -AutomationAccountName $AzAutomationAccount.AutomationAccountName -Name $AzAutomationJob.RunbookName -ErrorAction Stop -Verbose:$false
                            if ($AzAutomationRunbook) {
                                Write-Verbose '[COMMON]: - Retrievedd Automation Runbook details'
                                [Environment]::SetEnvironmentVariable('AZURE_AUTOMATION_RUNBOOK_CreationTime', $AzAutomationRunbook.CreationTime.ToUniversalTime())
                                [Environment]::SetEnvironmentVariable('AZURE_AUTOMATION_RUNBOOK_LastModifiedTime', $AzAutomationRunbook.LastModifiedTime.ToUniversalTime())
                            }
                            else {
                                Throw "[COMMON]: - Unable to find own Automation Runbook details for runbook name $($AzAutomationJob.RunbookName)"
                            }
                        }
                        else {
                            Throw "[COMMON]: - Unable to find own Automation Job details for job Id $($PSPrivateMetadata.JobId)"
                        }
                    }
                    else {
                        Throw '[COMMON]: - Missing global variable $PSPrivateMetadata.JobId'
                    }
                }
                else {
                    Throw "[COMMON]: - Unable to find own Automation Account details for '$env:MG_PRINCIPAL_DISPLAYNAME'"
                }
            }
            else {
                Throw '[COMMON]: - Missing environment variable $env:MG_PRINCIPAL_DISPLAYNAME. Please run Common_0001__Connect-MgGraph.ps1 first.'
            }
        }
        else {
            Write-Verbose '[COMMON]: - Not running in Azure Automation - no connection environment variables set.'
        }
    }
    catch {
        Throw $_
    }
}

Get-Variable | Where-Object { $StartupVariables -notcontains @($_.Name, 'return') } | & { process { Remove-Variable -Scope 0 -Name $_.Name -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -Verbose:$false -Debug:$false } }        # Delete variables created in this script to free up memory for tiny Azure Automation sandbox
Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
