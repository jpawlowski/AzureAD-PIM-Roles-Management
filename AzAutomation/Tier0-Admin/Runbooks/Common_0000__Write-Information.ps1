<#PSScriptInfo
.VERSION 1.0.0
.GUID 559c2a2a-cf2d-46d5-a39b-4ca644a4075b
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
    Write information to information stream and return back object

.DESCRIPTION
    Common runbook that can be used by other runbooks. It can not be started as an Azure Automation job directly.
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]
    $Param
)

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
# Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | & { process{$_.PSObject.Properties | & { process{$_.Name + ': ' + $_.Value} }} }) -join ', ') ---"

$params = if ($Param) {
    if ($Param -is [String]) {
        @{ MessageData = $Param }
    }
    else {
        $Param.Clone()
    }
}
else {
    @{}
}

if (-Not $params.MessageData -and $params.Message) {
    $params.MessageData = $params.Message
    $params.Remove('Message')
}
$iparams = @{}
$params.Keys | & {
    process {
        if ($_ -notin 'MessageData', 'Tags') { return }
        $iparams.$_ = $params.$_
    }
}
$params.Message = $params.MessageData
$params.Remove('MessageData')

Write-Information @iparams

# Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
return $params
