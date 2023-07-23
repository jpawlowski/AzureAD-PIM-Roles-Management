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
    Use 'All' or only a specified list of Microsoft Entra Conditional Access Authentication Contexts. When combined with -Tier0, -Tier1, or -Tier2 parameter, Authentication Contexts outside these tiers are ignored.

.PARAMETER AuthStrength
    Use 'All' or only a specified list of Microsoft Entra Conditional Access Authentication Stengths. When combined with -Tier0, -Tier1, or -Tier2 parameter, Authentication Stengths outside these tiers are ignored.

.PARAMETER NamedLocations
    Use 'All' or only a specified list of Microsoft Entra Conditional Access Named Locations. When combined with -Tier0, -Tier1, or -Tier2 parameter, locations outside these tiers are ignored.

.PARAMETER TierCAPolicies
    Use 'All' or only a specified list of Microsoft Entra Conditional Access policies for admins. When combined with -Tier0, -Tier1, or -Tier2 parameter, policies outside these tiers are ignored.

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
    Folder path to configuration files in PS1 script format. Default: './config/'.

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
    [string[]]$AuthContext,
    [string[]]$AuthStrength,
    [string[]]$NamedLocations,
    [switch]$ValidateBreakGlass,
    [switch]$SkipBreakGlassValidation,
    [string[]]$TierAdminUnits,
    [string[]]$TierCAPolicies,
    [string[]]$TierGroups,
    [switch]$Tier0,
    [switch]$Tier1,
    [switch]$Tier2,
    [string]$TenantId,
    [switch]$UseDeviceCode,
    [string]$ConfigPath,
    [switch]$Force
)

$LibFiles = @(
    'Common.functions.ps1'
    'Load.config.ps1'
    ($Roles -or $TierAdminUnits -or $TierGroups -or $TierCAPolicies -or $ValidateBreakGlass ? 'Test-Entra-Tier0-BreakGlass.function.ps1' : $null)
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
        ErrorAction       = 'Stop'
        Scopes            = $MgScopes
    }
    if ($TenantId) { $params.TenantId = $TenantId }
    if ($UseDeviceCode) { $params.UseDeviceCode = $UseDeviceCode }
    Connect-MyMgGraph @params

    $params = @{
        ErrorAction = 'Stop'
        Force       = $Force
        Confirm     = $ConfirmPreference
        WhatIf      = $WhatIfPreference
    }
    if ($Tier0) { $params.Tier0 = $Tier0 }
    if ($Tier1) { $params.Tier1 = $Tier1 }
    if ($Tier2) { $params.Tier2 = $Tier2 }

    if ($NamedLocations) {
        $Update = $false
        $WhitelistIDs = @()
        $WhitelistNames = @()

        if ($Update) {
            $params.Config = $EntraCANamedLocations
            Update-Entra-CA-NamedLocations @params
        }
    }
    if ($AuthStrength) {
        $Update = $false
        $WhitelistIDs = @()
        $WhitelistNames = @()

        if ($Update) {
            $params.Config = $EntraCAAuthStrengths
            Update-Entra-CA-AuthStrength @params
        }
    }
    if ($AuthContext) {
        $Update = $false
        $WhitelistIDs = @()
        $WhitelistNames = @()

        if ($Update) {
            $params.Config = $EntraCAAuthContexts
            Update-Entra-CA-AuthContext @params
        }
    }

    if ($SkipBreakGlassValidation -and !$ValidateBreakGlass) {
        Write-Warning "Break Glass Validation SKIPPED"
    }
    elseif ($Roles -or $TierAdminUnits -or $TierGroups -or $TierCAPolicies -or $ValidateBreakGlass) {
        Test-Entra-Tier0-BreakGlass -Config $EntraTier0BreakGlass -ErrorAction Stop
    }

    if ($Roles) {
        $Update = $false
        $WhitelistIDs = @()
        $WhitelistNames = @()
        if (
            ($Roles.count -eq 1) -and
            ($Roles[0].GetType().Name -eq 'String') -and
            ($Roles[0] -eq 'All')
        ) {
            $Update = $true
        }
        else {
            foreach ($item in $Roles) {
                if ($item.GetType().Name -eq 'String') {
                    if ($item -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$') {
                        $WhitelistIDs += $item
                    }
                    else {
                        $WhitelistNames += $item
                    }
                    $Update = $true
                }
                elseif ($item.GetType().Name -eq 'Hashtable') {
                    if ($item.Id) {
                        $WhitelistIDs += $item.Id
                        $Update = $true
                    }
                    elseif ($item.TemplateId) {
                        $WhitelistIDs += $item.TemplateId
                        $Update = $true
                    }
                    elseif ($item.displayName) {
                        $WhitelistNames += $item.displayName
                        $Update = $true
                    }
                }
            }
        }

        if ($Update) {
            $params.Config = $EntraRoleClassifications
            $params.DefaultConfig = $EntraRoleManagementRulesDefaults
            if ($WhitelistIDs) { $params.Id = $WhitelistIDs }
            if ($WhitelistNames) { $params.Name = $WhitelistNames }
            Update-Entra-RoleRules @params
            $params.Remove('DefaultConfig')
            $params.Remove('Id')
            $params.Remove('Name')
        }
    }

    if ($TierAdminUnits) {
        $Update = $false
        $WhitelistIDs = @()
        $WhitelistNames = @()
        if (
            ($TierAdminUnits.count -eq 1) -and
            ($TierAdminUnits[0].GetType().Name -eq 'String') -and
            ($TierAdminUnits[0] -eq 'All')
        ) {
            $Update = $true
        }
        else {
            foreach ($item in $TierAdminUnits) {
                if ($item.GetType().Name -eq 'String') {
                    if ($item -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$') {
                        $WhitelistIDs += $item
                    }
                    else {
                        $WhitelistNames += $item
                    }
                    $Update = $true
                }
                elseif ($item.GetType().Name -eq 'Hashtable') {
                    if ($item.Id) {
                        $WhitelistIDs += $item.Id
                        $Update = $true
                    }
                    elseif ($item.TemplateId) {
                        $WhitelistIDs += $item.TemplateId
                        $Update = $true
                    }
                    elseif ($item.displayName) {
                        $WhitelistNames += $item.displayName
                        $Update = $true
                    }
                }
            }
        }

        if ($Update) {
            $params.Config = $EntraAdminUnits
            $params.TierAdminUnits = $true
            if ($WhitelistIDs) { $params.Id = $WhitelistIDs }
            if ($WhitelistNames) { $params.Name = $WhitelistNames }
            Update-Entra-AdminUnits @params
            $params.Remove('TierAdminUnits')
            $params.Remove('Id')
            $params.Remove('Name')
        }
    }

    if ($TierGroups) {
        $Update = $false
        $WhitelistIDs = @()
        $WhitelistNames = @()
        if (
            ($TierGroups.count -eq 1) -and
            ($TierGroups[0].GetType().Name -eq 'String') -and
            ($TierGroups[0] -eq 'All')
        ) {
            $Update = $true
        }
        else {
            foreach ($item in $TierGroups) {
                if ($item.GetType().Name -eq 'String') {
                    if ($item -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$') {
                        $WhitelistIDs += $item
                    }
                    else {
                        $WhitelistNames += $item
                    }
                    $Update = $true
                }
                elseif ($item.GetType().Name -eq 'Hashtable') {
                    if ($item.Id) {
                        $WhitelistIDs += $item.Id
                        $Update = $true
                    }
                    elseif ($item.TemplateId) {
                        $WhitelistIDs += $item.TemplateId
                        $Update = $true
                    }
                    elseif ($item.displayName) {
                        $WhitelistNames += $item.displayName
                        $Update = $true
                    }
                }
            }
        }

        if ($Update) {
            $params.Config = $EntraGroups
            $params.TierGroups = $true
            if ($WhitelistIDs) { $params.Id = $WhitelistIDs }
            if ($WhitelistNames) { $params.Name = $WhitelistNames }
            Update-Entra-Groups @params
            $params.Remove('TierGroups')
            $params.Remove('Id')
            $params.Remove('Name')
        }
    }

    if ($TierCAPolicies) {
        $Update = $false
        $WhitelistIDs = @()
        $WhitelistNames = @()

        if ($Update) {
            $params.Config = $EntraCAPolicies
            $params.TierCAPolicies = $true
            if ($WhitelistIDs) { $params.Id = $WhitelistIDs }
            if ($WhitelistNames) { $params.Name = $WhitelistNames }
            Update-Entra-CA-Policies @params
            $params.Remove('TierCAPolicies')
            $params.Remove('CommonCAPolicies')
        }
    }
}
catch {
    Write-Error $_
    exit 1
}

exit 0
