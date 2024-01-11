<#PSScriptInfo
.VERSION 0.9.0
.GUID 03b78b5d-1e83-44bc-83ce-a5c0f101461b
.AUTHOR Julian Pawlowski
.COMPANYNAME Workoho GmbH
.COPYRIGHT (c) 2024 Workoho GmbH. All rights reserved.
.TAGS TieringModel Identity CloudAdministrator Security Azure Automation AzureAutomation
.LICENSEURI
.PROJECTURI
.ICONURI
.EXTERNALMODULEDEPENDENCIES Microsoft.Graph,Microsoft.Graph.Beta,Az
.REQUIREDSCRIPTS CloudAdmin_0000__Common_0000__Get-ConfigurationConstants.ps1,Common_0000__Convert-PSEnvToPSLocalVariable.ps1,Common_0000__Get-RandomPassword.ps1,Common_0000__Import-Module.ps1,Common_0000__Submit-Webhook.ps1,Common_0000__Write-Error.ps1,Common_0000__Write-Information.ps1,Common_0000__Write-JsonOutput.ps1,Common_0000__Write-Warning.ps1,Common_0001__Connect-ExchangeOnline.ps1,Common_0001__Connect-MgGraph.ps1,Common_0002__Import-AzAutomationVariableToPSEnv.ps1,Common_0002__Wait-AzAutomationConcurrentJob.ps1,Common_0003__Confirm-MgAppPermission.ps1,Common_0003__Confirm-MgDirectoryRoleActiveAssignment.ps1
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>

<#
.SYNOPSIS
    Create or update a dedicated cloud native account for administrative purposes in Tier 0, 1, or 2

.DESCRIPTION
    Create a dedicated cloud native account for administrative purposes that can perform privileged tasks in Tier 0.
    For Tier 1 and Tier 2, the creation of a dedicated user account is optional depending on your custom configuration, so that only a precondition check is performed before the user is added to the respective security group.

    For dedicated admin accounts, User Principal Name and mail address will use the initial .onmicrosoft.com domain of the respective Entra ID tenant.
    The admin account will be referred to the main user account from ReferralUserId by using the manager property as well as using the same Employee information (if set).
    To identify as a Cloud Administrator account, the EmployeeType property will be used so that it can be used as an alternative to the UPN naming convention.
    Also, an extension attribute is used to reflect the account type. If the same extension attribute is also used for the referring account, it is copied and a prefix/suffix is added to represent the respective Tier level.
    Permanent e-mail forwarding to the referring user ID will be configured to receive notifications, e.g. from Entra Privileged Identity Management.

    NOTE: This script uses the Microsoft Graph Beta API as it requires support for Restricted Management Administrative Units which is not available in the stable API.

.PARAMETER ReferralUserId
    User account identifier of the existing main user account. May be an Entra Identity Object ID or User Principal Name (UPN).

.PARAMETER Tier
    The Tier level where the Cloud Administrator account shall be created.

.PARAMETER UserPhotoUrl
    URL of an image that shall be set as default photo for the user. Must use HTTPS protocol, end with .jpg/.jpeg/.png/?*, and use image/* as Content-Type in HTTP return header.
    If environment variable $env:AV_CloudAdminTier<Tier>_UserPhotoUrl is set, it will be used as a fallback option.
    In case no photo URL was provided at all, Entra square logo from organizational tenant branding will be used.
    The recommended size of the photo is 648x648 px.

.PARAMETER JobReference
    This information may be added for back reference in other IT systems. It will simply be added to the Job data.

.PARAMETER OutputJson
    Output the result in JSON format.
    This is useful when output data needs to be processed in other IT systems after the job was completed.

.PARAMETER OutputText
    Output the generated User Principal Name only.

.NOTES
    CONDITIONS TO CREATE A CLOUD ADMINISTRATOR ACCOUNT
    ==================================================

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

    In case an existing Cloud Administrator account was found for referral user ID, it must be a cloud native account to be updated. Otherwise an error is returned and manual cleanup of the on-premises synced account is required to resolve the conflict.
    If an existing Cloud administrator account was soft-deleted before, it will be permanently deleted before re-creating the account. A soft-deleted mailbox will be permanently deleted in that case as well.
    The user part of the Cloud Administrator account must be mutually exclusive to the tenant. A warning will be generated if there is other accounts using either a similar User Principal Name or same Display Name, Mail, Mail Nickname, or ProxyAddress.


    CUSTOM CONFIGURATION SETTINGS
    =============================

    Variables for custom configuration settings, either from $env:<VariableName>,
    or Azure Automation Account Variables, whose will automatically be published in $env.

    ********************************************************************************************************
    * Please note that <Tier> in the variable name must be replaced by the intended Tier level 0, 1, or 2. *
    * For example: AV_CloudAdminTier0_GroupId, AV_CloudAdminTier1_GroupId, AV_CloudAdminTier2_GroupId      *
    ********************************************************************************************************

    AV_CloudAdmin_RestrictedAdminUnitId - [String] - Default Value: $null
        ...

    AV_CloudAdmin_AccountTypeExtensionAttribute - [Integer] - Default Value: 15
        Save user account type information in this extension attribute. Content from the referral user will be copied and the Cloud Administrator
        information is added either as prefix or suffix (see AV_CloudAdminTier<Tier>_ExtensionAttribute* settings below).

    AV_CloudAdmin_AccountTypeEmployeeType - [Boolean] - Default Value: $true
        ...

    AV_CloudAdmin_ReferenceExtensionAttribute - [Integer] - Default Value: 14
        ...

    AV_CloudAdmin_ReferenceManager - [Boolean] - Default Value: $false
        ...

    AV_CloudAdmin_Webhook - [String] - Default Value: $null
        Send return data in JSON format as POST to this webhook URL.

    AV_CloudAdminTier0_AccountRestrictedAdminUnitId
        ...

    AV_CloudAdminTier<Tier>_AccountAdminUnitId
        Tier 1 and 2 only, see AV_CloudAdminTier0_AccountRestrictedAdminUnitId for Tier 0.

    AV_CloudAdminTier<Tier>_UserPhotoUrl - [String] - Default Value: <empty>
        Default value for script parameter UserPhotoUrl. If no parameter was provided, this value will be used instead.
        If no value was provided at all, the tenant's square logo will be used.

    AV_CloudAdminTier<Tier>_LicenseSkuPartNumber - [String] - Default Value: EXCHANGEDESKLESS
        License assigned to the dedicated admin user account. The license SKU part number must contain an Exchange Online service plan to generate a mailbox
        for the user (see https://learn.microsoft.com/en-us/entra/identity/users/licensing-service-plan-reference).
        Multiple licenses may be assigned using a whitespace delimiter.
        For the license containing the Exchange Online service plan, only that service plan is enabled for the user, any other service plan within that license will be disabled.
        If GroupId is also provided, group-based licensing is implied and Exchange Online service plan activation will only be monitored before continuing.

    AV_CloudAdminTier<Tier>_GroupId - [String] - Default Value: <empty>
        Entra Group Object ID where the user shall be added. If the group is dynamic, group membership update will only be monitored before continuing.

    AV_CloudAdminTier<Tier>_GroupDescription - [String] - Default Value: Tier <Tier> Cloud Administrators
        ...

    AV_CloudAdminTier<Tier>_DedicatedAccount - [Boolean] - Default Value: $true for Tier 0, $false for Tier 1 and 2
        ...

    AV_CloudAdminTier<Tier>_AccountDomain - [String] - Default Value: onmicrosoft.com
        ...

    AV_CloudAdminTier<Tier>_AccountTypeEmployeeTypePrefix - [String] - Default Value: 
        ...

    AV_CloudAdminTier<Tier>_AccountTypeEmployeeTypePrefixSeparator - [String] - Default Value: 
        ...

    AV_CloudAdminTier<Tier>_AccountTypeEmployeeTypeSuffix - [String] - Default Value: 
        ...

    AV_CloudAdminTier<Tier>_AccountTypeEmployeeTypeSuffixSeparator - [String] - Default Value: 
        ...

    AV_CloudAdminTier<Tier>_AccountTypeExtensionAttributePrefix - [String] - Default Value: 
        ...

    AV_CloudAdminTier<Tier>_AccountTypeExtensionAttributePrefixSeparator - [String] - Default Value: 
        ...

    AV_CloudAdminTier<Tier>_AccountTypeExtensionAttributeSuffix - [String] - Default Value: 
        ...

    AV_CloudAdminTier<Tier>_AccountTypeExtensionAttributeSuffixSeparator - [String] - Default Value: 
        ...

    AV_CloudAdminTier<Tier>_UserDisplayNamePrefix - [String] - Default Value: 
        ...

    AV_CloudAdminTier<Tier>_UserDisplayNamePrefixSeparator - [String] - Default Value: 
        ...

    AV_CloudAdminTier<Tier>_UserDisplayNameSuffix - [String] - Default Value: 
        ...

    AV_CloudAdminTier<Tier>_UserDisplayNameSuffixSeparator - [String] - Default Value: 
        ...

    AV_CloudAdminTier<Tier>_GivenNamePrefix - [String] - Default Value: 
        ...

    AV_CloudAdminTier<Tier>_GivenNamePrefixSeparator - [String] - Default Value: 
        ...

    AV_CloudAdminTier<Tier>_GivenNameSuffix - [String] - Default Value: 
        ...

    AV_CloudAdminTier<Tier>_GivenNameSuffixSeparator - [String] - Default Value: 
        ...

    AV_CloudAdminTier<Tier>_UserPrincipalNamePrefix - [String] - Default Value: 
        ...

    AV_CloudAdminTier<Tier>_UserPrincipalNamePrefixSeparator - [String] - Default Value: 
        ...

    AV_CloudAdminTier<Tier>_UserPrincipalNameSuffix - [String] - Default Value: 
        ...

    AV_CloudAdminTier<Tier>_UserPrincipalNameSuffixSeparator - [String] - Default Value: 
        ...

.EXAMPLE
    New-CloudAdministrator-Account-V1.ps1 -ReferralUserId first.last@example.com -Tier 0

.EXAMPLE
    New-CloudAdministrator-Account-V1.ps1 -ReferralUserId first.last@example.com -Tier 0 -UserPhotoUrl https://example.com/assets/Tier0-Admins.png

    Provide a different URL for the photo to be uploaded to the new Cloud Administrator account.

.EXAMPLE
    $csv = Get-Content list.csv | ConvertFrom-Csv; New-CloudAdministrator-Account-V1.ps1 -ReferralUserId $csv.ReferralUserId -Tier $csv.Tier -UserPhotoUrl $csv.UserPhotoUrl

    BATCH PROCESSING
    ================

    Azure Automation has limited support for regular PowerShell pipelining as it does not process inline execution of child runbooks within Begin/End blocks.
    Therefore, classic PowerShell pipelining does NOT work. Instead, an array can be used to provide the required input data.
    The advantage is that the script will run more efficient as some tasks only need to be performed once per batch instead of each individual account.
#>

#region TODO:
#- remove MgBeta and see if it can be replaced by Invoke-MgGraph, especially for Identity.(Beta).Governace ...
#- convert ReferralUserId to #EXT# format for domains that are not validated in the tenant
#- regex check for UPN which is currently commented out
#- find existing account not only by UPN but also extensionAttribute and manager and EmployeeType
#- Install PowerShell modules that are mentioned as "requires" but do not update existing ones, just to support the initial run of the script
#- review import modules / beta vs. v1.0 and check memory consumption in azure automation
#- review documentation
#- create visual
#endregion

[CmdletBinding()]
Param (
    [Parameter(Position = 0, mandatory = $true)]
    [Array]$ReferralUserId,

    [Parameter(Position = 1, mandatory = $true)]
    [Array]$Tier,

    [Parameter(Position = 2)]
    [Array]$UserPhotoUrl,

    [Boolean]$OutJson,
    [Boolean]$OutText,
    [Hashtable]$JobReference
)

#region [COMMON] PARAMETER COUNT VALIDATION ------------------------------------
if (
    ($ReferralUserId.Count -gt 1) -and
    (
        ($ReferralUserId.Count -ne $Tier.Count) -or
        ($ReferralUserId.Count -ne $UserPhotoUrl.Count)
    )
) {
    Throw 'ReferralUserId, Tier, and UserPhotoUrl must contain the same number of items for batch processing.'
}
#endregion ---------------------------------------------------------------------

#region [COMMON] IMPORT MODULES ------------------------------------------------
.\Common_0000__Import-Module.ps1 -Modules @(
    @{ Name = 'Microsoft.Graph.Beta.Identity.DirectoryManagement'; MinimumVersion = '2.0'; MaximumVersion = '2.65535' }
    @{ Name = 'Microsoft.Graph.Beta.Groups'; MinimumVersion = '2.0'; MaximumVersion = '2.65535' }
    @{ Name = 'Microsoft.Graph.Beta.Users'; MinimumVersion = '2.0'; MaximumVersion = '2.65535' }
    @{ Name = 'Microsoft.Graph.Beta.Users.Actions'; MinimumVersion = '2.0'; MaximumVersion = '2.65535' }
    @{ Name = 'Microsoft.Graph.Beta.Applications'; MinimumVersion = '2.0'; MaximumVersion = '2.65535' }
) 1> $null

#endregion ---------------------------------------------------------------------

#region [COMMON] OPEN CONNECTIONS: Microsoft Graph -----------------------------
.\Common_0001__Connect-MgGraph.ps1 -Scopes @(
    'User.ReadWrite.All'
    'Directory.Read.All'
    'Group.ReadWrite.All'
    'Organization.Read.All'
    'OnPremDirectorySynchronization.Read.All'
    'Mail.Send'
) 1> $null
#endregion ---------------------------------------------------------------------

#region [COMMON] ENVIRONMENT ---------------------------------------------------
.\Common_0002__Import-AzAutomationVariableToPSEnv.ps1 1> $null
$Constants = .\CloudAdmin_0000__Common_0000__Get-ConfigurationConstants.ps1
.\Common_0000__Convert-PSEnvToPSLocalVariable.ps1 -Variable $Constants 1> $null
#endregion ---------------------------------------------------------------------

#region [COMMON] CONCURRENT JOBS -----------------------------------------------
if ((.\Common_0002__Wait-AzAutomationConcurrentJob.ps1) -ne $true) {
    $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                Message           = "Maximum job runtime was reached."
                ErrorId           = '504'
                Category          = 'OperationTimeout'
                RecommendedAction = 'Try again later.'
                CategoryActivity  = 'Job Concurrency Check'
                CategoryReason    = "Maximum job runtime was reached."
            }))
}
#endregion ---------------------------------------------------------------------

#region Administrative Unit Validation -----------------------------------------
$AllowPrivilegedRoleAdministratorInAzureAutomation = $false
$AdminUnitIsMemberManagementRestricted = $false
@($CloudAdminRestrictedAdminUnitId; $AccountRestrictedAdminUnitId_Tier0; $AccountAdminUnitId_Tier1; $AccountAdminUnitId_Tier2) | Where-Object { -Not [string]::IsNullOrEmpty($_) } | Select-Object -Unique | & {
    process {
        try {
            $AdminUnitObj = Get-MgBetaAdministrativeUnit -AdministrativeUnitId $_ -ErrorAction Stop
        }
        catch {
            Throw $_
        }

        if ($AdminUnitObj.IsMemberManagementRestricted) {
            $script:AdminUnitIsMemberManagementRestricted = $true
        }

        if (
            $_ -in @(
                $CloudAdminRestrictedAdminUnitId
                $AccountRestrictedAdminUnitId_Tier0
            )
        ) {
            if (-Not $AdminUnitObj.IsMemberManagementRestricted) {
                Throw "Admin Unit $($AdminUnitObj.DisplayName) ($($AdminUnitObj.Id)): Must have restricted management enabled to be used for Cloud Administration."
            }
            if ($AdminUnitObj.Visibility -ne 'HiddenMembership') {
                Throw "Admin Unit $($AdminUnitObj.DisplayName) ($($AdminUnitObj.Id)): Must have HiddenMembership visibility to be used for Cloud Administration."
            }
        }

        if (
            $_ -in @(
                $AccountAdminUnitId_Tier1
                $AccountAdminUnitId_Tier2
            )
        ) {
            if (-Not $AdminUnitObj.IsMemberManagementRestricted) {
                Write-Warning "Admin Unit $($AdminUnitObj.DisplayName) ($($AdminUnitObj.Id)): Consider recreating with `-IsMemberManagementRestricted:$true` to increase security."
            }
            if ($AdminUnitObj.Visibility -ne 'HiddenMembership') {
                Write-Warning "Admin Unit $($AdminUnitObj.DisplayName) ($($AdminUnitObj.Id)): Consider recreating with `-Visibility 'HiddenMembership'` to increase security."
            }
        }

        if (
            ($_ -eq $CloudAdminRestrictedAdminUnitId) -and
            ($null -ne $AdminUnitObj.AdditionalProperties.membershipRuleProcessingState) -and
            ($AdminUnitObj.AdditionalProperties.membershipRuleProcessingState -eq 'On')
        ) {
            Throw "Admin Unit $($AdminUnitObj.DisplayName) ($($AdminUnitObj.Id)): Must use static membership only as it is intended to contain privileged role groups only."
        }

        if (
            $_ -in @(
                $AccountRestrictedAdminUnitId_Tier0
                $AccountAdminUnitId_Tier1
                $AccountAdminUnitId_Tier2
            ) -and (
                ($null -eq $AdminUnitObj.AdditionalProperties.membershipRuleProcessingState) -or
                ($AdminUnitObj.AdditionalProperties.membershipRuleProcessingState -ne 'On')
            )
        ) {
            $script:AllowPrivilegedRoleAdministratorInAzureAutomation = $true
            Write-Warning "Admin Unit $($AdminUnitObj.DisplayName) ($($AdminUnitObj.Id)): Consider changing membership rule to dynamic for automatic member assignment and avoid Privileged Role Administrator permissions. You may use property extensionAttribute$AccountTypeExtensionAttribute to identify Cloud Administrator account types."
        }
    }
}
if ($AdminUnitIsMemberManagementRestricted) {
    .\Common_0001__Connect-MgGraph.ps1 -WarningAction SilentlyContinue -Scopes @(
        'Directory.Write.Restricted'
    ) 1> $null
}
#endregion ---------------------------------------------------------------------

#region Required Microsoft Entra Directory Permissions Validation --------------
$DirectoryPermissions = .\Common_0003__Confirm-MgDirectoryRoleActiveAssignment.ps1 -AllowPrivilegedRoleAdministratorInAzureAutomation:$AllowPrivilegedRoleAdministratorInAzureAutomation -Roles @(
    # Exchange Online to setup email forwarding
    if ($DedicatedAccount_Tier0 -or $DedicatedAccount_Tier1 -or $DedicatedAccount_Tier2) {
        Write-Verbose 'Require directory role: Exchange Recipient Administrator'
        @{
            DisplayName = 'Exchange Recipient Administrator'
            TemplateId  = '31392ffb-586c-42d1-9346-e59415a2cc4e'
        }
    }

    # Cloud Administration Admin Units
    if ($AllowPrivilegedRoleAdministratorInAzureAutomation) {
        Write-Verbose 'Require directory role: Privileged Role Administrator'
        @{
            DisplayName = 'Privileged Role Administrator'
            TemplateId  = 'e8611ab8-c189-46e8-94e1-60213ab1f814'
        }
    }

    # Cloud Administration Groups
    if ($GroupId_Tier0 -or $GroupId_Tier1 -or $GroupId_Tier2) {
        Write-Verbose 'Require directory role: Groups Administrator'
        @{
            DisplayName      = 'Groups Administrator'
            TemplateId       = 'fdd7a751-b60b-444a-984c-02652fe8fa1c'
            DirectoryScopeId = if ($CloudAdminRestrictedAdminUnitId) { "/administrativeUnits/$CloudAdminRestrictedAdminUnitId" } else { '/' }
        }
    }

    # Tier 0 Cloud Admin Accounts
    if ($DedicatedAccount_Tier0) {
        Write-Verbose 'Require directory role (Tier 0): User Administrator'
        @{
            DisplayName      = 'User Administrator'
            TemplateId       = 'fe930be7-5e62-47db-91af-98c3a49a38b1'
            DirectoryScopeId = if ($AccountRestrictedAdminUnitId_Tier0) { "/administrativeUnits/$AccountRestrictedAdminUnitId_Tier0" } else { '/' }
        }
        if (-Not $GroupId_Tier0) {
            Write-Verbose 'Require directory role (Tier 0): License Administrator'
            @{
                DisplayName      = 'License Administrator'
                TemplateId       = '4d6ac14f-3453-41d0-bef9-a3e0c569773a'
                DirectoryScopeId = if ($AccountRestrictedAdminUnitId_Tier0) { "/administrativeUnits/$AccountRestrictedAdminUnitId_Tier0" } else { '/' }
            }
        }
    }

    # Tier 1 Cloud Admin Accounts
    if ($DedicatedAccount_Tier1) {
        Write-Verbose 'Require directory role (Tier 1): User Administrator'
        @{
            DisplayName      = 'User Administrator'
            TemplateId       = 'fe930be7-5e62-47db-91af-98c3a49a38b1'
            DirectoryScopeId = if ($AccountAdminUnitId_Tier1) { "/administrativeUnits/$AccountAdminUnitId_Tier1" } else { '/' }
        }
        if (-Not $GroupId_Tier1) {
            Write-Verbose 'Require directory role (Tier 1): License Administrator'
            @{
                DisplayName      = 'License Administrator'
                TemplateId       = '4d6ac14f-3453-41d0-bef9-a3e0c569773a'
                DirectoryScopeId = if ($AccountAdminUnitId_Tier1) { "/administrativeUnits/$AccountAdminUnitId_Tier1" } else { '/' }
            }
        }
    }

    # Tier 2 Cloud Admin Accounts
    if ($DedicatedAccount_Tier2) {
        Write-Verbose 'Require directory role (Tier 2): User Administrator'
        @{
            DisplayName      = 'User Administrator'
            TemplateId       = 'fe930be7-5e62-47db-91af-98c3a49a38b1'
            DirectoryScopeId = if ($AccountAdminUnitId_Tier2) { "/administrativeUnits/$AccountAdminUnitId_Tier2" } else { '/' }
        }
        if (-Not $GroupId_Tier2) {
            Write-Verbose 'Require directory role (Tier 2): License Administrator'
            @{
                DisplayName      = 'License Administrator'
                TemplateId       = '4d6ac14f-3453-41d0-bef9-a3e0c569773a'
                DirectoryScopeId = if ($AccountAdminUnitId_Tier2) { "/administrativeUnits/$AccountAdminUnitId_Tier2" } else { '/' }
            }
        }
    }
)
#endregion ---------------------------------------------------------------------

#region License Existance Validation -------------------------------------------
try {
    $TenantLicensed = Get-MgBetaSubscribedSku -All -ErrorAction Stop
}
catch {
    Throw $_
}

$SkuPartNumberWithExchangeServicePlan = $null
@(($LicenseSkuPartNumber_Tier0 -split ' '); ($LicenseSkuPartNumber_Tier1 -split ' '); ($LicenseSkuPartNumber_Tier2 -split ' ')) | Where-Object { -Not [string]::IsNullOrEmpty($_) } | Select-Object -Unique | & {
    process {
        $SkuPartNumber = $_
        $Sku = $TenantLicensed | Where-Object { $_.SkuPartNumber -eq $SkuPartNumber } | Select-Object -Property Sku*, ServicePlans
        if (-Not $Sku) {
            Throw "License SkuPartNumber $SkuPartNumber is not available to this tenant. Licenses must be purchased before creating Cloud Administrator accounts."
        }
        if ($Sku.ServicePlans | Where-Object { ($_.AppliesTo -eq 'User') -and ($_.ServicePlanName -Match 'EXCHANGE') }) {
            if ($null -eq $SkuPartNumberWithExchangeServicePlan) {
                $script:SkuPartNumberWithExchangeServicePlan = $Sku.SkuPartNumber
                Write-Verbose "Detected Exchange Online service plan in SkuPartNumber $SkuPartNumberWithExchangeServicePlan."
            }
            else {
                Throw "There can only be one license configured containing an Exchange Online service plan: Make your choice between $SkuPartNumberWithExchangeServicePlan and $($Sku.SkuPartNumber)."
            }
        }
    }
}
if ($null -eq $SkuPartNumberWithExchangeServicePlan) {
    Throw "One of the configured SkuPartNumbers must contain an Exchange Online service plan."
}
#endregion ---------------------------------------------------------------------

#region [COMMON] INITIALIZE SCRIPT VARIABLES -----------------------------------
$tenant = Get-MgBetaOrganization -OrganizationId (Get-MgContext).TenantId
$tenantDomain = $tenant.VerifiedDomains | Where-Object { $_.IsInitial -eq $true }
$tenantBranding = Get-MgBetaOrganizationBranding -OrganizationId $tenant.Id
$persistentError = $false
$Iteration = 0

# To improve memory consumption, return arrays are kept separate until the end of this script
$returnOutput = [System.Collections.ArrayList]@()
$returnInformation = [System.Collections.ArrayList]@()
$returnWarning = [System.Collections.ArrayList]@()
$returnError = [System.Collections.ArrayList]@()
$return = @{
    Job = .\Common_0003__Get-AzAutomationJobInfo.ps1
}
if ($JobReference) { $return.Job.Reference = $JobReference }
#endregion ---------------------------------------------------------------------

#region Group Validation -------------------------------------------------------
if (
    (@($GroupId_Tier0, $GroupId_Tier1, $GroupId_Tier2) | Where-Object { -Not [string]::IsNullOrEmpty($_) }).Count -ne
    (@($GroupId_Tier0, $GroupId_Tier1, $GroupId_Tier2) | Where-Object { -Not [string]::IsNullOrEmpty($_) } | Sort-Object -Unique).Count
) {
    Throw "Configured group object IDs in AV_CloudAdminTier<Tier>_GroupId must be unique. Use separate groups for each Tier level."
}

@($GroupId_Tier0, $GroupId_Tier1, $GroupId_Tier2) | Where-Object { -Not [string]::IsNullOrEmpty($_) } | & {
    process {
        $ThisTier = if ($_ -eq $GroupId_Tier0) { 0 } elseif ($_ -eq $GroupId_Tier1) { 1 } elseif ($_ -eq $GroupId_Tier2) { 2 }
        try {
            $GroupObj = Get-MgBetaGroup -GroupId $_ -ExpandProperty 'Owners' -ErrorAction Stop
        }
        catch {
            Throw $_
        }

        if (-Not $GroupObj.SecurityEnabled) {
            Throw "Group $($GroupObj.DisplayName) ($($GroupObj.Id)): Must be security-enabled to be used for Cloud Administration."
        }

        if ($null -ne $GroupObj.OnPremisesSyncEnabled) {
            Throw "Group $($GroupObj.DisplayName) ($($GroupObj.Id)): Must never be synced from on-premises directory to be used for Cloud Administration."
        }

        if (
            $GroupObj.GroupType -and
                ($GroupObj.GroupType -contains 'Unified')
        ) {
            Throw "Group $($GroupObj.DisplayName) ($($GroupObj.Id)): Must not be a Microsoft 365 Group to be used for Cloud Administration."
        }

        if ($GroupObj.MailEnabled) {
            Throw "Group $($GroupObj.DisplayName) ($($GroupObj.Id)): Must not be mail-enabled to be used for Cloud Administration."
        }

        if (
                    (-Not $GroupObj.IsManagementRestricted) -and
                    (-Not $GroupObj.IsAssignableToRole)
        ) {
            Throw "Group $($GroupObj.DisplayName) ($($GroupObj.Id)): Must be protected by a Restricted Management Administrative Unit (preferred), or at least role-enabled to be used for Cloud Administration. (IsMemberManagementRestricted = $($GroupObj.IsManagementRestricted), IsAssignableToRole = $($GroupObj.IsAssignableToRole))"
        }

        if ($GroupObj.IsAssignableToRole) {
            if ($GroupObj.IsManagementRestricted) {
                Write-Warning "Group $($GroupObj.DisplayName) ($($GroupObj.Id)): Consider recreating the group without role enablement to avoid Privileged Role Administrator role assignment. Using Management Restricted Administrative Unit only should be the preferred protection for Cloud Administration."
            }
            if (-Not (
                    $DirectoryPermissions | Where-Object {
                        # Privileged Role Administrator
                        ($_.TemplateId -eq 'e8611ab8-c189-46e8-94e1-60213ab1f814') -or

                        # Global Administrator
                        ($_.TemplateId -eq '62e90394-69f5-4237-9190-012177145e10')
                    }
                )
            ) {
                Throw "Group $($GroupObj.DisplayName) ($($GroupObj.Id)): Missing Privileged Role Administrator permission to change membership of this group. Preferably, add this group to a Management Restricted Administrative Unit instead of assinging the missing role."
            }
        }

        if ($GroupObj.IsManagementRestricted) {
            if ($CloudAdminRestrictedAdminUnitId) {
                if (-Not (Get-MgBetaAdministrativeUnitMemberAsGroup -AdministrativeUnitId $CloudAdminRestrictedAdminUnitId -DirectoryObjectId $GroupObj.Id -ErrorAction SilentlyContinue)) {
                    Throw "Group $($GroupObj.DisplayName) ($($GroupObj.Id)): Group must be a member if Management Restricted Administrative Unit $CloudAdminRestrictedAdminUnitId to be used for Cloud Administration."
                }
            }
            else {
                Throw "Group $($GroupObj.DisplayName) ($($GroupObj.Id)): Group is Management Restricted by undefined Administrative Unit. Please add the respective Administrative Unit ID to configuration variable `$env:AV_CloudAdmin_RestrictedAdminUnitId"
            }

            if (
                ($GroupObj.GroupType -Contains 'DynamicMembership') -and
                ($GroupObj.MembershipRuleProcessingState -eq 'On')
            ) {
                if ($ThisTier -eq 0) {
                    Throw "Group $($GroupObj.DisplayName) ($($GroupObj.Id)): Must not use dynamic membership to be used for Cloud Administration in Tier 0."
                }
                else {
                    Write-Warning "Group $($GroupObj.DisplayName) ($($GroupObj.Id)): Consider disabling dynamic group membership for increased security."
                }
                if ($GroupObj.MembershipRule -notmatch '(?m)^.*user\..+$') {
                    Throw "Group $($GroupObj.DisplayName) ($($GroupObj.Id)): Must only use dynamic membership rule addressing user objects."
                }
            }

            .\Common_0001__Connect-MgGraph.ps1 -WarningAction SilentlyContinue -Scopes @(
                'Directory.Write.Restricted'
            ) 1> $null
        }

        $GroupDescription = Get-Variable -ValueOnly -name "GroupDescription_Tier$ThisTier"
        if (-Not $GroupObj.Description) {
            if (-Not [string]::IsNullOrEmpty($GroupDescription)) {
                Write-Warning "Group $($GroupObj.DisplayName) ($($GroupObj.Id)): Adding missing description for Tier $ThisTier identification."
                try {
                    Update-MgBetaGroup -GroupId $GroupObj.Id -Description $GroupDescription -ErrorAction Stop 1> $null
                }
                catch {
                    Throw $_
                }
            }
        }
        elseif (
                (-Not [string]::IsNullOrEmpty($GroupDescription)) -and
                ($GroupObj.Description -ne $GroupDescription)
        ) {
            Throw "Group $($GroupObj.DisplayName) ($($GroupObj.Id)): The description does not clearly identify this group as a Tier $ThisTier Administrators group. To avoid incorrect group assignments, please check that you are using the correct group. To use this group for Tier $Tier management, set the description property to '$GroupDescription'."
        }

        if ('Private' -ne $GroupObj.Visibility) {
            Write-Warning "Group $($GroupObj.DisplayName) ($($GroupObj.Id)): Correcting visibility to Private for Cloud Administration."
            try {
                Update-MgBetaGroup -GroupId $GroupObj.Id -Visibility 'Private' -ErrorAction Stop 1> $null
            }
            catch {
                Throw $_
            }
        }

        if ($GroupObj.Owners) {
            ForEach ($owner in $GroupObj.Owners) {
                Write-Warning "Group $($GroupObj.DisplayName) ($($GroupObj.Id)): Removing unwanted group owner $($owner.Id)."
                try {
                    Remove-MgBetaGroupOwnerByRef -GroupId $GroupObj.Id -DirectoryObjectId $owner.Id -ErrorAction Stop 1> $null
                }
                catch {
                    Throw $_
                }
            }
        }
    }
}
#endregion ---------------------------------------------------------------------

#region [COMMON] OPEN CONNECTIONS: Exchange Online -----------------------------
.\Common_0003__Confirm-MgAppPermission.ps1 -Permissions @(
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
) 1> $null

.\Common_0001__Connect-ExchangeOnline.ps1 -Organization $tenantDomain.Name -CommandName Get-EXOMailbox, Get-Mailbox, Set-Mailbox, Set-UserPhoto 1> $null
#endregion ---------------------------------------------------------------------

#region Process Referral User --------------------------------------------------
function ProcessReferralUser ($ReferralUserId, $Tier, $UserPhotoUrl) {
    Write-Verbose "-----STARTLOOP $ReferralUserId, Tier $Tier ---"

    #region [COMMON] LOOP HANDLING -------------------------------------------------
    # Only process items if there was no error during script initialization before
    if (($Iteration -eq 0) -and ($returnError.Count -gt 0)) { $persistentError = $true }
    if ($persistentError) {
        $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                    Message           = "${ReferralUserId}: Skipped processing."
                    ErrorId           = '500'
                    Category          = 'OperationStopped'
                    TargetName        = $ReferralUserId
                    TargetObject      = $null
                    RecommendedAction = 'Try again later.'
                    CategoryActivity  = 'Persisent Error'
                    CategoryReason    = "No other items are processed due to persistent error before."
                }))
        return
    }

    $Iteration++
    #endregion ---------------------------------------------------------------------

    #region [COMMON] LOOP ENVIRONMENT ----------------------------------------------
    .\Common_0000__Convert-PSEnvToPSLocalVariable.ps1 -Variable $Constants -scriptParameterOnly $true 1> $null

    $DedicatedAccount = Get-Variable -ValueOnly -Name "DedicatedAccount_Tier$Tier"
    $AllowedGuestOrExternalUserTypes = @( (Get-Variable -ValueOnly -Name "AllowedGuestOrExternalUserTypes_Tier$Tier") -split ' ' | Where-Object { -Not [string]::IsNullOrEmpty($_) } | Select-Object -Unique )
    $AllowMicrosoftAccount = Get-Variable -ValueOnly -Name "AllowMicrosoftAccount_Tier$Tier"
    $AllowSameDomainForReferralUser = Get-Variable -ValueOnly -Name "AllowSameDomainForReferralUser_Tier$Tier"
    $AdminUnitId = if ($Tier -eq 0) { Get-Variable -ValueOnly -Name "AccountRestrictedAdminUnitId_Tier0" } else { Get-Variable -ValueOnly -Name "AccountAdminUnitId_Tier$Tier" }
    $LicenseSkuPartNumbers = @( (Get-Variable -ValueOnly -Name "LicenseSkuPartNumber_Tier$Tier") -split ' ' | Where-Object { -Not [string]::IsNullOrEmpty($_) } | Select-Object -Unique )
    $AccountDomain = if ((Get-Variable -ValueOnly -Name "AccountDomain_Tier$Tier") -eq 'onmicrosoft.com') { $tenantDomain.Name } else { Get-Variable -ValueOnly -Name "AccountDomain_Tier$Tier" }
    $GroupId = Get-Variable -ValueOnly -Name "GroupId_Tier$Tier"
    $PhotoUrlUser = Get-Variable -ValueOnly -Name "PhotoUrl_Tier$Tier"

    $AdminUnitObj = $null
    if (-Not [string]::IsNullOrEmpty($AdminUnitId)) {
        $AdminUnitObj = Get-MgBetaAdministrativeUnit -AdministrativeUnitId $AdminUnitId
    }

    $GroupObj = $null
    if (-Not [string]::IsNullOrEmpty($GroupId)) {
        $GroupObj = Get-MgBetaGroup -GroupId $GroupId
    }

    $refUserExObj = $null
    $UserObj = $null
    $TenantLicensed = $null
    $UpdatedUserOnly = $false
    #endregion ---------------------------------------------------------------------

    #region Group Validation -------------------------------------------------------
    if ($DedicatedAccount -eq $false) {
        if (-Not $GroupObj) {
            $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                        Message          = "${ReferralUserId}: Internal configuration error."
                        ErrorId          = '500'
                        Category         = 'InvalidData'
                        TargetName       = $ReferralUserId
                        TargetObject     = $null
                        TargetType       = 'UserId'
                        CategoryActivity = 'Cloud Administrator Creation'
                        CategoryReason   = "Static group for Tier $Tier must be configured in AV_CloudAdminTier${Tier}_GroupId when using ordinary user accounts."
                    }))
            return
        }

        if (
            ($GroupObj.GroupType -Contains 'DynamicMembership') -and
            ($GroupObj.MembershipRuleProcessingState -eq 'On')
        ) {
            $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                        Message          = "${ReferralUserId}: Internal configuration error."
                        ErrorId          = '500'
                        Category         = 'InvalidData'
                        TargetName       = $ReferralUserId
                        TargetObject     = $null
                        TargetType       = 'UserId'
                        CategoryActivity = 'Cloud Administrator Creation'
                        CategoryReason   = "Group for Tier $Tier Cloud Administration must not use Dynamic Membership when using ordinary user accounts."
                    }))
            return
        }
    }
    #endregion

    #region [COMMON] PARAMETER VALIDATION ------------------------------------------
    $regex = '^[^\s]+@[^\s]+\.[^\s]+$|^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$'
    if ($ReferralUserId -notmatch $regex) {
        $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                    Message           = "${ReferralUserId}: ReferralUserId is invalid"
                    ErrorId           = '400'
                    Category          = 'SyntaxError'
                    TargetName        = $ReferralUserId
                    TargetObject      = $null
                    TargetType        = 'UserId'
                    RecommendedAction = 'Provide either User Principal Name, or Object ID (UUID).'
                    CategoryActivity  = 'ReferralUserId parameter validation'
                    CategoryReason    = "Parameter ReferralUserId does not match $regex"
                }))
        return
    }
    $regex = '^[0-2]$'
    if ($Tier -notmatch $regex) {
        $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                    Message           = "${ReferralUserId}: Tier $Tier is invalid"
                    ErrorId           = '400'
                    Category          = 'SyntaxError'
                    TargetName        = $ReferralUserId
                    TargetObject      = $null
                    TargetType        = 'Retry again later'
                    RecommendedAction = 'Provide a Tier level of 0, 1, or 2.'
                    CategoryActivity  = 'Tier parameter validation'
                    CategoryReason    = "Parameter Tier does not match $regex"
                }))
        return
    }
    $regex = '(?:^https:\/\/.+(?:\.png|\.jpg|\.jpeg|\?.+)$|^$)'
    if ($UserPhotoUrl -notmatch $regex) {
        $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                    Message           = "${ReferralUserId}: UserPhotoUrl $UserPhotoUrl is invalid"
                    ErrorId           = '400'
                    Category          = 'SyntaxError'
                    TargetName        = $ReferralUserId
                    TargetObject      = $null
                    TargetType        = 'UserId'
                    RecommendedAction = 'Please correct the URL format for paramter UserPhotoUrl.'
                    CategoryActivity  = 'UserPhotoUrl parameter validation'
                    CategoryReason    = "Parameter UserId does not match $regex"
                }))
        return
    }
    #endregion ---------------------------------------------------------------------

    #region Referral User Validation -----------------------------------------------
    $userProperties = @(
        'Id'
        'UserType'
        'CreatedDateTime'
        'IsResourceAccount'
        'CreationType'
        'ExternalUserState'
        'Identities'
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

    $params = @{
        UserId         = $ReferralUserId
        Property       = $userProperties
        ExpandProperty = $userExpandPropeties
        ErrorAction    = 'Stop'
    }
    try {
        $refUserObj = Get-MgBetaUser @params
    }
    catch {
        $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                    Message           = "${ReferralUserId}: Referral User ID does not exist in directory."
                    ErrorId           = '404'
                    Category          = 'ObjectNotFound'
                    TargetName        = $ReferralUserId
                    TargetObject      = $null
                    TargetType        = 'UserId'
                    RecommendedAction = 'Provide an existing User Principal Name, or Object ID (UUID).'
                    CategoryActivity  = 'ReferralUserId user validation'
                    CategoryReason    = 'Referral User ID does not exist in directory.'
                }))
        return
    }

    #region All Accounts
    if (-Not $refUserObj.AccountEnabled) {
        $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                    Message          = "${ReferralUserId}: Referral User ID is disabled. A Cloud Administrator account can only be set up for active accounts."
                    ErrorId          = '403'
                    Category         = 'NotEnabled'
                    TargetName       = $refUserObj.UserPrincipalName
                    TargetObject     = $refUserObj.Id
                    TargetType       = 'UserId'
                    CategoryActivity = 'ReferralUserId user validation'
                    CategoryReason   = 'Referral User ID is disabled. A Cloud Administrator account can only be set up for active accounts.'
                }))
        return
    }

    if ($refUserObj.IsResourceAccount) {
        $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                    Message          = "${ReferralUserId}: Resource accounts can not have a Cloud Administrator account created."
                    ErrorId          = '403'
                    Category         = 'PermissionDenied'
                    TargetName       = $refUserObj.UserPrincipalName
                    TargetObject     = $refUserObj.Id
                    TargetType       = 'UserId'
                    CategoryActivity = 'ReferralUserId user validation'
                    CategoryReason   = 'Referral User ID is a resource account.'
                }))
        return
    }

    $refUserTypeDetails = .\Common_0002__Get-MgUserTypeDetail.ps1 -UserObject $refUserObj

    if ($refUserTypeDetails.IsEmailOTPAuthentication -ne $false) {
        $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                    Message          = "${ReferralUserId}: Referral User ID must not use email one-time passcode authentication."
                    ErrorId          = '403'
                    Category         = 'PermissionDenied'
                    TargetName       = $refUserObj.UserPrincipalName
                    TargetObject     = $refUserObj.Id
                    TargetType       = 'UserId'
                    CategoryActivity = 'ReferralUserId user validation'
                    CategoryReason   = 'Referral User ID has defined identity details that indicate email one-time passcode authentication.'
                }))
        return
    }

    if ($refUserTypeDetails.IsFacebookAccount -ne $false) {
        $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                    Message          = "${ReferralUserId}: Referral User ID must not be a facebook.com identity."
                    ErrorId          = '403'
                    Category         = 'PermissionDenied'
                    TargetName       = $refUserObj.UserPrincipalName
                    TargetObject     = $refUserObj.Id
                    TargetType       = 'UserId'
                    CategoryActivity = 'ReferralUserId user validation'
                    CategoryReason   = 'Referral User ID has defined identity Issuer of facebook.com.'
                }))
        return
    }

    if (
        ($refUserTypeDetails.IsMicrosoftAccount -ne $false) -and
        ($AllowMicrosoftAccount -ne $true)
    ) {
        $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                    Message          = "${ReferralUserId}: Referral User ID must not be a Microsoft Account."
                    ErrorId          = '403'
                    Category         = 'PermissionDenied'
                    TargetName       = $refUserObj.UserPrincipalName
                    TargetObject     = $refUserObj.Id
                    TargetType       = 'UserId'
                    CategoryActivity = 'ReferralUserId user validation'
                    CategoryReason   = 'Referral User ID has defined identity Issuer of MicrosoftAccount.'
                }))
        return
    }

    # if (
    #     ($refUserObj.UserPrincipalName -match '^A[0-9][A-Z][-_].+@.+$') -or # Tiered admin accounts, e.g. A0C_*, A1L-*, etc.
    #     ($refUserObj.UserPrincipalName -match '^ADM[CL]?[-_].+@.+$') -or # Non-Tiered admin accounts, e.g. ADM_, ADMC-* etc.
    #     ($refUserObj.UserPrincipalName -match '^(?:SVCC?_.+|SVC[A-Z0-9]+)@.+$') -or # Service Accounts
    #     ($refUserObj.UserPrincipalName -match '^(?:Sync_.+|[A-Z]+SyncServiceAccount.*)@.+$')  # Entra Sync Accounts
    # ) {
    #     $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
    #         Message          = "${ReferralUserId}: This type of user name can not have a Cloud Administrator account created."
    #         ErrorId          = '403'
    #         Category         = 'PermissionDenied'
    #         TargetName       = $refUserObj.UserPrincipalName
    #         TargetObject     = $refUserObj.Id
    #         TargetType       = 'UserId'
    #         CategoryActivity = 'ReferralUserId user validation'
    #         CategoryReason   = 'Referral User ID is listed as not capable of having a Cloud Administrator account.'
    #     }))
    #     return
    # }

    if ([string]::IsNullOrEmpty($refUserObj.DisplayName)) {
        $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                    Message          = "${ReferralUserId}: Referral User ID must have display name set."
                    ErrorId          = '403'
                    Category         = 'InvalidType'
                    TargetName       = $refUserObj.UserPrincipalName
                    TargetObject     = $refUserObj.Id
                    TargetType       = 'UserId'
                    CategoryActivity = 'ReferralUserId user validation'
                    CategoryReason   = 'Referral User ID must have DisplayName property set.'
                }))
        return
    }

    if (
        ($null -ne $refUserObj.EmployeeHireDate) -and
        ($return.Job.CreationTime -lt $refUserObj.EmployeeHireDate)
    ) {
        $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                    Message          = "${ReferralUserId}: Referral User ID will start to work at $($refUserObj.EmployeeHireDate | Get-Date -Format 'o') Universal Time. A Cloud Administrator account can only be set up for active employees."
                    ErrorId          = '403'
                    Category         = 'ResourceUnavailable'
                    TargetName       = $refUserObj.UserPrincipalName
                    TargetObject     = $refUserObj.Id
                    TargetType       = 'UserId'
                    CategoryActivity = 'ReferralUserId user validation'
                    CategoryReason   = "Referral User ID will start to work at $($refUserObj.EmployeeHireDate | Get-Date -Format 'o') Universal Time. A Cloud Administrator account can only be set up for active employees."
                }))
        return
    }

    if (
        ($null -ne $refUserObj.EmployeeLeaveDateTime) -and
        ($return.Job.CreationTime -ge $refUserObj.EmployeeLeaveDateTime.AddDays(-45))
    ) {
        $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                    Message          = "${ReferralUserId}: Referral User ID is scheduled for deactivation at $($refUserObj.EmployeeLeaveDateTime | Get-Date -Format 'o') Universal Time. A Cloud Administrator account can only be set up a maximum of 45 days before the planned leaving date."
                    ErrorId          = '403'
                    Category         = 'OperationStopped'
                    TargetName       = $refUserObj.UserPrincipalName
                    TargetObject     = $refUserObj.Id
                    TargetType       = 'UserId'
                    CategoryActivity = 'ReferralUserId user validation'
                    CategoryReason   = "Referral User ID is scheduled for deactivation at $($refUserObj.EmployeeLeaveDateTime | Get-Date -Format 'o') Universal Time. A Cloud Administrator account can only be set up a maximum of 45 days before the planned leaving date."
                }))
        return
    }
    #endregion

    if ($refUserTypeDetails.IsInternal -eq $true) {

        #region Internal Accounts
        if (
            ($DedicatedAccount -eq $true) -and
            (($refUserObj.UserPrincipalName).Split('@')[1] -eq $AccountDomain) -and
            ($AllowSameDomainForReferralUser -ne $true)
        ) {
            $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                        Message          = "${ReferralUserId}: Internal Referral User ID must not use domain $AccountDomain."
                        ErrorId          = '403'
                        Category         = 'PermissionDenied'
                        TargetName       = $refUserObj.UserPrincipalName
                        TargetObject     = $refUserObj.Id
                        TargetType       = 'UserId'
                        CategoryActivity = 'ReferralUserId user validation'
                        CategoryReason   = "Internal Referral User ID must not use domain $AccountDomain which would be the same for the dedicated Cloud Administrator account."
                    }))
            return
        }

        if (
            ($refUserObj.UserPrincipalName).Split('@')[1] -match '^.+\.onmicrosoft\.com$'
        ) {
            $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                        Message          = "${ReferralUserId}: Internal Referral User ID must not use a onmicrosoft.com subdomain."
                        ErrorId          = '403'
                        Category         = 'PermissionDenied'
                        TargetName       = $refUserObj.UserPrincipalName
                        TargetObject     = $refUserObj.Id
                        TargetType       = 'UserId'
                        CategoryActivity = 'ReferralUserId user validation'
                        CategoryReason   = 'Internal Referral User ID must not use a onmicrosoft.com subdomain.'
                    }))
            return
        }

        if (
            ($true -eq $tenant.OnPremisesSyncEnabled) -and
            ($true -ne $refUserObj.OnPremisesSyncEnabled)
        ) {
            $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                        Message          = "${ReferralUserId}: Referral User ID must be a hybrid identity synced from on-premises directory."
                        ErrorId          = '403'
                        Category         = 'InvalidType'
                        TargetName       = $refUserObj.UserPrincipalName
                        TargetObject     = $refUserObj.Id
                        TargetType       = 'UserId'
                        CategoryActivity = 'ReferralUserId user validation'
                        CategoryReason   = "Referral User ID must be a hybrid identity synced from on-premises directory."
                    }))
            return
        }

        if (
            (-Not $refUserObj.Manager) -or
            (-Not $refUserObj.Manager.Id)
        ) {
            $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                        Message          = "${ReferralUserId}: Referral User ID must have manager property set."
                        ErrorId          = '403'
                        Category         = 'ResourceUnavailable'
                        TargetName       = $refUserObj.UserPrincipalName
                        TargetObject     = $refUserObj.Id
                        TargetType       = 'UserId'
                        CategoryActivity = 'ReferralUserId user validation'
                        CategoryReason   = 'Referral User ID must have manager property set.'
                    }))
            return
        }

        try {
            $refUserExObj = Get-EXOMailbox -ExternalDirectoryObjectId $refUserObj.Id -ErrorAction Stop
        }
        catch {
            $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                        Message          = "${ReferralUserId}: Referral User ID must have a mailbox."
                        ErrorId          = '403'
                        Category         = 'NotEnabled'
                        TargetName       = $refUserObj.UserPrincipalName
                        TargetObject     = $refUserObj.Id
                        TargetType       = 'UserId'
                        CategoryActivity = 'ReferralUserId user validation'
                        CategoryReason   = "Referral User ID must have a mailbox."
                    }))
            return
        }
        finally {
            Write-Verbose "Found existing mailbox for $($refUserObj.Id) ($($refUserObj.Id)) with PrimarySmtpAddress $($refUserExObj.PrimarySmtpAddress)"
        }

        if (('UserMailbox' -ne $refUserExObj.RecipientType) -or ('UserMailbox' -ne $refUserExObj.RecipientTypeDetails)) {
            $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                        Message          = "${ReferralUserId}: Referral User ID mailbox must be of type UserMailbox."
                        ErrorId          = '403'
                        Category         = 'InvalidType'
                        TargetName       = $refUserObj.UserPrincipalName
                        TargetObject     = $refUserObj.Id
                        TargetType       = 'UserId'
                        CategoryActivity = 'ReferralUserId user validation'
                        CategoryReason   = "Cloud Administrator accounts can not be created for user mailbox types of $($refUserExObj.RecipientTypeDetails)"
                    }))
            return
        }
        #endregion

    }

    else {

        #region Guest or External Accounts
        if (
            ([string]::IsNullOrEmpty($refUserTypeDetails.GuestOrExternalUserType)) -or
            ([string]::IsNullOrEmpty($AllowedGuestOrExternalUserTypes)) -or
            ($refUserTypeDetails.GuestOrExternalUserType -notin $AllowedGuestOrExternalUserTypes)
        ) {
            $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                        Message          = "${ReferralUserId}: Referral User ID is a guest or external user that can not be used for Cloud Administration in Tier $Tier."
                        ErrorId          = '403'
                        Category         = 'PermissionDenied'
                        TargetName       = $refUserObj.UserPrincipalName
                        TargetObject     = $refUserObj.Id
                        TargetType       = 'UserId'
                        CategoryActivity = 'ReferralUserId user validation'
                        CategoryReason   = "Referral User ID is of guest or external user type $($refUserTypeDetails.GuestOrExternalUserType)"
                    }))
            return
        }

        if ($DedicatedAccount -eq $true) {
            $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                        Message          = "${ReferralUserId}: Guest or external Referral User ID cannot have dedicated account created for Cloud Administration in Tier $Tier."
                        ErrorId          = '403'
                        Category         = 'PermissionDenied'
                        TargetName       = $refUserObj.UserPrincipalName
                        TargetObject     = $refUserObj.Id
                        TargetType       = 'UserId'
                        CategoryActivity = 'ReferralUserId user validation'
                        CategoryReason   = "Cloud Administration in Tier $Tier requires a dedicated account, but a guest or external account must not be used as Referral User ID."
                    }))
            return
        }
        #endregion

    }
    #endregion ---------------------------------------------------------------------

    #region No Dedicated User Account required -------------------------------------
    if ($DedicatedAccount -eq $false) {
        Write-Verbose "NO dedicated account required for Tier $Tier Cloud Administration, assigning ordinary user account directly instead."

        if ($PhotoUrlUser) {
            $script:returnInformation.Add(( .\Common_0000__Write-Information.ps1 @{
                        Message          = "${ReferralUserId}: User photo was not updated for ordinary user account."
                        Category         = 'NotEnabled'
                        TargetName       = $refUserObj.UserPrincipalName
                        TargetObject     = $refUserObj.Id
                        TargetType       = 'UserId'
                        CategoryActivity = 'Account Provisioning'
                        CategoryReason   = "Only dedicated Cloud Administration accounts may have their user photo updated."
                        Tags             = 'UserId', 'Account Provisioning'
                    }))
        }

        #region Group Membership Assignment --------------------------------------------
        if ($GroupObj) {
            $params = @{
                ConsistencyLevel = 'eventual'
                GroupId          = $GroupObj.Id
                CountVariable    = 'CountVar'
                Filter           = "Id eq '$($refUserObj.Id)'"
            }
            if (-Not (Get-MgBetaGroupMember @params)) {
                Write-Verbose "Implying manually adding user to static group $($GroupObj.DisplayName) ($($GroupObj.Id))"
                New-MgBetaGroupMember -GroupId $GroupObj.Id -DirectoryObjectId $refUserObj.Id
            }
        }
        else {
            $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                        Message          = "${ReferralUserId}: Internal configuration error."
                        ErrorId          = '500'
                        Category         = 'InvalidData'
                        TargetName       = $refUserObj.UserPrincipalName
                        TargetObject     = $refUserObj.Id
                        TargetType       = 'UserId'
                        CategoryActivity = 'Cloud Administrator Creation'
                        CategoryReason   = "A group must be configured for Tier $Tier Cloud Administration in variable AV_CloudAdminTier${Tier}_GroupId."
                    }))
            return
        }

        Write-Verbose "Nominated ordinary user account $($refUserObj.UserPrincipalName) ($($refUserObj.Id)) as Tier $Tier Cloud Administrator account" -Verbose
        #endregion ---------------------------------------------------------------------

        #region Add Return Data --------------------------------------------------------
        $data = @{
            Input        = @{
                ReferralUser = @{
                    Id                = $refUserObj.Id
                    UserPrincipalName = $refUserObj.UserPrincipalName
                    Mail              = $refUserObj.Mail
                    DisplayName       = $refUserObj.DisplayName
                }
                Tier         = $Tier
            }
            Manager      = @{
                Id                = $refUserObj.Manager.Id
                UserPrincipalName = $refUserObj.manager.AdditionalProperties.userPrincipalName
                Mail              = $refUserObj.manager.AdditionalProperties.mail
                DisplayName       = $refUserObj.manager.AdditionalProperties.displayName
            }
            UserPhotoUrl = $null
        }

        ForEach ($property in $userProperties) {
            if ($null -eq $data.$property) {
                $data.$property = $refUserObj.$property
            }
        }

        if ($UserPhotoUrl) { $data.Input.UserPhotoUrl = $UserPhotoUrl }
        if ($AdminUnitObj) { $data.AdministrativeUnit = $AdminUnitObj }

        if ($OutText) {
            Write-Output $(if ($data.UserPrincipalName) { $data.UserPrincipalName } else { $null })
        }
        #endregion ---------------------------------------------------------------------

        Write-Verbose "-------ENDLOOP $ReferralUserId ---"
        return $data
    }
    #endregion

    #region Prepare New User Account Properties ------------------------------------
    Write-Verbose "Dedicated account is required for Tier $Tier Cloud Administration"

    $UserPrefix = if (Get-Variable -ValueOnly -Name "UserPrincipalNamePrefix_Tier$Tier") {
        (Get-Variable -ValueOnly -Name "UserPrincipalNamePrefix_Tier$Tier") +
        $(if (Get-Variable -ValueOnly -Name "UserPrincipalNamePrefixSeparator_Tier$Tier") { Get-Variable -ValueOnly -Name "UserPrincipalNamePrefixSeparator_Tier$Tier" } else { '' } )
    }
    else { '' }

    $UserSuffix = if (Get-Variable -ValueOnly -Name "UserPrincipalNameSuffix_Tier$Tier") {
        $(if (Get-Variable -ValueOnly -Name "UserPrincipalNameSuffixSeparator_Tier$Tier") { Get-Variable -ValueOnly -Name "UserPrincipalNameSuffixSeparator_Tier$Tier" } else { '' } ) +
        (Get-Variable -ValueOnly -Name "UserPrincipalNameSuffix_Tier$Tier")
    }
    else { '' }

    if (-Not ($tenant.VerifiedDomains | Where-Object { $_.Name -eq $AccountDomain })) {
        $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                    Message           = "${ReferralUserId}: Missing verified domain."
                    ErrorId           = '500'
                    Category          = 'InvalidData'
                    TargetName        = $refUserObj.UserPrincipalName
                    TargetObject      = $refUserObj.Id
                    TargetType        = 'UserId'
                    RecommendedAction = "Add domain $AccountDomain to the list of verified domains of the tenant first."
                    CategoryActivity  = 'Cloud Administrator Creation'
                    CategoryReason    = "Domain $AccountDomain is not a verified domain of the tenant."
                }))
        return
    }

    if (-Not ($tenant.VerifiedDomains | Where-Object { ($_.Name -eq $AccountDomain) -and ($_.Capabilities.Split(', ') -contains 'Email') })) {
        $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                    Message           = "${ReferralUserId}: Missing email capability."
                    ErrorId           = '500'
                    Category          = 'InvalidData'
                    TargetName        = $refUserObj.UserPrincipalName
                    TargetObject      = $refUserObj.Id
                    TargetType        = 'UserId'
                    RecommendedAction = "Enable email capability for verfified domain $AccountDomain."
                    CategoryActivity  = 'Cloud Administrator Creation'
                    CategoryReason    = "Domain $AccountDomain has no email capability enabled."
                }))
        return
    }

    $BodyParamsNull = @{
        JobTitle = $null
    }
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
        UserPrincipalName             = $UserPrefix + ($refUserObj.UserPrincipalName).Split('@')[0] + $UserSuffix + '@' + $AccountDomain
        Mail                          = $UserPrefix + ($refUserObj.UserPrincipalName).Split('@')[0] + $UserSuffix + '@' + $AccountDomain
        MailNickname                  = $UserPrefix + $refUserObj.MailNickname + $UserSuffix
        PasswordPolicies              = 'DisablePasswordExpiration'
    }

    Write-Verbose 'Copying property DisplayName'
    $BodyParams.DisplayName = ''
    if (Get-Variable -ValueOnly -Name "UserDisplayNamePrefix_Tier$Tier") {
        Write-Verbose "Adding prefix to property DisplayName"
        $BodyParams.DisplayName += Get-Variable -ValueOnly -Name "UserDisplayNamePrefix_Tier$Tier"
        if (Get-Variable -ValueOnly -Name "UserDisplayNamePrefixSeparator_Tier$Tier") {
            $BodyParams.DisplayName += Get-Variable -ValueOnly -Name "UserDisplayNamePrefixSeparator_Tier$Tier"
        }
    }
    $BodyParams.DisplayName += $refUserObj.DisplayName
    if (Get-Variable -ValueOnly -Name "UserDisplayNameSuffix_Tier$Tier") {
        Write-Verbose "Adding suffix to property DisplayName"
        if (Get-Variable -ValueOnly -Name "UserDisplayNameSuffixSeparator_Tier$Tier") {
            $BodyParams.DisplayName += Get-Variable -ValueOnly -Name "UserDisplayNameSuffixSeparator_Tier$Tier"
        }
        $BodyParams.DisplayName += Get-Variable -ValueOnly -Name "UserDisplayNameSuffix_Tier$Tier"
    }

    if ($AccountTypeEmployeeType -eq $true) {
        if ([string]::IsNullOrEmpty($refUserObj.EmployeeType)) {
            Write-Verbose "Creating property EmployeeType"
            $BodyParams.EmployeeType = if (Get-Variable -ValueOnly -Name "AccountTypeEmployeeTypePrefix_Tier$Tier") {
                (Get-Variable -ValueOnly -Name "AccountTypeEmployeeTypePrefix_Tier$Tier")
            }
            elseif (Get-Variable -ValueOnly -Name "AccountTypeEmployeeTypeSuffix_Tier$Tier") {
                (Get-Variable -ValueOnly -Name "AccountTypeEmployeeTypeSuffix_Tier$Tier")
            }
            else { $null }
        }
        else {
            Write-Verbose "Copying property EmployeeType"
            $BodyParams.EmployeeType = ''
            if (Get-Variable -ValueOnly -Name "AccountTypeEmployeeTypePrefix_Tier$Tier") {
                Write-Verbose "Adding prefix to property EmployeeType"
                $BodyParams.EmployeeType += Get-Variable -ValueOnly -Name "AccountTypeEmployeeTypePrefix_Tier$Tier"
                if (Get-Variable -ValueOnly -Name "AccountTypeEmployeeTypePrefixSeparator_Tier$Tier") {
                    $BodyParams.EmployeeType += Get-Variable -ValueOnly -Name "AccountTypeEmployeeTypePrefixSeparator_Tier$Tier"
                }
            }
            $BodyParams.EmployeeType += $refUserObj.EmployeeType
            if (Get-Variable -ValueOnly -Name "AccountTypeEmployeeTypeSuffix_Tier$Tier") {
                Write-Verbose "Adding suffix to property EmployeeType"
                if (Get-Variable -ValueOnly -Name "AccountTypeEmployeeTypeSuffixSeparator_Tier$Tier") {
                    $BodyParams.EmployeeType += Get-Variable -ValueOnly -Name "AccountTypeEmployeeTypeSuffixSeparator_Tier$Tier"
                }
                $BodyParams.EmployeeType += Get-Variable -ValueOnly -Name "AccountTypeEmployeeTypeSuffix_Tier$Tier"
            }
        }

        if ($null -eq $BodyParams.EmployeeType) {
            $BodyParams.Remove('EmployeeType')
            $BodyParamsNull.EmployeeType = $null
        }
    }
    else {
        $BodyParamsNull.EmployeeType = $null
    }

    $extAttrAccountType = 'extensionAttribute' + $AccountTypeExtensionAttribute
    if (-Not [string]::IsNullOrEmpty($AccountTypeExtensionAttribute)) {
        if ([string]::IsNullOrEmpty($refUserObj.OnPremisesExtensionAttributes.$extAttrAccountType)) {
            Write-Verbose "Creating property $extAttrAccountType"
            $BodyParams.OnPremisesExtensionAttributes.$extAttrAccountType = if (Get-Variable -ValueOnly -Name "AccountTypeExtensionAttributePrefix_Tier$Tier") {
                (Get-Variable -ValueOnly -Name "AccountTypeExtensionAttributePrefix_Tier$Tier")
            }
            elseif (Get-Variable -ValueOnly -Name "AccountTypeExtensionAttributeSuffix_Tier$Tier") {
                (Get-Variable -ValueOnly -Name "AccountTypeExtensionAttributeSuffix_Tier$Tier")
            }
            else { $null }
        }
        else {
            Write-Verbose "Copying property $extAttrName"
            $BodyParams.OnPremisesExtensionAttributes.$extAttrName = ''
            if (Get-Variable -ValueOnly -Name "AccountTypeExtensionAttributePrefix_Tier$Tier") {
                Write-Verbose "Adding prefix to property EmployeeType"
                $BodyParams.EmployeeType += Get-Variable -ValueOnly -Name "AccountTypeExtensionAttributePrefix_Tier$Tier"
                if (Get-Variable -ValueOnly -Name "AccountTypeExtensionAttributePrefixSeparator_Tier$Tier") {
                    $BodyParams.EmployeeType += Get-Variable -ValueOnly -Name "AccountTypeExtensionAttributePrefixSeparator_Tier$Tier"
                }
            }
            $BodyParams.OnPremisesExtensionAttributes.$extAttrName += $refUserObj.EmployeeType
            if (Get-Variable -ValueOnly -Name "AccountTypeExtensionAttributeSuffix_Tier$Tier") {
                Write-Verbose "Adding suffix to property EmployeeType"
                if (Get-Variable -ValueOnly -Name "AccountTypeExtensionAttributeSuffixSeparator_Tier$Tier") {
                    $BodyParams.OnPremisesExtensionAttributes.$extAttrName += Get-Variable -ValueOnly -Name "AccountTypeExtensionAttributeSuffixSeparator_Tier$Tier"
                }
                $BodyParams.OnPremisesExtensionAttributes.$extAttrName += Get-Variable -ValueOnly -Name "AccountTypeExtensionAttributeSuffix_Tier$Tier"
            }
        }
    }

    if (
        [string]::IsNullOrEmpty($BodyParams.EmployeeType) -and
        [string]::IsNullOrEmpty($BodyParams.OnPremisesExtensionAttributes.$extAttrAccountType)
    ) {
        $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                    Message          = "${ReferralUserId}: Internal configuration error."
                    ErrorId          = '500'
                    Category         = 'InvalidData'
                    TargetName       = $refUserObj.UserPrincipalName
                    TargetObject     = $refUserObj.Id
                    TargetType       = 'UserId'
                    CategoryActivity = 'Cloud Administrator Creation'
                    CategoryReason   = "Either EmployeeType or extensionAttribute method must be configured to store account type."
                }))
        $persistentError = $true
        return
    }

    $extAttrRef = 'extensionAttribute' + $ReferenceExtensionAttribute
    if (-Not [string]::IsNullOrEmpty($ReferenceExtensionAttribute)) {
        if (
            (-Not [string]::IsNullOrEmpty($BodyParams.OnPremisesExtensionAttributes.$extAttrRef)) -or
            (-Not [string]::IsNullOrEmpty($refUserObj.OnPremisesExtensionAttributes.$extAttrRef))
        ) {
            $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                        Message          = "${ReferralUserId}: Internal configuration error."
                        ErrorId          = '500'
                        Category         = 'ResourceExists'
                        TargetName       = $refUserObj.UserPrincipalName
                        TargetObject     = $refUserObj.Id
                        TargetType       = 'UserId'
                        CategoryActivity = 'Cloud Administrator Creation'
                        CategoryReason   = "Reference extension attribute '$extAttrRef' must not be used by other IT services."
                    }))
            $persistentError = $true
            return
        }

        Write-Verbose "Creating property $extAttrRef"
        $BodyParams.OnPremisesExtensionAttributes.$extAttrRef = $refUserObj.Id
    }

    if (
        ($ReferenceManager -eq $false) -and
        [string]::IsNullOrEmpty($BodyParams.OnPremisesExtensionAttributes.$extAttrRef)
    ) {
        $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                    Message          = "${ReferralUserId}: Internal configuration error."
                    ErrorId          = '500'
                    Category         = 'InvalidData'
                    TargetName       = $refUserObj.UserPrincipalName
                    TargetObject     = $refUserObj.Id
                    TargetType       = 'UserId'
                    CategoryActivity = 'Cloud Administrator Creation'
                    CategoryReason   = "Either EmployeeType or extensionAttribute method must be configured to store account type."
                }))
        $persistentError = $true
        return
    }

    if (-Not [string]::IsNullOrEmpty($refUserObj.GivenName)) {
        Write-Verbose 'Copying property GivenName'
        $BodyParams.GivenName = $(
            if (Get-Variable -ValueOnly -Name "GivenNamePrefix_Tier$Tier") {
                Write-Verbose 'Adding prefix to property GivenName'
                (Get-Variable -ValueOnly -Name "GivenNamePrefix_Tier$Tier") +
                $(if (Get-Variable -ValueOnly -Name "GivenNamePrefixSeparator_Tier$Tier") { Get-Variable -ValueOnly -Name "GivenNamePrefixSeparator_Tier$Tier" } else { '' } )
            }
            else { '' }
        ) + $refUserObj.GivenName + $(
            if (Get-Variable -ValueOnly -Name "GivenNameSuffix_Tier$Tier") {
                Write-Verbose 'Adding suffix to property GivenName'
                $(if (Get-Variable -ValueOnly -Name "GivenNameSuffixSeparator_Tier$Tier") { Get-Variable -ValueOnly -Name "GivenNameSuffixSeparator_Tier$Tier" } else { '' } ) +
                (Get-Variable -ValueOnly -Name "GivenNameSuffix_Tier$Tier")
            }
            else { '' }
        )
    }

    ForEach ($property in $userProperties) {
        if (
            ($null -eq $BodyParams.$property) -and
            ($property -notin @(
                'Id'
                'UserType'
                'CreatedDateTime'
                'IsResourceAccount'
                'CreationType'
                'ExternalUserState'
                'Identities'
                'Mail'
            )) -and
            ($property -notmatch '^OnPremises')
        ) {
            # Empty or null values require special handling as of today
            if ([string]::IsNullOrEmpty($refUserObj.$property)) {
                Write-Verbose "Clearing property $property"
                $BodyParamsNull.$property = $null
            }
            else {
                Write-Verbose "Copying property $property"
                $BodyParams.$property = $refUserObj.$property
            }
        }
    }

    if ([string]::IsNullOrEmpty($BodyParams.UsageLocation) -and -not $GroupObj) {
        $BodyParams.UsageLocation = if ($tenant.DefaultUsageLocation) {
            Write-Verbose "Creating property UsageLocation from tenant DefaultUsageLocation"
            $tenant.DefaultUsageLocation
        }
        else {
            Write-Verbose "Creating property UsageLocation from tenant CountryLetterCode"
            $tenant.CountryLetterCode
        }
    }
    #endregion ---------------------------------------------------------------------

    #region Cleanup Soft-Deleted User Accounts -------------------------------------
    $params = @{
        OutputType = 'PSObject'
        Method     = 'GET'
        Headers    = @{ ConsistencyLevel = 'eventual' }
        Uri        = "https://graph.microsoft.com/beta/directory/deletedItems/microsoft.graph.user?`$count=true&`$filter=endsWith(UserPrincipalName,'$($BodyParams.UserPrincipalName)')"
    }
    $deletedUserList = Invoke-MgGraphRequest @params

    if ($deletedUserList.'@odata.count' -gt 0) {
        ForEach ($deletedUserObj in $deletedUserList.Value) {
            $script:returnInformation.Add(( .\Common_0000__Write-Information.ps1 @{
                        Message          = "${ReferralUserId}: Soft-deleted admin account $($deletedUserObj.UserPrincipalName) ($($deletedUserObj.Id)) was permanently deleted before re-creation."
                        Category         = 'ResourceExists'
                        TargetName       = $refUserObj.UserPrincipalName
                        TargetObject     = $refUserObj.Id
                        TargetType       = 'UserId'
                        CategoryActivity = 'Account Provisioning'
                        CategoryReason   = "An existing admin account was deleted before."
                        Tags             = 'UserId', 'Account Provisioning'
                    }))

            $params = @{
                OutputType = 'PSObject'
                Method     = 'DELETE'
                Uri        = "https://graph.microsoft.com/beta/directory/deletedItems/$($deletedUserObj.Id)"
            }
            Invoke-MgGraphRequest @params 1> $null
        }
    }
    #endregion ---------------------------------------------------------------------

    #region User Account Compliance Check -----------------------------------------
    $params = @{
        ConsistencyLevel = 'eventual'
        Count            = 'userCount'
        OrderBy          = 'UserPrincipalName'
        Filter           = @(
            "startsWith(UserPrincipalName, '$(($BodyParams.UserPrincipalName).Split('@')[0])@') or"
            "startsWith(Mail, '$(($BodyParams.Mail).Split('@')[0])@') or"
            "DisplayName eq '$($BodyParams.DisplayName)' or"
            "MailNickname eq '$($BodyParams.MailNickname)' or"
            "proxyAddresses/any(x:x eq 'smtp:$($BodyParams.Mail)')"
        ) -join ' '
    }
    $duplicatesObj = Get-MgBetaUser @params

    if ($userCount -gt 1) {
        Write-Warning "Admin account $($BodyParams.UserPrincipalName) is not mutually exclusive. $userCount existing accounts found: $( $duplicatesObj.UserPrincipalName )"

        $script:returnWarning.Add(( .\Common_0000__Write-Warning.ps1 @{
                    Message           = "${ReferralUserId}: Admin account must be mutually exclusive."
                    ErrorId           = '103'
                    Category          = 'ResourceExists'
                    TargetName        = $refUserObj.UserPrincipalName
                    TargetObject      = $refUserObj.Id
                    TargetType        = 'UserId'
                    RecommendedAction = "Delete conflicting administration account to comply with corporate compliance policy: $($duplicatesObj.UserPrincipalName)"
                    CategoryActivity  = 'Account Compliance'
                    CategoryReason    = "Other accounts were found using the same namespace."
                }))
    }
    #endregion ---------------------------------------------------------------------

    #region Create or Update User Account ------------------------------------------
    $params = @{
        UserId         = $BodyParams.UserPrincipalName
        Property       = $userProperties
        ExpandProperty = $userExpandPropeties
        ErrorAction    = 'SilentlyContinue'
    }
    $existingUserObj = Get-MgBetaUser @params

    if ($null -ne $existingUserObj) {
        if ($null -ne $existingUserObj.OnPremisesSyncEnabled) {
            $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                        Message           = "${ReferralUserId}: Conflicting Admin account $($existingUserObj.UserPrincipalName) ($($existingUserObj.Id)) $( if ($existingUserObj.OnPremisesSyncEnabled) { 'is' } else { 'was' } ) synced from on-premises."
                        ErrorId           = '500'
                        Category          = 'ResourceExists'
                        TargetName        = $refUserObj.UserPrincipalName
                        TargetObject      = $refUserObj.Id
                        TargetType        = 'UserId'
                        RecommendedAction = 'Manual deletion of this cloud object is required to resolve this conflict.'
                        CategoryActivity  = 'Cloud Administrator Creation'
                        CategoryReason    = "Conflicting Admin account $($existingUserObj.UserPrincipalName) ($($existingUserObj.Id)) $( if ($existingUserObj.OnPremisesSyncEnabled) { 'is' } else { 'was' } ) synced from on-premises."
                    }))
            return
        }

        $BodyParams.Remove('UserPrincipalName')
        $BodyParams.Remove('AccountEnabled')
        $params = @{
            UserId        = $existingUserObj.Id
            BodyParameter = $BodyParams
            Confirm       = $false
            ErrorAction   = 'Stop'
        }

        try {
            Update-MgBetaUser @params 1> $null
        }
        catch {
            $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                        Message          = $Error[0].Exception.Message
                        ErrorId          = '500'
                        Category         = $Error[0].CategoryInfo.Category
                        TargetName       = $refUserObj.UserPrincipalName
                        TargetObject     = $refUserObj.Id
                        TargetType       = 'UserId'
                        CategoryActivity = 'Account Provisioning'
                        CategoryReason   = $Error[0].CategoryInfo.Reason
                    }))
            return
        }

        if ($BodyParamsNull.Count -gt 0) {
            # Workaround as properties cannot be nulled using Update-MgBetaUser at the moment ...
            $params = @{
                OutputType  = 'PSObject'
                Method      = 'PATCH'
                Uri         = "https://graph.microsoft.com/beta/users/$($existingUserObj.Id)"
                Body        = $BodyParamsNull
                ErrorAction = 'Stop'
            }
            try {
                Invoke-MgGraphRequest @params 1> $null
            }
            catch {
                $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                            Message          = $Error[0].Exception.Message
                            ErrorId          = '500'
                            Category         = $Error[0].CategoryInfo.Category
                            TargetName       = $refUserObj.UserPrincipalName
                            TargetObject     = $refUserObj.Id
                            TargetType       = 'UserId'
                            CategoryActivity = 'Account Provisioning'
                            CategoryReason   = $Error[0].CategoryInfo.Reason
                        }))
                return
            }
        }
        $UserObj = Get-MgBetaUser -UserId $existingUserObj.Id
        $UpdatedUserOnly = $true
        Write-Verbose "Updated existing Tier $Tier Cloud Administrator account $($UserObj.UserPrincipalName) ($($UserObj.Id)) with information from $($refUserObj.UserPrincipalName) ($($refUserObj.Id))" -Verbose
    }
    else {
        #region License Availability Validation Before New Account Creation ------------
        $TenantLicensed = Get-MgBetaSubscribedSku -All | Where-Object { $_.SkuPartNumber -in $LicenseSkuPartNumbers } | Select-Object -Property Sku*, ConsumedUnits, ServicePlans -ExpandProperty PrepaidUnits
        ForEach ($Sku in $TenantLicensed) {
            if ($Sku.ConsumedUnits -ge $Sku.Enabled) {
                $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                            Message           = "${ReferralUserId}: License SkuPartNumber $($Sku.SkuPartNumber) has run out of free licenses."
                            ErrorId           = '503'
                            Category          = 'LimitsExceeded'
                            TargetName        = $refUserObj.UserPrincipalName
                            TargetObject      = $refUserObj.Id
                            TargetType        = 'UserId'
                            RecommendedAction = 'Purchase additional licenses to create new Cloud Administrator accounts.'
                            CategoryActivity  = 'License Availability Validation'
                            CategoryReason    = "License SkuPartNumber $($Sku.SkuPartNumber) has run out of free licenses."
                        }))
                $persistentError = $true
            }
            else {
                Write-Verbose "License SkuPartNumber $($Sku.SkuPartNumber) has at least 1 free license available to continue"
            }
        }
        if ($persistentError) { return }
        #endregion ---------------------------------------------------------------------

        $BodyParams.PasswordProfile = @{
            Password                             = .\Common_0000__Get-RandomPassword.ps1 -length 128 -minLower 8 -minUpper 8 -minNumber 8 -minSpecial 8
            ForceChangePasswordNextSignIn        = $false
            ForceChangePasswordNextSignInWithMfa = $false
        }

        try {
            $UserObj = New-MgBetaUser -BodyParameter $BodyParams -ErrorAction Stop
        }
        catch {
            $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                        Message          = $Error[0].Exception.Message
                        ErrorId          = '500'
                        Category         = $Error[0].CategoryInfo.Category
                        TargetName       = $refUserObj.UserPrincipalName
                        TargetObject     = $refUserObj.Id
                        TargetType       = 'UserId'
                        CategoryActivity = 'Account Provisioning'
                        CategoryReason   = $Error[0].CategoryInfo.Reason
                    }))
            return
        }

        # Wait for user provisioning consistency
        $DoLoop = $true
        $RetryCount = 1
        $MaxRetry = 30
        $WaitSec = 7
        $newUser = $UserObj

        do {
            $params = @{
                ConsistencyLevel = 'eventual'
                CountVariable    = 'CountVar'
                Filter           = "Id eq '$($newUser.Id)'"
                ErrorAction      = 'SilentlyContinue'
            }
            $UserObj = Get-MgBetaUser @params

            if ($null -ne $UserObj) {
                $DoLoop = $false
            }
            elseif ($RetryCount -ge $MaxRetry) {
                if (-Not $UpdatedUserOnly) {
                    Remove-MgBetaUser -UserId $newUser.Id -ErrorAction SilentlyContinue 1> $null
                }
                $DoLoop = $false

                $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                            Message           = "${ReferralUserId}: Account provisioning consistency timeout for $($newUser.UserPrincipalName)."
                            ErrorId           = '504'
                            Category          = 'OperationTimeout'
                            TargetName        = $refUserObj.UserPrincipalName
                            TargetObject      = $refUserObj.Id
                            TargetType        = 'UserId'
                            RecommendedAction = 'Try again later.'
                            CategoryActivity  = 'Account Provisioning'
                            CategoryReason    = "A timeout occured during provisioning wait after account creation."
                        }))
                return
            }
            else {
                $RetryCount += 1
                Write-Verbose "Try $RetryCount of ${MaxRetry}: Waiting another $WaitSec seconds for user provisioning consistency ..." -Verbose
                Start-Sleep -Seconds $WaitSec
            }
        } While ($DoLoop)

        Write-Verbose "Created new Tier $Tier Cloud Administrator account $($UserObj.UserPrincipalName) ($($UserObj.Id)) with information from $($refUserObj.UserPrincipalName) ($($refUserObj.Id))" -Verbose
    }

    if ($null -eq $UserObj) {
        $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                    Message          = "${ReferralUserId}: Could not create or update Tier $Tier Cloud Administrator account $($BodyParams.UserPrincipalName): $($Error[0].Message)"
                    ErrorId          = '503'
                    Category         = 'NotSpecified'
                    TargetName       = "$($refUserObj.UserPrincipalName): $($Error[0].CategoryInfo.TargetName)"
                    TargetObject     = $refUserObj.Id
                    TargetType       = 'UserId'
                    CategoryActivity = $Error[0].CategoryInfo.Activity
                    CategoryReason   = $Error[0].CategoryInfo.Reason
                }))
        return
    }
    #endregion ---------------------------------------------------------------------

    #region Update Admninistrative Unit Membership ---------------------------------
    $params = @{
        ConsistencyLevel     = 'eventual'
        AdministrativeUnitId = $AdminUnitObj.Id
        DirectoryObjectId    = $UserObj.Id
        ErrorAction          = 'SilentlyContinue'
    }
    if ($AdminUnitObj -and ($null -eq (Get-MgBetaAdministrativeUnitMemberAsUser @params))) {
        if (-not $AdminUnitObj.AdditionalProperties.membershipRuleProcessingState -or ($AdminUnitObj.AdditionalProperties.membershipRuleProcessingState -ne 'On')) {
            Write-Verbose "Adding account to Admin Unit $($AdminUnitObj.DisplayName) ($($AdminUnitObj.Id))"
            $params = @{
                OutputType  = 'PSObject'
                Method      = 'POST'
                Headers     = @{ ConsistencyLevel = 'eventual' }
                Uri         = "https://graph.microsoft.com/beta/directory/administrativeUnits/$($AdminUnitObj.Id)/members/`$ref"
                Body        = @{
                    '@odata.id' = "https://graph.microsoft.com/beta/users/$($UserObj.Id)"
                }
                ErrorAction = 'Stop'
            }

            try {
                Invoke-MgGraphRequest @params 1> $null
            }
            catch {
                $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                            Message          = $Error[0].Exception.Message
                            ErrorId          = '500'
                            Category         = $Error[0].CategoryInfo.Category
                            TargetName       = $refUserObj.UserPrincipalName
                            TargetObject     = $refUserObj.Id
                            TargetType       = 'UserId'
                            CategoryActivity = 'Account Provisioning'
                            CategoryReason   = $Error[0].CategoryInfo.Reason
                        }))
                return
            }
        }
        else {
            Write-Verbose "Admin Unit $($AdminUnitObj.DisplayName) ($($AdminUnitObj.Id)) as dynamic membership processing enabled; skipping manually adding account and wait for dynamic processing instead."
        }

        # Wait for admin unit membership
        $DoLoop = $true
        $RetryCount = 1
        $MaxRetry = 30
        $WaitSec = 7

        do {
            $params = @{
                ConsistencyLevel     = 'eventual'
                AdministrativeUnitId = $AdminUnitObj.Id
                DirectoryObjectId    = $UserObj.Id
                ErrorAction          = 'SilentlyContinue'
            }
            if ($null -ne (Get-MgBetaAdministrativeUnitMemberAsUser @params)) {
                Write-Verbose "OK: Detected admin unit membership."
                $DoLoop = $false
            }
            elseif ($RetryCount -ge $MaxRetry) {
                if (-Not $UpdatedUserOnly) {
                    Remove-MgBetaUser -UserId $UserObj.Id -ErrorAction SilentlyContinue 1> $null
                }
                $DoLoop = $false

                $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                            Message           = "${ReferralUserId}: Admin Unit assignment timeout for $($UserObj.UserPrincipalName)."
                            ErrorId           = '504'
                            Category          = 'OperationTimeout'
                            TargetName        = $refUserObj.UserPrincipalName
                            TargetObject      = $refUserObj.Id
                            TargetType        = 'UserId'
                            RecommendedAction = 'Try again later.'
                            CategoryActivity  = 'Account Provisioning'
                            CategoryReason    = "A timeout occured during provisioning wait after admin unit assignment."
                        }))
                return
            }
            else {
                $RetryCount += 1
                Write-Verbose "Try $RetryCount of ${MaxRetry}: Waiting another $WaitSec seconds for admin unit assignment ..." -Verbose
                Start-Sleep -Seconds $WaitSec
            }
        } While ($DoLoop)
    }
    #endregion ---------------------------------------------------------------------

    #region Update Manager Reference -----------------------------------------------
    if ($ReferenceManager -eq $true) {
        if (
            (-Not $existingUserObj) -or
            ($existingUserObj.Manager.Id -ne $refUserObj.Id)
        ) {
            if ($existingUserObj) {
                Write-Warning "Correcting Manager reference to $($refUserObj.UserPrincipalName) ($($refUserObj.Id))"
            }
            $NewManager = @{
                '@odata.id' = 'https://graph.microsoft.com/beta/users/' + $refUserObj.Id
            }
            try {
                Set-MgBetaUserManagerByRef -UserId $UserObj.Id -BodyParameter $NewManager -ErrorAction Stop 1> $null
            }
            catch {
                $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                            Message          = $Error[0].Exception.Message
                            ErrorId          = '500'
                            Category         = $Error[0].CategoryInfo.Category
                            TargetName       = $refUserObj.UserPrincipalName
                            TargetObject     = $refUserObj.Id
                            TargetType       = 'UserId'
                            CategoryActivity = 'Account Provisioning'
                            CategoryReason   = $Error[0].CategoryInfo.Reason
                        }))
                return
            }
        }
    }
    elseif (
        $existingUserObj -and
        ($null -ne $existingUserObj.Manager.Id)
    ) {
        Write-Warning "Removing Manager reference to $($existingUserObj.Manager.DisplayName) ($($existingUserObj.Manager.Id))"
        try {
            Remove-MgBetaUserManagerByRef -UserId $existingUserObj.Id -ErrorAction Stop
        }
        catch {
            $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                        Message          = $Error[0].Exception.Message
                        ErrorId          = '500'
                        Category         = $Error[0].CategoryInfo.Category
                        TargetName       = $refUserObj.UserPrincipalName
                        TargetObject     = $refUserObj.Id
                        TargetType       = 'UserId'
                        CategoryActivity = 'Account Provisioning'
                        CategoryReason   = $Error[0].CategoryInfo.Reason
                    }))
            return
        }
    }
    #endregion ---------------------------------------------------------------------

    #region License Availability Validation For Pre-Existing Account ---------------
    if (-Not $TenantLicensed) {
        $TenantLicensed = Get-MgBetaSubscribedSku -All | Where-Object { $_.SkuPartNumber -in $LicenseSkuPartNumbers } | Select-Object -Property Sku*, ConsumedUnits, ServicePlans -ExpandProperty PrepaidUnits
        ForEach ($Sku in $TenantLicensed) {
            if ($Sku.ConsumedUnits -ge $Sku.Enabled) {
                $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                            Message           = "${ReferralUserId}: License SkuPartNumber $($Sku.SkuPartNumber) has run out of free licenses."
                            ErrorId           = '503'
                            Category          = 'LimitsExceeded'
                            TargetName        = $refUserObj.UserPrincipalName
                            TargetObject      = $refUserObj.Id
                            TargetType        = 'UserId'
                            RecommendedAction = 'Purchase additional licenses to create new Cloud Administrator accounts.'
                            CategoryActivity  = 'License Availability Validation'
                            CategoryReason    = "License SkuPartNumber $($Sku.SkuPartNumber) has run out of free licenses."
                        }))
                $persistentError = $true
            }
            else {
                Write-Verbose "License SkuPartNumber $($Sku.SkuPartNumber) has at least 1 free license available to continue"
            }
        }
        if ($persistentError) { return }
    }
    #endregion ---------------------------------------------------------------------

    #region Direct License Assignment ----------------------------------------------
    if (-Not $GroupObj) {
        Write-Verbose "Implying direct license assignment is required as no GroupId was provided for group-based licensing."
        $UserLicensed = Get-MgBetaUserLicenseDetail -UserId $UserObj.Id
        $params = @{
            UserId         = $UserObj.Id
            AddLicenses    = [System.Collections.ArrayList]@()
            RemoveLicenses = [System.Collections.ArrayList]@()
            ErrorAction    = 'Stop'
        }

        ForEach ($SkuPartNumber in $LicenseSkuPartNumbers) {
            if (-Not ($UserLicensed | Where-Object { $_.SkuPartNumber -eq $SkuPartNumber })) {
                Write-Verbose "Adding missing license $SkuPartNumber"
                $Sku = $TenantLicensed | Where-Object { $_.SkuPartNumber -eq $SkuPartNumber }
                $license = @{
                    SkuId = $Sku.SkuId
                }
                if ($SkuPartNumber -eq $SkuPartNumberWithExchangeServicePlan) {
                    $license.DisabledPlans = $Sku.ServicePlans | Where-Object { ($_.AppliesTo -eq 'User') -and ($_.ServicePlanName -NotMatch 'EXCHANGE') } | Select-Object -ExpandProperty ServicePlanId
                }
                $params.AddLicenses += $license
            }
        }

        if (
            ($params.AddLicenses.Count -gt 0) -or
            ($params.RemoveLicenses.Count -gt 0)
        ) {
            try {
                Set-MgBetaUserLicense @params 1> $null
            }
            catch {
                $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                            Message          = $Error[0].Exception.Message
                            ErrorId          = '500'
                            Category         = $Error[0].CategoryInfo.Category
                            TargetName       = $refUserObj.UserPrincipalName
                            TargetObject     = $refUserObj.Id
                            TargetType       = 'UserId'
                            CategoryActivity = 'Account Provisioning'
                            CategoryReason   = $Error[0].CategoryInfo.Reason
                        }))
                return
            }
        }
    }
    #endregion ---------------------------------------------------------------------

    #region Group Membership Assignment --------------------------------------------
    if ($GroupObj) {
        if (
            ($GroupObj.GroupType -NotContains 'DynamicMembership') -or
            ($GroupObj.MembershipRuleProcessingState -ne 'On')
        ) {
            $params = @{
                ConsistencyLevel = 'eventual'
                GroupId          = $GroupObj.Id
                CountVariable    = 'CountVar'
                Filter           = "Id eq '$($UserObj.Id)'"
            }
            if (-Not (Get-MgBetaGroupMember @params)) {
                Write-Verbose "Adding user to static group $($GroupObj.DisplayName) ($($GroupObj.Id))"
                try {
                    New-MgBetaGroupMember -GroupId $GroupObj.Id -DirectoryObjectId $UserObj.Id -ErrorAction Stop
                }
                catch {
                    $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                                Message          = $Error[0].Exception.Message
                                ErrorId          = '500'
                                Category         = $Error[0].CategoryInfo.Category
                                TargetName       = $refUserObj.UserPrincipalName
                                TargetObject     = $refUserObj.Id
                                TargetType       = 'UserId'
                                CategoryActivity = 'Account Provisioning'
                                CategoryReason   = $Error[0].CategoryInfo.Reason
                            }))
                    return
                }
            }
        }

        # Wait for group membership
        $DoLoop = $true
        $RetryCount = 1
        $MaxRetry = 30
        $WaitSec = 7

        do {
            $params = @{
                ConsistencyLevel = 'eventual'
                GroupId          = $GroupObj.Id
                CountVariable    = 'CountVar'
                Filter           = "Id eq '$($UserObj.Id)'"
            }
            if ($null -ne (Get-MgBetaGroupMember @params)) {
                Write-Verbose "OK: Detected group memnbership."
                $DoLoop = $false
            }
            elseif ($RetryCount -ge $MaxRetry) {
                if (-Not $UpdatedUserOnly) {
                    Remove-MgBetaUser -UserId $UserObj.Id -ErrorAction SilentlyContinue 1> $null
                }
                $DoLoop = $false

                $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                            Message           = "${ReferralUserId}: Group assignment timeout for $($UserObj.UserPrincipalName)."
                            ErrorId           = '504'
                            Category          = 'OperationTimeout'
                            TargetName        = $refUserObj.UserPrincipalName
                            TargetObject      = $refUserObj.Id
                            TargetType        = 'UserId'
                            RecommendedAction = 'Try again later.'
                            CategoryActivity  = 'Account Provisioning'
                            CategoryReason    = "A timeout occured during provisioning wait after group assignment."
                        }))
                return
            }
            else {
                $RetryCount += 1
                Write-Verbose "Try $RetryCount of ${MaxRetry}: Waiting another $WaitSec seconds for group assignment ..." -Verbose
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
        $UserLicensed = Get-MgBetaUserLicenseDetail -UserId $UserObj.Id
        if (
            ($null -ne $UserLicensed) -and
            (
                $UserLicensed.ServicePlans | Where-Object {
                    ($_.AppliesTo -eq 'User') -and
                    ($_.ProvisioningStatus -eq 'Success') -and
                    ($_.ServicePlanName -Match 'EXCHANGE')
                }
            )
        ) {
            Write-Verbose "OK: Detected license provisioning completion."
            $DoLoop = $false
        }
        elseif ($RetryCount -ge $MaxRetry) {
            if (-Not $UpdatedUserOnly) {
                Remove-MgBetaUser -UserId $UserObj.Id -ErrorAction SilentlyContinue 1> $null
            }
            $DoLoop = $false

            $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                        Message           = "${ReferralUserId}: Exchange Online license activation timeout for $($UserObj.UserPrincipalName)."
                        ErrorId           = '504'
                        Category          = 'OperationTimeout'
                        TargetName        = $refUserObj.UserPrincipalName
                        TargetObject      = $refUserObj.Id
                        TargetType        = 'UserId'
                        RecommendedAction = 'Try again later.'
                        CategoryActivity  = 'Account Provisioning'
                        CategoryReason    = "A timeout occured during Exchange Online license activation."
                    }))
            return
        }
        else {
            $RetryCount += 1
            Write-Verbose "Try $RetryCount of ${MaxRetry}: Waiting another $WaitSec seconds for Exchange license assignment ..." -Verbose
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
        $userExObj = Get-EXOMailbox -ExternalDirectoryObjectId $UserObj.Id -ErrorAction SilentlyContinue
        if ($null -ne $userExObj) {
            Write-Verbose "OK: Detected mailbox provisioning completion."
            $DoLoop = $false
        }
        elseif ($RetryCount -ge $MaxRetry) {
            if (-Not $UpdatedUserOnly) {
                Remove-MgBetaUser -UserId $UserObj.Id -ErrorAction SilentlyContinue 1> $null
            }
            $DoLoop = $false

            $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                        Message           = "${ReferralUserId}: Mailbox provisioning timeout for $($UserObj.UserPrincipalName)."
                        ErrorId           = '504'
                        Category          = 'OperationTimeout'
                        TargetName        = $refUserObj.UserPrincipalName
                        TargetObject      = $refUserObj.Id
                        TargetType        = 'UserId'
                        RecommendedAction = 'Try again later.'
                        CategoryActivity  = 'Account Provisioning'
                        CategoryReason    = "A timeout occured during mailbox provisioning."
                    }))
            return
        }
        else {
            $RetryCount += 1
            Write-Verbose "Try $RetryCount of ${MaxRetry}: Waiting another $WaitSec seconds for mailbox creation ..." -Verbose
            Start-Sleep -Seconds $WaitSec
        }
    } While ($DoLoop)
    #endregion ---------------------------------------------------------------------

    #region Configure E-mail Forwarding --------------------------------------------
    $params = @{
        Identity                      = $userExObj.Identity
        ForwardingAddress             = $refUserExObj.Identity
        ForwardingSmtpAddress         = $null
        DeliverToMailboxAndForward    = $false
        HiddenFromAddressListsEnabled = $true
        WarningAction                 = 'SilentlyContinue'
        ErrorAction                   = 'Stop'
    }
    try {
        Set-Mailbox @params 1> $null
    }
    catch {
        $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                    Message          = $Error[0].Exception.Message
                    ErrorId          = '500'
                    Category         = $Error[0].CategoryInfo.Category
                    TargetName       = $refUserObj.UserPrincipalName
                    TargetObject     = $refUserObj.Id
                    TargetType       = 'UserId'
                    CategoryActivity = 'Account Provisioning'
                    CategoryReason   = $Error[0].CategoryInfo.Reason
                }))
        return
    }

    $userExMbObj = Get-Mailbox -Identity $userExObj.Identity
    $UserObj = Get-MgBetaUser -UserId $UserObj.Id -Property $userProperties -ExpandProperty $userExpandPropeties
    #endregion ---------------------------------------------------------------------

    #region Set User Photo ---------------------------------------------------------
    $SquareLogoRelativeUrl = if ($tenantBranding.SquareLogoRelativeUrl) {
        $tenantBranding.SquareLogoRelativeUrl
    }
    elseif ($tenantBranding.SquareLogoDarkRelativeUrl) {
        $tenantBranding.SquareLogoDarkRelativeUrl
    }
    else { $null }

    $PhotoUrl = $null
    $response = $null
    ForEach (
        $url in @(
            if ($PhotoUrlUser) { $PhotoUrlUser }
            if ($SquareLogoRelativeUrl) {
                ForEach ($Cdn in $tenantBranding.CdnList) {
                    "https://$Cdn/$SquareLogoRelativeUrl"
                }
            }
        )
    ) {
        $params = @{
            UseBasicParsing = $true
            Method          = 'GET'
            Uri             = $url
            TimeoutSec      = 10
            ErrorAction     = 'Stop'
        }

        try {
            $response = Invoke-WebRequest @params

            if ($response.StatusCode -eq 200) {
                if ($response.Headers.'Content-Type' -notmatch '^image/') {
                    Write-Error "Photo from URL '$($Url)' must have Content-Type 'image/*'."
                }
                else {
                    Write-Verbose "Successfully retrieved User Photo from $url"
                    $PhotoUrl = $url
                    break
                }
            }
        }
        catch {
            Write-Warning "Failed to retrieve User Photo from $url"
        }
    }
    if ($response) {
        $ExoUserPhoto = $false
        Write-Verbose 'Uploading User Photo to Microsoft Graph'
        $params = @{
            InFile      = 'nonExistat.lat'
            UserId      = $UserObj.Id
            Data        = ([System.IO.MemoryStream]::new($response.Content))
            ErrorAction = 'Stop'
        }
        try {
            Set-MgBetaUserPhotoContent @params 1> $null
        }
        catch {
            if ($AdminUnitObj) {
                $ExoUserPhoto = $true
                Write-Verbose "User $($UserObj.UserPrincipalName) ($($UserObj.Id)): Cannot use Microsoft Graph API to update User Photo. Open feature request at Microsoft to implement Administrative Unit support in Microsoft Graph API when using Set-MgUserPhotoContent. Also see 'https://go.microsoft.com/fwlink/p/?linkid=2249705'."
            }
            else {
                $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                            Message          = $Error[0].Exception.Message
                            ErrorId          = '500'
                            Category         = $Error[0].CategoryInfo.Category
                            TargetName       = $refUserObj.UserPrincipalName
                            TargetObject     = $refUserObj.Id
                            TargetType       = 'UserId'
                            CategoryActivity = 'Account Provisioning: Update User Photo (Microsoft Graph PowerShell)'
                            CategoryReason   = $Error[0].CategoryInfo.Reason
                        }))
            }
        }

        # This is a workaround that is announced to stop working in April 2024 due to Deprecation of Exchange Online PowerShell UserPhoto cmdlets: https://go.microsoft.com/fwlink/p/?linkid=2249705
        if ($ExoUserPhoto) {
            Write-Verbose 'Uploading User Photo to Exchange Online'
            $params = @{
                Identity    = $userExObj.Identity
                PictureData = $response.Content
                Confirm     = $false
                ErrorAction = 'Stop'
            }
            try {
                Set-UserPhoto @params 1> $null
            }
            catch {
                $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                            Message          = $Error[0].Exception.Message
                            ErrorId          = '500'
                            Category         = $Error[0].CategoryInfo.Category
                            TargetName       = $refUserObj.UserPrincipalName
                            TargetObject     = $refUserObj.Id
                            TargetType       = 'UserId'
                            CategoryActivity = 'Account Provisioning: Update User Photo (Exchange Online PowerShell)'
                            CategoryReason   = $Error[0].CategoryInfo.Reason
                        }))
            }
            finally {
                Write-Warning "User $($UserObj.UserPrincipalName) ($($UserObj.Id)): User Photo update used Exchange Online cmdlet Set-UserPhoto that is announced to stop working in April 2024 due to deprecation of Exchange Online PowerShell UserPhoto cmdlets, see 'https://go.microsoft.com/fwlink/p/?linkid=2249705'."
            }
        }
    }
    else {
        Write-Error "Failed to retrieve User Photo from all URLs"
    }
    #endregion ---------------------------------------------------------------------

    #region Add Return Data --------------------------------------------------------
    $data = @{
        Input                      = @{
            ReferralUser = @{
                Id                = $refUserObj.Id
                UserPrincipalName = $refUserObj.UserPrincipalName
                Mail              = $refUserObj.Mail
                DisplayName       = $refUserObj.DisplayName
            }
            Tier         = $Tier
        }
        IndirectManager            = @{
            Id                = $refUserObj.manager.Id
            UserPrincipalName = $refUserObj.manager.AdditionalProperties.userPrincipalName
            Mail              = $refUserObj.manager.AdditionalProperties.mail
            DisplayName       = $refUserObj.manager.AdditionalProperties.displayName
        }
        ForwardingAddress          = $userExMbObj.ForwardingAddress
        ForwardingSMTPAddress      = $userExMbObj.ForwardingSMTPAddress
        DeliverToMailboxandForward = $userExMbObj.DeliverToMailboxandForward
    }

    ForEach ($property in $userProperties) {
        if ($null -eq $data.$property) {
            $data.$property = $UserObj.$property
        }
    }

    if ($UserObj.Manager.Id) {
        $data.Manager = @{
            Id                = $UserObj.Manager.Id
            UserPrincipalName = $UserObj.manager.AdditionalProperties.userPrincipalName
            Mail              = $UserObj.manager.AdditionalProperties.mail
            DisplayName       = $UserObj.manager.AdditionalProperties.displayName
        }
    }
    else { $UserObj.Manager = @{} }

    if ($UserPhotoUrl) { $data.Input.UserPhotoUrl = $UserPhotoUrl }
    if ($PhotoUrl) { $data.UserPhotoUrl = $PhotoUrl }
    if ($AdminUnitObj) { $data.AdministrativeUnit = $AdminUnitObj }

    if ($OutText) {
        Write-Output $(if ($data.UserPrincipalName) { $data.UserPrincipalName } else { $null })
    }
    #endregion ---------------------------------------------------------------------

    Write-Verbose "-------ENDLOOP $ReferralUserId ---"

    return $data
}

0..$($ReferralUserId.Count) | & {
    process {
        if ([string]::IsNullOrEmpty($ReferralUserId[$_])) { return }
        if ([string]::IsNullOrEmpty($Tier[$_])) { return }
        [System.GC]::Collect()
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        $params = @{
            ReferralUserId = $ReferralUserId[$_]
            Tier           = $Tier[$_]
            UserPhotoUrl   = if ([string]::IsNullOrEmpty($UserPhotoUrl) -or [string]::IsNullOrEmpty($UserPhotoUrl[$_])) { $null } else { $UserPhotoUrl[$_] }
        }
        $returnOutput.Add((ProcessReferralUser @params))
    }
}
#endregion ---------------------------------------------------------------------

#region Output Return Data -----------------------------------------------------
$return.Output = $returnOutput
$return.Information = $returnInformation
$return.Warning = $returnWarning
$return.Error = $returnError
if ($returnError.Count -eq 0) { $return.Success = $true } else { $return.Success = $false }
$return.Job.EndTime = (Get-Date).ToUniversalTime()
$return.Job.Runtime = $return.Job.EndTime - $return.Job.StartTime
$return.Job.Waittime = $return.Job.CreationTime - $return.Job.StartTime

if ($Webhook) { .\Common_0000__Submit-Webhook.ps1 -Uri $Webhook -Body $return 1> $null }
$InformationPreference = $origInformationPreference
if (($true -eq $OutText) -or ($PSBoundParameters.Keys -contains 'OutJson') -and ($false -eq $OutJson)) { return }
if ($OutJson) { .\Common_0000__Write-JsonOutput.ps1 $return; return }

return $return
#endregion ---------------------------------------------------------------------
