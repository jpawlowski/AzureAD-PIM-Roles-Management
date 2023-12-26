<#PSScriptInfo
.VERSION 1.0.0
.GUID b39dc20f-f5de-4f6b-958e-41762df89805
.AUTHOR Julian Pawlowski
.COMPANYNAME Workoho GmbH
.COPYRIGHT (c) 2024 Workoho GmbH. All rights reserved.
.TAGS
.LICENSEURI
.PROJECTURI
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS Common__0001_Connect-MgGraph.ps1,Common_0000__Import-Modules.ps1
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>

<#
.SYNOPSIS
    Get permissions to other applications of current application

.DESCRIPTION
    Common runbook that can be used by other runbooks. It can not be started as an Azure Automation job directly.
#>

[CmdletBinding()]
Param(
    [Array]$App
)

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | ForEach-Object { $_.PSObject.Properties | ForEach-Object { $_.Name + ': ' + $_.Value } }) -join ', ') ---"

#region CONNECTIONS ------------------------------------------------------------
.\Common__0001_Connect-MgGraph.ps1 1> $null
#endregion ---------------------------------------------------------------------

#region [COMMON] ENVIRONMENT ---------------------------------------------------
.\Common_0000__Import-Modules.ps1 -Modules @(
    @{ Name = 'Microsoft.Graph.Beta.Users'; MinimumVersion = '2.0'; MaximumVersion = '2.65535' }
    @{ Name = 'Microsoft.Graph.Beta.Applications'; MinimumVersion = '2.0'; MaximumVersion = '2.65535' }
) 1> $null
#endregion ---------------------------------------------------------------------

$return = @()

$AppRoleAssignments = $null
$PermissionGrants = $null

if ((Get-MgContext).AuthType -eq 'Delegated') {
    $AppRoleAssignments = Get-MgBetaUserAppRoleAssignment `
        -UserId $global:MyMgPrincipal.Id `
        -ConsistencyLevel eventual `
        -CountVariable countVar `
        -ErrorAction SilentlyContinue

    $PermissionGrants = Get-MgOauth2PermissionGrant `
        -All `
        -Filter "PrincipalId eq '$($global:MyMgPrincipal.Id)'" `
        -CountVariable countVar `
        -ErrorAction SilentlyContinue
}
else {
    $AppRoleAssignments = Get-MgBetaServicePrincipalAppRoleAssignment `
        -ServicePrincipalId $global:MyMgPrincipal.Id `
        -ConsistencyLevel eventual `
        -CountVariable countVar `
        -ErrorAction SilentlyContinue

    $PermissionGrants = Get-MgOauth2PermissionGrant `
        -All `
        -Filter "ClientId eq '$($global:MyMgPrincipal.Id)'" `
        -CountVariable countVar `
        -ErrorAction SilentlyContinue
}

if (-Not $App) {
    foreach ($Item in $AppRoleAssignments) {
        $App += $Item.ResourceId
    }
}

foreach ($Item in $App | Select-Object -Unique) {
    $DisplayName = $null
    $AppId = $null
    $AppResource = $null

    if ($Item -is [String]) {
        if ($Item -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$') {
            $AppId = $Item
        }
        else {
            $DisplayName = $Item
        }
    }
    elseif ($Item.AppId) {
        $AppId = $Item.AppId
    }
    elseif ($Item.DisplayName) {
        $DisplayName = $Item.DisplayName
    }

    if ($AppId) {
        $AppResource = Get-MgBetaServicePrincipal -All -ConsistencyLevel eventual -Filter "ServicePrincipalType eq 'Application' and (Id eq '$($AppId)') or (appId eq '$($AppId)')"
    }
    elseif ($DisplayName) {
        $AppResource = Get-MgBetaServicePrincipal -All -ConsistencyLevel eventual -Filter "ServicePrincipalType eq 'Application' and DisplayName eq '$($DisplayName)'"
    }

    if (-Not $AppResource) {
        Write-Warning "Unable to find application: $DisplayName $(if ($AppId) { $AppId })"
        continue
    }

    $AppRoles = @()
    if ($AppRoleAssignments) {
        foreach ($appRoleId in ($AppRoleAssignments | Where-Object ResourceId -eq $AppResource.Id | Select-Object -ExpandProperty AppRoleId -Unique)) {
            $AppRoles += $AppResource.AppRoles | Where-Object Id -eq $appRoleId | Select-Object -ExpandProperty Value
        }
    }

    $Oauth2PermissionScopes = @{}
    if ($PermissionGrants) {
        foreach ($Permissions in ($PermissionGrants | Where-Object ResourceId -eq $AppResource.Id)) {
            foreach ($Permission in $Permissions) {
                $PrincipalTypeName = 'Admin'
                if ($Permission.ConsentType -ne 'AllPrincipals') {
                    $PrincipalTypeName = $Permission.PrincipalId
                }
                $Permission.Scope.Trim() -split ' ' | ForEach-Object {
                    if (-Not $Oauth2PermissionScopes.$PrincipalTypeName) {
                        $Oauth2PermissionScopes.$PrincipalTypeName = @()
                    }
                    $Oauth2PermissionScopes.$PrincipalTypeName += $_
                }
            }
        }
    }

    $return += @{
        AppId                  = $AppResource.AppId
        DisplayName            = $AppResource.DisplayName
        AppRoles               = $AppRoles
        Oauth2PermissionScopes = $Oauth2PermissionScopes
    }
}

Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
return $return
