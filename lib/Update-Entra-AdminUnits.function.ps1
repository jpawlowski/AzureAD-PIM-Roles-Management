<#
.SYNOPSIS

.DESCRIPTION

.LINK
    https://github.com/jpawlowski/AzureAD-PIM-Roles-Management

.NOTES
    Filename: Update-Entra-AdminUnits.function.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
#>
#Requires -Version 7.2
#Requires -Modules @{ ModuleName='Microsoft.Graph.Beta.Identity.DirectoryManagement'; ModuleVersion='2.0' }

$MgScopes += 'AdministrativeUnit.ReadWrite.All'
$MgScopes += 'Directory.Write.Restricted'

function Update-Entra-AdminUnits {
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'High'
    )]
    [OutputType([Int])]
    Param (
        [array]$Config,
        [switch]$CommonAdminUnits,
        [switch]$TierAdminUnits,
        [switch]$Tier0,
        [switch]$Tier1,
        [switch]$Tier2
    )

    $Tiers = @();

    if ($TierAdminUnits) {
        if ($Tier0) {
            $Tiers += 0
        }
        if ($Tier1) {
            $Tiers += 1
        }
        if ($Tier2) {
            $Tiers += 2
        }
        if ($Tiers.Count -eq 0) {
            $Tiers = @(0, 1, 2)
        }
    }

    if ($CommonAdminUnits -or !$TierAdminUnits) {
        $Tiers += 3
    }

    Write-Host "EntraMaxAdminTier $EntraMaxAdminTier"
    $i = 0
    foreach ($ConfigLevel in $Tiers) {
        $PercentComplete = $i / $ConfigLevel.Count * 100
        $params = @{
            Activity         = 'Working on Tier                  '
            Status           = " $([math]::floor($PercentComplete))% Complete: Tier $ConfigLevel"
            PercentComplete  = $PercentComplete
            CurrentOperation = 'EntraAdminUnitsConfigLevel'
        }
        Write-Progress @params
    }
}
