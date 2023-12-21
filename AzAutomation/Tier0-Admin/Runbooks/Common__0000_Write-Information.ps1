<#
.SYNOPSIS
    Write information to information stream and return back object
#>

#Requires -Version 5.1

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]
    $Param
)

# if (-Not $MyInvocation.PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name) ---"

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
foreach ($key in $params.Keys) {
    if ($key -notin 'MessageData', 'Tags') { continue }
    $iparams.$key = $params.$key
}
$params.Message = $params.MessageData
$params.Remove('MessageData')

Write-Information @iparams

Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"

return $params
