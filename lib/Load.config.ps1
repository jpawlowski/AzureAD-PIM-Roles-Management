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
    'AAD_Tier0_BreakGlass.config.ps1'
    'AAD_CA_NamedLocations.config.ps1'
    'AAD_CA_AuthContexts.config.ps1'
    'AAD_CA_AuthStrengths.config.ps1'
    'AAD_CA_Policies.config.ps1'
    'AAD_Role_Classifications.config.ps1'
    'AAD_Role_ManagementRulesDefaults.config.ps1'
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
