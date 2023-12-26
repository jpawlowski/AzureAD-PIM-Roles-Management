<#PSScriptInfo
.VERSION 1.0.0
.GUID 7c2ab51e-4863-474e-bfcf-6854d3c3a688
.AUTHOR Julian Pawlowski
.COMPANYNAME Workoho GmbH
.COPYRIGHT (c) 2024 Workoho GmbH. All rights reserved.
.TAGS
.LICENSEURI
.PROJECTURI
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS Common_0002__Connect-AzAccount.ps1
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>

<#
.SYNOPSIS
    Wait for other concurrent jobs of the same runbook in Azure Automation

.DESCRIPTION
    Common runbook that can be used by other runbooks. It can not be started as an Azure Automation job directly.
#>

#Requires -Version 5.1

[CmdletBinding()]
Param()

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | ForEach-Object { $_.PSObject.Properties | ForEach-Object { $_.Name + ': ' + $_.Value } }) -join ', ') ---"

$return = $null

if ($env:AZURE_AUTOMATION_RUNBOOK_Name) {

    #region [COMMON] CONNECTIONS ---------------------------------------------------
    .\Common_0002__Connect-AzAccount.ps1 1> $null
    #endregion ---------------------------------------------------------------------

    $DoLoop = $true
    $RetryCount = 1
    $MaxRetry = 120
    $WaitSec = 30

    do {
        try {
            $jobs = Get-AzAutomationJob -ResourceGroupName $env:AZURE_AUTOMATION_ResourceGroupName -AutomationAccountName $env:AZURE_AUTOMATION_AccountName -RunbookName $env:AZURE_AUTOMATION_RUNBOOK_Name -ErrorAction Stop
        }
        catch {
            Throw $_
        }
        $activeJobs = $jobs | Where-Object { $_.status -eq 'Running' -or $_.status -eq 'Queued' -or $_.status -eq 'New' -or $_.status -eq 'Activating' -or $_.status -eq 'Resuming' } | Sort-Object -Property CreationTime

        $jobRanking = @()
        $rank = 0

        foreach ($activeJob in $activeJobs) {
            $rank++
            $activeJob | Add-Member -MemberType NoteProperty -Name jobRanking -Value $rank -Force
            $jobRanking += $activeJob
        }

        $currentJob = $activeJobs | Where-Object { $_.JobId -eq $PSPrivateMetadata.JobId }

        If ($currentJob.jobRanking -eq 1) {
            $DoLoop = $false
            $return = $true
        }
        elseif ($RetryCount -ge $MaxRetry) {
            $DoLoop = $false
            $return = $false
        }
        else {
            $RetryCount += 1
            Write-Verbose "$(Get-Date -Format yyyy-MM-dd-hh-mm-ss.ffff) Waiting for concurrent jobs: I am at rank $($currentJob.jobRanking) ..."
            Start-Sleep -Seconds $WaitSec
        }
    } While ($DoLoop)
}
else {
    $return = $true
    Write-Verbose 'Not running in Azure Automation: Concurrency check NOT ACTIVE.'
}

Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"

return $return