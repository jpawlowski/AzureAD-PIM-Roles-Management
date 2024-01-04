<#PSScriptInfo
.VERSION 1.0.0
.GUID e392dfb1-8ca4-4f5c-b073-c453ce004891
.AUTHOR Julian Pawlowski
.COMPANYNAME Workoho GmbH
.COPYRIGHT (c) 2024 Workoho GmbH. All rights reserved.
.TAGS
.LICENSEURI
.PROJECTURI
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS Common_0001__Connect-MgGraph.ps1,Common_0001__Connect-AzAccount.ps1
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>

<#
.SYNOPSIS
    Get detailled information about the current job in Azure Automation

.DESCRIPTION
    Common runbook that can be used by other runbooks. It can not be started as an Azure Automation job directly.
#>

[CmdletBinding()]
Param()

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | ForEach-Object { $_.PSObject.Properties | ForEach-Object { $_.Name + ': ' + $_.Value } }) -join ', ') ---"

$Job = @{}

if ($env:AZURE_AUTOMATION_RUNBOOK_Name) {
    $Job.CreationTime = (Get-Date $env:AZURE_AUTOMATION_RUNBOOK_JOB_CreationTime).ToUniversalTime()
    $Job.StartTime = (Get-Date $env:AZURE_AUTOMATION_RUNBOOK_JOB_StartTime).ToUniversalTime()

    $Job.AutomationAccount = @{
        SubscriptionId = $env:AZURE_AUTOMATION_SubscriptionId
        ResourceGroupName = $env:AZURE_AUTOMATION_ResourceGroupName
        Name = $env:AZURE_AUTOMATION_AccountName
        Identity = @{
            PrincipalId = $env:AZURE_AUTOMATION_IDENTITY_PrincipalId
            TenantId = $env:AZURE_AUTOMATION_IDENTITY_TenantId
            Type = $env:AZURE_AUTOMATION_IDENTITY_Type
        }
    }
    $Job.Runbook = @{
        Name = $env:AZURE_AUTOMATION_RUNBOOK_Name
        CreationTime = (Get-Date $env:AZURE_AUTOMATION_RUNBOOK_CreationTime).ToUniversalTime()
        LastModifiedTime = (Get-Date $env:AZURE_AUTOMATION_RUNBOOK_LastModifiedTime).ToUniversalTime()
    }
}
else {
    $Job.CreationTime = (Get-Date ).ToUniversalTime()
    $Job.StartTime = $Job.CreationTime
    $Job.Runbook = @{
        Name = (Get-Item $MyInvocation.MyCommand).BaseName
    }
}

Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
return $Job
