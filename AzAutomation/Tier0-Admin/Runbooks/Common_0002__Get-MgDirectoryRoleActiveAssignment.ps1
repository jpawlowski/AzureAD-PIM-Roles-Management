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
.REQUIREDSCRIPTS Common_0001__Connect-MgGraph.ps1,Common_0000__Import-Module.ps1
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>

<#
.SYNOPSIS
    Get active directory roles of current user

.DESCRIPTION
    Common runbook that can be used by other runbooks. It can not be started as an Azure Automation job directly.
#>

[CmdletBinding()]
Param()

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | ForEach-Object { $_.PSObject.Properties | ForEach-Object { $_.Name + ': ' + $_.Value } }) -join ', ') ---"
$StartupVariables = (Get-Variable | ForEach-Object { $_.Name })

# Avoid using Microsoft.Graph.Identity.Governance module as it requires too much memory in Azure Automation
$params = @{
    OutputType  = 'PSObject'
    Method      = 'GET'
    Uri         = "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?`$filter=PrincipalId eq %27$($env:MG_PRINCIPAL_ID)%27&`$expand=roleDefinition"
    ErrorAction = 'Stop'
}

try {
    $return = (Invoke-MgGraphRequest @params).value
}
catch {
    Throw $_
}

Write-Verbose "Received directory roles:`n$($return | ConvertTo-Json -Depth 5 -WarningAction SilentlyContinue)"

Get-Variable | Where-Object { $StartupVariables -notcontains @($_.Name, 'return') } | ForEach-Object { Remove-Variable -Scope 0 -Name $_.Name -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -Verbose:$false -Debug:$false }
Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
return $return
