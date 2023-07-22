<#
.SYNOPSIS

.DESCRIPTION

.LINK
    https://github.com/jpawlowski/AzureAD-PIM-Roles-Management

.NOTES
    Filename: Update-Entra-Groups.function.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
#>
#Requires -Version 7.2
#Requires -Modules @{ ModuleName='Microsoft.Graph.Beta.Identity.DirectoryManagement'; ModuleVersion='2.0' }

$MgScopes += 'AdministrativeUnit.ReadWrite.All'
$MgScopes += 'Directory.Write.Restricted'

function Update-Entra-Groups {
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'High'
    )]
    [OutputType([Int])]
    Param (
        [array]$Config,
        [switch]$CommonGroups,
        [switch]$TierGroups,
        [switch]$Tier0,
        [switch]$Tier1,
        [switch]$Tier2
    )

    Write-Host "+++++++ Groups ++++++++"
    $Config | ConvertTo-Json -Depth 100
}
