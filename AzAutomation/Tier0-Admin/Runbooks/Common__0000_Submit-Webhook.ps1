<#
.SYNOPSIS
    Send data to web service
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
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name) ---"

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
