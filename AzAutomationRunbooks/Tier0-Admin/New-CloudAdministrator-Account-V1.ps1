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


    CUSTOM CONFIGURATION SETTINGS
    =============================

    Variables for custom configuration settings, either from $env:<VariableName>,
    or Azure Automation Account Variables, whose will automatically be published in $env.

    .Variable AV_Tier<Tier>Admin_UserPhotoUrl - [String]
        Default value for script parameter UserPhotoUrl. If no parameter was provided, this value will be used instead.

    .VARIABLE AV_Tier<Tier>Admin_LicenseSkuPartNumber - [String]
        License assigned to the user. The license SkuPartNumber must contain an Exchange Online service plan to generate a mailbox for the user (see https://learn.microsoft.com/en-us/entra/identity/users/licensing-service-plan-reference).
        If avTier<Tier>AdminGroupId is also provided, group-based licensing is implied and license assignment will only be monitored before continuing.
        This parameter has a default value for Exchange Online Kiosk license (SkuPartNumber EXCHANGEDESKLESS) and only Exchange license plan will be enabled in it.

    .VARIABLE AV_Tier<Tier>Admin_GroupId - [String]
        Entra Group Object ID where the user shall be added. If the group is dynamic, group membership update will only be monitored before continuing.

    .VARIABLE AV_Tier<Tier>Admin_Webhook - [String]
        Send return data in JSON format as POST to this webhook URL.

    Please note that <Tier> in the variable name must be replaced by the intended Tier level 0, 1, or 2.
    For example:

        AV_Tier0Admin_GroupId
        AV_Tier1Admin_GroupId
        AV_Tier2Admin_GroupId

.PARAMETER ReferralUserId
    User account identifier of the existing main user account. May be an Entra Identity Object ID or User Principal Name (UPN).

.PARAMETER Tier
    The Tier level where the Cloud Administrator account shall be created.

.PARAMETER UserPhotoUrl
    URL of an image that shall be set as default photo for the user. Must use HTTPS protocol, end with .jpg/.jpeg/.png, and use image/* as Content-Type in HTTP return header.
    If environment variable $env:AV_Tier<Tier>Admin_UserPhotoUrl is set, it will be used as a fallback option.
    In case no photo URL was provided at all, Entra square logo from organizational tenant branding will be used.

.PARAMETER OutputJson
    Output the result in JSON format.
    This is automatically implied when running in Azure Automation and no Webhook parameter was set.

.PARAMETER OutputText
    Output the generated User Principal Name only.

.NOTES
    Original name: New-CloudAdministrator-Account-V1.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
    Version: 0.0.1
#>

#Requires -Version 5.1
#Requires -Modules @{ ModuleName='Az.Accounts'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Az.Resources'; ModuleVersion='6.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Authentication'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Identity.SignIns'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Identity.DirectoryManagement'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Users'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Groups'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Applications'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='ExchangeOnlineManagement'; ModuleVersion='3.0' }

#region TODO:
#- add Git revision to .NOTES section during git commit
#-admin prefix separator as variable
#- research if Desired State Provisioning could be used?
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
#- Install PowerShell modules what are mentioned as "requires" but do not update existing ones, just to support the initial run of the script
#endregion

[CmdletBinding(
    SupportsShouldProcess,
    ConfirmImpact = 'Medium',
    DefaultParameterSetName = 'HashtableOutput'
)]
[OutputType([Hashtable], ParameterSetName = 'HashtableOutput')]
[OutputType([String], ParameterSetName = 'JsonOutput')]
[OutputType([String], ParameterSetName = 'TextOutput')]
Param (
    [Parameter(ParameterSetName = 'HashtableOutput', Position = 0, mandatory = $true, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
    [Parameter(ParameterSetName = 'StringOutput', Position = 0, mandatory = $true, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
    [Parameter(ParameterSetName = 'TextOutput', Position = 0, mandatory = $true, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
    [String]$ReferralUserId,

    [Parameter(ParameterSetName = 'HashtableOutput', Position = 1, mandatory = $true, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
    [Parameter(ParameterSetName = 'StringOutput', Position = 1, mandatory = $true, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
    [Parameter(ParameterSetName = 'TextOutput', Position = 1, mandatory = $true, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
    [String]$Tier,

    [Parameter(ParameterSetName = 'HashtableOutput', Position = 2, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
    [Parameter(ParameterSetName = 'StringOutput', Position = 2, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
    [Parameter(ParameterSetName = 'TextOutput', Position = 2, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
    [AllowEmptyString()]
    [String]$UserPhotoUrl,

    [parameter(ParameterSetName = 'StringOutput')]
    [Boolean]$OutJson,

    [parameter(ParameterSetName = 'TextOutput')]
    [Boolean]$OutText
)

Begin {
    #region [COMMON] SCRIPT CONFIGURATION PARAMETERS -------------------------------
    $ConfigurationVariables = @(
        @{
            sourceName             = "AV_Tier${Tier}Admin_LicenseSkuPartNumber"
            respectScriptParameter = $null
            mapToVariable          = 'LicenseSkuPartNumber'
            defaultValue           = 'EXCHANGEDESKLESS'
            Regex                  = '^[A-Z][A-Z_]+[A-Z]$'
        }
        @{
            sourceName             = "AV_Tier${Tier}Admin_GroupId"
            respectScriptParameter = $null
            mapToVariable          = 'GroupId'
            defaultValue           = $null
            Regex                  = '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$'
        }
        @{
            sourceName             = "AV_Tier${Tier}Admin_UserPhotoUrl"
            respectScriptParameter = 'UserPhotoUrl'
            mapToVariable          = 'PhotoUrl'
            defaultValue           = $null
            Regex                  = '^https:\/\/.+(?:\.png|\.jpg|\.jpeg|\?.+)$'
        }
        @{
            sourceName             = "AV_Tier${Tier}Admin_Webhook"
            respectScriptParameter = $null
            mapToVariable          = 'Webhook'
            defaultValue           = $null
            Regex                  = '^https:\/\/.+$'
        }
    )

    $MgGraphScopes = @(
        'User.ReadWrite.All'
        'Directory.Read.All'
        'Group.ReadWrite.All'
        'Organization.Read.All'
        'OnPremDirectorySynchronization.Read.All'
        'Mail.Send'
    )

    $MgGraphDirectoryRoles = @(
        @{
            DisplayName = 'Exchange Recipient Administrator'
            TemplateId  = '31392ffb-586c-42d1-9346-e59415a2cc4e'
        }
        @{
            DisplayName = 'Group Administrator'
            TemplateId  = 'fdd7a751-b60b-444a-984c-02652fe8fa1c'
        }
        @{
            DisplayName = 'License Administrator'
            TemplateId  = '4d6ac14f-3453-41d0-bef9-a3e0c569773a'
        }
        @{
            DisplayName = 'User Administrator'
            TemplateId  = 'fe930be7-5e62-47db-91af-98c3a49a38b1'
        }

        # # Only required if group is role-enabled
        # @{
        #     DisplayName = 'Privileged Role Administrator'
        #     TemplateId  = 'e8611ab8-c189-46e8-94e1-60213ab1f814'
        # }
    )

    $MgAppPermissions = @(
        @{
            DisplayName = 'Office 365 Exchange Online'
            AppId       = '00000002-0000-0ff1-ce00-000000000000'
            AppRoles    = @(
                'Exchange.ManageAsApp'
            )
            # Oauth2PermissionScopes = @{
            #     Admin = @(
            #     )
            #     '<User-ObjectId>' = @(
            #     )
            # }
        }
    )
    #endregion ---------------------------------------------------------------------

    #region [COMMON] INFORMATION OUTPUT FOR INTERACTIVE SESSIONS -------------------
    $origInformationPreference = $InformationPreference
    if (
        (-not $env:AZUREPS_HOST_ENVIRONMENT) -and
        (-not $PSPrivateMetadata.JobId)
    ) {
        $InformationPreference = 'Continue'
    }
    #endregion ---------------------------------------------------------------------

    #region [COMMON] ENVIRONMENT ---------------------------------------------------
    ./Common__0001_Add-AzAutomationVariableToPSEnv.ps1
    ./Common__0000_Convert-PSEnvToPSLocalVariable.ps1 -Variable $ConfigurationVariables
    #endregion ---------------------------------------------------------------------

    #region [COMMON] OPEN PERSISTENT CONNECTIONS -----------------------------------
    # Microsoft Graph connection
    ./Common__0000_Connect-MgGraph.ps1 -Scopes $MGGRAPHSCOPES
    $tenant = Get-MgOrganization -OrganizationId (Get-MgContext).TenantId
    $tenantDomain = $tenant.VerifiedDomains | Where-Object IsInitial -eq true
    $tenantBranding = Get-MgOrganizationBranding -OrganizationId $tenant.Id

    # Confirm required Microsoft Graph directory roles
    ./Common__0001_Confirm-MgDirectoryRoleActiveAssignment.ps1 -Roles $MgGraphDirectoryRoles 1> $null

    # Confirm required permissions for other app besides Microsoft Graph
    ./Common__0001_Confirm-MgAppPermission.ps1 -Permissions $MgAppPermissions 1> $null

    # Exchange Online connection
    ./Common__0000_Connect-ExchangeOnline.ps1 -Organization $tenantDomain.Name
    #endregion ---------------------------------------------------------------------

    #region [COMMON] INITIALIZE SCRIPT VARIABLES -----------------------------------
    $return = @{
        Information = @()
        Warning     = @()
        Error       = @()
    }
    $persistentError = $false
    $Iteration = 0
    #endregion ---------------------------------------------------------------------

    #region Group Validation -------------------------------------------------------
    $groupObj = $null
    if ($GroupId) {
        $groupObj = Get-MgBetaGroup `
            -GroupId $GroupId `
            -ExpandProperty Owners `
            -ErrorAction SilentlyContinue

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
        if (
            (-Not $groupObj.IsManagementRestricted) -and
            (-Not $groupObj.IsAssignableToRole)
        ) {
            Throw "Group $($groupObj.DisplayName) ($($groupObj.Id)): Must be protected by a Restricted Management Administrative Unit (preferred), or at least role-enabled to be used for Cloud Administration. (IsMemberManagementRestricted = $($groupObj.IsManagementRestricted), IsAssignableToRole = $($groupObj.IsAssignableToRole))"
        }
        elseif ($groupObj.IsAssignableToRole) {
            ./Common__0001_Confirm-MgDirectoryRoleActiveAssignment.ps1 -WarningAction SilentlyContinue -Roles @(
                @{
                    DisplayName = 'Privileged Role Administrator'
                    TemplateId  = 'e8611ab8-c189-46e8-94e1-60213ab1f814'
                }
            ) 1> $null
        }
        if ('Private' -ne $groupObj.Visibility) {
            Write-Warning "Group $($groupObj.DisplayName) ($($groupObj.Id)): Correcting visibility to Private for Cloud Administration."
            Update-MgBetaGroup `
                -GroupId $groupObj.Id `
                -Visibility 'Private' `
                1> $null
        }
        #TODO check for assigned roles and remove them
        if ($groupObj.Owners) {
            foreach ($owner in $groupObj.Owners) {
                Write-Warning "Group $($groupObj.DisplayName) ($($groupObj.Id)): Removing unwanted group owner $($owner.Id)"
                Remove-MgGroupOwnerByRef `
                    -GroupId $groupObj.Id `
                    -DirectoryObjectId $owner.Id `
                    1> $null
            }
        }

        $GroupDescription = "Tier $Tier Cloud Administrators"
        if (-Not $groupObj.Description) {
            Write-Warning "Group $($groupObj.DisplayName) ($($groupObj.Id)): Adding missing description for Tier $Tier identification"
            Update-MgGroup -GroupId -Description $GroupDescription 1> $null
        }
        elseif ($groupObj.Description -ne $GroupDescription) {
            Throw "Group $($groupObj.DisplayName) ($($groupObj.Id)): The description does not clearly identify this group as a Tier $Tier Administrators group. To avoid incorrect group assignments, please check that you are using the correct group. To use this group for Tier $Tier management, set the description property to '$GroupDescription'."
        }
    }
    #endregion ---------------------------------------------------------------------

    #region License Existance Validation -------------------------------------------
    $License = Get-MgSubscribedSku -All | Where-Object SkuPartNumber -eq $LicenseSkuPartNumber | Select-Object -Property Sku*, ServicePlans

    if (-Not $License) {
        Throw "License SkuPartNumber $LicenseSkuPartNumber is not available to this tenant."
    }

    if (-Not ($License.ServicePlans | Where-Object -FilterScript { ($_.AppliesTo -eq 'User') -and ($_.ServicePlanName -Match 'EXCHANGE') })) {
        Throw "License SkuPartNumber $LicenseSkuPartNumber does not contain an Exchange Online service plan."
    }
    #endregion ---------------------------------------------------------------------
}

Process {
    #region [COMMON] PS PIPELINE LOOP HANDLING -------------------------------------
    # Only process items if there was no error in Begin{} section
    if (($Iteration -eq 0) -and ($return.Error.Count -gt 0)) { $persistentError = $true }
    if ($persistentError) { return }
    $Iteration++
    #endregion ---------------------------------------------------------------------

    #region [COMMON] PARAMETER VALIDATION FOR AZURE AUTOMATION ---------------------
    $regex = '^(?:.+@.{3,}\..{2,}|[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12})$'
    if ($ReferralUserId -notmatch $regex) {
        $return.Error += ./Common__0000_Write-Error.ps1 @{
            Message           = "${ReferralUserId}: ReferralUserId is invalid"
            ErrorId           = '400'
            Category          = 'SyntaxError'
            TargetName        = $ReferralUserId
            TargetObject      = $null
            TargetType        = 'User'
            RecommendedAction = 'Provide either User Principal Name, or Object ID (UUID).'
            CategoryActivity  = 'ReferralUserId parameter validation'
            CategoryReason    = "Parameter ReferralUserId does not match $regex"
        }
        return
    }
    $regex = '^[0-2]$'
    if ($Tier -notmatch $regex) {
        $return.Error += ./Common__0000_Write-Error.ps1 @{
            Message           = "${ReferralUserId}: Tier $Tier is invalid"
            ErrorId           = '400'
            Category          = 'SyntaxError'
            TargetName        = $ReferralUserId
            TargetObject      = $null
            TargetType        = 'User'
            RecommendedAction = 'Provide a Tier level of 0, 1, or 2.'
            CategoryActivity  = 'Tier parameter validation'
            CategoryReason    = "Parameter Tier does not match $regex"
        }
        return
    }
    $regex = '(?:^https:\/\/.+(?:\.png|\.jpg|\.jpeg|\?.+)$|^$)'
    if ($UserPhotoUrl -notmatch $regex) {
        $return.Error += ./Common__0000_Write-Error.ps1 @{
            Message           = "${ReferralUserId}: UserPhotoUrl $UserPhotoUrl is invalid"
            ErrorId           = '400'
            Category          = 'SyntaxError'
            TargetName        = $ReferralUserId
            TargetObject      = $null
            TargetType        = 'User'
            RecommendedAction = 'Please correct the URL format for paramter UserPhotoUrl.'
            CategoryActivity  = 'UserPhotoUrl parameter validation'
            CategoryReason    = "Parameter UserId does not match $regex"
        }
        return
    }
    #endregion ---------------------------------------------------------------------

    #region Referral User Validation -----------------------------------------------
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

    $refUserObj = Get-MgUser `
        -UserId $ReferralUserId `
        -Property $userProperties `
        -ExpandProperty $userExpandPropeties `
        -ErrorAction SilentlyContinue

    if ($null -eq $refUserObj) {
        $return.Error += ./Common__0000_Write-Error.ps1 @{
            Message           = "${ReferralUserId}: Referral User ID does not exist in directory."
            ErrorId           = '404'
            Category          = 'ObjectNotFound'
            TargetName        = $ReferralUserId
            TargetObject      = $null
            TargetType        = 'User'
            RecommendedAction = 'Provide an existing User Principal Name, or Object ID (UUID).'
            CategoryActivity  = 'ReferralUserId user validation'
            CategoryReason    = 'Referral User ID does not exist in directory.'
        }
        return
    }

    if (
    ($refUserObj.UserPrincipalName -match '^A[0-9][A-Z][-_].+@.+$') -or # Tiered admin accounts, e.g. A0C_*, A1L-*, etc.
    ($refUserObj.UserPrincipalName -match '^ADM[CL]?[-_].+@.+$') -or # Non-Tiered admin accounts, e.g. ADM_, ADMC-* etc.
    ($refUserObj.UserPrincipalName -match '^.+#EXT#@.+\.onmicrosoft\.com$') -or # External Accounts
    ($refUserObj.UserPrincipalName -match '^(?:SVCC?_.+|SVC[A-Z0-9]+)@.+$') -or # Service Accounts
    ($refUserObj.UserPrincipalName -match '^(?:Sync_.+|[A-Z]+SyncServiceAccount.*)@.+$')  # Entra Sync Accounts
    ) {
        $return.Error += ./Common__0000_Write-Error.ps1 @{
            Message          = "${ReferralUserId}: This type of user name can not have a Cloud Administrator account created."
            ErrorId          = '403'
            Category         = 'PermissionDenied'
            TargetName       = $refUserObj.UserPrincipalName
            TargetObject     = $refUserObj.Id
            TargetType       = 'User'
            CategoryActivity = 'ReferralUserId user validation'
            CategoryReason   = 'Referral User ID is listed as not capable of having a Cloud Administrator account.'
        }
        return
    }

    if (($refUserObj.UserPrincipalName).Split('@')[1] -match '^.+\.onmicrosoft\.com$') {
        $return.Error += ./Common__0000_Write-Error.ps1 @{
            Message          = "${ReferralUserId}: Referral User ID must not use a onmicrosoft.com subdomain."
            ErrorId          = '403'
            Category         = 'PermissionDenied'
            TargetName       = $refUserObj.UserPrincipalName
            TargetObject     = $refUserObj.Id
            TargetType       = 'User'
            CategoryActivity = 'ReferralUserId user validation'
            CategoryReason   = 'Referral User ID must not use a onmicrosoft.com subdomain.'
        }
        return
    }

    if (-Not $refUserObj.AccountEnabled) {
        $return.Error += ./Common__0000_Write-Error.ps1 @{
            Message          = "${ReferralUserId}: Referral User ID is disabled. A Cloud Administrator account can only be set up for active accounts."
            ErrorId          = '403'
            Category         = 'NotEnabled'
            TargetName       = $refUserObj.UserPrincipalName
            TargetObject     = $refUserObj.Id
            TargetType       = 'User'
            CategoryActivity = 'ReferralUserId user validation'
            CategoryReason   = 'Referral User ID is disabled. A Cloud Administrator account can only be set up for active accounts.'
        }
        return
    }

    if ($refUserObj.UserType -ne 'Member') {
        $return.Error += ./Common__0000_Write-Error.ps1 @{
            Message          = "${ReferralUserId}: Referral User ID must be of type Member."
            ErrorId          = '403'
            Category         = 'InvalidType'
            TargetName       = $refUserObj.UserPrincipalName
            TargetObject     = $refUserObj.Id
            TargetType       = 'User'
            CategoryActivity = 'ReferralUserId user validation'
            CategoryReason   = 'Referral User ID is disabled. A Cloud Administrator account can only be set up for active accounts.'
        }
        return
    }

    if (
    (-Not $refUserObj.Manager) -or
    (-Not $refUserObj.Manager.Id)
    ) {
        $return.Error += ./Common__0000_Write-Error.ps1 @{
            Message          = "${ReferralUserId}: Referral User ID must have manager property set."
            ErrorId          = '403'
            Category         = 'ResourceUnavailable'
            TargetName       = $refUserObj.UserPrincipalName
            TargetObject     = $refUserObj.Id
            TargetType       = 'User'
            CategoryActivity = 'ReferralUserId user validation'
            CategoryReason   = 'Referral User ID must have manager property set.'
        }
        return
    }

    $timeNow = Get-Date

    if (
    ($null -ne $refUserObj.EmployeeHireDate) -and
    ($timeNow.ToUniversalTime() -lt $refUserObj.EmployeeHireDate)
    ) {
        $return.Error += ./Common__0000_Write-Error.ps1 @{
            Message          = "${ReferralUserId}: Referral User ID will start to work at $($refUserObj.EmployeeHireDate | Get-Date -Format 'o') Universal Time. A Cloud Administrator account can only be set up for active employees."
            ErrorId          = '403'
            Category         = 'ResourceUnavailable'
            TargetName       = $refUserObj.UserPrincipalName
            TargetObject     = $refUserObj.Id
            TargetType       = 'User'
            CategoryActivity = 'ReferralUserId user validation'
            CategoryReason   = "Referral User ID will start to work at $($refUserObj.EmployeeHireDate | Get-Date -Format 'o') Universal Time. A Cloud Administrator account can only be set up for active employees."
        }
        return
    }

    if (
    ($null -ne $refUserObj.EmployeeLeaveDateTime) -and
    ($timeNow.ToUniversalTime() -ge $refUserObj.EmployeeLeaveDateTime.AddDays(-45))
    ) {
        $return.Error += ./Common__0000_Write-Error.ps1 @{
            Message          = "${ReferralUserId}: Referral User ID is scheduled for deactivation at $($refUserObj.EmployeeLeaveDateTime | Get-Date -Format 'o') Universal Time. A Cloud Administrator account can only be set up a maximum of 45 days before the planned leaving date."
            ErrorId          = '403'
            Category         = 'OperationStopped'
            TargetName       = $refUserObj.UserPrincipalName
            TargetObject     = $refUserObj.Id
            TargetType       = 'User'
            CategoryActivity = 'ReferralUserId user validation'
            CategoryReason   = "Referral User ID is scheduled for deactivation at $($refUserObj.EmployeeLeaveDateTime | Get-Date -Format 'o') Universal Time. A Cloud Administrator account can only be set up a maximum of 45 days before the planned leaving date."
        }
        return
    }

    $tenant = Get-MgOrganization
    $tenantDomain = $tenant.VerifiedDomains | Where-Object IsInitial -eq true

    if ($true -eq $tenant.OnPremisesSyncEnabled -and ($true -ne $refUserObj.OnPremisesSyncEnabled)) {
        $return.Error += ./Common__0000_Write-Error.ps1 @{
            Message          = "${ReferralUserId}: Referral User ID must be a hybrid identity synced from on-premises directory."
            ErrorId          = '403'
            Category         = 'InvalidType'
            TargetName       = $refUserObj.UserPrincipalName
            TargetObject     = $refUserObj.Id
            TargetType       = 'User'
            CategoryActivity = 'ReferralUserId user validation'
            CategoryReason   = "Referral User ID must be a hybrid identity synced from on-premises directory."
        }
        return
    }

    $refUserExObj = Get-EXOMailbox `
        -UserPrincipalName $refUserObj.UserPrincipalName `
        -ErrorAction SilentlyContinue

    if ($null -eq $refUserExObj) {
        $return.Error += ./Common__0000_Write-Error.ps1 @{
            Message          = "${ReferralUserId}: Referral User ID must have a mailbox."
            ErrorId          = '403'
            Category         = 'NotEnabled'
            TargetName       = $refUserObj.UserPrincipalName
            TargetObject     = $refUserObj.Id
            TargetType       = 'User'
            CategoryActivity = 'ReferralUserId user validation'
            CategoryReason   = "Referral User ID must have a mailbox."
        }
        return
    }

    if ('UserMailbox' -ne $refUserExObj.RecipientType -or 'UserMailbox' -ne $refUserExObj.RecipientTypeDetails) {
        $return.Error += ./Common__0000_Write-Error.ps1 @{
            Message          = "${ReferralUserId}: Referral User ID mailbox must be of type UserMailbox. Cloud Administrator accounts can not be created for user mailbox types of $($refUserExObj.RecipientTypeDetails)"
            ErrorId          = '403'
            Category         = 'InvalidType'
            TargetName       = $refUserObj.UserPrincipalName
            TargetObject     = $refUserObj.Id
            TargetType       = 'User'
            CategoryActivity = 'ReferralUserId user validation'
            CategoryReason   = "Referral User ID mailbox must be of type UserMailbox. Cloud Administrator accounts can not be created for user mailbox types of $($refUserExObj.RecipientTypeDetails)"
        }
        return
    }
    #endregion ---------------------------------------------------------------------

    #region Prepare New User Account Properties ------------------------------------
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
            Password                             = ./Common__0000_Get-RandomPassword.ps1 -lowerChars 32 -upperChars 32 -numbers 32 -symbols 32
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
    if ([string]::IsNullOrEmpty($BodyParams.UsageLocation) -and -not $groupObj) {
        $BodyParams.UsageLocation = if ($tenant.DefaultUsageLocation) {
            $tenant.DefaultUsageLocation
        }
        else {
            $tenant.CountryLetterCode
        }
    }
    #endregion ---------------------------------------------------------------------

    #region Cleanup Soft-Deleted User Accounts -------------------------------------
    $deletedUserList = Invoke-MgGraphRequest `
        -OutputType PSObject `
        -Method GET `
        -Headers @{ 'ConsistencyLevel' = 'eventual' } `
        -Uri "https://graph.microsoft.com/beta/directory/deletedItems/microsoft.graph.user?`$count=true&`$filter=endsWith(UserPrincipalName,'$($BodyParams.UserPrincipalName)')"

    if ($deletedUserList.'@odata.count' -gt 0) {
        foreach ($deletedUserObj in $deletedUserList.Value) {
            $return.Warning += ./Common__0000_Write-Warning.ps1 @{
                Message          = "${ReferralUserId}: Soft-deleted admin account $($deletedUserObj.UserPrincipalName) ($($deletedUserObj.Id)) was permanently deleted before re-creation."
                ErrorId          = '205'
                Category         = 'ResourceExists'
                TargetName       = $refUserObj.UserPrincipalName
                TargetObject     = $refUserObj.Id
                TargetType       = 'User'
                CategoryActivity = 'Account Provisioning'
                CategoryReason   = "An existing admin account was deleted before."
            }

            Invoke-MgGraphRequest `
                -OutputType PSObject `
                -Method DELETE `
                -Uri "https://graph.microsoft.com/beta/directory/deletedItems/$($deletedUserObj.Id)"
        }
    }
    #endregion ---------------------------------------------------------------------

    #region User Account Compliance Check -----------------------------------------
    $duplicatesObj = Get-MgUser `
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
    if ($userCount -gt 1) {
        Write-Warning "Admin account $($BodyParams.UserPrincipalName) is not mutually exclusive. $userCount existing accounts found: $( $duplicatesObj.UserPrincipalName )"

        $return.Warning += ./Common__0000_Write-Warning.ps1 @{
            Message           = "${ReferralUserId}: Admin account must be mutually exclusive."
            ErrorId           = '103'
            Category          = 'ResourceExists'
            TargetName        = $refUserObj.UserPrincipalName
            TargetObject      = $refUserObj.Id
            TargetType        = 'User'
            RecommendedAction = "Delete conflicting administration account to comply with corporate compliance policy: $($duplicatesObj.UserPrincipalName)"
            CategoryActivity  = 'Account Compliance'
            CategoryReason    = "Other accounts were found using the same namespace."
        }
    }
    #endregion ---------------------------------------------------------------------

    #region Create or Update User Account ------------------------------------------
    $existingUserObj = Get-MgUser `
        -UserId $BodyParams.UserPrincipalName `
        -Property $userProperties `
        -ExpandProperty $userExpandPropeties `
        -ErrorAction SilentlyContinue

    $userObj = $null
    $License = $null
    if ($null -ne $existingUserObj) {
        if ($null -ne $existingUserObj.OnPremisesSyncEnabled) {
            $return.Error += ./Common__0000_Write-Error.ps1 @{
                Message           = "${ReferralUserId}: Conflicting Admin account $($existingUserObj.UserPrincipalName) ($($existingUserObj.Id)) $( if ($existingUserObj.OnPremisesSyncEnabled) { 'is' } else { 'was' } ) synced from on-premises."
                ErrorId           = '500'
                Category          = 'ResourceExists'
                TargetName        = $refUserObj.UserPrincipalName
                TargetObject      = $refUserObj.Id
                TargetType        = 'User'
                RecommendedAction = 'Manual deletion of this cloud object is required to resolve this conflict.'
                CategoryActivity  = 'Cloud Administrator Creation'
                CategoryReason    = "Conflicting Admin account $($existingUserObj.UserPrincipalName) ($($existingUserObj.Id)) $( if ($existingUserObj.OnPremisesSyncEnabled) { 'is' } else { 'was' } ) synced from on-premises."
            }
            return
        }
        Write-Verbose "Updating account $($existingUserObj.UserPrincipalName) ($($existingUserObj.Id)) with information from $($refUserObj.UserPrincipalName) ($($refUserObj.Id))"
        $BodyParams.Remove('UserPrincipalName')
        $BodyParams.Remove('AccountEnabled')
        $BodyParams.Remove('PasswordProfile')
        Update-MgUser `
            -UserId $existingUserObj.Id `
            -BodyParameter $BodyParams `
            -Confirm:$false `
            1> $null
        if ($BodyParamsNull.Count -gt 0) {
            # Workaround as properties cannot be nulled using Update-MgUser at the moment ...
            Invoke-MgGraphRequest `
                -OutputType PSObject `
                -Method PATCH `
                -Uri "https://graph.microsoft.com/v1.0/users/$($existingUserObj.Id)" `
                -Body $BodyParamsNull `
                1> $null
        }
        $userObj = Get-MgUser `
            -UserId $existingUserObj.Id `
            -ErrorAction SilentlyContinue
    }
    else {
        #region License Availability Validation ----------------------------------------
        $License = Get-MgSubscribedSku -All | Where-Object SkuPartNumber -eq $LicenseSkuPartNumber | Select-Object -Property Sku*, ConsumedUnits, ServicePlans -ExpandProperty PrepaidUnits
        if ($License.ConsumedUnits -ge $License.Enabled) {
            $return.Error += ./Common__0000_Write-Error.ps1 @{
                Message           = "${ReferralUserId}: License SkuPartNumber $LicenseSkuPartNumber has run out of free licenses."
                ErrorId           = '503'
                Category          = 'LimitsExceeded'
                TargetName        = $refUserObj.UserPrincipalName
                TargetObject      = $refUserObj.Id
                TargetType        = 'User'
                RecommendedAction = 'Purchase additional licenses to create new Cloud Administrator accounts.'
                CategoryActivity  = 'License Availability Validation'
                CategoryReason    = "License SkuPartNumber $LicenseSkuPartNumber has run out of free licenses."
            }
            $persistentError = $true
            return
        }
        #endregion ---------------------------------------------------------------------

        $userObj = New-MgUser `
            -BodyParameter $BodyParams `
            -ErrorAction SilentlyContinue `
            -Confirm:$false

        # Wait for user provisioning consistency
        $DoLoop = $true
        $RetryCount = 1
        $MaxRetry = 30
        $WaitSec = 7
        $newUser = $userObj

        do {
            $userObj = Get-MgUser `
                -ConsistencyLevel eventual `
                -CountVariable CountVar `
                -Filter "Id eq '$($newUser.Id)'" `
                -ErrorAction SilentlyContinue
            if ($null -ne $userObj) {
                $DoLoop = $false
            }
            elseif ($RetryCount -ge $MaxRetry) {
                Remove-MgUser `
                    -UserId $newUser.Id `
                    -ErrorAction SilentlyContinue `
                    -Confirm:$false `
                    1> $null
                $DoLoop = $false

                $return.Error += ./Common__0000_Write-Error.ps1 @{
                    Message           = "${ReferralUserId}: Account provisioning consistency timeout for $($newUser.UserPrincipalName)."
                    ErrorId           = '504'
                    Category          = 'OperationTimeout'
                    TargetName        = $refUserObj.UserPrincipalName
                    TargetObject      = $refUserObj.Id
                    TargetType        = 'User'
                    RecommendedAction = 'Try again later.'
                    CategoryActivity  = 'Account Provisioning'
                    CategoryReason    = "A timeout occured during provisioning wait after account creation."
                }
                return
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
        $return.Error += ./Common__0000_Write-Error.ps1 @{
            Message          = "${ReferralUserId}: Could not create or update Tier $Tier Cloud Administrator account $($BodyParams.UserPrincipalName): $($Error[0].Message)"
            ErrorId          = '503'
            Category         = 'NotSpecified'
            TargetName       = "$($refUserObj.UserPrincipalName): $($Error[0].CategoryInfo.TargetName)"
            TargetObject     = $refUserObj.Id
            TargetType       = 'User'
            CategoryActivity = $Error[0].CategoryInfo.Activity
            CategoryReason   = $Error[0].CategoryInfo.Reason
        }
        return
    }
    #endregion ---------------------------------------------------------------------

    #region Update Manager Reference -----------------------------------------------
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
        Set-MgUserManagerByRef -UserId $userObj.Id -BodyParameter $NewManager 1> $null
    }
    #endregion ---------------------------------------------------------------------

    #region License Availability Validation ----------------------------------------
    if (-Not $License) {
        $License = Get-MgSubscribedSku -All | Where-Object SkuPartNumber -eq $LicenseSkuPartNumber | Select-Object -Property Sku*, ConsumedUnits, ServicePlans -ExpandProperty PrepaidUnits
        if ($License.ConsumedUnits -ge $License.Enabled) {
            $return.Error += ./Common__0000_Write-Error.ps1 @{
                Message           = "${ReferralUserId}: License SkuPartNumber $LicenseSkuPartNumber has run out of free licenses."
                ErrorId           = '503'
                Category          = 'LimitsExceeded'
                TargetName        = $refUserObj.UserPrincipalName
                TargetObject      = $refUserObj.Id
                TargetType        = 'User'
                RecommendedAction = 'Purchase additional licenses to create new Cloud Administrator accounts.'
                CategoryActivity  = 'License Availability Validation'
                CategoryReason    = "License SkuPartNumber $LicenseSkuPartNumber has run out of free licenses."
            }
            $persistentError = $true
            return
        }
    }
    #endregion ---------------------------------------------------------------------

    #region Direct License Assignment ----------------------------------------------
    $userLicObj = Get-MgUserLicenseDetail -UserId $userObj.Id
    if ($groupObj) {
        #TODO remove any direct license assignment to enforce group-based licensing
    }
    elseif (-Not ($userLicObj | Where-Object SkuPartNumber -eq $LicenseSkuPartNumber)) {
        Write-Verbose "Implying direct license assignment is required as no GroupId was provided for group-based licensing."
        $disabledPlans = $License.ServicePlans | Where-Object -FilterScript { ($_.AppliesTo -eq 'User') -and ($_.ServicePlanName -NotMatch 'EXCHANGE') } | Select-Object -ExpandProperty ServicePlanId
        $addLicenses = @(
            @{
                SkuId         = $License.SkuId
                DisabledPlans = $disabledPlans
            }
        )
        Set-MgUserLicense `
            -UserId $userObj.Id `
            -AddLicenses $addLicenses `
            -RemoveLicenses @() `
            1> $null
    }
    #endregion ---------------------------------------------------------------------

    #region Group Membership Assignment --------------------------------------------
    if ($groupObj) {
        if (
            $groupObj.GroupType -NotContains 'DynamicMembership' -or
        ($groupObj.MembershipRuleProcessingState -ne 'On')
        ) {
            $groupMembership = Get-MgGroupMember `
                -ConsistencyLevel eventual `
                -GroupId $groupObj.Id `
                -CountVariable CountVar `
                -Filter "Id eq '$($userObj.Id)'"
            if (-Not $groupMembership) {
                Write-Verbose "Implying manually adding user to static group $($groupObj.DisplayName) ($($groupObj.Id))"
                New-MgBetaGroupMember -GroupId $groupObj.Id -DirectoryObjectId $userObj.Id
            }
        }

        # Wait for group membership
        $DoLoop = $true
        $RetryCount = 1
        $MaxRetry = 30
        $WaitSec = 7

        do {
            $groupMembership = Get-MgGroupMember `
                -ConsistencyLevel eventual `
                -GroupId $groupObj.Id `
                -CountVariable CountVar `
                -Filter "Id eq '$($userObj.Id)'"
            if ($null -ne $groupMembership) {
                $DoLoop = $false
            }
            elseif ($RetryCount -ge $MaxRetry) {
                Remove-MgUser `
                    -UserId $userObj.Id `
                    -ErrorAction SilentlyContinue `
                    -Confirm:$false `
                    1> $null
                $DoLoop = $false

                $return.Error += ./Common__0000_Write-Error.ps1 @{
                    Message           = "${ReferralUserId}: Group assignment timeout for $($newUser.UserPrincipalName)."
                    ErrorId           = '504'
                    Category          = 'OperationTimeout'
                    TargetName        = $refUserObj.UserPrincipalName
                    TargetObject      = $refUserObj.Id
                    TargetType        = 'User'
                    RecommendedAction = 'Try again later.'
                    CategoryActivity  = 'Account Provisioning'
                    CategoryReason    = "A timeout occured during provisioning wait after group assignment."
                }
                return
            }
            else {
                $RetryCount += 1
                Write-Verbose "Try $RetryCount of ${MaxRetry}: Waiting another $WaitSec seconds for group assignment ..."
                Start-Sleep -Seconds $WaitSec
            }
        } While ($DoLoop)
    }
    #endregion ---------------------------------------------------------------------

    #region Wait for Exchange Service Plan Provisioning ----------------------------
    $DoLoop = $true
    $RetryCount = 1
    $MaxRetry = 30
    $WaitSec = 7

    do {
        $userLicObj = Get-MgUserLicenseDetail -UserId $userObj.Id
        if (
            ($null -ne $userLicObj) -and
            (
                $userLicObj.ServicePlans | Where-Object -FilterScript {
                    ($_.AppliesTo -eq 'User') -and
                    ($_.ProvisioningStatus -eq 'Success') -and
                    ($_.ServicePlanName -Match 'EXCHANGE')
                }
            )
        ) {
            $DoLoop = $false
        }
        elseif ($RetryCount -ge $MaxRetry) {
            Remove-MgUser `
                -UserId $userObj.Id `
                -ErrorAction SilentlyContinue `
                -Confirm:$false `
                1> $null
            $DoLoop = $false

            $return.Error += ./Common__0000_Write-Error.ps1 @{
                Message           = "${ReferralUserId}: Exchange Online license activation timeout for $($newUser.UserPrincipalName)."
                ErrorId           = '504'
                Category          = 'OperationTimeout'
                TargetName        = $refUserObj.UserPrincipalName
                TargetObject      = $refUserObj.Id
                TargetType        = 'User'
                RecommendedAction = 'Try again later.'
                CategoryActivity  = 'Account Provisioning'
                CategoryReason    = "A timeout occured during Exchange Online license activation."
            }
            return
        }
        else {
            $RetryCount += 1
            Write-Verbose "Try $RetryCount of ${MaxRetry}: Waiting another $WaitSec seconds for Exchange license assignment ..."
            Start-Sleep -Seconds $WaitSec
        }
    } While ($DoLoop)
    #endregion ---------------------------------------------------------------------

    #region Wait for Mailbox to become available -----------------------------------
    $DoLoop = $true
    $RetryCount = 1
    $MaxRetry = 60
    $WaitSec = 15

    $userExObj = $null
    do {
        $userExObj = Get-EXOMailbox `
            -UserPrincipalName $userObj.UserPrincipalName `
            -ErrorAction SilentlyContinue
        if ($null -ne $userExObj) {
            $DoLoop = $false
        }
        elseif ($RetryCount -ge $MaxRetry) {
            Remove-MgUser `
                -UserId $userObj.Id `
                -ErrorAction SilentlyContinue `
                -Confirm:$false `
                1> $null
            $DoLoop = $false

            $return.Error += ./Common__0000_Write-Error.ps1 @{
                Message           = "${ReferralUserId}: Mailbox provisioning timeout for $($newUser.UserPrincipalName)."
                ErrorId           = '504'
                Category          = 'OperationTimeout'
                TargetName        = $refUserObj.UserPrincipalName
                TargetObject      = $refUserObj.Id
                TargetType        = 'User'
                RecommendedAction = 'Try again later.'
                CategoryActivity  = 'Account Provisioning'
                CategoryReason    = "A timeout occured during mailbox provisioning."
            }
            return
        }
        else {
            $RetryCount += 1
            Write-Verbose "Try $RetryCount of ${MaxRetry}: Waiting another $WaitSec seconds for mailbox creation ..."
            Start-Sleep -Seconds $WaitSec
        }
    } While ($DoLoop)
    #endregion ---------------------------------------------------------------------

    #region Configure E-mail Forwarding --------------------------------------------
    Set-Mailbox `
        -Identity $userExObj.Identity `
        -ForwardingAddress $refUserExObj.Identity `
        -ForwardingSmtpAddress $null `
        -DeliverToMailboxAndForward $false `
        -HiddenFromAddressListsEnabled $true `
        -WarningAction SilentlyContinue `
        1> $null

    $userExMbObj = Get-Mailbox -Identity $userExObj.Identity
    $userObj = Get-MgUser `
        -UserId $userObj.Id `
        -Property $userProperties `
        -ExpandProperty $userExpandPropeties
    #endregion ---------------------------------------------------------------------

    #region Set User Photo ---------------------------------------------------------
    $Url = $PhotoUrl
    if (-Not $PhotoUrl) {
        $index = Get-Random -Minimum 0 -Maximum $tenantBranding.CdnList.Count
        if ($tenantBranding.SquareLogoRelativeUrl) {
            Write-Verbose "Using tenant square logo as user photo"
            $Url = 'https://' + $tenantBranding.CdnList[$index] + '/' + $tenantBranding.SquareLogoRelativeUrl
        }
        elseif ($tenantBranding.SquareLogoRelativeUrl) {
            Write-Verbose "Using tenant square logo dark as user photo"
            $Url = 'https://' + $tenantBranding.CdnList[$index] + '/' + $tenantBranding.SquareLogoDarkRelativeUrl
        }
    }

    if ($Url) {
        Write-Verbose "Retrieving user photo from URL '$($Url)'"
        Invoke-WebRequest `
            -UseBasicParsing `
            -Method GET `
            -Uri $Url `
            -TimeoutSec 10 `
            -ErrorAction SilentlyContinue `
            -OutVariable UserPhoto `
            1> $null
        if (
            (-Not $UserPhoto) -or
            ($UserPhoto.StatusCode -ne 200) -or
            (-Not $UserPhoto.Content)
        ) {
            Write-Warning "Unable to download photo from URL '$($Url)'"
        }
        elseif (
            $UserPhoto.Headers.'Content-Type' -notmatch '^image/'
        ) {
            Write-Warning "Photo from URL '$($Url)' must have Content-Type 'image/*'."
        }
        else {
            Write-Verbose 'Updating user photo'
            Set-MgUserPhotoContent `
                -InFile nonExistat.lat `
                -UserId $userObj.Id `
                -Data ([System.IO.MemoryStream]::new($UserPhoto.Content)) `
                1> $null
        }
    }
    #endregion ---------------------------------------------------------------------

    #region Add Return Data ----------------------------------------------------
    $data = @{
        ReferralUserId             = $refUserObj.Id
        ReferralUser               = @{
            Id                = $refUserObj.Id
            UserPrincipalName = $refUserObj.UserPrincipalName
            Mail              = $refUserObj.Mail
            DisplayName       = $refUserObj.DisplayName
        }
        Tier                       = $Tier
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
        if ($null -eq $data.$property) {
            $data.$property = $userObj.$property
        }
    }
    if ($PhotoUrl ) { $data.UserPhotoUrl = $PhotoUrl }

    if (-Not $return.Data) { $return.Data = @() }
    $return.Data += $data

    if ($OutText) {
        Write-Output $(if ($data.UserPrincipalName) { $data.UserPrincipalName } else { $null })
    }
    #endregion ---------------------------------------------------------------------
}

End {
    #region Send and Output Return Data --------------------------------------------
    if ($Webhook) { ./Common__0000_Submit-Webhook.ps1 -Uri $Webhook -Body $return }
    $InformationPreference = $origInformationPreference
    if (($true -eq $OutText) -or ($PSBoundParameters.Keys -contains 'OutJson') -and ($false -eq $OutJson)) { return }
    if ($OutJson) { ./Common__0000_Write-JsonOutput.ps1 $return; return }

    return $return
    #endregion ---------------------------------------------------------------------
}
