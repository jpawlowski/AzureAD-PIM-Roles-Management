<#
.SYNOPSIS
    Create a new Microsoft Entra Service Principal to execute runbooks in our Tier 0 Azure Automation Account

.DESCRIPTION
    Create a new Microsoft Entra Service Principal to execute runbooks in our Tier 0 Azure Automation Account

.PARAMETER TenantId
    Tenant ID

.PARAMETER Subscription
    Subscription Name

.PARAMETER ResourceGroupName
    ResourceGroupName

.PARAMETER Name
    Name

.NOTES
    Filename: New-AzAdServicePrincipal-for-Tier1-IAM.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
    Version: 1.0
#>
#Requires -Version 5.1
#Requires -Modules @{ ModuleName='Az.Accounts'; ModuleVersion='2.8' }
#Requires -Modules @{ ModuleName='Az.Resources'; ModuleVersion='6.0' }

[CmdletBinding(
    SupportsShouldProcess,
    ConfirmImpact = 'High'
)]
Param (
    [Parameter(Position = 0, mandatory = $true)]
    [string]$TenantId,
    [Parameter(Position = 1, mandatory = $true)]
    [string]$Subscription,
    [Parameter(Position = 2, mandatory = $true)]
    [string]$ResourceGroupName,
    [Parameter(Position = 3, mandatory = $true)]
    [string]$AutomationAccountName,
    [Parameter(Position = 4, mandatory = $true)]
    [string]$Name
)

if ("AzureAutomation/" -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
    Throw 'This script must be run interactively by a privileged administrator account.'
}

if (
    (-Not (Get-AzContext)) -or
    ($TenantId -ne (Get-AzContext).Tenant)
) {
    Connect-AzAccount `
        -TenantId $TenantId `
        -Subscription $Subscription `
        -Scope Process
}
elseif (
    ($Subscription -ne (Get-AzContext).Subscription.Name) -and
    ($Subscription -ne (Get-AzContext).Subscription.Id)
) {
    Set-AzContext -Subscription $Subscription -WarningAction SilentlyContinue
}

$automationAccount = Get-AzAutomationAccount `
    -ResourceGroupName $ResourceGroupName `
    -Name $AutomationAccountName `
    -ErrorAction SilentlyContinue

if (-Not $automationAccount) {
    Throw "Please make sure to create the Azure Automation Account first."
}

$ServicePrincipal = Get-AzADServicePrincipal `
    -DisplayName $Name `
    -ErrorAction SilentlyContinue

if (-Not $ServicePrincipal) {
    if ($PSCmdlet.ShouldProcess(
            "Create Microsoft Entra Service Principal $($Name)",
            "Do you confirm to create new Microsoft Entra Service Principal $($Name) ?",
            'Create new Microsoft Entra Service Principal'
        )) {
        $ServicePrincipal = New-AzADServicePrincipal `
            -DisplayName $Name
        Write-Output 'Note: Save these information with care!'
        Write-Output ('Display Name: ' + $ServicePrincipal.DisplayName)
        Write-Output ('Application (client) ID: ' + $ServicePrincipal.AppId)
        Write-Output ('Client Secret: ' + $ServicePrincipal.PasswordCredentials.SecretText)
    }
    elseif ($WhatIfPreference) {
        Write-Verbose 'What If: A new Microsoft Entra Service Principal would have been created.'
    }
    else {
        Write-Verbose 'Creation of new Microsoft Entra Service Principal was aborted.'
        exit
    }
}

if ($PSCmdlet.ShouldProcess(
        "Assign desired Azure roles to Microsoft Entra Service Principal $($ServicePrincipal.AppId) ($($ServicePrincipal.DisplayName)) to access Azure Automation Account $($automationAccount.AutomationAccountName)",
        "Do you confirm to assign desired Azure roles to Service Principal $($ServicePrincipal.DisplayName) to access Azure Automation Account $($automationAccount.AutomationAccountName)?",
        'Assign Azure roles to Microsoft Entra Service Principal'
    )) {

    $Scope = "/subscriptions/$($automationAccount.SubscriptionId)/resourceGroups/$($automationAccount.ResourceGroupName)/providers/Microsoft.Automation/automationAccounts/$($automationAccount.AutomationAccountName)"
    $AzRoles = @(
        'Reader'
        'Automation Job Operator'
    )

    foreach ($RoleName in $AzRoles) {
        Write-Output "   Assigning: $RoleName"
        $null = New-AzRoleAssignment -ObjectId $ServicePrincipal.Id `
            -RoleDefinitionName $RoleName `
            -Scope $Scope `
            -ErrorAction SilentlyContinue
    }
}
