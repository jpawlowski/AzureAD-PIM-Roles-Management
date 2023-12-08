<#
.SYNOPSIS
    Create a dedicated cloud native account for administrative purposes in Tier 0

.DESCRIPTION
    Create a dedicated cloud native account for administrative purposes that can perform privileged tasks in Tier 0, Tier 1, and Tier 2.

.PARAMETER ReferralUserId
    User account identifier of the existing main user account. May be an Entra Identity Object ID or User Principal Name (UPN).

.PARAMETER Webhook
    Send return data as POST to this webhook URL.

.PARAMETER OutputJson
    Output the result in JSON format

.PARAMETER OutputText
    Output the generated User Principal Name only.

.NOTES
    Filename: New-Admin-Tier0-V1.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
    Version: 0.0.1
#>
#Requires -Version 5.1
#Requires -Modules @{ ModuleName='Microsoft.Graph.Identity.SignIns'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Users'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Groups'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='ExchangeOnlineManagement'; ModuleVersion='3.0' }

[CmdletBinding(
    SupportsShouldProcess,
    ConfirmImpact = 'High'
)]
Param (
    [Parameter(Position = 0, mandatory = $true)]
    [string]$ReferralUserId,
    [switch]$Webhook,
    [switch]$OutJson,
    [switch]$OutText
)

Function ResilientRemoteCall {
    param(
        $ScriptBlock
    )

    $DoLoop = $true
    $RetryCount = 0

    do {
        try {
            Invoke-Command -ScriptBlock $ScriptBlock
            Write-Verbose "Invoked $ScriptBlock completed"
            $DoLoop = $false
        }
        catch {
            if ($RetryCount -gt 3) {
                Write-Verbose "Invoked '$ScriptBlock' failed 3 times and we will not try again."
                $DoLoop = $false
            }
            else {
                Write-Verbose "Invoked '$ScriptBlock' failed, retrying in 15 seconds ..."
                Start-Sleep -Seconds 15
                $RetryCount += 1
            }
        }
    } While ($DoLoop)
}
function Get-RandomCharacter($length, $characters) {
    if ($length -lt 1) { return '' }
    $random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.Length }
    $private:ofs = ''
    return [string]$characters[$random]
}
function Get-ScrambleString([string]$inputString) {
    $characterArray = $inputString.ToCharArray()
    $scrambledStringArray = $characterArray | Get-Random -Count $characterArray.Length
    $outputString = -join $scrambledStringArray
    return $outputString
}
function Get-RandomPassword($lowerChars, $upperChars, $numbers, $symbols) {
    if ($null -eq $lowerChars) { $lowerChars = 8 }
    if ($null -eq $upperChars) { $upperChars = 8 }
    if ($null -eq $numbers) { $numbers = 8 }
    if ($null -eq $symbols) { $symbols = 8 }
    $password = Get-RandomCharacter -length $lowerChars -characters 'abcdefghiklmnoprstuvwxyz'
    $password += Get-RandomCharacter -length $upperChars -characters 'ABCDEFGHKLMNOPRSTUVWXYZ'
    $password += Get-RandomCharacter -length $numbers -characters '1234567890'
    $password += Get-RandomCharacter -length $symbols -characters "@#$%^&*-_!+=[]{}|\:',.?/`~`"();<>"
    return Get-ScrambleString $password
}

if ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
    if (-Not $Webhook) { $OutJson = $true }
    $ProgressPreference = 'SilentlyContinue'
}

$MgScopes = @(
    'User.ReadWrite.All'                        # To read and write user information, inlcuding EmployeeHireDate
    'Directory.ReadWrite.All'                   # To read and write directory data
    'User.Read.All'                             # To read user information, inlcuding EmployeeHireDate
    'Directory.Read.All'                        # To read directory data
)
$MissingMgScopes = @()
$return = @{}
$refUserObj = $null
$refUserExObj = $null
$existingUserObj = $null
$userObj = $null
$userLicObj = $null
$userExObj = $null
$userExMbObj = $null

if (
    ($ReferralUserId -match '^A[0-9][A-Z][-_].+@.+$') -or # Tiered admin accounts, e.g. A0C_*, A1L-*, etc.
    ($ReferralUserId -match '^ADM[CL]?[-_].+@.+$') -or # Non-Tiered admin accounts, e.g. ADM_, ADMC-* etc.
    ($ReferralUserId -match '^.+#EXT#@.+\.onmicrosoft\.com$') -or # External Accounts
    ($ReferralUserId -match '^(?:SVCC?_.+|SVC[A-Z0-9]+)@.+$') -or # Service Accounts
    ($ReferralUserId -match '^(?:Sync_.+|[A-Z]+SyncServiceAccount.*)@.+$')  # Entra Sync Accounts
) {
    Write-Error 'This type of user can not have a Tier 0 administrator account created.'
    exit 1
}

foreach ($MgScope in $MgScopes) {
    if ($WhatIfPreference -and ($MgScope -like '*Write*')) {
        Write-Verbose "What If: Removed $MgScope from required Microsoft Graph scopes"
    }
}
if (-Not (Get-MgContext)) {
    if ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
        ResilientRemoteCall { Write-Verbose (Connect-MgGraph -Identity -ContextScope Process) }
        Write-Verbose (Get-MgContext | ConvertTo-Json)
    }
    else {
        ResilientRemoteCall { Connect-MgGraph -Scopes $MgScopes -ContextScope Process }
    }
}
foreach ($MgScope in $MgScopes) {
    if ($MgScope -notin @((Get-MgContext).Scopes)) {
        $MissingMgScopes += $MgScope
    }
}
if ($MissingMgScopes) {
    if ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
        Throw "Missing Microsoft Graph authorization scopes:`n`n$($MissingMgScopes -join "`n")"
    }
    else {
        ResilientRemoteCall { Connect-MgGraph -Scopes $MgScopes -ContextScope Process }
    }
}

# If connection to Microsoft Graph seems okay
#

$refUserObj = ResilientRemoteCall {
    Get-MgUser `
        -UserId $ReferralUserId `
        -Property @(
        'Id'
        'UserPrincipalName'
        'Mail'
        'ShowInAddressList'
        'DisplayName'
        'GivenName'
        'Surname'
        'JobTitle'
        'PreferredName'
        'EmployeeId'
        'EmployeeHireDate'
        'EmployeeLeaveDateTime'
        'EmployeeOrgData'
        'EmployeeType'
        'UserType'
        'AccountEnabled'
        'OnPremisesSamAccountName'
        'OnPremisesSyncEnabled'
        'PreferredLanguage'
        'CompanyName'
        'Department'
        'StreetAddress'
        'City'
        'PostalCode'
        'State'
        'Country'
        'UsageLocation'
        'OfficeLocation'
        'MobilePhone'
        'FaxNumber'
    ) `
        -ExpandProperty @(
        'Manager'
    )`
        -ErrorAction SilentlyContinue `
        -Debug:$DebugPreference `
        -Verbose:$false
}

if ($null -eq $refUserObj) {
    Write-Error 'Referral User ID does not exist.'
    exit 1
}

# If user details could be retrieved
#

if ($null -ne $refUserObj.DeletedDateTime) {
    Write-Error 'Referral User ID is deleted. A Tier 0 administrator account can only be set up for active accounts.'
    exit 1
}

if (-Not $refUserObj.AccountEnabled) {
    Write-Error 'Referral User ID is disabled. A Tier 0 administrator account can only be set up for active accounts.'
    exit 1
}

if ($refUserObj.UserType -ne 'Member') {
    Write-Error 'Referral User ID needs to be of type Member.'
    exit 1
}

$timeNow = Get-Date

if ($null -ne $refUserObj.EmployeeHireDate -and ($timeNow.ToUniversalTime() -lt $refUserObj.EmployeeHireDate)) {
    Write-Error "Referral User ID will start to work at $($refUserObj.EmployeeHireDate | Get-Date -Format 'o') Universal Time. A Tier 0 administrator account can only be set up for active employees."
    exit 1
}

if ($null -ne $refUserObj.EmployeeLeaveDateTime -and ($timeNow.ToUniversalTime() -ge $refUserObj.EmployeeLeaveDateTime.AddDays(-30))) {
    Write-Error "Referral User ID is scheduled for deactivation at $($refUserObj.EmployeeLeaveDateTime | Get-Date -Format 'o') Universal Time. A Tier 0 administrator account can only be set up a maximum of 30 days before the planned leaving date."
    exit 1
}

$tenant = ResilientRemoteCall { Get-MgOrganization }
$tenantDomain = $tenant.VerifiedDomains | Where-Object IsInitial -eq true

if (
    ((Get-ConnectionInformation | Where-Object Organization -eq $tenantDomain.Name).State -ne 'Connected') -or
    ((Get-ConnectionInformation | Where-Object Organization -eq $tenantDomain.Name).tokenStatus -ne 'Active')
) {
    if ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
        ResilientRemoteCall { Write-Verbose (Connect-ExchangeOnline -ShowBanner:$false -ManagedIdentity -Organization $tenantDomain.Name) }
        Write-Verbose (Get-ConnectionInformation | Where-Object Organization -eq $tenantDomain.Name | ConvertTo-Json)
    }
    else {
        ResilientRemoteCall { Connect-ExchangeOnline -ShowBanner:$false -Organization $tenantDomain.Name }
    }
}

$refUserExObj = ResilientRemoteCall {
    Get-EXOMailbox `
        -UserPrincipalName $refUserObj.UserPrincipalName `
        -ErrorAction SilentlyContinue `
        -Debug:$DebugPreference `
        -Verbose:$false
}

if ($null -eq $refUserExObj) {
    Write-Error 'Referral User ID needs to have a mailbox.'
    exit 1
}

if ('UserMailbox' -ne $refUserExObj.RecipientType -or 'UserMailbox' -ne $refUserExObj.RecipientTypeDetails) {
    Write-Error "Referral User ID mailbox must to be of type UserMailbox. Admin accounts can not be created for user mailbox types of $($refUserExObj.RecipientTypeDetails)"
    exit 1
}

$BodyParams = @{}
$BodyParams.Manager = $refUserObj.Id
$BodyParams.UserPrincipalName = 'A0C-' + ($refUserObj.UserPrincipalName).Split('@')[0] + '@' + $tenantDomain.Name
$BodyParams.DisplayName = 'A0C-' + $refUserObj.DisplayName
$BodyParams.GivenName = 'A0C-' + $refUserObj.GivenName
$BodyParams.AccountEnabled = $true
$BodyParams.MailNickname = (New-Guid).Guid.Substring(0, 10)
$BodyParams.PasswordProfile = @{
    Password                             = Get-RandomPassword -lowerChars 32 -upperChars 32 -numbers 32 -symbols 32
    ForceChangePasswordNextSignIn        = $false
    ForceChangePasswordNextSignInWithMfa = $false
}
$BodyParams.PasswordPolicy = @{
    DisablePasswordExpiration = $true
}
if ($null -ne $refUserObj.EmployeeHireDate) { $BodyParams.EmployeeHireDate = $refUserObj.EmployeeHireDate }
if ($null -ne $refUserObj.EmployeeLeaveDateTime) { $BodyParams.EmployeeHireDate = $refUserObj.EmployeeLeaveDateTime }

$existingUserObj = ResilientRemoteCall {
    Get-MgUser `
        -UserId $BodyParams.UserPrincipalName `
        -ErrorAction SilentlyContinue `
        -Debug:$DebugPreference `
        -Verbose:$false
}

if ($null -ne $existingUserObj) {
    Write-Warning "Admin account $($existingUserObj.UserPrincipalName) is already existing for referral user $($refUserObj.UserPrincipalName)"
    Write-Verbose "Updating account $($existingUserObj.UserPrincipalName) with information from $($refUserObj.UserPrincipalName)"
    $BodyParams.Remove('UserPrincipalName')
    $BodyParams.Remove('AccountEnabled')
    $BodyParams.Remove('MailNickname')
    $BodyParams.Remove('PasswordProfile')
    if ($BodyParams.PasswordPolicy.DisablePasswordExpiration) { $BodyParams.PasswordPolicies = 'DisablePasswordExpiration' }
    $BodyParams.Remove('PasswordPolicy')
    $null = ResilientRemoteCall {
        Update-MgUser `
            -UserId $existingUserObj.Id `
            -BodyParameter $BodyParams `
            -ErrorAction SilentlyContinue `
            -Confirm:$false
    }
    $userObj = ResilientRemoteCall {
        Get-MgUser `
            -UserId $existingUserObj.Id `
            -ErrorAction SilentlyContinue `
            -Debug:$DebugPreference `
            -Verbose:$false
    }
}
else {
    $userObj = ResilientRemoteCall {
        New-MgUser `
            -BodyParameter $BodyParams `
            -ErrorAction SilentlyContinue `
            -Confirm:$false
    }
}

if ($null -eq $userObj) {
    Write-Error ("Could not create administrator account $($BodyParams.UserPrincipalName): " + $Error[0].CategoryInfo.TargetName + ': ' + $Error[0].ToString())
    exit 1
}

Write-Verbose "Created administrator account $($BodyParams.UserPrincipalName))"

# Wait for licenses
$DoLoop = $true
$RetryCount = 0
$MaxRetry = 30
$WaitSec = 15

do {
    $userLicObj = ResilientRemoteCall {
        Get-MgUserLicenseDetail -UserId $userObj.Id
    }
    if ($null -ne $userLicObj) {
        $DoLoop = $false
    }
    elseif ($RetryCount -gt $MaxRetry) {
        Write-Error "Group-based licensing timeout (group-based licensing did not assign a license?). Deleting unfinished administrator account $($userObj.UserPrincipalName) ($($userObj.Id)) ..."
        $userObj = ResilientRemoteCall {
            Remove-MgUser `
                -UserId $userObj.Id `
                -ErrorAction SilentlyContinue `
                -Confirm:$false -WhatIf #TODO
        }
        $DoLoop = $false
        exit 1
    }
    else {
        $RetryCount += 1
        Write-Verbose "Try $RetryCount of ${MaxRetry}: Waiting another $WaitSec seconds for Exchange license assignment ..."
        Start-Sleep -Seconds $WaitSec
    }
} While ($DoLoop)

# Wait for mailbox
$DoLoop = $true
$RetryCount = 0
$MaxRetry = 60
$WaitSec = 15

do {
    $userExObj = ResilientRemoteCall {
        Get-EXOMailbox `
            -UserPrincipalName $userObj.UserPrincipalName `
            -ErrorAction SilentlyContinue `
            -Debug:$DebugPreference `
            -Verbose:$false
    }
    if ($null -ne $userExObj) {
        $DoLoop = $false
    }
    elseif ($RetryCount -gt $MaxRetry) {
        Write-Error "Mailbox creation timeout (group-based licensing did not assign a license?). Deleting unfinished administrator account $($userObj.UserPrincipalName) ($($userObj.Id)) ..."
        $userObj = ResilientRemoteCall {
            Remove-MgUser `
                -UserId $userObj.Id `
                -ErrorAction SilentlyContinue `
                -Confirm:$false -WhatIf #TODO
        }
        $DoLoop = $false
        exit 1
    }
    else {
        $RetryCount += 1
        Write-Verbose "Try $RetryCount of ${MaxRetry}: Waiting another $WaitSec seconds for mailbox creation ..."
        Start-Sleep -Seconds $WaitSec
    }
} While ($DoLoop)

Set-Mailbox `
    -Identity $userExObj.Identity `
    -ForwardingAddress $refUserExObj.Identity `
    -ForwardingSmtpAddress $null `
    -DeliverToMailboxAndForward $false `
    -WarningAction SilentlyContinue

$userExMbObj = Get-Mailbox -Identity $userExObj.Identity
$userObj = ResilientRemoteCall {
    Get-MgUser `
        -UserId $userObj.Id `
        -Property @(
        'Id'
        'UserPrincipalName'
        'Mail'
        'ShowInAddressList'
        'DisplayName'
        'GivenName'
        'Surname'
        'JobTitle'
        'PreferredName'
        'EmployeeId'
        'EmployeeHireDate'
        'EmployeeLeaveDateTime'
        'EmployeeOrgData'
        'EmployeeType'
        'UserType'
        'AccountEnabled'
        'OnPremisesSamAccountName'
        'OnPremisesSyncEnabled'
        'PreferredLanguage'
        'CompanyName'
        'Department'
        'StreetAddress'
        'City'
        'PostalCode'
        'State'
        'Country'
        'UsageLocation'
        'OfficeLocation'
        'MobilePhone'
        'FaxNumber'
    ) `
        -ExpandProperty @(
        'Manager'
    )`
        -ErrorAction SilentlyContinue `
        -Debug:$DebugPreference `
        -Verbose:$false
}

$return.Data = @{
    '@odata.context'           = $userObj.AdditionalProperties.'@odata.context'
    Id                         = $userObj.Id
    UserPrincipalName          = $userObj.UserPrincipalName
    Mail                       = $userObj.Mail
    DisplayName                = $userObj.DisplayName
    EmployeeHireDate           = $userObj.EmployeeHireDate
    EmployeeLeaveDateTime      = $userObj.EmployeeLeaveDateTime
    UserType                   = $userObj.UserType
    AccountEnabled             = $userObj.AccountEnabled
    Manager                    = @{
        Id                = $userObj.Manager.Id
        UserPrincipalName = $userObj.manager.AdditionalProperties.userPrincipalName
        Mail              = $userObj.manager.AdditionalProperties.mail
        DisplayName       = $userObj.manager.AdditionalProperties.displayName
    }
    ForwardingAddress          = $userExMbObj.ForwardingAddress
    ForwardingSMTPAddress      = $userExMbObj.ForwardingSMTPAddress
    DeliverToMailboxandForward = $userExMbObj.DeliverToMailboxandForward
}


if ($return.Data.Count -eq 0) { $return.Remove('Data') }
if ($Webhook) { ResilientRemoteCall { Write-Verbose $(Invoke-WebRequest -UseBasicParsing -Uri $Webhook -Method POST -Body $($return | ConvertTo-Json -Depth 4)) } }
if ($OutText) { return Write-Output (if ($return.Data.TemporaryAccessPass.TemporaryAccessPass) { $return.Data.TemporaryAccessPass.TemporaryAccessPass } else { $null }) }
if ($OutJson) { return Write-Output $($return | ConvertTo-Json -Depth 4) }

return $return
