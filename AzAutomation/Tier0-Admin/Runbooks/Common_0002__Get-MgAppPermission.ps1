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
.REQUIREDSCRIPTS Common_0001__Connect-MgGraph.ps1,Common_0000__Import-Module.ps1
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
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | & { process{$_.PSObject.Properties | & { process{$_.Name + ': ' + $_.Value} }} }) -join ', ') ---"
$StartupVariables = (Get-Variable | & { process { $_.Name } })      # Remember existing variables so we can cleanup ours at the end of the script

try {
    if ((Get-Module).Name -match 'Microsoft.Graph.Beta') {
        #region [COMMON] ENVIRONMENT ---------------------------------------------------
        .\Common_0000__Import-Module.ps1 -Modules @(
            @{ Name = 'Microsoft.Graph.Beta.Identity.SignIns'; MinimumVersion = '2.0'; MaximumVersion = '2.65535' }
            @{ Name = 'Microsoft.Graph.Beta.Applications'; MinimumVersion = '2.0'; MaximumVersion = '2.65535' }
            @{ Name = 'Microsoft.Graph.Beta.Users'; MinimumVersion = '2.0'; MaximumVersion = '2.65535' }
        ) 1> $null
        #endregion ---------------------------------------------------------------------

        $return = [System.Collections.ArrayList]::new()

        if ((Get-MgContext).AuthType -eq 'Delegated') {
            $AppRoleAssignments = Get-MgBetaUserAppRoleAssignment `
                -UserId $env:MG_PRINCIPAL_ID `
                -ConsistencyLevel eventual `
                -CountVariable countVar `
                -ErrorAction SilentlyContinue `
                -Verbose:$false

            $PermissionGrants = Get-MgBetaOauth2PermissionGrant `
                -All `
                -Filter "PrincipalId eq '$($env:MG_PRINCIPAL_ID)'" `
                -CountVariable countVar `
                -ErrorAction SilentlyContinue `
                -Verbose:$false
        }
        else {
            $AppRoleAssignments = Get-MgBetaServicePrincipalAppRoleAssignment `
                -ServicePrincipalId $env:MG_PRINCIPAL_ID `
                -ConsistencyLevel eventual `
                -CountVariable countVar `
                -ErrorAction SilentlyContinue `
                -Verbose:$false

            $PermissionGrants = Get-MgBetaOauth2PermissionGrant `
                -All `
                -Filter "ClientId eq '$($env:MG_PRINCIPAL_ID)'" `
                -CountVariable countVar `
                -ErrorAction SilentlyContinue `
                -Verbose:$false
        }

        if ($null -eq $App) {
            $Apps = [System.Collections.ArrayList]::new()
            foreach ($Item in $AppRoleAssignments) {
                $null = $Apps.Add($Item.ResourceId)
            }
        }
        else {
            $Apps = $App | Select-Object -Unique
        }

        foreach ($Item in $Apps) {
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
                $AppResource = Get-MgBetaServicePrincipal -All -ConsistencyLevel eventual -Filter "ServicePrincipalType eq 'Application' and (Id eq '$($AppId)') or (appId eq '$($AppId)')" -Verbose:$false
            }
            elseif ($DisplayName) {
                $AppResource = Get-MgBetaServicePrincipal -All -ConsistencyLevel eventual -Filter "ServicePrincipalType eq 'Application' and DisplayName eq '$($DisplayName)'" -Verbose:$false
            }

            if (-Not $AppResource) {
                Write-Warning "[COMMON]: - Unable to find application: $DisplayName $(if ($AppId) { $AppId })"
                continue
            }

            $AppRoles = [System.Collections.ArrayList]::new()
            if ($AppRoleAssignments) {
                foreach ($appRoleId in ($AppRoleAssignments | Where-Object ResourceId -eq $AppResource.Id | Select-Object -ExpandProperty AppRoleId -Unique)) {
                    $null = $AppRoles.Add(($AppResource.AppRoles | Where-Object Id -eq $appRoleId | Select-Object -ExpandProperty Value))
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
                                $Oauth2PermissionScopes.$PrincipalTypeName = [System.Collections.ArrayList]::new()
                            }
                            $null = ($Oauth2PermissionScopes.$PrincipalTypeName).Add($_)
                        }
                    }
                }
            }

            $null = $return.Add(
                @{
                    AppId                  = $AppResource.AppId
                    DisplayName            = $AppResource.DisplayName
                    AppRoles               = $AppRoles
                    Oauth2PermissionScopes = $Oauth2PermissionScopes
                }
            )
        }
    }
    else {
        #region [COMMON] ENVIRONMENT ---------------------------------------------------
        .\Common_0000__Import-Module.ps1 -Modules @(
            @{ Name = 'Microsoft.Graph.Users'; MinimumVersion = '2.0'; MaximumVersion = '2.65535' }
            @{ Name = 'Microsoft.Graph.Applications'; MinimumVersion = '2.0'; MaximumVersion = '2.65535' }
        ) 1> $null
        #endregion ---------------------------------------------------------------------

        $return = [System.Collections.ArrayList]::new()

        if ((Get-MgContext).AuthType -eq 'Delegated') {
            $AppRoleAssignments = Get-MgUserAppRoleAssignment `
                -UserId $env:MG_PRINCIPAL_ID `
                -ConsistencyLevel eventual `
                -CountVariable countVar `
                -ErrorAction SilentlyContinue `
                -Verbose:$false

            $PermissionGrants = Get-MgOauth2PermissionGrant `
                -All `
                -Filter "PrincipalId eq '$($env:MG_PRINCIPAL_ID)'" `
                -CountVariable countVar `
                -ErrorAction SilentlyContinue `
                -Verbose:$false
        }
        else {
            $AppRoleAssignments = Get-MgServicePrincipalAppRoleAssignment `
                -ServicePrincipalId $env:MG_PRINCIPAL_ID `
                -ConsistencyLevel eventual `
                -CountVariable countVar `
                -ErrorAction SilentlyContinue `
                -Verbose:$false

            $PermissionGrants = Get-MgOauth2PermissionGrant `
                -All `
                -Filter "ClientId eq '$($env:MG_PRINCIPAL_ID)'" `
                -CountVariable countVar `
                -ErrorAction SilentlyContinue `
                -Verbose:$false
        }

        if ($null -eq $App) {
            $Apps = [System.Collections.ArrayList]::new()
            foreach ($Item in $AppRoleAssignments) {
                $null = $Apps.Add($Item.ResourceId)
            }
        }
        else {
            $Apps = $App | Select-Object -Unique
        }

        foreach ($Item in $Apps) {
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
                $AppResource = Get-MgServicePrincipal -All -ConsistencyLevel eventual -Filter "ServicePrincipalType eq 'Application' and (Id eq '$($AppId)') or (appId eq '$($AppId)')" -Verbose:$false
            }
            elseif ($DisplayName) {
                $AppResource = Get-MgServicePrincipal -All -ConsistencyLevel eventual -Filter "ServicePrincipalType eq 'Application' and DisplayName eq '$($DisplayName)'" -Verbose:$false
            }

            if (-Not $AppResource) {
                Write-Warning "[COMMON]: - Unable to find application: $DisplayName $(if ($AppId) { $AppId })"
                continue
            }

            $AppRoles = [System.Collections.ArrayList]::new()
            if ($AppRoleAssignments) {
                foreach ($appRoleId in ($AppRoleAssignments | Where-Object ResourceId -eq $AppResource.Id | Select-Object -ExpandProperty AppRoleId -Unique)) {
                    $null = $AppRoles.Add(($AppResource.AppRoles | Where-Object Id -eq $appRoleId | Select-Object -ExpandProperty Value))
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
                                $Oauth2PermissionScopes.$PrincipalTypeName = [System.Collections.ArrayList]::new()
                            }
                            $null = ($Oauth2PermissionScopes.$PrincipalTypeName).Add($_)
                        }
                    }
                }
            }

            $null = $return.Add(
                @{
                    AppId                  = $AppResource.AppId
                    DisplayName            = $AppResource.DisplayName
                    AppRoles               = $AppRoles
                    Oauth2PermissionScopes = $Oauth2PermissionScopes
                }
            )
        }
    }
}
catch {
    Throw $_
}

Get-Variable | Where-Object { $StartupVariables -notcontains @($_.Name, 'return') } | & { process { Remove-Variable -Scope 0 -Name $_.Name -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -Verbose:$false -Debug:$false } }        # Delete variables created in this script to free up memory for tiny Azure Automation sandbox
Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
return $return
