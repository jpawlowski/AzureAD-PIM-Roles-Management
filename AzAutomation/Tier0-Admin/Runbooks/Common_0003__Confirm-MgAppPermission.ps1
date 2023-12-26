<#PSScriptInfo
.VERSION 1.0.0
.GUID fda5d103-410a-435c-915d-d79e586ade6d
.AUTHOR Julian Pawlowski
.COMPANYNAME Workoho GmbH
.COPYRIGHT (c) 2024 Workoho GmbH. All rights reserved.
.TAGS
.LICENSEURI
.PROJECTURI
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS Common_0002__Get-MgAppPermission.ps1
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>

<#
.SYNOPSIS
    Validate if current application has assigned the listed app roles in Microsoft Entra

.DESCRIPTION
    Common runbook that can be used by other runbooks. It can not be started as an Azure Automation job directly.

.PARAMETER Permissions
    Collection of Apps and their desired permissions. A hash object may look like:

    @{
        [System.String]DisplayName = <DisplayName>
        [System.String]AppId = <roleTemplateId>
        AppRoles = @(
            'Directory.Read.All'
            'User.Read.All'
        )
        Oauth2PermissionScopes = @{
            Admin = @(
                'offline_access'
                'openid'
                'profile'
            )
            '<User-ObjectId>' = @(
            )
        }
    }
#>

[CmdletBinding()]
Param(
    [Parameter(mandatory = $true)]
    [Array]$Permissions
)

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | ForEach-Object { $_.PSObject.Properties | ForEach-Object { $_.Name + ': ' + $_.Value } }) -join ', ') ---"

$AppPermissions = .\Common_0002__Get-MgAppPermission.ps1

foreach ($Permission in ($Permissions | Select-Object -Unique)) {
#TODO
}

Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
