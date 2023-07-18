<#
.SYNOPSIS

.DESCRIPTION

.LINK
    https://github.com/jpawlowski/AzureAD-PIM-Roles-Management

.NOTES
    Filename: Update-Entra-CA-Policies.function.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
#>
#Requires -Version 7.2

$MgScopes += 'Application.Read.All'
$MgScopes += 'Policy.Read.All'
$MgScopes += 'Policy.ReadWrite.ConditionalAccess'

function Update-Entra-CA-Policies {
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'High'
    )]
    Param (
        [string]$ConfigPath,
        [switch]$AdminCAPolicies,
        [switch]$CommonCAPolicies,
        [switch]$Tier0,
        [switch]$Tier1,
        [switch]$Tier2
    )

}
