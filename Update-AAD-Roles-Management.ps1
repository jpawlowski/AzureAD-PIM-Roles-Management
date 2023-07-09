#Requires -Version 7.2
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

    # Mandatory parameters: at least 1 of 6 needs to be given
    [Parameter(Mandatory, ParameterSetName = "AtLeastOption1", HelpMessage = "Update all or only a specified list of Azure AD roles. When combined with -Tier0, -Tier1, or -Tier2 parameter, roles outside these tiers are ignored.")]
    [Parameter (Mandatory = $false, ParameterSetName = "AtLeastOption2")]
    [Parameter (Mandatory = $false, ParameterSetName = "AtLeastOption3")]
    [Parameter (Mandatory = $false, ParameterSetName = "AtLeastOption4")]
    [Parameter (Mandatory = $false, ParameterSetName = "AtLeastOption5")]
    [Parameter (Mandatory = $false, ParameterSetName = "AtLeastOption6")]
    [array]$UpdateRoles,

    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption1")]
    [Parameter(Mandatory, ParameterSetName = "AtLeastOption2", HelpMessage = "Update Azure AD Authentication Contexts")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption3")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption4")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption5")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption6")]
    [switch]$UpdateAuthContext,

    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption1")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption2")]
    [Parameter(Mandatory, ParameterSetName = "AtLeastOption3", HelpMessage = "Create or update Azure AD Authentication Strengths")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption4")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption5")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption6")]
    [switch]$CreateAuthStrength,

    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption1")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption2")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption3")]
    [Parameter(Mandatory, ParameterSetName = "AtLeastOption4", HelpMessage = "Create or update Azure AD Named Locations")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption5")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption6")]
    [switch]$CreateNamedLocations,

    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption1")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption2")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption3")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption4")]
    [Parameter(Mandatory, ParameterSetName = "AtLeastOption5", HelpMessage = "Create or update Azure AD Conditional Access policies for admins")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption6")]
    [switch]$CreateAdminCAPolicies,

    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption1")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption2")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption3")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption4")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption5")]
    [Parameter(Mandatory, ParameterSetName = "AtLeastOption6", HelpMessage = "Validate Break Glass Accounts (takes precedence to -NoBreakGlassValidation)")]
    [switch]$ValidateBreakGlass,

    # Optional parameters
    [Parameter(HelpMessage = "Skip Break Glass Account validation")]
    [switch]$SkipBreakGlassValidation = $false,

    [Parameter(HelpMessage = "Perform changes to Tier0.")]
    [switch]$Tier0,

    [Parameter(HelpMessage = "Perform changes to Tier1.")]
    [switch]$Tier1,

    [Parameter(HelpMessage = "Perform changes to Tier2.")]
    [switch]$Tier2,

    [Parameter(HelpMessage = "Azure AD tenant ID.")]
    [string]$TenantId,

    [Parameter(HelpMessage = "Use device code authentication instead of a browser control.")]
    [switch]$UseDeviceCode,

    [Parameter(HelpMessage = "Folder path to configuration files in PS1 format. Default: './config/'.")]
    [string]$ConfigPath,

    [Parameter(HelpMessage = "Run script without user interaction. If PS session was started with -NonInteractive parameter, it will be inherited. Note that updates of Tier0 settings always requires manual user interaction.")]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$LibFiles = @(
    'Common.functions.ps1'
    'Load.config.ps1'
    ($CreateAdminCAPolicies -or $ValidateBreakGlass ? 'Test-AAD-Tier0-BreakGlass.function.ps1' : $null)
    ($UpdateRoleRules ? 'Update-AAD-RoleRules.function.ps1' : $null)
    ($UpdateAuthContext ? 'Update-AAD-CA-AuthContext.function.ps1' : $null)
    ($CreateAuthStrength ? 'Update-AAD-CA-AuthStrength.function.ps1' : $null)
    ($CreateNamedLocations ? 'Update-AAD-CA-NamedLocations.function.ps1' : $null)
    ($CreateAdminCAPolicies ? 'Update-AAD-CA-Policies.function.ps1' : $null)
)
foreach ($FileName in $LibFiles) {
    if ($null -eq $FileName -or $FileName -eq '') { continue }
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

if ($UpdateRoles) {
    $MgScopes += 'RoleManagement.ReadWrite.Directory'
}
if ($UpdateAuthContext) {
    $MgScopes += "AuthenticationContext.ReadWrite.All"
}
if ($CreateNamedLocations -or $CreateAuthStrength -or $CreateAdminCAPolicies) {
    $MgScopes += 'Policy.Read.All'
    $MgScopes += 'Policy.ReadWrite.ConditionalAccess'
    $MgScopes += 'Application.Read.All'
}
if ($CreateAdminCAPolicies -or $ValidateBreakGlass) {
    $MgScopes += 'User.Read.All'
    $MgScopes += 'Group.Read.All'
    $MgScopes += 'AdministrativeUnit.Read.All'
    $MgScopes += 'RoleManagement.Read.Directory'
    $MgScopes += 'UserAuthenticationMethod.Read.All'
}
if ($CreateAdminUnits) {
    $MgScopes += 'AdministrativeUnit.ReadWrite.All'
}

Connect-MyMgGraph

if ($CreateNamedLocations) {
    Update-AAD-CA-NamedLocations
}
if ($CreateAuthStrength) {
    Update-AAD-CA-AuthStrength
}
if ($UpdateAuthContext) {
    Update-AAD-CA-AuthContext
}
if ($UpdateRoleRules) {
    Update-AAD-RoleRules
}
if ($CreateAdminCAPolicies -or $ValidateBreakGlass) {
    Test-AAD-Tier0-BreakGlass
}

if ($validBreakGlass) {
    if ($CreateAdminCAPolicies) {
        Update-AAD-CA-Policies
    }
}
