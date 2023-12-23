<#
.SYNOPSIS
    Imports modules silently
#>

[CmdletBinding()]
Param(
    [Parameter(mandatory = $true)]
    [Array]$Modules
)

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name) ---"

$OrigVerbosePreference = $global:VerbosePreference
$global:VerbosePreference = 'SilentlyContinue'

$Missing = @()

foreach ($Module in $Modules) {
    try {
        $Module.ErrorAction = 'Stop'
        Import-Module @Module
    }
    catch {
        $Missing += $_
    }
}

If ($Missing.Count -gt 0) {
    Throw $Missing
}

$global:VerbosePreference = $OrigVerbosePreference

Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
