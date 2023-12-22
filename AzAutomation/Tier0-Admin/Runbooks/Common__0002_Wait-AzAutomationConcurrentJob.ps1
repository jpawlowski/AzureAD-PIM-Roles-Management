<#
.SYNOPSIS
    Wait for other concurrent jobs of the same runbook in Azure Automation

.NOTES
    Original name: Common__0002_Wait-AzAutomationConcurrentJob.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
    Version: 1.0.0
#>

#Requires -Version 5.1

[CmdletBinding()]
Param()

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name) ---"

$return = $null

if ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {

    #region [COMMON] CONNECTIONS ---------------------------------------------------
    .\Common__0001_Connect-AzAccount.ps1 1> $null
    #endregion ---------------------------------------------------------------------

    .\Common__0000_Import-Modules.ps1 -Modules @(
        @{ Name = 'Az.Automation'; MinimumVersion = '1.9'; MaximumVersion = '1.65535' }
    ) 1> $null

    $DoLoop = $true
    $RetryCount = 1
    $MaxRetry = 120
    $WaitSec = 30

    $AA = Get-AzAutomationAccount
    $RunbookName = (Get-AzAutomationJob -AutomationAccountName $AA.AutomationAccountName -ResourceGroupName $AA.ResourceGroupName -Id $PSPrivateMetadata.JobId).RunbookName

    do {
        try {
            $jobs = Get-AzAutomationJob -ResourceGroupName $AA.ResourceGroupName -AutomationAccountName $AA.AutomationAccountName -RunbookName $RunbookName -ErrorAction Stop
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