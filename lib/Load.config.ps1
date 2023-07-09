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

$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Description."
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Description."
$cancel = New-Object System.Management.Automation.Host.ChoiceDescription "&Cancel", "Description."
$choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no, $cancel)

$MgScopes = @()

$ConfigFiles = @(
    'Environment.config.ps1'
    'AAD-Tier0-BreakGlass.config.ps1'
    'AAD-CA-AuthContexts.config.ps1'
    'AAD-CA-AuthStrengths.config.ps1'
    'AAD-CA-NamedLocations.config.ps1'
    'AAD-CA-Policies.config.ps1'
    'AAD-Role-Classifications.config.ps1'
    'AAD-Role-ManagementRulesDefaults.config.ps1'
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
