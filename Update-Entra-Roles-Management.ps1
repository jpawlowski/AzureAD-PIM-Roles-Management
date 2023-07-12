<#
.SYNOPSIS
    Implement a Security Tiering Model for Microsoft Entra Privileged Roles using Microsoft Entra Privileged Identity Management.

.DESCRIPTION
    This script combines the following Microsoft Azure components to harden Privileged Roles in Microsoft Entra:

    * Microsoft Entra Privileged Identity Management (requires Microsoft Entra ID P2 license)
    * Microsoft Entra Conditional Access (requires Microsoft Entra ID P1 or P2 license):
        - Authentication Contexts
        - Authentication Strengths
        - Conditional Access Policies
    * Microsoft Entra Administrative Units (requires Microsoft Entra ID P1 license for admins)

.PARAMETER Roles
    Use 'All' or only a specified list of Microsoft Entra roles. When combined with -Tier0, -Tier1, or -Tier2 parameter, roles outside these tiers are ignored.

.PARAMETER AuthContext
    Update Microsoft Entra Authentication Contexts.

.PARAMETER AuthStrength
    Create or update Microsoft Entra Authentication Strengths.

.PARAMETER NamedLocations
    Create or update Microsoft Entra Named Locations.

.PARAMETER AdminCAPolicies
    Create or update Microsoft Entra Conditional Access policies for admins.

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
    Microsoft Entra tenant ID. Otherwise implied from configuration files, $env:TenantId or $TenantId.

.PARAMETER UseDeviceCode
    Use device code authentication instead of a browser control.

.PARAMETER ConfigPath
    Folder path to configuration files in PS1 format. Default: './config/'.

.NOTES
    Filename: Update-Entra-Roles-Management.ps1
    Author: Julian Pawlowski
#>

#Requires -Version 7.2

[
    CmdletBinding(
        SupportsShouldProcess
    )
]
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
    [string]$ConfigPath
)

$LibFiles = @(
    'Common.functions.ps1'
    'Load.config.ps1'
    ($AdminCAPolicies -or $ValidateBreakGlass ? 'Test-Entra-Tier0-BreakGlass.function.ps1' : $null)
    ($Roles ? 'Update-Entra-RoleRules.function.ps1' : $null)
    ($AuthContext ? 'Update-Entra-CA-AuthContext.function.ps1' : $null)
    ($AuthStrength ? 'Update-Entra-CA-AuthStrength.function.ps1' : $null)
    ($NamedLocations ? 'Update-Entra-CA-NamedLocations.function.ps1' : $null)
    ($AdminCAPolicies ? 'Update-Entra-CA-Policies.function.ps1' : $null)
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

Connect-MyMgGraph -Scopes $MgScopes

if ($NamedLocations) {
    Update-Entra-CA-NamedLocations
}
if ($AuthStrength) {
    Update-Entra-CA-AuthStrength
}
if ($AuthContext) {
    Update-Entra-CA-AuthContext
}
if ($UpdateRoleRules) {
    Update-Entra-RoleRules
}

if ($SkipBreakGlassValidation -and !$ValidateBreakGlass) {
    Write-Warning "Break Glass Account validation SKIPPED"
    $validBreakGlass = $true
}

if (!$validBreakGlass -and ($AdminCAPolicies -or $ValidateBreakGlass)) {
    Test-Entra-Tier0-BreakGlass $EntraCABreakGlass
}

if ($validBreakGlass) {
    if ($AdminCAPolicies) {
        Update-Entra-CA-Policies
    }
}
