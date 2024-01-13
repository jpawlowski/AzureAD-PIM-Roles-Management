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
.REQUIREDSCRIPTS Common_0001__Connect-MgGraph.ps1,Common_0000__Import-Module.ps1
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
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | & { process{$_.PSObject.Properties | & { process{$_.Name + ': ' + $_.Value} }} }) -join ', ') ---"
# $StartupVariables = (Get-Variable | & { process { $_.Name } })      # Remember existing variables so we can cleanup ours at the end of the script

$return = @{
    IsInternal               = $null
    IsEmailOTPAuthentication = $null
    IsFacebookAccount        = $null
    IsGoogleAccount          = $null
    IsMicrosoftAccount       = $null
    IsExternalEntraAccount   = $null
    IsFederated              = $null
    GuestOrExternalUserType  = $null
}

if (-Not [string]::IsNullOrEmpty($UserObject.Identities)) {
    Write-Verbose 'Evaluating identities'
    if (
        (($UserObject.Identities).Issuer -contains 'mail') -or
        (($UserObject.Identities).SignInType -contains 'emailAddress')
    ) {
        Write-Verbose '- IsEmailOTPAuthentication'
        $return.IsEmailOTPAuthentication = $true
    }
    else {
        $return.IsEmailOTPAuthentication = $false
    }

    if (($UserObject.Identities).Issuer -contains 'facebook.com') {
        Write-Verbose '- IsFacebookAccount'
        $return.IsFacebookAccount = $true
    }
    else {
        $return.IsFacebookAccount = $false
    }

    if (($UserObject.Identities).Issuer -contains 'google.com') {
        Write-Verbose '- IsGoogleAccount'
        $return.IsGoogleAccount = $true
    }
    else {
        $return.IsGoogleAccount = $false
    }

    if (($UserObject.Identities).Issuer -contains 'MicrosoftAccount') {
        Write-Verbose '- IsMicrosoftAccount'
        $return.IsMicrosoftAccount = $true
    }
    else {
        $return.IsMicrosoftAccount = $false
    }

    if (($UserObject.Identities).Issuer -contains 'ExternalAzureAD') {
        Write-Verbose '- ExternalAzureAD'
        $return.IsExternalEntraAccount = $true
    }
    else {
        $return.IsExternalEntraAccount = $false
    }

    if (
        ($UserObject.Identities).SignInType -contains 'federated'
    ) {
        Write-Verbose '- IsFederated'
        $return.IsFederated = $true
    }
    else {
        $return.IsFederated = $false
    }
}

if (
    (-Not [string]::IsNullOrEmpty($UserObject.UserType)) -and
    (-Not [string]::IsNullOrEmpty($UserObject.UserPrincipalName))
) {
    Write-Verbose 'Evaluating UserType'

    if ($UserObject.UserType -eq 'Member') {
        if ($UserObject.UserPrincipalName -notmatch '^.+#EXT#@.+\.onmicrosoft\.com$') {
            $return.GuestOrExternalUserType = 'None'
        }
        else {
            $return.GuestOrExternalUserType = 'b2bCollaborationMember'
        }
    }
    elseif ($UserObject.UserType -eq 'Guest') {
        if ($UserObject.UserPrincipalName -notmatch '^.+#EXT#@.+\.onmicrosoft\.com$') {
            $return.GuestOrExternalUserType = 'internalGuest'
        }
        else {
            $return.GuestOrExternalUserType = 'b2bCollaborationGuest'
        }
    }
    else {
        $return.GuestOrExternalUserType = 'otherExternalUser'
    }
    Write-Verbose "- $($return.GuestOrExternalUserType)"
}

if (
    ($return.IsEmailOTPAuthentication -eq $false) -and
    ($return.IsFacebookAccount -eq $false) -and
    ($return.IsGoogleAccount -eq $false) -and
    ($return.IsMicrosoftAccount -eq $false) -and
    ($return.IsExternalEntraAccount -eq $false) -and
    ($return.IsFederated -eq $false) -and
    ($return.GuestOrExternalUserType -eq 'None')
) {
    Write-Verbose "Internal state: True"
    $return.IsInternal = $true
}
elseif (
    ($null -ne $return.IsEmailOTPAuthentication) -and
    ($null -ne $return.IsFacebookAccount) -and
    ($null -ne $return.IsGoogleAccount) -and
    ($null -ne $return.IsMicrosoftAccount) -and
    ($null -ne $return.IsExternalEntraAccount) -and
    ($null -ne $return.IsFederated) -and
    ($null -ne $return.GuestOrExternalUserType)
) {
    Write-Verbose "Internal state: False"
    $return.IsInternal = $false
}
else {
    Write-Warning "Internal state: UNKNOWN"
}

# Get-Variable | Where-Object { $StartupVariables -notcontains @($_.Name, 'return') } | & { process { Remove-Variable -Scope 0 -Name $_.Name -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -Verbose:$false -Debug:$false } }        # Delete variables created in this script to free up memory for tiny Azure Automation sandbox
Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
return $return
