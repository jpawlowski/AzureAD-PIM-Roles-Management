<#
.SYNOPSIS
    Connect to Azure using either a Managed Service Identity, or an interactive session

.OUTPUTS
    Microsoft.Azure.Commands.Profile.Models.Core.PSAzureContext

.NOTES
    Original name: Common__0001_Connect-AzAccount.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
    Version: 0.1.0
#>

[CmdletBinding()]
Param(
    $Tenant,
    $Subscription
)

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name) ---"

#region [COMMON] ENVIRONMENT ---------------------------------------------------
.\Common__0000_Import-Modules.ps1 -Modules @(
    @{ Name = 'Az.Accounts'; MinimumVersion = '2.8'; MaximumVersion = '2.65535' }
    @{ Name = 'Az.Automation'; MinimumVersion = '1.9'; MaximumVersion = '1.65535' }
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
}

Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
return $Context
