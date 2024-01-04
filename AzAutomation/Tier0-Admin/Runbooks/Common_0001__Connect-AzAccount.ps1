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
.REQUIREDSCRIPTS Common_0000__Import-Modules.ps1
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
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | ForEach-Object { $_.PSObject.Properties | ForEach-Object { $_.Name + ': ' + $_.Value } }) -join ', ') ---"

#region [COMMON] ENVIRONMENT ---------------------------------------------------
.\Common_0000__Import-Modules.ps1 -Modules @(
    @{ Name = 'Az.Accounts'; MinimumVersion = '2.8'; MaximumVersion = '2.65535' }
    @{ Name = 'Az.Automation'; MinimumVersion = '1.7'; MaximumVersion = '1.65535' }
) 1> $null
#endregion ---------------------------------------------------------------------

$Context = $null

$params = @{
    Scope = 'Process'
}

if (-Not (Get-AzContext)) {
    if ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
        Write-Verbose 'Using system-assigned Managed Service Identity'
        $params.Identity = $true
    }
    else {
        Write-Verbose 'Using interactive sign in'
    }

    try {
        Write-Information 'Connecting to Microsoft Azure ...'
        if ($Tenant) { $params.Tenant = $Tenant }
        if ($Subscription) { $params.Subscription = $Subscription }
        $Context = (Connect-AzAccount @params).context
    }
    catch {
        Throw "Failed to connect to Microsoft Azure";
    }

    $Context = Set-AzContext -SubscriptionName $Context.Subscription -DefaultProfile $Context

    if ($params.Identity) {
        $AzAutomationAccount = Get-AzAutomationAccount -DefaultProfile $Context -ErrorAction Stop | Where-Object AutomationAccountName -eq $env:MG_PRINCIPAL_DISPLAYNAME
        [Environment]::SetEnvironmentVariable('AZURE_AUTOMATION_SubscriptionId', $AzAutomationAccount.SubscriptionId)
        [Environment]::SetEnvironmentVariable('AZURE_AUTOMATION_ResourceGroupName', $AzAutomationAccount.ResourceGroupName)
        [Environment]::SetEnvironmentVariable('AZURE_AUTOMATION_AccountName', $AzAutomationAccount.AutomationAccountName)
        [Environment]::SetEnvironmentVariable('AZURE_AUTOMATION_IDENTITY_PrincipalId', $AzAutomationAccount.Identity.PrincipalId)
        [Environment]::SetEnvironmentVariable('AZURE_AUTOMATION_IDENTITY_TenantId', $AzAutomationAccount.Identity.TenantId)
        [Environment]::SetEnvironmentVariable('AZURE_AUTOMATION_IDENTITY_Type', $AzAutomationAccount.Identity.Type)

        $AzAutomationJob = Get-AzAutomationJob -DefaultProfile $Context -ResourceGroupName $env:AZURE_AUTOMATION_ResourceGroupName -AutomationAccountName $env:AZURE_AUTOMATION_AccountName -Id $PSPrivateMetadata.JobId -ErrorAction Stop
        [Environment]::SetEnvironmentVariable('AZURE_AUTOMATION_RUNBOOK_Name', $AzAutomationJob.RunbookName)
        [Environment]::SetEnvironmentVariable('AZURE_AUTOMATION_RUNBOOK_JOB_CreationTime', $AzAutomationJob.CreationTime.ToUniversalTime())
        [Environment]::SetEnvironmentVariable('AZURE_AUTOMATION_RUNBOOK_JOB_StartTime', $AzAutomationJob.StartTime.ToUniversalTime())

        $AzAutomationRunbook = Get-AzAutomationRunbook -DefaultProfile $Context -ResourceGroupName $env:AZURE_AUTOMATION_ResourceGroupName -AutomationAccountName $env:AZURE_AUTOMATION_AccountName -Name $env:AZURE_AUTOMATION_RUNBOOK_Name -ErrorAction Stop
        [Environment]::SetEnvironmentVariable('AZURE_AUTOMATION_RUNBOOK_CreationTime', $AzAutomationRunbook.CreationTime.ToUniversalTime())
        [Environment]::SetEnvironmentVariable('AZURE_AUTOMATION_RUNBOOK_LastModifiedTime', $AzAutomationRunbook.LastModifiedTime.ToUniversalTime())
    }
}

Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
return $Context
