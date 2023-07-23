<#
.SYNOPSIS

.DESCRIPTION

.LINK
    https://github.com/jpawlowski/AzureAD-PIM-Roles-Management

.NOTES
    Filename: Load.config.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
#>
#Requires -Version 7.2

if (
    ($null -eq $ConfigPath) -or
    ($ConfigPath -eq '')
) {
    $ConfigPath = Join-Path (Get-Item $PSScriptRoot).Parent 'config'
}

if (!(Test-Path -Path $ConfigPath -PathType Container)) {
    Throw "Configuration folder $ConfigPath does not exist. Make a copy of the 'template.config' folder to begin, or use the -ConfigPath parameter."
}

$MgScopes = @()

# Make sure subfolder variables will only be defined in config files
Clear-Variable -Name '*ConfigSubfolder'

$ConfigFiles = @(
    'Environment.config.ps1'
    'Entra-Tier0-BreakGlass.config.ps1'
    'Entra-AdminUnits.config.ps1'
    'Entra-Groups.config.ps1'
    'Entra-CA-AuthContexts.config.ps1'
    'Entra-CA-AuthStrengths.config.ps1'
    'Entra-CA-NamedLocations.config.ps1'
    'Entra-CA-Policies.config.ps1'
    'Entra-Role-Classifications.config.ps1'
    'Entra-Role-ManagementRulesDefaults.config.ps1'
)

foreach ($ConfigFile in $ConfigFiles) {
    $FilePath = Join-Path $ConfigPath $ConfigFile
    if (Test-Path -Path $FilePath -PathType Leaf) {
        try {
            Write-Debug "Loading configuration file $FilePath"
            . $FilePath
        }
        catch {
            Throw "Error reading configuration file: $_"
        }
    }
    else {
        Throw "Configuration file not found: $FilePath"
    }
}

foreach ($ConfigSubfolder in (Get-Variable -Name '*ConfigSubfolder')) {
    if ($null -eq $ConfigSubfolder.Value) { continue }
    [System.Collections.ArrayList]$Config = @()

    # Always process Tier configs first into separate arrays
    foreach ($d in (Get-ChildItem -LiteralPath (Join-Path $ConfigPath $ConfigSubfolder.Value) -Directory -Depth 0 -Include 'Tier*-Admin' | Sort-Object -Property Name)) {
        Write-Debug "Processing configuration folder $($d.FullName)"

        [System.Collections.ArrayList]$dirConfig = @()
        foreach ($f in (Get-ChildItem -LiteralPath $d.FullName -File -Include '*.config.ps1' | Sort-Object -Property Name)) {
            try {
                Write-Debug "   Loading configuration file $($f.Name)"
                $tmp = . $f.FullName
                $tmp.FileOrigin = $f
                $null = $dirConfig.Add($tmp)
            }
            catch {
                Throw "Error reading configuration file: $_"
            }
        }

        $null = $Config.Add($dirConfig)
    }

    [System.Collections.ArrayList]$dirConfig = @()
    $i = $Config.Add($dirConfig)

    if (
        ($null -eq $EntraMaxAdminTier) -or
        $EntraMaxAdminTier -notmatch '^\d+$' -or
        $EntraMaxAdminTier -lt ($i - 1)
    ) {
        $EntraMaxAdminTier = $i - 1
    }

    # Add any other config to same array
    $dirConfig = @()
    foreach ($d in (Get-ChildItem -LiteralPath (Join-Path $ConfigPath $ConfigSubfolder.Value) -Directory -Depth 0 -Exclude 'Tier*-Admin' | Sort-Object -Property Name)) {
        Write-Debug "Processing configuration folder $($d.FullName)"

        foreach ($f in (Get-ChildItem -LiteralPath $d.FullName -File -Include '*.config.ps1' | Sort-Object -Property Name)) {
            try {
                Write-Debug "   Loading configuration file $($f.Name)"
                $dirConfig += . $f.FullName
                $dirConfig.FileOrigin = $f
            }
            catch {
                Throw "Error reading configuration file: $_"
            }
        }
    }
    $Config[$i] = $dirConfig

    $VarName = ($ConfigSubfolder.Value).Replace('-', '').Replace('.config', '')
    New-Variable -Name $VarName -Value $Config -Confirm:$false -WhatIf:$false
}
