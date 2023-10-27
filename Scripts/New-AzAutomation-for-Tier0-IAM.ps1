<#
.SYNOPSIS
    Create a new Azure Automation Account including Managed Identity for IAM automations in Tier 0 environment

.DESCRIPTION
    Create a new Azure Automation Account including Managed Identity for IAM automations in Tier 0 environment

.PARAMETER ResourceGroupName
    ResourceGroupName

.PARAMETER Name
    Name

.PARAMETER Location
    Location

.PARAMETER Plan
    Plan

.PARAMETER Tags
    Tags

.PARAMETER DefaultProfile
    DefaultProfule

.PARAMETER Location
    Location

.NOTES
    Filename: New-AzAutomation-for-Tier0-IAM.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
    Version: 1.0
#>
#Requires -Version 5.1
#Requires -Modules @{ ModuleName='Microsoft.Graph.Authentication'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Identity.SignIns'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Users'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Users.Actions'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Users.Functions'; ModuleVersion='2.0' }

[CmdletBinding(
    SupportsShouldProcess,
    ConfirmImpact = 'Medium'
)]
Param (
    [Parameter(Position = 0, mandatory = $true)]
    [string]$ResourceGroupName,
    [Parameter(Position = 1, mandatory = $true)]
    [string]$Name,
    [Parameter(Position = 2)]
    [string]$Location,
    [string]$Plan,
    [IDictionary]$Tags,
    [IAzureContextContainer]$DefaultProfile
)

if ("AzureAutomation/" -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
    Throw 'This script must be run interactively by a privileged administrator account.'
}

$MgScopes = @(
    'User.Read.All'                             # To read user information, inlcuding EmployeeHireDate
    'UserAuthenticationMethod.Read.All'         # To read authentication methods of the user
    'UserAuthenticationMethod.ReadWrite.All'    # To update authentication methods (TAP) of the user
    'Policy.Read.All'                           # To read and validate current policy settings
)
$MissingMgScopes = @()

foreach ($MgScope in $MgScopes) {
    if ($WhatIfPreference -and ($MgScope -like '*Write*')) {
        Write-Verbose "WhatIf: Removed $MgScope from required Microsoft Graph scopes"
    }
    elseif ($MgScope -notin @((Get-MgContext).Scopes)) {
        $MissingMgScopes += $MgScope
    }
}

if (-Not (Get-MgContext)) {
    Connect-MgGraph -UseDeviceCode -Scopes $MgScopes -ContextScope Process
}
elseif ($MissingMgScopes) {
    Throw "Missing Microsoft Graph authorization scopes:`n`n$($MissingMgScopes -join "`n")"
}

if (-Not $return.Errors) {
    
}
