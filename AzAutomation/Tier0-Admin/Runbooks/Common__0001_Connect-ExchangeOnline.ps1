<#
.SYNOPSIS
    Connect to Microsoft Exchange Online

.PARAMETER Scopes

.NOTES
    Original name: Common__0001_Connect-ExchangeOnline.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
    Version: 0.9.0
#>

[CmdletBinding()]
Param(
    [Parameter(mandatory = $true)]
    [String]$Organization
)

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name) ---"

.\Common__0000_Import-Modules.ps1 -Modules @(
    @{ Name = 'ExchangeOnlineManagement'; MinimumVersion = '3.0'; MaximumVersion = '3.65535' }
) 1> $null

$params = @{
    Organization = $Organization
    ShowBanner   = $false
    ShowProgress = $false
}

$Connection = Get-ConnectionInformation

if (
    ($Connection) -and
    (
        (($Connection | Where-Object Organization -eq $params.Organization).State -ne 'Connected') -or
        (($Connection | Where-Object Organization -eq $params.Organization).tokenStatus -ne 'Active')
    )
) {
    $Connection | Where-Object Organization -eq $params.Organization | ForEach-Object {
        Disconnect-ExchangeOnline `
            -ConnectionId $_.ConnectionId `
            -Confirm:$false `
            -InformationAction SilentlyContinue
    }
    $Connection = $null
}

if (-Not ($Connection)) {
    if ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
        $params.ManagedIdentity = $true
    }

    try {
        Write-Information 'Connecting to Exchange Online ...'
        Connect-ExchangeOnline @params 1> $null
    }
    catch {
        Throw "Failed to connect to Exchange Online"
    }
}

Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
