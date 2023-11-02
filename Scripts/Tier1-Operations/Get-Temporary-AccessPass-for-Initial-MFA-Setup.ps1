<#
.SYNOPSIS
    Start Azure Automation Runbook and retrieve new Temporary Access Pass for initial MFA setup

.DESCRIPTION
    Start Azure Automation Runbook and retrieve new Temporary Access Pass for initial MFA setup.
    This is just an example script. You SHOULD save your client secret encrypted instead of in this file,
    or use certificate authentication to connect to Azure.

    Also make sure to change the defaults of the following parameters for unattended run of this script:

    - TenantId
    - Subscription
    - ResourceGroupName
    - AutomationAccountName

.PARAMETER TenantId
    Tenant ID

.PARAMETER Subscription
    Subscription Name

.PARAMETER ResourceGroupName
    ResourceGroupName

.PARAMETER AutomationAccountName
    AutomationAccountName

.PARAMETER UserId
    UserId

.NOTES
    Filename: Get-Temporary-AccessPass-for-Initial-MFA-Setup.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
    Version: 1.0
#>
#Requires -Version 5.1
#Requires -Modules @{ ModuleName='Az.Accounts'; ModuleVersion='2.12' }
#Requires -Modules @{ ModuleName='Az.Automation'; ModuleVersion='1.9' }

Param (
    [string]$TenantId = '8cb0668a-9ecd-4147-b144-fa23663291a8',
    [string]$Subscription = '6f0ea36a-a698-47f3-a52d-2aeb2d2d03cc',
    [string]$ResourceGroupName = 'corp-iam-automations-rg',
    [string]$AutomationAccountName = 'corp-iam-automations',
    [Parameter(Position = 0, mandatory = $true)]
    [string]$UserId
)

$ClientId = '4e85a7f1-28ef-48e3-a55b-e7fea66ca1bb'          # Fill in your client ID
$ClientSecret = 'ThisIsMySecretInClearText'                 # Fill in your client secret

if ("AzureAutomation/" -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
    Throw 'This script must not be run from an Azure Automation runbook.'
}

if (
    (-Not (Get-AzContext)) -or
    ($TenantId -ne (Get-AzContext).Tenant)
) {
    $SecureStringPwd = $ClientSecret | ConvertTo-SecureString -AsPlainText -Force
    $PSCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ClientId, $SecureStringPwd

    Connect-AzAccount `
        -ServicePrincipal `
        -Credential $PSCredential `
        -TenantId $TenantId `
        -Subscription $Subscription `
        -Scope Process
}
elseif (
    ($Subscription -ne (Get-AzContext).Subscription.Name) -and
    ($Subscription -ne (Get-AzContext).Subscription.Id)
) {
    $null = Set-AzContext -Subscription $Subscription -WarningAction SilentlyContinue
}

$job = Start-AzAutomationRunbook `
    -ResourceGroupName $ResourceGroupName `
    -AutomationAccountName $AutomationAccountName `
    -Name 'New-Temporary-Access-Pass-for-Initial-MFA-Setup-V1' `
    -Parameters @{ UserId = $UserId }

$doLoop = $true
Do {
    $job = Get-AzAutomationJob `
        -ResourceGroupName $job.ResourceGroupName `
        -AutomationAccountName $job.AutomationAccountName `
        -Id $job.JobId
    $status = $job.Status
    $doLoop = (($status -ne 'Completed') -and ($status -ne 'Failed') -and ($status -ne 'Suspended') -and ($status -ne 'Stopped'))
    Start-Sleep 3
} While ($doLoop)

$outputObj = Get-AzAutomationJobOutput `
    -ResourceGroupName $job.ResourceGroupName `
    -AutomationAccountName $job.AutomationAccountName `
    -Id $job.JobId `
    -Stream Output

$outputJson = ConvertFrom-Json -InputObject $outputObj.Summary

return $outputJson.data.TemporaryAccessPass.TemporaryAccessPass
