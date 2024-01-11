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
$StartupVariables = (Get-Variable | ForEach-Object { $_.Name })

foreach ($Item in $Variable) {
    # Script parameters be of type array/collection and be processed during a loop,
    # and therefore updated multiple times
    if (
        (($scriptParameterOnly -eq $true) -and ($null -eq $Item.respectScriptParameter)) -or
        (($scriptParameterOnly -eq $false) -and ($null -ne $Item.respectScriptParameter))
    ) { continue }

    if ($null -eq $Item.mapToVariable) {
        Write-Warning "[$($Item.sourceName) --> `$script:???] Missing mapToVariable property in configuration."
        continue
    }

    $params = @{
        Name  = $Item.mapToVariable
        Scope = 1
        Force = $true
    }

    if (-Not $Item.respectScriptParameter) { $params.Option = 'Constant' }

    if (
        ($Item.respectScriptParameter) -and
        ($null -ne $(Get-Variable -Name $Item.respectScriptParameter -Scope $params.Scope -ValueOnly -ErrorAction SilentlyContinue))
    ) {
        $params.Value = Get-Variable -Name $Item.respectScriptParameter -Scope $params.Scope -ValueOnly
        Write-Verbose "[$($Item.sourceName) --> `$script:$($params.Name)] Using value from script parameter $($Item.respectScriptParameter)"
    }
    elseif ([Environment]::GetEnvironmentVariable($Item.sourceName)) {
        $params.Value = (Get-ChildItem -Path "env:$($Item.sourceName)").Value
        Write-Verbose "[$($Item.sourceName) --> `$script:$($params.Name)] Using value from `$env:$($Item.sourceName)"
    }
    elseif ($Item.ContainsKey('defaultValue')) {
        $params.Value = $Item.defaultValue
        Write-Verbose "[$($Item.sourceName) --> `$script:$($params.Name)] `$env:$($Item.sourceName) not found, using built-in default value"
    }
    else {
        Write-Error "[$($Item.sourceName) --> `$script:$($params.Name)] Missing default value in configuration."
        continue
    }

    if (
        (-Not $Item.Regex) -and
        (($params.Value -ne $false) -and ($params.Value -ne $true))
    ) {
        if ($Item.ContainsKey('defaultValue')) {
            $params.Value = $Item.defaultValue
            Write-Warning "[$($Item.sourceName) --> `$script:$($params.Name)] Value does not seem to be a boolean, using built-in default value"
        }
        else {
            Write-Error "[$($Item.sourceName) --> `$script:$($params.Name)] Value does not seem to be a boolean, and no default value was found in configuration."
            continue
        }
    }

    if (
        $Item.Regex -and
        (-Not [String]::IsNullOrEmpty($params.Value)) -and
        ($params.Value -notmatch $Item.Regex)
    ) {
        $params.Value = $null
        if ($Item.ContainsKey('defaultValue')) {
            $params.Value = $Item.defaultValue
            Write-Warning "[$($Item.sourceName) --> `$script:$($params.Name)] Value does not match '$($Item.Regex)', using built-in default value"
        }
        else {
            Write-Error "[$($Item.sourceName) --> `$script:$($params.Name)] Value does not match '$($Item.Regex)', and no default value was found in configuration."
            continue
        }
    }
    New-Variable @params
}

Get-Variable | Where-Object { $StartupVariables -notcontains $_.Name } | ForEach-Object { Remove-Variable -Scope 0 -Name $_.Name -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -Verbose:$false -Debug:$false }
Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
