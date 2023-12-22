<#
.SYNOPSIS
    Write error to error stream and return back object
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]
    $Param
)

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name) ---"

$params = if ($Param) {
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

Write-Error @params

Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"

return $params