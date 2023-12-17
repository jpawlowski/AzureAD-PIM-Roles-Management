<#
.SYNOPSIS
    Validate if current application has assigned the listed app roles in Microsoft Entra

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

.NOTES
    Original name: Common__0001_Confirm-MgAppPermissionAssignment.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
    Version: 1.0.0
#>

#Requires -Version 5.1

[CmdletBinding()]
Param(
    [Parameter(mandatory = $true)]
    [Array]$Permissions
)

# if (-Not $MyInvocation.PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name) ---"

#region [COMMON] CONNECTIONS ---------------------------------------------------
./Common__0000_Connect-MgGraph.ps1 1> $null
#endregion ---------------------------------------------------------------------

$AppPermissions = ./Common__0000_Get-MgAppPermission.ps1

foreach ($Permission in ($Permissions | Select-Object -Unique)) {

}

Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
