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
    'OnPremDirectorySynchronization.Read.All'   # To read directory sync data
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
    Write-Error 'This type of user can not have a Tier 0 Cloud Administrator account created.'
    exit 1
}

foreach ($MgScope in $MgScopes) {
    if ($WhatIfPreference -and ($MgScope -like '*Write*')) {
        Write-Verbose "What If: Removed $MgScope from required Microsoft Graph scopes"
    }
}
if (-Not (Get-MgContext)) {
    if ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
        $null = ResilientRemoteCall { Write-Verbose (Connect-MgGraph -NoWelcome -Identity -ContextScope Process) }
        Write-Verbose (Get-MgContext | ConvertTo-Json)
    }
    else {
        Write-Information 'Opening connection to Microsoft Graph ...'
        ResilientRemoteCall { Connect-MgGraph -NoWelcome -Scopes $MgScopes -ContextScope Process }
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
        Write-Information 'Re-authentication to Microsoft Graph for missing scopes ...'
        ResilientRemoteCall { Connect-MgGraph -NoWelcome -Scopes $MgScopes -ContextScope Process }
    }
}

# If connection to Microsoft Graph seems okay
#
$userProperties = @(
    'Id'
    'UserPrincipalName'
    'Mail'
    'MailNickname'
    'DisplayName'
    'GivenName'
    'Surname'
    'EmployeeId'
    'EmployeeHireDate'
    'EmployeeLeaveDateTime'
    'EmployeeOrgData'
    'EmployeeType'
    'UserType'
    'AccountEnabled'
    'OnPremisesSamAccountName'
    'OnPremisesSyncEnabled'
    'CompanyName'
    'Department'
    'StreetAddress'
    'City'
    'PostalCode'
    'State'
    'Country'
    'UsageLocation'
    'OfficeLocation'
)
$userExpandPropeties = @(
    'Manager'
)

$refUserObj = ResilientRemoteCall {
    Get-MgUser `
        -UserId $ReferralUserId `
        -Property $userProperties `
        -ExpandProperty $userExpandPropeties `
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

if (-Not $refUserObj.AccountEnabled) {
    Write-Error 'Referral User ID is disabled. A Tier 0 Cloud Administrator account can only be set up for active accounts.'
    exit 1
}

if ($refUserObj.UserType -ne 'Member') {
    Write-Error 'Referral User ID must be of type Member.'
    exit 1
}

$timeNow = Get-Date

if ($null -ne $refUserObj.EmployeeHireDate -and ($timeNow.ToUniversalTime() -lt $refUserObj.EmployeeHireDate)) {
    Write-Error "Referral User ID will start to work at $($refUserObj.EmployeeHireDate | Get-Date -Format 'o') Universal Time. A Tier 0 Cloud Administrator account can only be set up for active employees."
    exit 1
}

if ($null -ne $refUserObj.EmployeeLeaveDateTime -and ($timeNow.ToUniversalTime() -ge $refUserObj.EmployeeLeaveDateTime.AddDays(-45))) {
    Write-Error "Referral User ID is scheduled for deactivation at $($refUserObj.EmployeeLeaveDateTime | Get-Date -Format 'o') Universal Time. A Tier 0 Cloud Administrator account can only be set up a maximum of 45 days before the planned leaving date."
    exit 1
}

$tenant = ResilientRemoteCall { Get-MgOrganization }
$tenantDomain = $tenant.VerifiedDomains | Where-Object IsInitial -eq true

if ($true -eq $tenant.OnPremisesSyncEnabled -and ($true -ne $refUserObj.OnPremisesSyncEnabled)) {
    Write-Error "Referral User ID must be a hybrid identity synced from on-premises directory."
    exit 1
}

if (
    ((Get-ConnectionInformation | Where-Object Organization -eq $tenantDomain.Name).State -ne 'Connected') -or
    ((Get-ConnectionInformation | Where-Object Organization -eq $tenantDomain.Name).tokenStatus -ne 'Active')
) {
    Get-ConnectionInformation | Where-Object Organization -eq $tenantDomain.Name | ForEach-Object { Disconnect-ExchangeOnline -ConnectionId $_.ConnectionId -Confirm:$false }
    if ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
        $null = ResilientRemoteCall { Write-Verbose (Connect-ExchangeOnline -ShowBanner:$false -ManagedIdentity -Organization $tenantDomain.Name) }
        Write-Verbose (Get-ConnectionInformation | Where-Object Organization -eq $tenantDomain.Name | ConvertTo-Json)
    }
    else {
        Write-Information 'Opening connection to Exchange Online ...'
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
    Write-Error 'Referral User ID must have a mailbox.'
    exit 1
}

if ('UserMailbox' -ne $refUserExObj.RecipientType -or 'UserMailbox' -ne $refUserExObj.RecipientTypeDetails) {
    Write-Error "Referral User ID mailbox must be of type UserMailbox. Tier 0 Cloud Administrator accounts can not be created for user mailbox types of $($refUserExObj.RecipientTypeDetails)"
    exit 1
}

$BodyParamsNull = @{
    JobTitle = $null
}
$BodyParams = @{
    MailNickname      = 'A0C-' + $refUserObj.MailNickname
    EmployeeType      = 'Tier 0 Cloud Administrator'
    UserPrincipalName = 'A0C-' + ($refUserObj.UserPrincipalName).Split('@')[0] + '@' + $tenantDomain.Name
    PasswordProfile   = @{
        Password                             = Get-RandomPassword -lowerChars 32 -upperChars 32 -numbers 32 -symbols 32
        ForceChangePasswordNextSignIn        = $false
        ForceChangePasswordNextSignInWithMfa = $false
    }
    PasswordPolicies  = 'DisablePasswordExpiration'
}
if (-Not [string]::IsNullOrEmpty($refUserObj.DisplayName)) {
    $BodyParams.DisplayName = 'A0C-' + $refUserObj.DisplayName
}
if (-Not [string]::IsNullOrEmpty($refUserObj.GivenName)) {
    $BodyParams.GivenName = 'A0C-' + $refUserObj.GivenName
}
ForEach ($property in $userProperties) {
    if (
        ($null -eq $BodyParams.$property) -and
        ($property -notin @('Id', 'Mail', 'UserType')) -and
        ($property -notmatch '^OnPremises')
    ) {
        # Empty or null values require special handling as of today
        if ([string]::IsNullOrEmpty($refUserObj.$property)) {
            $BodyParamsNull.$property = $null
        }
        else {
            $BodyParams.$property = $refUserObj.$property
        }
    }
}

$deletedUserList = ResilientRemoteCall {
    Invoke-MGGraphRequest `
        -OutputType PSObject `
        -Method GET `
        -Headers @{ 'ConsistencyLevel' = 'eventual' } `
        -Uri "https://graph.microsoft.com/beta/directory/deletedItems/microsoft.graph.user?`$count=true&`$filter=endsWith(UserPrincipalName,'$($BodyParams.UserPrincipalName)')" `
        -Debug:$DebugPreference `
        -Verbose:$false
}

if ($deletedUserList.'@odata.count' -gt 0) {
    foreach ($deletedUserObj in $deletedUserList.Value) {
        Write-Warning "Admin account $($deletedUserObj.UserPrincipalName) ($($deletedUserObj.Id)) was already existing for referral user $($refUserObj.UserPrincipalName), but was deleted on $($deletedUserObj.DeletedDateTime) Universal Time. Account will be permanently deleted for account re-creation."
        $mboxObj = ResilientRemoteCall {
            Get-EXOMailbox `
                -ExternalDirectoryObjectId $deletedUserObj.Id `
                -SoftDeletedMailbox
        }
        ResilientRemoteCall {
            Invoke-MGGraphRequest `
                -OutputType PSObject `
                -Method DELETE `
                -Uri "https://graph.microsoft.com/beta/directory/deletedItems/$($deletedUserObj.Id)" `
                -Debug:$DebugPreference `
                -Verbose:$false
        }
        if ($mboxObj) {
            ResilientRemoteCall {
                Remove-Mailbox `
                    -Identity $mboxObj.Identity `
                    -PermanentlyDelete `
                    -Confirm:$false
            }
        }
    }
}

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
    $BodyParams.Remove('PasswordProfile')
    $null = ResilientRemoteCall {
        Update-MgUser `
            -UserId $existingUserObj.Id `
            -BodyParameter $BodyParams `
            -Confirm:$false
    }
    if ($BodyParamsNull.Count -gt 0) {
        $null = ResilientRemoteCall {
            Invoke-MgGraphRequest `
                -OutputType PSObject `
                -Method PATCH `
                -Uri "https://graph.microsoft.com/v1.0/users/$($existingUserObj.Id)" `
                -Body $BodyParamsNull `
                -Debug:$DebugPreference `
                -Verbose:$false
        }
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
    Write-Error ("Could not create Tier 0 Cloud Administrator account $($BodyParams.UserPrincipalName): " + $Error[0].CategoryInfo.TargetName + ': ' + $Error[0].ToString())
    exit 1
}

$NewManager = @{
    '@odata.id' = 'https://graph.microsoft.com/v1.0/users/' + $refUserObj.Id
}
$null = ResilientRemoteCall {
    Set-MgUserManagerByRef -UserId $userObj.Id -BodyParameter $NewManager
}

Write-Verbose "Created Tier 0 Cloud Administrator account $($userObj.UserPrincipalName) ($($userObj.Id))"

# Wait for licenses
$DoLoop = $true
$RetryCount = 1
$MaxRetry = 30
$WaitSec = 7

do {
    $userLicObj = ResilientRemoteCall {
        Get-MgUserLicenseDetail -UserId $userObj.Id
    }
    if ($null -ne $userLicObj) {
        $DoLoop = $false
    }
    elseif ($RetryCount -ge $MaxRetry) {
        Write-Error "Group-based licensing timeout (group-based licensing did not assign a license?). Deleting unfinished Tier 0 Cloud Administrator account $($userObj.UserPrincipalName) ($($userObj.Id)) ..."
        $userObj = ResilientRemoteCall {
            Remove-MgUser `
                -UserId $userObj.Id `
                -ErrorAction SilentlyContinue `
                -Confirm:$false
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
$RetryCount = 1
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
    elseif ($RetryCount -ge $MaxRetry) {
        Write-Error "Mailbox creation timeout (group-based licensing did not assign a license?). Deleting unfinished Tier 0 Cloud Administrator account $($userObj.UserPrincipalName) ($($userObj.Id)) ..."
        $userObj = ResilientRemoteCall {
            Remove-MgUser `
                -UserId $userObj.Id `
                -ErrorAction SilentlyContinue `
                -Confirm:$false
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

$null = ResilientRemoteCall {
    Set-Mailbox `
        -Identity $userExObj.Identity `
        -ForwardingAddress $refUserExObj.Identity `
        -ForwardingSmtpAddress $null `
        -DeliverToMailboxAndForward $false `
        -HiddenFromAddressListsEnabled $true `
        -WarningAction SilentlyContinue
}

$userExMbObj = ResilientRemoteCall {
    Get-Mailbox -Identity $userExObj.Identity
}
$userObj = ResilientRemoteCall {
    Get-MgUser `
        -UserId $userObj.Id `
        -Property $userProperties `
        -ExpandProperty $userExpandPropeties `
        -Debug:$DebugPreference `
        -Verbose:$false
}

$return.Data = @{
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
ForEach ($property in $userProperties) {
    if ($null -eq $return.Data.$property) {
        $return.Data.$property = $userObj.$property
    }
}


if ($return.Data.Count -eq 0) { $return.Remove('Data') }
if ($Webhook) { ResilientRemoteCall { Write-Verbose $(Invoke-WebRequest -UseBasicParsing -Uri $Webhook -Method POST -Body $($return | ConvertTo-Json -Depth 4)) } }
if ($OutText) { return Write-Output $(if ($return.Data.UserPrincipalName) { $return.Data.UserPrincipalName } else { $null }) }
if ($OutJson) { return Write-Output $($return | ConvertTo-Json -Depth 4) }

return $return
