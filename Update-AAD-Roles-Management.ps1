<#
.SYNOPSIS
    Implement a Security Tiering Model for Azure AD Privileged Roles using Azure AD Privileged Identity Management.

.DESCRIPTION
    This script combines the following Microsoft Azure components to harden Privileged Roles in Azure Active Directory:

    * Azure AD Privileged Identity Management (AAD PIM; requires Azure AD Premium Plan 2 license)
    * Azure AD Conditional Access (AAD CA; requires Azure AD Premium Plan 1 or Plan 2 license):
        - Authentication Contexts
        - Authentication Strengths
        - Conditional Access Policies
    * Azure AD Administrative Units (AAD AU; requires Azure AD Premium Plan 1 license for admins)

.PARAMETER Roles
    Use 'All' or only a specified list of Azure AD roles. When combined with -Tier0, -Tier1, or -Tier2 parameter, roles outside these tiers are ignored.

.PARAMETER AuthContext
    Update Azure AD Authentication Contexts.

.PARAMETER AuthStrength
    Create or update Azure AD Authentication Strengths.

.PARAMETER NamedLocations
    Create or update Azure AD Named Locations.

.PARAMETER AdminCAPolicies
    Create or update Azure AD Conditional Access policies for admins.

.PARAMETER ValidateBreakGlass
    Validate Break Glass Accounts (takes precedence to -NoBreakGlassValidation).

.PARAMETER SkipBreakGlassValidation
    Skip Break Glass Account validation.

.PARAMETER Tier0
    Perform changes to Tier0.

.PARAMETER Tier1
    Perform changes to Tier1.

.PARAMETER Tier2
    Perform changes to Tier2.

.PARAMETER TenantId
    Azure AD tenant ID. Otherwise implied from configuration files, $env:TenantId or $TenantId.

.PARAMETER UseDeviceCode
    Use device code authentication instead of a browser control.

.PARAMETER ConfigPath
    Folder path to configuration files in PS1 format. Default: './config/'.

.PARAMETER Force
    Run script without user interaction. If PS session was started with -NonInteractive parameter, it will be inherited. Note that updates of Tier0 settings always requires manual user interaction.

.NOTES
    Filename: Update-AAD-Roles-Management.ps1
    Author: Julian Pawlowski
#>

#Requires -Version 7.2

[CmdletBinding()]
Param (

    # Mandatory parameters: at least 1 of 6 needs to be given
    [Parameter(Mandatory, ParameterSetName = "AtLeastOption1")]
    [Parameter (Mandatory = $false, ParameterSetName = "AtLeastOption2")]
    [Parameter (Mandatory = $false, ParameterSetName = "AtLeastOption3")]
    [Parameter (Mandatory = $false, ParameterSetName = "AtLeastOption4")]
    [Parameter (Mandatory = $false, ParameterSetName = "AtLeastOption5")]
    [Parameter (Mandatory = $false, ParameterSetName = "AtLeastOption6")]
    [array]$Roles,

    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption1")]
    [Parameter(Mandatory, ParameterSetName = "AtLeastOption2")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption3")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption4")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption5")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption6")]
    [switch]$AuthContext,

    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption1")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption2")]
    [Parameter(Mandatory, ParameterSetName = "AtLeastOption3")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption4")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption5")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption6")]
    [switch]$AuthStrength,

    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption1")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption2")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption3")]
    [Parameter(Mandatory, ParameterSetName = "AtLeastOption4")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption5")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption6")]
    [switch]$NamedLocations,

    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption1")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption2")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption3")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption4")]
    [Parameter(Mandatory, ParameterSetName = "AtLeastOption5")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption6")]
    [switch]$AdminCAPolicies,

    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption1")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption2")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption3")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption4")]
    [Parameter(Mandatory = $false, ParameterSetName = "AtLeastOption5")]
    [Parameter(Mandatory, ParameterSetName = "AtLeastOption6")]
    [switch]$ValidateBreakGlass,

    # Optional parameters
    [switch]$SkipBreakGlassValidation = $false,
    [switch]$Tier0,
    [switch]$Tier1,
    [switch]$Tier2,
    [string]$TenantId,
    [switch]$UseDeviceCode,
    [string]$ConfigPath,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$LibFiles = @(
    'Common.functions.ps1'
    'Load.config.ps1'
    ($AdminCAPolicies -or $ValidateBreakGlass ? 'Test-AAD-Tier0-BreakGlass.function.ps1' : $null)
    ($Roles ? 'Update-AAD-RoleRules.function.ps1' : $null)
    ($AuthContext ? 'Update-AAD-CA-AuthContext.function.ps1' : $null)
    ($AuthStrength ? 'Update-AAD-CA-AuthStrength.function.ps1' : $null)
    ($NamedLocations ? 'Update-AAD-CA-NamedLocations.function.ps1' : $null)
    ($AdminCAPolicies ? 'Update-AAD-CA-Policies.function.ps1' : $null)
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

if ($Roles) {
    $MgScopes += 'RoleManagement.ReadWrite.Directory'
}
if ($AuthContext) {
    $MgScopes += "AuthenticationContext.ReadWrite.All"
}
if ($NamedLocations -or $AuthStrength -or $AdminCAPolicies) {
    $MgScopes += 'Policy.Read.All'
    $MgScopes += 'Policy.ReadWrite.AuthenticationMethod'
    $MgScopes += 'Policy.ReadWrite.ConditionalAccess'
    $MgScopes += 'Application.Read.All'
}
if ($AdminCAPolicies -or $ValidateBreakGlass) {
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

if ($NamedLocations) {
    Update-AAD-CA-NamedLocations
}
if ($AuthStrength) {
    Update-AAD-CA-AuthStrength
}
if ($AuthContext) {
    Update-AAD-CA-AuthContext
}
if ($UpdateRoleRules) {
    Update-AAD-RoleRules
}

if ($SkipBreakGlassValidation -and !$ValidateBreakGlass) {
    Write-Warning "Break Glass Account validation SKIPPED"
    $validBreakGlass = $true
}

if (!$validBreakGlass -and ($AdminCAPolicies -or $ValidateBreakGlass)) {
    Test-AAD-Tier0-BreakGlass $AADCABreakGlass
}

if ($validBreakGlass) {
    if ($AdminCAPolicies) {
        Update-AAD-CA-Policies
    }
}
