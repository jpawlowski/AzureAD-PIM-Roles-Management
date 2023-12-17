<#
.SYNOPSIS
    Write warning to warning stream and return back object
#>

#Requires -Version 5.1

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]
    $Param
)

if (-Not $MyInvocation.PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
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

Write-Warning -Message ($params | Select-Object -Property Message).Message

Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"

return $params
