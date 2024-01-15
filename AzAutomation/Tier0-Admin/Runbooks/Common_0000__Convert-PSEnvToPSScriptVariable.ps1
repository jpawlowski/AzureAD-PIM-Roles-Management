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
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | & { process{$_.PSObject.Properties | & { process{$_.Name + ': ' + $_.Value} }} }) -join ', ') ---"
$StartupVariables = (Get-Variable | & { process { $_.Name } })      # Remember existing variables so we can cleanup ours at the end of the script

$Variable | & {
    process {
        # Script parameters be of type array/collection and be processed during a loop,
        # and therefore updated multiple times
        if (
            (($scriptParameterOnly -eq $true) -and ($null -eq $_.respectScriptParameter)) -or
            (($scriptParameterOnly -eq $false) -and ($null -ne $_.respectScriptParameter))
        ) { return }

        if ($null -eq $_.mapToVariable) {
            Write-Warning "[COMMON]: - [$($_.sourceName) --> `$script:???] Missing mapToVariable property in configuration."
            return
        }

        $params = @{
            Name  = $_.mapToVariable
            Scope = 2
            Force = $true
        }

        if (-Not $_.respectScriptParameter) { $params.Option = 'Constant' }

        if (
            ($_.respectScriptParameter) -and
            ($null -ne $(Get-Variable -Name $_.respectScriptParameter -Scope $params.Scope -ValueOnly -ErrorAction SilentlyContinue))
        ) {
            $params.Value = Get-Variable -Name $_.respectScriptParameter -Scope $params.Scope -ValueOnly
            Write-Verbose "[COMMON]: - [$($_.sourceName) --> `$script:$($params.Name)] Using value from script parameter $($_.respectScriptParameter)"
        }
        elseif ([Environment]::GetEnvironmentVariable($_.sourceName)) {
            $params.Value = (Get-ChildItem -Path "env:$($_.sourceName)").Value
            Write-Verbose "[COMMON]: - [$($_.sourceName) --> `$script:$($params.Name)] Using value from `$env:$($_.sourceName)"
        }
        elseif ($_.ContainsKey('defaultValue')) {
            $params.Value = $_.defaultValue
            Write-Verbose "[COMMON]: - [$($_.sourceName) --> `$script:$($params.Name)] `$env:$($_.sourceName) not found, using built-in default value"
        }
        else {
            Write-Error "[COMMON]: - [$($_.sourceName) --> `$script:$($params.Name)] Missing default value in configuration."
            return
        }

        if (
            (-Not $_.Regex) -and
            (($params.Value -ne $false) -and ($params.Value -ne $true))
        ) {
            if ($_.ContainsKey('defaultValue')) {
                $params.Value = $_.defaultValue
                Write-Warning "[COMMON]: - [$($_.sourceName) --> `$script:$($params.Name)] Value does not seem to be a boolean, using built-in default value"
            }
            else {
                Write-Error "[COMMON]: - [$($_.sourceName) --> `$script:$($params.Name)] Value does not seem to be a boolean, and no default value was found in configuration."
                return
            }
        }

        if (
            $_.Regex -and
            (-Not [String]::IsNullOrEmpty($params.Value)) -and
            ($params.Value -notmatch $_.Regex)
        ) {
            $params.Value = $null
            if ($_.ContainsKey('defaultValue')) {
                $params.Value = $_.defaultValue
                Write-Warning "[COMMON]: - [$($_.sourceName) --> `$script:$($params.Name)] Value does not match '$($_.Regex)', using built-in default value"
            }
            else {
                Write-Error "[COMMON]: - [$($_.sourceName) --> `$script:$($params.Name)] Value does not match '$($_.Regex)', and no default value was found in configuration."
                return
            }
        }
        New-Variable @params
    }
}

Get-Variable | Where-Object { $StartupVariables -notcontains $_.Name } | & { process { Remove-Variable -Scope 0 -Name $_.Name -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -Verbose:$false -Debug:$false } }        # Delete variables created in this script to free up memory for tiny Azure Automation sandbox
Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
