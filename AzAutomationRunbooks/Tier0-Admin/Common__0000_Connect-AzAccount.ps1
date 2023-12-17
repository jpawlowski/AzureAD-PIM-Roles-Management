<#
.SYNOPSIS
    Connect to Azure using either a Managed Service Identity, or an interactive session

.OUTPUTS
    Microsoft.Azure.Commands.Profile.Models.Core.PSAzureContext

.NOTES
    Original name: Common__0000_Connect-AzAccount.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
    Version: 0.1.0
#>

#Requires -Version 5.1

[CmdletBinding()]
Param(
    $Tenant,
    $Subscription
)

if (-Not $MyInvocation.PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name) ---"

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
