<#
.SYNOPSIS
    Implement a Security Tiering Model for Azure AD Privileged Roles using Azure AD Privileged Identity Management.
.DESCRIPTION
    This script combines the following Microsoft Azure components to harden Privileged Roles in Azure Active Directory:

    - Azure AD Privileged Identity Management (AAD PIM; requires Azure AD Premium Plan 2 license)
    - Azure AD Conditional Access (AAD CA; requires Azure AD Premium Plan 1 or Plan 2 license):
        - Authentication Contexts
        - Authentication Strengths
        - Conditional Access Policies
#>
[CmdletBinding()]
Param (
    [Parameter(HelpMessage = "Azure AD tenant ID.")]
    [string]$TenantId,
    [Parameter(HelpMessage = "Folder path to configuration files in PS1 format. Default: './config/'.")]
    [string]$ConfigPath,
    [Parameter(HelpMessage = "Update all or only a specified list of Azure AD roles. When combined with -Tier0, -Tier1, or -Tier2 parameter, roles outside these tiers are ignored.")]
    [array]$UpdateRoles,
    [Parameter(HelpMessage = "Update Azure AD Authentication Contexts")]
    [switch]$UpdateAuthContext,
    [Parameter(HelpMessage = "Create or update Azure AD Authentication Strengths")]
    [switch]$CreateAuthStrength,
    [Parameter(HelpMessage = "Create or update Azure AD Named Locations")]
    [switch]$CreateNamedLocations,
    [Parameter(HelpMessage = "Create or update Azure AD Conditional Access policies for admins in Tier 0-2")]
    [switch]$CreateAdminCAPolicies,
    [Parameter(HelpMessage = "Create or update general Azure AD Conditional Access policies, except for admins in Tier 0-2")]
    [switch]$CreateGeneralCAPolicies,
    [Parameter(HelpMessage = "Validate Break Glass Accounts (takes precedence to -NoBreakGlassValidation)")]
    [switch]$ValidateBreakGlass,
    [Parameter(HelpMessage = "Skip Break Glass Account validation")]
    [switch]$SkipBreakGlassValidation = $false,
    [Parameter(HelpMessage = "Perform changes to Tier0.")]
    [switch]$Tier0,
    [Parameter(HelpMessage = "Perform changes to Tier1.")]
    [switch]$Tier1,
    [Parameter(HelpMessage = "Perform changes to Tier2.")]
    [switch]$Tier2,
    [Parameter(HelpMessage = "Run script without user interaction. If PS session was started with -NonInteractive parameter, it will be inherited.")]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

try {
    Import-Module -Name "Microsoft.Graph.Identity.SignIns" -MinimumVersion 2.0
    Import-Module -Name "Microsoft.Graph.Identity.Governance" -MinimumVersion 2.0
}
catch {
    Write-Error "Error loading Microsoft Graph API: $_"
}

if (
    (-Not $UpdateRoles) -and
    (-Not $CreateNamedLocations) -and
    (-Not $UpdateAuthContext) -and
    (-Not $CreateAuthStrength) -and
    (-Not $ValidateBreakGlass) -and
    (-Not $CreateAdminCAPolicies) -and
    (-Not $CreateGeneralCAPolicies)
) {
    Write-Error "Missing parameter: What would you like to update and/or create? -UpdateRoles, -CreateNamedLocations, -UpdateAuthContext, -CreateAuthStrength, -CreateNamedLocations, -CreateAdminCAPolicies, -CreateGeneralCAPolicies, -ValidateBreakGlass"
}

$LibFiles = @(
    'Common.utils.ps1'
    'Load.config.ps1'
    'CreateNamedLocations.function.ps1'
    'CreateAuthStrength.function.ps1'
    'UpdateAuthContext.function.ps1'
    'UpdateRoleRules.function.ps1'
    'ValidateBreakGlass.function.ps1'
)
foreach ($FileName in $LibFiles) {
    $FilePath = Join-Path $(Join-Path $PSScriptRoot 'lib') $FileName
    if (Test-Path -Path $FilePath -PathType Leaf) {
        try {
            . $FilePath
        }
        catch {
            Throw "Error loading file: $_"
        }
    }
    else {
        Throw "File not found: $FilePath"
    }
}

if ($Force) {
    Write-Output ''
    Write-Output 'WARNING: !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
    Write-Output 'WARNING: ! Processing in unattended mode - BE CAREFUL !'
    Write-Output 'WARNING: !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
    Write-Output ''
}

ConnectMgGraph
CreateNamedLocations
CreateAuthStrength
UpdateAuthContext
UpdateRoleRules
ValidateBreakGlass

if ($validBreakGlass) {
    CreateCAPolicies
}
