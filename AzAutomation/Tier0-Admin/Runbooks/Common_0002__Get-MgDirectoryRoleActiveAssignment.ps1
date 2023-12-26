<#PSScriptInfo
.VERSION 1.0.0
.GUID 3e9f0b5b-be2f-4c10-bdfa-25d8b4550e67
.AUTHOR Julian Pawlowski
.COMPANYNAME Workoho GmbH
.COPYRIGHT (c) 2024 Workoho GmbH. All rights reserved.
.TAGS
.LICENSEURI
.PROJECTURI
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS Common_0001__Connect-MgGraph.ps1,Common_0000__Import-Modules.ps1
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>

<#
.SYNOPSIS
    Get active directory roles of current user

.DESCRIPTION
    Common runbook that can be used by other runbooks. It can not be started as an Azure Automation job directly.
#>

#Requires -Version 5.1

[CmdletBinding()]
Param()

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | ForEach-Object { $_.PSObject.Properties | ForEach-Object { $_.Name + ': ' + $_.Value } }) -join ', ') ---"

#region CONNECTIONS ------------------------------------------------------------
.\Common_0001__Connect-MgGraph.ps1 1> $null
#endregion ---------------------------------------------------------------------

#region [COMMON] ENVIRONMENT ---------------------------------------------------
.\Common_0000__Import-Modules.ps1 -Modules @(
    @{ Name = 'Microsoft.Graph.Beta.Users'; MinimumVersion = '2.0'; MaximumVersion = '2.65535' }
    @{ Name = 'Microsoft.Graph.Beta.Applications'; MinimumVersion = '2.0'; MaximumVersion = '2.65535' }
) 1> $null
#endregion ---------------------------------------------------------------------

$return = $null

if ((Get-MgContext).AuthType -eq 'Delegated') {
    $return = Get-MgBetaUserTransitiveMemberOfAsDirectoryRole `
        -UserId $global:MyMgPrincipal.Id `
        -ConsistencyLevel eventual `
        -CountVariable countVar
}
else {
    $return = Get-MgBetaServicePrincipalTransitiveMemberOfAsDirectoryRole `
        -ServicePrincipalId $global:MyMgPrincipal.Id `
        -ConsistencyLevel eventual `
        -CountVariable countVar
}

Write-Verbose "Received directory roles: $($return.DisplayName -join ', ')"

Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
return $return
