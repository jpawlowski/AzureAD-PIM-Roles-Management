<#PSScriptInfo
.VERSION 1.0.0
.GUID 86fdceff-6855-4789-b621-9e12b25097f8
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
    Imports modules silently

.DESCRIPTION
    Common runbook that can be used by other runbooks. It can not be started as an Azure Automation job directly.
#>

[CmdletBinding()]
Param(
    [Parameter(mandatory = $true)]
    [AllowEmptyCollection()]
    [Array]$Modules,

    [String]$AutoloadingPreference
)

$Initialized = $true

# Works only when running locally
$OrigVerbosePreference = $VerbosePreference
$VerbosePreference = 'SilentlyContinue'

# Works only when running in Azure Automation sandbox
$OrigGlobalVerbosePreference = $global:VerbosePreference
$global:VerbosePreference = 'SilentlyContinue'

try {
    if (-Not (Get-Module -Name PowerShellGet)) {
        $Initialized = $false
        Import-Module -Name PowerShellGet -ErrorAction Stop
    }
}
catch {
    Throw $_
}

$VerbosePreference = $OrigVerbosePreference
$global:VerbosePreference = $OrigGlobalVerbosePreference

if ($Initialized) {
    Write-Debug "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | & { process{$_.PSObject.Properties | & { process{$_.Name + ': ' + $_.Value} }} }) -join ', ') ---"
}
else {
    Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | & { process{$_.PSObject.Properties | & { process{$_.Name + ': ' + $_.Value} }} }) -join ', ') ---"
}

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }

if (-Not [string]::IsNullOrEmpty($AutoloadingPreference)) {
    Write-Verbose "[COMMON]: - Setting PowerShell module AutoloadingPreference to $AutoloadingPreference"
    $global:PSModuleAutoloadingPreference = $AutoloadingPreference
}
elseif ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
    Write-Verbose '[COMMON]: - Enforcing manual Import-Module in Azure Automation'
    $global:PSModuleAutoloadingPreference = 'ModuleQualified'
}

$VerbosePreference = 'SilentlyContinue'
$global:VerbosePreference = 'SilentlyContinue'

$LoadedModules = (Get-Module | & { process { $_.Name } })
$Missing = [System.Collections.ArrayList]::new()

$Modules | Where-Object { (-Not [string]::IsNullOrEmpty($_.Name)) -and ($LoadedModules -notContains $_.Name) } | & {
    process {
        $Module = $_
        $Optional = $_.Optional
        if ($null -ne $Module.Optional) { $Module.Remove('Optional') }
        Write-Debug "[COMMON]: - Importing module $($Module.Name)"
        $Module.Debug = $false
        $Module.Verbose = $false
        $Module.InformationAction = 'SilentlyContinue'
        $Module.WarningAction = 'SilentlyContinue'
        $Module.ErrorAction = 'Stop'

        try {
            Import-Module @Module
        }
        catch {
            $Module.Remove('Debug')
            $Module.Remove('Verbose')
            $Module.Remove('InformationAction')
            $Module.Remove('WarningAction')
            $Module.Remove('ErrorAction')
            $Module.ErrorDetails = $_

            if ($Optional -eq $true) {
                Write-Warning "[COMMON]: - Optional module could not be loaded: $(Module.Name)"
            }
            else {
                $null = $script:Missing.Add($Module)
            }
        }
    }
}

$global:VerbosePreference = $OrigGlobalVerbosePreference

If ($Missing.Count -gt 0) {
    Throw "Modules could not be loaded: $( $(ForEach ($item in $Missing | Sort-Object -Property Name) { ($item.Keys | Sort-Object @{Expression={$_ -eq "Name" -or $_ -eq "RequiredVersion"}; Descending=$true} | ForEach-Object { "${_}: $($item[$_])" }) -join '; ' }) -join ' | ' )"
}

Remove-Variable -Name Initialized, OrigVerbosePreference, Missing, LoadedModules, Modules, Module -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -Verbose:$false -Debug:$false

# To avoid clutter in the log, the script information ins only written once
if ($Initialized) {
    Write-Debug "-----END of $((Get-Item $PSCommandPath).Name) ---"
}
else {
    Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
}
