<#PSScriptInfo
.VERSION 1.0.0
.GUID 1e45ba32-bbcf-46f8-a759-05e36e67ac09
.AUTHOR Julian Pawlowski
.COMPANYNAME Workoho GmbH
.COPYRIGHT (c) 2024 Workoho GmbH. All rights reserved.
.TAGS
.LICENSEURI
.PROJECTURI
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>

<#
.SYNOPSIS
    Write error to error stream and return back object

.DESCRIPTION
    Common runbook that can be used by other runbooks. It can not be started as an Azure Automation job directly.
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]
    $Param
)

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
# Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | ForEach-Object { $_.PSObject.Properties | ForEach-Object { $_.Name + ': ' + $_.Value } }) -join ', ') ---"

$return = if ($Param) {
    if ($Param -is [String]) {
        @{ Message = $Param }
    }
    else {
        $Param.Clone()
    }
}
else {
    @{}
}

Write-Error @return

# Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
return $return
