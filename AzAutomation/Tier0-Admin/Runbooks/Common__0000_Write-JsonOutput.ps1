<#
.SYNOPSIS
    Write text in JSON format to output stream
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]
    $InputObject,

    [hashtable]$ConvertToParam
)

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name) ---"

$params = if ($ConvertToParam) { $ConvertToParam.Clone() } else { @{} }
if ($null -eq $params.Compress) {
    $params.Compress = $true
    if ('Continue' -eq $VerbosePreference) { $params.Compress = $false }
}
if ($null -eq $params.Depth) { $params.Depth = 100 }

Write-Output $($InputObject | ConvertTo-Json @params)

Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
