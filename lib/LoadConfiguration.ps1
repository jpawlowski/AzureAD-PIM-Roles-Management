function Test-NonInteractive {
    foreach ( $arg in [Environment]::GetCommandLineArgs() ) {
        if ( $arg -like "-noni*" ) {
            return $true
        }
    }
    return $false
}

if (
    ($null -eq $ConfigPath) -or
    ($ConfigPath -eq '')
) {
    $ConfigPath = Join-Path (Get-Item $PSScriptRoot).Parent 'config'
}

$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Description."
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Description."
$cancel = New-Object System.Management.Automation.Host.ChoiceDescription "&Cancel", "Description."
$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no, $cancel)

$ConfigFiles = @(
    'Environment.config.ps1'
    'MgGraph_Scopes.config.ps1'
    'AAD_CA_BreakGlass.config.ps1'
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

