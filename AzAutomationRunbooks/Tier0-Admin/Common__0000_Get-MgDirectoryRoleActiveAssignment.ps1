<#
.SYNOPSIS
    Get active directory roles of current user
#>

#Requires -Version 5.1

[CmdletBinding()]
Param()

if (-Not $MyInvocation.PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name) ---"

#region CONNECTIONS ------------------------------------------------------------
./Common__0000_Connect-MgGraph.ps1 1> $null
#endregion ---------------------------------------------------------------------

$return = $null

if ((Get-MgContext).AuthType -eq 'Delegated') {
    $return = Get-MgUserTransitiveMemberOfAsDirectoryRole `
        -UserId (Get-MgContext).Account `
        -ConsistencyLevel eventual `
        -CountVariable countVar
}
else {
    $ServicePrincipal = Get-MgServicePrincipalByAppId -AppId (Get-MgContext).ClientId
    $return = Get-MgServicePrincipalTransitiveMemberOfAsDirectoryRole `
        -ServicePrincipalId $ServicePrincipal.Id `
        -ConsistencyLevel eventual `
        -CountVariable countVar
}

Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
return $return
