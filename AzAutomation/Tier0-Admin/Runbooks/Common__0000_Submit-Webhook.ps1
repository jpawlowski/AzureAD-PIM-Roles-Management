<#PSScriptInfo
.VERSION 1.0.0
.GUID 35ab128e-c286-4240-9437-b4f2cd045650
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
    Send data to web service

.DESCRIPTION
    Common runbook that can be used by other runbooks. It can not be started as an Azure Automation job directly.
#>

[CmdletBinding()]
Param(
    [Parameter(mandatory = $true)]
    [String]$Uri,

    [Parameter(mandatory = $true)]
    [String]$Body,

    [Hashtable]$Param,
    [String]$ConvertTo = 'Json',
    [Hashtable]$ConvertToParam
)

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | ForEach-Object { $_.PSObject.Properties | ForEach-Object { $_.Name + ': ' + $_.Value } }) -join ', ') ---"

$WebRequestParams = if ($Param) { $Param.Clone() } else { @{} }
$WebRequestParams.Uri = $Uri

if (-Not $WebRequestParams.Method) { $WebRequestParams.Method = 'POST' }
if (-Not $WebRequestParams.UseBasicParsing) { $WebRequestParams.UseBasicParsing = $true }

$ConvertToParams = if ($ConvertToParam) { $ConvertToParam.Clone() } else { @{} }

Switch ($ConvertTo) {
    'Html' {
        $WebRequestParams.Body = $Body | ConvertTo-Html @ConvertToParams
    }
    'Json' {
        if ($null -eq $ConvertToParams.Depth) { $ConvertToParams.Depth = 100 }
        if ($null -eq $ConvertToParams.Compress) { $ConvertToParams.Compress = $true }
        $WebRequestParams.Body = $Body | ConvertTo-Json @ConvertToParams
    }
    'Xml' {
        if ($null -eq $ConvertToParams.Depth) { $ConvertToParams.Depth = 100 }
        $WebRequestParams.Body = $Body | ConvertTo-Xml @ConvertToParams
    }
    default {
        $WebRequestParams.Body = $Body
    }
}

$return = Invoke-WebRequest @WebRequestParams

Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
return $return
