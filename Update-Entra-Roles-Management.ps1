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

.PARAMETER TierCAPolicies
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
    Microsoft Entra tenant ID. Otherwise implied from configuration files or $env:AZURE_TENANT_ID.

.PARAMETER UseDeviceCode
    Use device code authentication instead of a browser control.

.PARAMETER ConfigPath
    Folder path to configuration files in PS1 format. Default: './config/'.

.LINK
    https://github.com/jpawlowski/AzureAD-PIM-Roles-Management

.NOTES
    Filename: Update-Entra-Roles-Management.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
#>
#Requires -Version 7.2

[
    CmdletBinding(
        SupportsShouldProcess
    )
]
Param (
    [string[]]$Roles,
    [switch]$AuthContext,
    [switch]$AuthStrength,
    [switch]$NamedLocations,
    [switch]$ValidateBreakGlass,
    [switch]$SkipBreakGlassValidation,
    [switch]$TierAdminUnits,
    [switch]$TierCAPolicies,
    [switch]$TierGroups,
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
    ($Roles -or $TierGroups -or $TierCAPolicies -or $ValidateBreakGlass ? 'Test-Entra-Tier0-BreakGlass.function.ps1' : $null)
    ($Roles ? 'Update-Entra-RoleRules.function.ps1' : $null)
    ($AuthContext ? 'Update-Entra-CA-AuthContext.function.ps1' : $null)
    ($AuthStrength ? 'Update-Entra-CA-AuthStrength.function.ps1' : $null)
    ($NamedLocations ? 'Update-Entra-CA-NamedLocations.function.ps1' : $null)
    ($TierAdminUnits ? 'Update-Entra-AdminUnits.function.ps1' : $null)
    ($TierGroups ? 'Update-Entra-Groups.function.ps1' : $null)
    ($TierCAPolicies ? 'Update-Entra-CA-Policies.function.ps1' : $null)
)
foreach ($FileName in $LibFiles) {
    if ($null -eq $FileName -or $FileName -eq '') { continue }
    $FilePath = Join-Path $(Join-Path $PSScriptRoot 'lib') $FileName
    if (Test-Path -Path $FilePath -PathType Leaf) {
        try {
            Write-Debug "Loading file $FilePath"
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

try {
    $params = @{
        Scopes = $MgScopes
    }
    if ($TenantId) { $params.TenantId = $TenantId }
    if ($UseDeviceCode) { $params.UseDeviceCode = $UseDeviceCode }
    Connect-MyMgGraph @params

    $params = @{}
    if ($Tier0) { $params.Tier0 = $Tier0 }
    if ($Tier1) { $params.Tier1 = $Tier1 }
    if ($Tier2) { $params.Tier2 = $Tier2 }

    if ($NamedLocations) {
        $params.Config = $EntraCANamedLocations
        Update-Entra-CA-NamedLocations @params
    }
    if ($AuthStrength) {
        $params.Config = $EntraCAAuthStrengths
        Update-Entra-CA-AuthStrength @params
    }
    if ($AuthContext) {
        $params.Config = $EntraCAAuthContexts
        Update-Entra-CA-AuthContext @params
    }

    if ($SkipBreakGlassValidation -and !$ValidateBreakGlass) {
        Write-Warning "Break Glass Validation SKIPPED"
    } elseif ($Roles -or $TierGroups -or $TierCAPolicies -or $ValidateBreakGlass) {
        Test-Entra-Tier0-BreakGlass -Config $EntraTier0BreakGlass
    }

    if ($Roles) {
        $UpdateRoleRules = $false
        $RoleTemplateIDsWhitelist = @();
        $RoleNamesWhitelist = @();
        if (
            ($Roles.count -eq 1) -and
            ($Roles[0].GetType().Name -eq 'String') -and
            ($Roles[0] -eq 'All')
        ) {
            $UpdateRoleRules = $true
        }
        else {
            foreach ($role in $Roles) {
                if ($role.GetType().Name -eq 'String') {
                    if ($role -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$') {
                        $RoleTemplateIDsWhitelist += $role
                    }
                    else {
                        $RoleNamesWhitelist += $role
                    }
                    $UpdateRoleRules = $true
                }
                elseif ($role.GetType().Name -eq 'Hashtable') {
                    if ($role.TemplateId) {
                        $RoleTemplateIDsWhitelist += $role.TemplateId
                        $UpdateRoleRules = $true
                    }
                    elseif ($role.displayName) {
                        $RoleNamesWhitelist += $role.displayName
                        $UpdateRoleRules = $true
                    }
                }
            }
        }

        if ($UpdateRoleRules) {
            $params.Config = $EntraRoleClassifications
            $params.DefaultConfig = $EntraRoleManagementRulesDefaults
            if ($RoleTemplateIDsWhitelist) { $params.Id = $RoleTemplateIDsWhitelist }
            if ($RoleNamesWhitelist) { $params.Name = $RoleNamesWhitelist }
            Update-Entra-RoleRules @params
            $params.Remove('DefaultConfig')
        }
    }

    if ($TierAdminUnits) {
        $params.Config = $EntraAdminUnits
        $params.TierAdminUnits = $true
        $params.CommonAdminUnits = $false
        Update-Entra-AdminUnits @params
        $params.Remove('TierAdminUnits')
        $params.Remove('CommonAdminUnits')
    }

    if ($TierGroups) {
        $params.Config = $EntraGroups
        $params.TierGroups = $true
        $params.CommonGroups = $false
        Update-Entra-Groups @params
        $params.Remove('TierGroups')
        $params.Remove('CommonGroups')
    }

    if ($TierCAPolicies) {
        $params.Config = $EntraCAPolicies
        $params.TierCAPolicies = $true
        $params.CommonCAPolicies = $false
        Update-Entra-CA-Policies @params
        $params.Remove('TierCAPolicies')
        $params.Remove('CommonCAPolicies')
    }
}
catch {
    Write-Error $_
    exit 1
}

exit 0
