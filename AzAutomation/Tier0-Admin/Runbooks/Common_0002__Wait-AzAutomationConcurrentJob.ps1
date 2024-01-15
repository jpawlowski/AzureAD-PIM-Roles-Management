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
.REQUIREDSCRIPTS Common_0001__Connect-AzAccount.ps1
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>

<#
.SYNOPSIS
    Wait for other concurrent jobs of the same runbook in Azure Automation

.DESCRIPTION
    Common runbook that can be used by other runbooks. It can not be started as an Azure Automation job directly.
#>

[CmdletBinding()]
Param()

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | & { process{$_.PSObject.Properties | & { process{$_.Name + ': ' + $_.Value} }} }) -join ', ') ---"
$StartupVariables = (Get-Variable | & { process { $_.Name } })      # Remember existing variables so we can cleanup ours at the end of the script

if ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {

    #region [COMMON] CONNECTIONS ---------------------------------------------------
    .\Common_0001__Connect-AzAccount.ps1 1> $null
    #endregion ---------------------------------------------------------------------

    if ([string]::IsNullOrEmpty($env:AZURE_AUTOMATION_ResourceGroupName)) {
        Throw 'Missing environment variable $env:AZURE_AUTOMATION_ResourceGroupName.'
    }
    if ([string]::IsNullOrEmpty($env:AZURE_AUTOMATION_AccountName)) {
        Throw 'Missing environment variable $env:AZURE_AUTOMATION_AccountName.'
    }
    if ([string]::IsNullOrEmpty($env:AZURE_AUTOMATION_RUNBOOK_Name)) {
        Throw 'Missing environment variable $env:AZURE_AUTOMATION_RUNBOOK_Name.'
    }

    if ($env:AZURE_AUTOMATION_ResourceGroupName -and $env:AZURE_AUTOMATION_AccountName -and $env:AZURE_AUTOMATION_RUNBOOK_Name) {

        $DoLoop = $true
        $RetryCount = 1
        $MaxRetry = 120
        $WaitSec = 30

        do {
            try {
                $jobs = Get-AzAutomationJob -ResourceGroupName $env:AZURE_AUTOMATION_ResourceGroupName -AutomationAccountName $env:AZURE_AUTOMATION_AccountName -RunbookName $env:AZURE_AUTOMATION_RUNBOOK_Name -ErrorAction Stop -Verbose:$false
            }
            catch {
                Throw $_
            }
            $activeJobs = $jobs | Where-Object { $_.status -eq 'Running' -or $_.status -eq 'Queued' -or $_.status -eq 'New' -or $_.status -eq 'Activating' -or $_.status -eq 'Resuming' } | Sort-Object -Property CreationTime
            Clear-Variable -Name jobs

            $jobRanking = [System.Collections.ArrayList]::new()
            $rank = 0

            foreach ($activeJob in $activeJobs) {
                $rank++
                $activeJob | Add-Member -MemberType NoteProperty -Name jobRanking -Value $rank -Force
                $null = $jobRanking.Add($activeJob)
            }

            $currentJob = $activeJobs | Where-Object { $_.JobId -eq $PSPrivateMetadata.JobId }
            Clear-Variable -Name activeJobs

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
                Write-Verbose "[COMMON]: - $(Get-Date -Format yyyy-MM-dd-hh-mm-ss.ffff) Waiting for concurrent jobs: I am at rank $($currentJob.jobRanking) ..." -Verbose
                Start-Sleep -Seconds $WaitSec
            }
        } While ($DoLoop)
    }
}
else {
    Write-Verbose '[COMMON]: - Not running in Azure Automation: Concurrency check NOT ACTIVE.'
    $return = $true
}

Get-Variable | Where-Object { $StartupVariables -notcontains @($_.Name, 'return') } | & { process { Remove-Variable -Scope 0 -Name $_.Name -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -Verbose:$false -Debug:$false } }        # Delete variables created in this script to free up memory for tiny Azure Automation sandbox
Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
return $return
