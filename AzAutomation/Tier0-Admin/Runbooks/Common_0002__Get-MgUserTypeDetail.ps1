<#PSScriptInfo
.VERSION 1.0.0
.GUID 66ac2035-7460-40e8-a4c2-aa7e0816f117
.AUTHOR Julian Pawlowski
.COMPANYNAME Workoho GmbH
.COPYRIGHT (c) 2024 Workoho GmbH. All rights reserved.
.TAGS
.LICENSEURI
.PROJECTURI
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS Common_0001__Connect-MgGraph.ps1,Common_0000__Import-Modules.ps1
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>

<#
.SYNOPSIS
    Get account type of a user object in the directory

.DESCRIPTION
    Common runbook that can be used by other runbooks. It can not be started as an Azure Automation job directly.
#>

[CmdletBinding()]
Param(
    [Parameter(mandatory = $true)]
    [Object]$UserObject
)

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | ForEach-Object { $_.PSObject.Properties | ForEach-Object { $_.Name + ': ' + $_.Value } }) -join ', ') ---"

#region [COMMON] ENVIRONMENT ---------------------------------------------------
.\Common_0000__Import-Modules.ps1 -Modules @(
    @{ Name = 'Microsoft.Graph.Beta.Users'; MinimumVersion = '2.0'; MaximumVersion = '2.65535' }
) 1> $null
#endregion ---------------------------------------------------------------------

$return = @{}

if ($null -eq $UserObject.Identities) {
    $return.IsEmailOTPAuthentication = $null
    $return.IsFacebookAccount = $null
    $return.IsMicrosoftAccount = $null
}
elseif (
    (($UserObject.Identities).Issuer -contains 'mail') -or
    (($UserObject.Identities).Identities.SignInType -contains 'emailAddress') -or
    (($UserObject.Identities).Identities.SignInType -contains 'userName')
) {
    $return.IsEmailOTPAuthentication = $true
    $return.IsFacebookAccount = $false
    $return.IsMicrosoftAccount = $false
}
elseif (($UserObject.Identities).Issuer -contains 'facebook.com') {
    $return.IsEmailOTPAuthentication = $false
    $return.IsFacebookAccount = $true
    $return.IsMicrosoftAccount = $false
}
elseif (($UserObject.Identities).Issuer -contains 'MicrosoftAccount') {
    $return.IsEmailOTPAuthentication = $false
    $return.IsFacebookAccount = $false
    $return.IsMicrosoftAccount = $true
}
else {
    $return.IsEmailOTPAuthentication = $false
    $return.IsFacebookAccount = $false
    $return.IsMicrosoftAccount = $false
}

if (
    ($null -eq $UserObject.UserType) -or
    ($null -eq $UserObject.UserPrincipalName)
) {
    $return.GuestOrExternalUserType = $null
}
elseif ($UserObject.UserType -eq 'External') {
    $return.GuestOrExternalUserType = 'otherExternalUser'
}
elseif ($UserObject.UserType -eq 'Guest') {
    if ($UserObject.UserPrincipalName -notmatch '^.+#EXT#@.+\.onmicrosoft\.com$') {
        $return.GuestOrExternalUserType = 'internalGuest'
    }
    else {
        $return.GuestOrExternalUserType = 'b2bCollaborationGuest'
    }
}
elseif (
    ($UserObject.UserType -eq 'Member') -and
    ($UserObject.UserPrincipalName -match '^.+#EXT#@.+\.onmicrosoft\.com$')
) {
    $return.GuestOrExternalUserType = 'b2bCollaborationMember'
}
else {
    $return.GuestOrExternalUserType = 'None'
}

if (
    ($return.GuestOrExternalUserType -eq 'None') -and
    ($return.IsEmailOTPAuthentication -eq $false) -and
    ($return.IsFacebookAccount -eq $false) -and
    ($return.IsMicrosoftAccount -eq $false)
) {
    $return.IsInternal = $true
}
else {
    $return.IsInternal = $false
}

Write-Verbose "Determined User Type Details: $($return | ConvertTo-Json)"

Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
return $return
