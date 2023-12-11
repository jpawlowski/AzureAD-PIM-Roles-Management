<#
.SYNOPSIS
    Create or update a dedicated cloud native account for administrative purposes in Tier 0, 1, or 2

.DESCRIPTION
    Create a dedicated cloud native account for administrative purposes that can perform privileged tasks in Tier 0, Tier 1, and/or Tier 2.
    User Principal Name and mail address of the admin account will use the initial .onmicrosoft.com domain of the respective Entra ID tenant.
    The admin account will be referred to the main user account from ReferralUserId by using the manager property as well as using the same Employee information (if set).
    To identify as a Cloud Administrator account, the EmployeeType property will be used so that it can be used as an alternative to the UPN naming convention.
    Also, extensionAttribute15 will be used to reflect the account type. If the same extension attribute is also used for the referring account, it is copied and a prefix of 'AxC__' is added where 'x' represents the respective Tier level.
    Permanent e-mail forwarding to the referring user ID will be configured to receive notifications, e.g. from Entra Privileged Identity Management.

    Following conditions must be met to create a Cloud Administrator account:

         1. A free license with Exchange Online plan must be available.
         2. Referral user ID must exist.
         3. Referral user ID must be an ordinary user account.
         4. Referral user ID must not use a onmicrosoft.com subdomain.
         5. Referral user ID must be enabled.
         6. Referral user ID must be of directory type Member.
         7. Referral user ID must have a manager.
         8. If Referral user ID has EmployeeHireDate, the date and time must be reached.
         9. If Referral user ID has EmployeeLeaveDateTime, the current date and time must be at least 45 days before.
        10. If tenant has on-premises directory sync enabled, referral user ID must be a hybrid user account.
        11. Referral user ID must have a mailbox of type UserMailbox.

    In case an existing Cloud Administrator account was found for referral user ID, it must by a cloud native account to be updated. Otherwise an error is returned and manual cleanup of the on-premises synced account is required to resolve the conflict.
    If an existing Cloud administrator account was soft-deleted before, it will be permanently deleted before re-creating the account. A soft-deleted mailbox will be permanently deleted in that case as well.
    The user part of the Cloud Administrator account must be mutually exclusive to the tenant. A warning will be generated if there is other accounts using either a similar User Principal Name or same Display Name, Mail, Mail Nickname, or ProxyAddress.

.PARAMETER ReferralUserId
    User account identifier of the existing main user account. May be an Entra Identity Object ID or User Principal Name (UPN).

.PARAMETER LicenseSkuPartNumber
    License assigned to the user. The license SkuPartNumber must contain an Exchange Online service plan to generate a mailbox for the user (see https://learn.microsoft.com/en-us/entra/identity/users/licensing-service-plan-reference).
    If GroupId is also provided, group-based licensing is implied and license assignment will only be monitored before continuing.
    This parameter has a default value for Exchange Online Kiosk license (SkuPartNumber EXCHANGEDESKLESS) and only Exchange license plan will be enabled in it.
    If environment variable $env:avTier0AdminLicenseSkuPartNumber is set, it will be used and takes precedence.
    In Azure Automation, automation variable avTier0AdminLicenseSkuPartNumber will be used and takes precedence.

.PARAMETER GroupId
    Entra Group Object ID where the user shall be added. If the group is dynamic, group membership update will only be monitored before continuing.
    If environment variable $env:avTier0AdminGroupId is set, it will be used and takes precedence.
    In Azure Automation, automation variable avTier0AdminGroupId will be used and takes precedence.

.PARAMETER UserPhotoUrl
    URL of an image that shall be set as default photo for the user. Must be HTTPS and use image/png or image/jpeg as Content-Type in HTTP return header.
    If environment variable $env:avTier0AdminUserPhotoUrl is set, it will be used and takes precedence.
    In Azure Automation, automation variable avTier0AdminUserPhotoUrl will be used and takes precedence.

.PARAMETER Webhook
    Send return data in JSON format as POST to this webhook URL.
    If not set, environment variable $env:avTier0AdminWebhook will be used instead.
    If not set and run in Azure Automation, automation variable avTier0AdminWebhook will be used instead.

.PARAMETER OutputJson
    Output the result in JSON format.
    This is automatically implied when running in Azure Automation and no Webhook parameter was set.

.PARAMETER OutputText
    Output the generated User Principal Name only.

.PARAMETER Version
    Print version information.

.NOTES
    Filename: New-CloudAdministrator-Account-V1.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
    Version: 0.0.1
#>

#TODO:
#-admin prefix separator as variable
#- research if Desired State Provisioning could be used?
#- Add multi tier support
#- Multiple licenses support
#- variable for dedicated account yes/no per tier
#- Variable for extension attribute
#- Parallel run check
#- Check refUser for extensionAttribute and EmployeeType
#- Send emails were applicable
#- find existing account not only by UPN but also extensionAttribute and EmployeeType
#- WhatIf support
#- Progress support
#- Only update account if there is actual changes to it and report that changes had to be made --> a continuous monitoring and enforcement of the account state shall be possible via scheduled task

#Requires -Version 5.1
#Requires -Modules @{ ModuleName='Az.Accounts'; ModuleVersion='2.12' }
#Requires -Modules @{ ModuleName='Az.Resources'; ModuleVersion='6.8' }
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
    [Parameter(mandatory = $true)]
    [ValidateRange(0, 2)][int]$Tier,
    [string]$LicenseSkuPartNumber,
    [string]$GroupId,
    [string]$UserPhotoUrl,
    [string]$Webhook,
    [switch]$OutJson,
    [switch]$OutText,
    [switch]$Version
)

if ($Version) {
    (Get-Help $MyInvocation.InvocationName -Full).PSExtended.AlertSet
    exit
}
Write-Verbose $(((Get-Help $MyInvocation.InvocationName -Full).PSExtended.AlertSet.Alert.Text) )

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
Function Send-FailMail {
    $to = "email@domain.com"
    $from = "FromEmail@domain.com"
    $bcc = $from
    $subject = "Employee Photo - $photo - Failed to Update"
    $type = "html"
    $template = "C:\temp\PhotoFailMail.html"
    $params = @{
        Message         = @{
            Subject       = $subject
            Body          = @{
                ContentType = $type
                Content     = $template
            }
            ToRecipients  = @(
                @{
                    EmailAddress = @{
                        Address = $to
                    }
                }
            )
            BccRecipients = @(
                @{
                    EmailAddress = @{
                        Address = $bcc
                    }
                }
            )
        }
        SaveToSentItems = "true"
    }
    Send-MgUserMail -UserId $from -BodyParameter $params
}
Function Get-RandomCharacter($length, $characters) {
    if ($length -lt 1) { return '' }
    $random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.Length }
    $private:ofs = ''
    return [string]$characters[$random]
}
Function Get-ScrambleString([string]$inputString) {
    $characterArray = $inputString.ToCharArray()
    $scrambledStringArray = $characterArray | Get-Random -Count $characterArray.Length
    $outputString = -join $scrambledStringArray
    return $outputString
}
Function Get-RandomPassword($lowerChars, $upperChars, $numbers, $symbols) {
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
    $null = ResilientRemoteCall { Write-Verbose (Connect-AzAccount -Identity -Scope Process) }
    Write-Verbose (Get-AzContext | ConvertTo-Json)

    $tmpLicenseSkuPartNumber = ResilientRemoteCall { Get-AzAutomationVariable -Name "avTier${Tier}AdminLicenseSkuPartNumber" -ErrorAction SilentlyContinue }
    if ($tmpLicenseSkuPartNumber.Value) {
        if ($LicenseSkuPartNumber) {
            Write-Warning 'Ignored LicenseSkuPartNumber parameter from job request input and replaced by Azure Automation variable.'
        }
        else {
            Write-Verbose 'Using LicenseSkuPartNumber from Azure Automation variable.'
        }
        Set-Variable LicenseSkuPartNumber -Option Constant -Value $tmpLicenseSkuPartNumber.Value
    }
    else {
        Set-Variable LicenseSkuPartNumber -Option Constant -Value 'EXCHANGEDESKLESS'
        Write-Verbose "Using LicenseSkuPartNumber built-in default value $LicenseSkuPartNumber."
    }
    $tmpGroupId = ResilientRemoteCall { Get-AzAutomationVariable -Name "avTier${Tier}AdminGroupId" -ErrorAction SilentlyContinue }
    if ($tmpGroupId.Value) {
        if ($GroupId) {
            Write-Warning 'Ignored GroupId parameter from job request input and replaced by Azure Automation variable.'
        }
        else {
            Write-Verbose 'Using GroupId from Azure Automation variable.'
        }
        Set-Variable GroupId -Option Constant -Value $tmpGroupId.Value
    }
    $tmpUserPhotoUrl = ResilientRemoteCall { Get-AzAutomationVariable -Name "avTier${Tier}AdminUserPhotoUrl" -ErrorAction SilentlyContinue }
    if ($tmpUserPhotoUrl.Value) {
        if ($UserPhotoUrl) {
            Write-Warning 'Ignored UserPhotoUrl parameter from job request input and replaced by Azure Automation variable.'
        }
        else {
            Write-Verbose 'Using UserPhotoUrl from Azure Automation variable.'
        }
        Set-Variable UserPhotoUrl -Option Constant -Value $tmpUserPhotoUrl.Value
    }
    if (-Not $Webhook) {
        $tmpWebhook = ResilientRemoteCall { Get-AzAutomationVariable -Name "avTier${Tier}AdminWebhook" -ErrorAction SilentlyContinue }
        if ($tmpWebhook.Value) {
            Write-Verbose 'Using Webhook from Azure Automation variable.'
            Set-Variable Webhook -Option Constant -Value $tmpWebhook.Value
        }
    }

    if (-Not $Webhook) { $OutJson = $true }
    $ProgressPreference = 'SilentlyContinue'
}
else {
    if (Get-ChildItem -Path env:"avTier${Tier}AdminLicenseSkuPartNumber" -ErrorAction SilentlyContinue) {
        if ($LicenseSkuPartNumber) {
            Write-Warning 'Ignored LicenseSkuPartNumber parameter and replaced by environment variable.'
        }
        else {
            Write-Verbose 'Using LicenseSkuPartNumber from environment variable.'
        }
        $LicenseSkuPartNumber = (Get-ChildItem -Path env:"avTier${Tier}AdminLicenseSkuPartNumber").Value
    }
    else {
        $LicenseSkuPartNumber = 'EXCHANGEDESKLESS'
        Write-Verbose "Using LicenseSkuPartNumber built-in default value $LicenseSkuPartNumber."
    }
    if (Get-ChildItem -Path env:"avTier${Tier}AdminGroupId" -ErrorAction SilentlyContinue) {
        if ($GroupId) {
            Write-Warning 'Ignored GroupId parameter and replaced by environment variable.'
        }
        else {
            Write-Verbose 'Using GroupId from environment variable.'
        }
        $GroupId = (Get-ChildItem -Path env:"avTier${Tier}AdminGroupId").Value
    }
    if (Get-ChildItem -Path env:"avTier${Tier}AdminUserPhotoUrl" -ErrorAction SilentlyContinue) {
        if ($UserPhotoUrl) {
            Write-Warning 'Ignored UserPhotoUrl parameter and replaced by environment variable.'
        }
        else {
            Write-Verbose 'Using UserPhotoUrl from environment variable.'
        }
        $UserPhotoUrl = (Get-ChildItem -Path env:"avTier${Tier}AdminUserPhotoUrl").Value
    }
    if (-Not $Webhook -and (Get-ChildItem -Path env:"avTier${Tier}AdminWebhook" -ErrorAction SilentlyContinue)) {
        Write-Verbose 'Using Webhook from environment variable.'
        $Webhook = (Get-ChildItem -Path env:"avTier${Tier}AdminWebhook").Value
    }
}

if ($GroupId -and ($GroupId -notmatch '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$')) {
    Throw "Malformed UUID for GroupId: $GroupId"
}
if ($UserPhotoUrl -and ($UserPhotoUrl -notmatch '^https:\/\/.+(?:\.png|\.jpg|\.jpeg)$')) {
    Throw "Malformed URL for UserPhotoUrl: $UserPhotoUrl"
}
if ($Webhook -and ($Webhook -notmatch '^https:\/\/.+$')) {
    Throw "Malformed URL for Webhook: $Webhook"
}

$MgScopes = @(
    'User.ReadWrite.All'                        # To read and write user information, including EmployeeHireDate
    'Directory.ReadWrite.All'                   # To read and write directory data
    'User.Read.All'                             # To read user information, including EmployeeHireDate
    'Directory.Read.All'                        # To read directory data
    'Organization.Read.All'                     # To read organization data, e.g. licenses
    'OnPremDirectorySynchronization.Read.All'   # To read directory sync data
    'RoleManagement.ReadWrite.Directory'        # To update role-assignable groups
)
$MissingMgScopes = @()
$return = @{}
$groupObj = $null
$refUserObj = $null
$refUserExObj = $null
$existingUserObj = $null
$userObj = $null
$userLicObj = $null
$userExObj = $null
$userExMbObj = $null

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
        Write-Verbose 'Opening connection to Microsoft Graph ...'
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
        Write-Verbose 'Re-authentication to Microsoft Graph for missing scopes ...'
        ResilientRemoteCall { Connect-MgGraph -NoWelcome -Scopes $MgScopes -ContextScope Process }
    }
}

# If connection to Microsoft Graph seems okay
#

if ($GroupId) {
    $groupObj = ResilientRemoteCall {
        Get-MgGroup `
            -GroupId $GroupId `
            -ExpandProperty 'Owners' `
            -ErrorAction SilentlyContinue
    }

    if (-Not $groupObj) {
        Throw "GroupId $($GroupId) does not exist."
    }
    if (-Not $groupObj.SecurityEnabled) {
        Throw "Group $($groupObj.DisplayName) ($($groupObj.Id)): Must be security-enabled to be used for Cloud Administration."
    }
    if ($null -ne $groupObj.OnPremisesSyncEnabled) {
        Throw "Group $($groupObj.DisplayName) ($($groupObj.Id)): Must never be synced from on-premises directory to be used for Cloud Administration."
    }
    if (
        $groupObj.GroupType -and
        ($groupObj.GroupType -contains 'Unified')
    ) {
        Throw "Group $($groupObj.DisplayName) ($($groupObj.Id)): Must not be a Microsoft 365 Group to be used for Cloud Administration."
    }
    if ($groupObj.MailEnabled) {
        Throw "Group $($groupObj.DisplayName) ($($groupObj.Id)): Must not be mail-enabled to be used for Cloud Administration."
    }
    #TODO check for restricted admin unit of group
    if (-Not $groupObj.IsAssignableToRole) {
        Throw "Group $($groupObj.DisplayName) ($($groupObj.Id)): Must be role-enabled or protected by a Restricted Management Administrative Unit to be used for Cloud Administration."
    }
    if ('Private' -ne $groupObj.Visibility) {
        Write-Warning "Group $($groupObj.DisplayName) ($($groupObj.Id)): Correcting visibility to Private for Cloud Administration."
        $null = ResilientRemoteCall {
            Set-MgGroup `
                -GroupId $groupObj.Id `
                -Visibility 'Private'
        }
    }
    #TODO check for assigned roles and remove them
    if ($groupObj.Owners) {
        foreach ($owner in $groupObj.Owners) {
            Write-Warning "Group $($groupObj.DisplayName) ($($groupObj.Id)): Removing unwanted group owner $($owner.Id)"
            $null = ResilientRemoteCall {
                Remove-MgGroupOwnerByRef `
                    -GroupId $groupObj.Id `
                    -DirectoryObjectId $owner.Id
            }
        }
    }

    $GroupDescription = "Tier $Tier Cloud Administrators"
    if (-Not $groupObj.Description) {
        Write-Warning "Group $($groupObj.DisplayName) ($($groupObj.Id)): Adding missing description for Tier $Tier identification"
        $null = ResilientRemoteCall {
            Update-MgGroup -GroupId -Description $GroupDescription
        }
    }
    elseif ($groupObj.Description -ne $GroupDescription) {
        Throw "Group $($groupObj.DisplayName) ($($groupObj.Id)): The description does not clearly identify this group as a Tier $Tier Administrators group. To avoid incorrect group assignments, please check that you are using the correct group. To use this group for Tier $Tier management, set the description property to '$GroupDescription'."
    }
}

$License = ResilientRemoteCall {
    Get-MgSubscribedSku -All | Where-Object SkuPartNumber -eq $LicenseSkuPartNumber | Select-Object -Property Sku*, ConsumedUnits, ServicePlans -ExpandProperty PrepaidUnits
}

if (-Not $License) {
    Throw "License SkuPartNumber $LicenseSkuPartNumber is not available to this tenant."
}

if (-Not ($License.ServicePlans | Where-Object { ($_.AppliesTo -eq 'User') -and ($_.ServicePlanName -Match 'EXCHANGE') })) {
    Throw "License SkuPartNumber $LicenseSkuPartNumber does not contain an Exchange Online service plan."
}

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
    'OnPremisesExtensionAttributes'
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

# If referral user details could be retrieved
#

if (
    ($refUserObj.UserPrincipalName -match '^A[0-9][A-Z][-_].+@.+$') -or # Tiered admin accounts, e.g. A0C_*, A1L-*, etc.
    ($refUserObj.UserPrincipalName -match '^ADM[CL]?[-_].+@.+$') -or # Non-Tiered admin accounts, e.g. ADM_, ADMC-* etc.
    ($refUserObj.UserPrincipalName -match '^.+#EXT#@.+\.onmicrosoft\.com$') -or # External Accounts
    ($refUserObj.UserPrincipalName -match '^(?:SVCC?_.+|SVC[A-Z0-9]+)@.+$') -or # Service Accounts
    ($refUserObj.UserPrincipalName -match '^(?:Sync_.+|[A-Z]+SyncServiceAccount.*)@.+$')  # Entra Sync Accounts
) {
    Write-Error "This type of user name can not have a Cloud Administrator account created."
    exit 1
}

if (($refUserObj.UserPrincipalName).Split('@')[1] -match '^.+\.onmicrosoft\.com$') {
    Write-Error "Referral User ID must not use a onmicrosoft.com subdomain."
    exit 1
}

if (-Not $refUserObj.AccountEnabled) {
    Write-Error 'Referral User ID is disabled. A Cloud Administrator account can only be set up for active accounts.'
    exit 1
}

if ($refUserObj.UserType -ne 'Member') {
    Write-Error 'Referral User ID must be of type Member.'
    exit 1
}

if (
    (-Not $refUserObj.Manager) -or (-Not $refUserObj.Manager.Id)
) {
    Write-Error 'Referral User ID must have manager property set.'
    exit 1
}

$timeNow = Get-Date

if ($null -ne $refUserObj.EmployeeHireDate -and ($timeNow.ToUniversalTime() -lt $refUserObj.EmployeeHireDate)) {
    Write-Error "Referral User ID will start to work at $($refUserObj.EmployeeHireDate | Get-Date -Format 'o') Universal Time. A Cloud Administrator account can only be set up for active employees."
    exit 1
}

if ($null -ne $refUserObj.EmployeeLeaveDateTime -and ($timeNow.ToUniversalTime() -ge $refUserObj.EmployeeLeaveDateTime.AddDays(-45))) {
    Write-Error "Referral User ID is scheduled for deactivation at $($refUserObj.EmployeeLeaveDateTime | Get-Date -Format 'o') Universal Time. A Cloud Administrator account can only be set up a maximum of 45 days before the planned leaving date."
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
    Get-ConnectionInformation | Where-Object Organization -eq $tenantDomain.Name | ForEach-Object { Disconnect-ExchangeOnline -ConnectionId $_.ConnectionId -Confirm:$false -InformationAction SilentlyContinue }
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
    Write-Error "Referral User ID mailbox must be of type UserMailbox. Cloud Administrator accounts can not be created for user mailbox types of $($refUserExObj.RecipientTypeDetails)"
    exit 1
}

$BodyParamsNull = @{
    JobTitle = $null
}
$AdminPrefix = "A${Tier}C"
$BodyParams = @{
    OnPremisesExtensionAttributes = @{
        extensionAttribute1  = $null
        extensionAttribute2  = $null
        extensionAttribute3  = $null
        extensionAttribute4  = $null
        extensionAttribute5  = $null
        extensionAttribute6  = $null
        extensionAttribute7  = $null
        extensionAttribute8  = $null
        extensionAttribute9  = $null
        extensionAttribute10 = $null
        extensionAttribute11 = $null
        extensionAttribute12 = $null
        extensionAttribute13 = $null
        extensionAttribute14 = $null
        extensionAttribute15 = $null
    }
    EmployeeType                  = "Tier $Tier Cloud Administrator"
    UserPrincipalName             = $AdminPrefix + '-' + ($refUserObj.UserPrincipalName).Split('@')[0] + '@' + $tenantDomain.Name
    Mail                          = $AdminPrefix + '-' + ($refUserObj.UserPrincipalName).Split('@')[0] + '@' + $tenantDomain.Name
    MailNickname                  = $AdminPrefix + '-' + $refUserObj.MailNickname
    PasswordProfile               = @{
        Password                             = Get-RandomPassword -lowerChars 32 -upperChars 32 -numbers 32 -symbols 32
        ForceChangePasswordNextSignIn        = $false
        ForceChangePasswordNextSignInWithMfa = $false
    }
    PasswordPolicies              = 'DisablePasswordExpiration'
}
if ([string]::IsNullOrEmpty($refUserObj.OnPremisesExtensionAttributes.extensionAttribute15)) {
    $BodyParams.OnPremisesExtensionAttributes.extensionAttribute15 = $AdminPrefix
}
else {
    $BodyParams.OnPremisesExtensionAttributes.extensionAttribute15 = $AdminPrefix + '__' + $refUserObj.OnPremisesExtensionAttributes.extensionAttribute15
}
if (-Not [string]::IsNullOrEmpty($refUserObj.DisplayName)) {
    $BodyParams.DisplayName = $AdminPrefix + '-' + $refUserObj.DisplayName
}
if (-Not [string]::IsNullOrEmpty($refUserObj.GivenName)) {
    $BodyParams.GivenName = $AdminPrefix + '-' + $refUserObj.GivenName
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
    Invoke-MgGraphRequest `
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
                -SoftDeletedMailbox `
                -ErrorAction SilentlyContinue
        }
        ResilientRemoteCall {
            Invoke-MgGraphRequest `
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

$duplicatesObj = ResilientRemoteCall {
    Get-MgUser `
        -ConsistencyLevel eventual `
        -Count userCount `
        -OrderBy UserPrincipalName `
        -Filter "`
        startsWith(UserPrincipalName, '$(($BodyParams.UserPrincipalName).Split('@')[0])@') or `
        startsWith(Mail, '$(($BodyParams.Mail).Split('@')[0])@') or `
        DisplayName eq '$($BodyParams.DisplayName)' or `
        MailNickname eq '$($BodyParams.MailNickname)' or `
        proxyAddresses/any(x:x eq 'smtp:$($BodyParams.Mail)') `
    "
}
if ($userCount -gt 1) {
    Write-Warning "Admin account $($BodyParams.UserPrincipalName) is not mutually exclusive. $userCount existing accounts found: $( $duplicatesObj.UserPrincipalName )"
}

$existingUserObj = ResilientRemoteCall {
    Get-MgUser `
        -UserId $BodyParams.UserPrincipalName `
        -Property $userProperties `
        -ExpandProperty $userExpandPropeties `
        -ErrorAction SilentlyContinue `
        -Debug:$DebugPreference `
        -Verbose:$false
}

if ($null -ne $existingUserObj) {
    if ($null -ne $existingUserObj.OnPremisesSyncEnabled) {
        Write-Error "Conflicting Admin account $($existingUserObj.UserPrincipalName) ($($existingUserObj.Id)) $( if ($existingUserObj.OnPremisesSyncEnabled) { 'is' } else { 'was' } ) synced from on-premises for referral user $($refUserObj.UserPrincipalName) ($($refUserObj.Id)). Manual deletion of this cloud object is required to resolve this conflict."
        exit 1
    }
    Write-Verbose "Updating account $($existingUserObj.UserPrincipalName) ($($existingUserObj.Id)) with information from $($refUserObj.UserPrincipalName) ($($refUserObj.Id))"
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
        # Workaround as properties cannot be nulled using Update-MgUser at the moment ...
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
    if ($License.ConsumedUnits -ge $License.Enabled) {
        Throw "License SkuPartNumber $LicenseSkuPartNumber has run out of free licenses. Purchase additional licenses to create new Cloud Administrator accounts."
    }

    $userObj = ResilientRemoteCall {
        New-MgUser `
            -BodyParameter $BodyParams `
            -ErrorAction SilentlyContinue `
            -Confirm:$false
    }

    # Wait for user provisioning consistency
    $DoLoop = $true
    $RetryCount = 1
    $MaxRetry = 30
    $WaitSec = 7
    $newUserId = $userObj.Id

    do {
        $userObj = ResilientRemoteCall {
            Get-MgUser `
                -ConsistencyLevel eventual `
                -CountVariable CountVar `
                -Filter "Id eq '$newUserId'" `
                -ErrorAction SilentlyContinue `
                -Debug:$DebugPreference `
                -Verbose:$false
        }
        if ($null -ne $userObj) {
            $DoLoop = $false
        }
        elseif ($RetryCount -ge $MaxRetry) {
            $userObj = ResilientRemoteCall {
                Remove-MgUser `
                    -UserId $newUserId `
                    -ErrorAction SilentlyContinue `
                    -Confirm:$false
            }
            $DoLoop = $false
            Throw "User provisioning consistency timeout: Tier 0 Cloud Administrator account $($userObj.UserPrincipalName) ($($userObj.Id)) was deleted after unfinished provisioning."
        }
        else {
            $RetryCount += 1
            Write-Verbose "Try $RetryCount of ${MaxRetry}: Waiting another $WaitSec seconds for user provisioning consistency ..."
            Start-Sleep -Seconds $WaitSec
        }
    } While ($DoLoop)

    Write-Verbose "Created Tier $Tier Cloud Administrator account $($userObj.UserPrincipalName) ($($userObj.Id)) with information from $($refUserObj.UserPrincipalName) ($($refUserObj.Id))"
}

if ($null -eq $userObj) {
    Write-Error ("Could not create or update Tier $Tier Cloud Administrator account $($BodyParams.UserPrincipalName): " + $Error[0].CategoryInfo.TargetName + ': ' + $Error[0].ToString())
    exit 1
}

if (
    (-Not $existingUserObj) -or
    ($existingUserObj.Manager.Id -ne $refUserObj.Id)
) {
    if ($existingUserObj) {
        Write-Warning "Correcting Manager reference to $($refUserObj.UserPrincipalName) ($($refUserObj.Id))"
    }
    $NewManager = @{
        '@odata.id' = 'https://graph.microsoft.com/v1.0/users/' + $refUserObj.Id
    }
    $null = ResilientRemoteCall {
        Set-MgUserManagerByRef -UserId $userObj.Id -BodyParameter $NewManager
    }
}

$userLicObj = ResilientRemoteCall {
    Get-MgUserLicenseDetail -UserId $userObj.Id
}
if (-Not ($userLicObj | Where-Object SkuPartNumber -eq $LicenseSkuPartNumber)) {
    if ($License.ConsumedUnits -ge $License.Enabled) {
        Throw "License SkuPartNumber $LicenseSkuPartNumber has run out of free licenses. Purchase additional licenses to update $($userObj.UserPrincipalName)."
    }

    if (-Not $groupObj) {
        Write-Verbose "Implying direct license assignment is required as no GroupId was provided for group-based licensing."
        $disabledPlans = $License.ServicePlans | Where-Object { ($_.AppliesTo -eq 'User') -and ($_.ServicePlanName -NotMatch 'EXCHANGE') } | Select-Object -ExpandProperty ServicePlanId
        $addLicenses = @(
            @{
                SkuId         = $License.SkuId
                DisabledPlans = $disabledPlans
            }
        )
        $null = ResilientRemoteCall {
            Set-MgUserLicense `
                -UserId $userObj.Id `
                -AddLicenses $addLicenses `
                -RemoveLicenses @()
        }
    }
}
elseif ($groupObj) {
    #TODO remove any direct license assignment to enforce group-based licensing
}

if ($groupObj) {
    if (
        $groupObj.GroupType -NotContains 'DynamicMembership' -or
        ($groupObj.MembershipRuleProcessingState -ne 'On')
    ) {
        $groupMembership = ResilientRemoteCall {
            Get-MgGroupMember `
                -ConsistencyLevel eventual `
                -GroupId $groupObj.Id `
                -CountVariable CountVar `
                -Filter "Id eq '$($userObj.Id)'"
        }
        if (-Not $groupMembership) {
            Write-Verbose "Implying manually adding user to static group $($groupObj.DisplayName) ($($groupObj.Id))"
            New-MgGroupMember -GroupId $groupObj.Id -DirectoryObjectId $userObj.Id
        }
    }

    # Wait for group membership
    $DoLoop = $true
    $RetryCount = 1
    $MaxRetry = 30
    $WaitSec = 7

    do {
        $groupMembership = ResilientRemoteCall {
            Get-MgGroupMember `
                -ConsistencyLevel eventual `
                -GroupId $groupObj.Id `
                -CountVariable CountVar `
                -Filter "Id eq '$($userObj.Id)'"
        }
        if ($null -ne $groupMembership) {
            $DoLoop = $false
        }
        elseif ($RetryCount -ge $MaxRetry) {
            $userObj = ResilientRemoteCall {
                Remove-MgUser `
                    -UserId $userObj.Id `
                    -ErrorAction SilentlyContinue `
                    -Confirm:$false
            }
            $DoLoop = $false
            Throw "Group assignment timeout: Tier $Tier Cloud Administrator account $($userObj.UserPrincipalName) ($($userObj.Id)) was deleted after unfinished provisioning."
        }
        else {
            $RetryCount += 1
            Write-Verbose "Try $RetryCount of ${MaxRetry}: Waiting another $WaitSec seconds for Exchange license assignment ..."
            Start-Sleep -Seconds $WaitSec
        }
    } While ($DoLoop)
}

# Wait for licenses
$DoLoop = $true
$RetryCount = 1
$MaxRetry = 30
$WaitSec = 7

do {
    $userLicObj = ResilientRemoteCall {
        Get-MgUserLicenseDetail -UserId $userObj.Id
    }
    if (
        ($null -ne $userLicObj) -and
        ($userLicObj.ServicePlans | Where-Object { ($_.AppliesTo -eq 'User') -and ($_.ProvisioningStatus -eq 'Success') -and ($_.ServicePlanName -Match 'EXCHANGE') })
    ) {
        $DoLoop = $false
    }
    elseif ($RetryCount -ge $MaxRetry) {
        $userObj = ResilientRemoteCall {
            Remove-MgUser `
                -UserId $userObj.Id `
                -ErrorAction SilentlyContinue `
                -Confirm:$false
        }
        $DoLoop = $false
        Throw "License assignment timeout: Tier $Tier Cloud Administrator account $($userObj.UserPrincipalName) ($($userObj.Id)) was deleted after unfinished provisioning."
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
        $userObj = ResilientRemoteCall {
            Remove-MgUser `
                -UserId $userObj.Id `
                -ErrorAction SilentlyContinue `
                -Confirm:$false
        }
        $DoLoop = $false
        Throw "Mailbox creation timeout: Tier $Tier Cloud Administrator account $($userObj.UserPrincipalName) ($($userObj.Id)) was deleted after unfinished provisioning."
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

if ($UserPhotoUrl) {
    Write-Verbose "Retrieving user photo from URL '$($UserPhotoUrl)'"
    $null = Invoke-WebRequest `
        -UseBasicParsing `
        -Method GET `
        -Uri $UserPhotoUrl `
        -TimeoutSec 3 `
        -RetryIntervalSec 5 `
        -MaximumRetryCount 3 `
        -ErrorAction SilentlyContinue `
        -OutVariable UserPhoto
    if (
        (-Not $UserPhoto) -or
        ($UserPhoto.StatusCode -ne 200) -or
        (-Not $UserPhoto.Content)
    ) {
        Write-Warning "Unable to download photo from URL '$($UserPhotoUrl)'"
    }
    elseif (
        ($UserPhoto.Headers.'Content-Type' -ne 'image/png') -and
        ($UserPhoto.Headers.'Content-Type' -ne 'image/jpeg')
    ) {
        Write-Warning "Photo from URL '$($UserPhotoUrl)' must have Content-Type 'image/png' or 'image/jpeg'."
    }
    else {
        Write-Verbose 'Updating user photo'
        $null = ResilientRemoteCall {
            Set-MgUserPhotoContent `
                -InFile nonExistat.lat `
                -UserId $userObj.Id `
                -Data ([System.IO.MemoryStream]::new($UserPhoto.Content))
        }
    }
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
