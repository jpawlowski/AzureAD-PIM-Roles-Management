<#
.SYNOPSIS
    Get permissions to other applications of current application
#>

#Requires -Version 5.1
#Requires -Modules @{ ModuleName='Microsoft.Graph.Identity.SignIns'; ModuleVersion='2.0'; MaximumVersion='2.65535' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Users'; ModuleVersion='2.0'; MaximumVersion='2.65535' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Applications'; ModuleVersion='2.0'; MaximumVersion='2.65535' }

[CmdletBinding()]
Param(
    [Array]$App
)

if (-Not $MyInvocation.PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name) ---"

#region CONNECTIONS ------------------------------------------------------------
.\Common__0000_Connect-MgGraph.ps1 1> $null
#endregion ---------------------------------------------------------------------

$return = @()

$AppRoleAssignments = $null
$PermissionGrants = $null

if ((Get-MgContext).AuthType -eq 'Delegated') {
    $Principal = Get-MgUser -UserId (Get-MgContext).Account
    $AppRoleAssignments = Get-MgUserAppRoleAssignment `
        -UserId $Principal.Id `
        -ConsistencyLevel eventual `
        -CountVariable countVar `
        -ErrorAction SilentlyContinue

    $PermissionGrants = Get-MgOauth2PermissionGrant `
        -All `
        -Filter "PrincipalId eq '$($Principal.Id)'" `
        -CountVariable countVar `
        -ErrorAction SilentlyContinue
}
else {
    $Principal = Get-MgServicePrincipalByAppId -AppId (Get-MgContext).ClientId
    $AppRoleAssignments = Get-MgServicePrincipalAppRoleAssignment `
        -ServicePrincipalId $Principal.Id `
        -ConsistencyLevel eventual `
        -CountVariable countVar `
        -ErrorAction SilentlyContinue

    $PermissionGrants = Get-MgOauth2PermissionGrant `
        -All `
        -Filter "ClientId eq '$($Principal.Id)'" `
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
        $AppResource = Get-MgServicePrincipal -All -ConsistencyLevel eventual -Filter "ServicePrincipalType eq 'Application' and (Id eq '$($AppId)') or (appId eq '$($AppId)')"
    }
    elseif ($DisplayName) {
        $AppResource = Get-MgServicePrincipal -All -ConsistencyLevel eventual -Filter "ServicePrincipalType eq 'Application' and DisplayName eq '$($DisplayName)'"
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
