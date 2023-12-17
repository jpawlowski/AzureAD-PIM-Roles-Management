<#
.SYNOPSIS
    Import variables from script parameter and $env to local script scope

.NOTES
    Original name: Common__0000_Convert-PSEnvToPSLocalVariable.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
    Version: 1.0.0
#>

#Requires -Version 5.1

[CmdletBinding()]
Param(
    [Parameter(mandatory = $true)]
    [Array]$Variable
)

if (-Not $MyInvocation.PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name) ---"

foreach ($Item in $Variable) {
    $params = @{
        Name   = $Item.mapToVariable
        Value  = $null
        Scope  = 1
        Force  = $true
        Option = 'Constant'
    }
    if (
        ($Item.respectScriptParameter) -and
        (-Not [string]::IsNullOrEmpty($(Get-Variable -Name $Item.respectScriptParameter -Scope $params.Scope -ValueOnly -ErrorAction SilentlyContinue)))
    ) {
        if ($Item.respectScriptParameter) {
            $params.Value = Get-Variable -Name $Item.respectScriptParameter -Scope $params.Scope -ValueOnly
        }
        Write-Verbose "Using $($params.Name) from script parameter $($Item.respectScriptParameter)"
    }
    elseif (Get-ChildItem -Path "env:$($Item.sourceName)" -ErrorAction SilentlyContinue) {
        $params.Value = (Get-ChildItem -Path "env:$($Item.sourceName)").Value
        Write-Verbose "Using $($params.Name) from `$env:$($Item.sourceName)"
    }
    elseif ($Item.defaultValue) {
        $params.Value = $Item.defaultValue
        Write-Verbose "`$env:$($Item.sourceName) not found, using $($params.Name) built-in default value"
    }
    if (
        $params.Value -and
        ($Item.Regex) -and
        ($params.Value -notmatch $Item.Regex)
    ) {
        Write-Warning "Value of environment variable $($Item.sourceName) does not match '$($Item.Regex)' and was ignored"
        $params.Value = $null
    }
    New-Variable @params
}

Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
