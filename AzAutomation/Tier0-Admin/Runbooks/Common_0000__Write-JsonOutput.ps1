<#PSScriptInfo
.VERSION 1.0.0
.GUID fd95f377-4c0a-4dfa-addd-14cf6dca99cf
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
    Write text in JSON format to output stream

.DESCRIPTION
    Common runbook that can be used by other runbooks. It can not be started as an Azure Automation job directly.
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]
    $InputObject,

    [hashtable]$ConvertToParam
)

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
# Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | & { process{$_.PSObject.Properties | & { process{$_.Name + ': ' + $_.Value} }} }) -join ', ') ---"

$params = if ($ConvertToParam) { $ConvertToParam.Clone() } else { @{} }
if ($null -eq $params.Compress) {
    $params.Compress = $true
    if ($VerbosePreference -eq 'Continue') { $params.Compress = $false }
}
if ($null -eq $params.Depth) { $params.Depth = 100 }

Write-Output $($InputObject | ConvertTo-Json @params)

# Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
