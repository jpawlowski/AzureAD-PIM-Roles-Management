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

$ConfigFiles = @(
    'Environment.config.ps1'
    'Entra-Tier0-BreakGlass.config.ps1'
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
