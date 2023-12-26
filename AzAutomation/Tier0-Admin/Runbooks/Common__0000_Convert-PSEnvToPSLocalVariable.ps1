<#PSScriptInfo
.VERSION 1.0.0
.GUID a775a4d9-9195-4410-a2bf-b1eeaa0da599
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
    Import variables from script parameter and $env to local script scope

.DESCRIPTION
    Common runbook that can be used by other runbooks. It can not be started as an Azure Automation job directly.
#>

[CmdletBinding()]
Param(
    [Parameter(mandatory = $true)]
    [AllowEmptyCollection()]
    [Array]$Variable,

    [Boolean]$scriptParameterOnly
)

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | ForEach-Object { $_.PSObject.Properties | ForEach-Object { $_.Name + ': ' + $_.Value } }) -join ', ') ---"

foreach ($Item in $Variable) {
    # Script parameters be of type array/collection and be processed during a loop,
    # and therefore updated multiple times
    if (
        (($scriptParameterOnly -eq $true) -and ($null -eq $Item.respectScriptParameter)) -or
        (($scriptParameterOnly -eq $false) -and ($null -ne $Item.respectScriptParameter))
    ) { continue }

    $params = @{
        Name  = $Item.mapToVariable
        Value = $null
        Scope = 1
        Force = $true
        # Option = 'Constant'
    }
    if (-Not $Item.respectScriptParameter) { $params.Option = 'Constant' }
    if (
        ($Item.respectScriptParameter) -and
        (-Not [string]::IsNullOrEmpty($(Get-Variable -Name $Item.respectScriptParameter -Scope $params.Scope -ValueOnly -ErrorAction SilentlyContinue)))
    ) {
        if ($Item.respectScriptParameter) {
            $params.Value = Get-Variable -Name $Item.respectScriptParameter -Scope $params.Scope -ValueOnly
        }
        Write-Verbose "Using $($params.Name) from script parameter $($Item.respectScriptParameter)"
    }
    elseif ([Environment]::GetEnvironmentVariable($Item.sourceName)) {
        $params.Value = (Get-ChildItem -Path "env:$($Item.sourceName)").Value
        Write-Verbose "Using $($params.Name) from `$env:$($Item.sourceName)"
    }
    elseif ($Item.defaultValue) {
        $params.Value = $Item.defaultValue
        Write-Verbose "`$env:$($Item.sourceName) not found, using $($params.Name) built-in default value"
    }
    if (
        $params.Value -and
        $Item.Type -and
        ($Item.Type -eq 'Boolean') -and
        (($params.Value -ne $false) -and ($params.Value -ne $true))
    ) {
        Write-Warning "Environment variable $($Item.sourceName) does not seem to be a boolean so it is ignored"
        $params.Value = $null
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
