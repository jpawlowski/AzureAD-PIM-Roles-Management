<#PSScriptInfo
.VERSION 0.9.0
.GUID 03b78b5d-1e83-44bc-83ce-a5c0f101461b
.AUTHOR Julian Pawlowski
.COMPANYNAME Workoho GmbH
.COPYRIGHT (c) 2024 Workoho GmbH. All rights reserved.
.TAGS TieringModel CloudAdministrator Identity Microsoft365 Security Azure Automation AzureAutomation
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
    Activate or update a user account for Cloud Administration in in Tier 0, 1, or 2

.DESCRIPTION
    For Tier 0 access, a dedicated cloud native account for is created and its lifecycle is bound to the referring account.
    For Tier 1 and Tier 2, the creation of a dedicated user account is optional depending on your custom configuration, so that only a precondition check is performed before the user is added to the respective security group.
    Also, external or guest accounts may be activated for Cloud Administration in Tier 1 or Tier 2.

    For dedicated admin accounts, User Principal Name and mail address use the initial .onmicrosoft.com domain of the respective Entra ID tenant, but may also be configured to use a custom domain.
    Other attributes are mostly copied from the referring user ID. The admin account holds a reference by using extensionAttribute14 conisting the object ID.
    To identify as a Cloud Administrator account, extensionAttribute15 reflects the respective Tier level so that it can be used for dynamic membership rules in administrative units and security groups.
    Permanent email forwarding to the referring user ID is configured to receive notifications, e.g. from Entra Privileged Identity Management so that admins are aware of expiring directory role assignments.

    For dedicated admin accounts that exist already, they will be updated with information from the referring user account.

    NOTE: This script uses the Microsoft Graph Beta API as it requires support for Restricted Management Administrative Units which is not available in the stable API.

.PARAMETER ReferralUserId
    User account identifier of the existing main user account. May be an Entra Identity Object ID or User Principal Name (UPN).
    External or guest accounts are converted to their local User Principal Name automatically.

.PARAMETER Tier
    The Tier level where access should be granted.

.PARAMETER UserPhotoUrl
    URL of an image that shall be set as default photo for the user. Must use HTTPS protocol, end with .jpg/.jpeg/.png/?*, and server must return image/* as Content-Type in HTTP header.
    If environment variable $env:AV_CloudAdminTier<Tier>_UserPhotoUrl is set, it will be used as a fallback option.
    In case no photo URL was provided at all, Entra square logo from organizational tenant branding will be used.
    The recommended size of the photo is 648x648 px.

.PARAMETER JobReference
    This information may be added for back reference in other IT systems. It will simply be added to the Job data.

.PARAMETER OutObject
    Output the result as object, e.g. when working with PowerShell pipelining.

.PARAMETER OutputJson
    Output the result in JSON format.
    This is useful when output data needs to be processed in other IT systems after the job was completed.

.PARAMETER OutText
    Output the generated User Principal Name only.

.OUTPUTS
    Output may be requested by using one of the parameters -OutObject, -OutputJson, or -OutText.
    Otherwise, a Success text output is generated, indicating if all referring user IDs where activated for Cloud Administration.

.NOTES
    CONDITIONS TO ENABLE A USER FOR CLOUD ADMINISTRATION
    ====================================================

    Depending on the requested Tier level, a dedicated Cloud Administrator account may be created, or the requesting account is enabled directly.
    For example, Tier 0 access always requires a dedicated Cloud Administrator account, while for Tier 1 access, the user account is activated directly.

    External or guest users may also be used for Cloud Administration, depending on the required Tier access.
    For example, Tier 0 and Tier 1 access is prohibited while Tier 2 access may be enabled.

    Depending if a referring user ID is internal or external, different preconditions are validated:

        Overall readiness:
             1. Tenant MUST be of type AAD / B2B (not B2C).
             2. Microsoft Graph permissions of the logged in user / application ID / managed identity.
             3. Entra directory permissions of the logged in user / application ID / managed identity.
             4. Exchange Online permissions of the logged in user / application ID / managed identity.
             5. Exchange Online subscription MUST exist in the tenant.
             6. Administrative Unit settings must be secure:
                - Admin units for Cloud Administration security groups and Tier 0 admin accounts MUST have Restricted Management enabled and visibility set to HiddenMembership. This may be optional for Tier 1 and Tier 2 admin units.
                - MUST NOT use dynamic membership for Cloud Administration groups.
                - SHOULD use dynamic membership for Tier 0, Tier 1, and Tier 2 admin accounts.
                - MUST NOT include devices and MUST only include either groups OR users.
             7. Security groups for Tier level access must be secure:
                - MUST NOT be synchronized from on-premises (and must never have been before)
                - MUST NOT be a Unified Group
                - MUST NOT be email enabled
                - MUST be protected by a Management Restricted Administrative Unit (preferred)
                - OR by having role assignment capablitity enabled (requires permanent Privileged Role Administrator assignment)
                - MUST NOT use dynamic membership for Tier 0, MAY use for Tier 1 and Tier 2 (not recommended). When no dedicated admin accounts are used, the group MUST be static.
                - SHOULD use a specified description to avoid addressing the wrong group
                - MUST NOT have any group owners assigned (otherwise, they will be removed immediately)

        All referring user IDs:
             1. MUST exist.
             2. MUST be enabled.
             3. MUST NOT be a resource account.
             4. MUST have a display name.
             5. When set, EmployeeHireDate MUST be in the past.
             6. When set, EmployeeLeaveDateTime MUST be more than 45 days in the future.
             7. Free license with Exchange Online plan MUST be available (only when dedicated account is created).

        Internal referring user IDs:
             1. MUST NOT use the same domain as a dedicated admin account (only when dedicated account is created).
             2. MUST NOT use any onmicrosoft.com domain.
             3. MUST be a hybrid user if tenant has on-premises directory synchronization enabled.
             4. MUST have a manager reference.
             5. MUST have a mailbox of type UserMailbox or RemoteUserMailbox if UPN domain WAS enabled for email.
             6. Mail property's domain name MUST have a valid MX record in DNS if UPN domain WAS NOT enabled for email.
             7. MUST have signed in within the last 14 days at least once.

        External referring user IDs:
             1. Must NOT use email OTP authentication.
             2. Must NOT be a Facebook identity.
             3. Must NOT be a Google identity.
             4. Must NOT be a personal Microsoft account.
             5. MAY be an external Microsoft Entra account (default setting: Tier 2 only).
             6. Must NOT be a federated identity.
             7. Mail property's domain name MUST have a valid MX record in DNS.
             8. MUST have a valid user type (default setting: Tier 2 only, may be internalGuest / b2bCollaborationGuest / b2bCollaborationMember)
             9. MUST have redeemed any guest invitation.
            10. MUST have signed in within the last 30 days at least once.
            11. MUST NOT be used when dedicated account is required.

    If a dedicated Cloud Administrator account is required for the respective Tier, the following conditions are checked:

             1. In case an existing Cloud Administrator account was found for referral user ID, it must be a cloud native account to be updated.
                Otherwise an error is returned and manual cleanup of the on-premises synced account is required to resolve the conflict.
             2. If an existing Cloud administrator account was soft-deleted before, it will be permanently deleted before re-creating the account.
             3. The user part of the Cloud Administrator account must be mutually exclusive to the tenant.
                A warning will be generated if there is other accounts using either a similar User Principal Name or same Display Name, Mail, Mail Nickname, or ProxyAddress.


    DIFFERENTIATE BETWEEN INTERNAL AND EXTERNAL USER ACCOUNTS
    =========================================================

    The type of external user is determined based on the definition of guestOrExternalUserTypes defined here:
    https://learn.microsoft.com/en-us/graph/api/resources/conditionalaccessguestsorexternalusers?view=graph-rest-beta#properties

    That means, a user account is only considered internal if these prerequisites are met:

        1. Must NOT use email OTP authentication.
        2. Must NOT be a Facebook identity.
        3. Must NOT be a Google identity.
        4. Must NOT be a personal Microsoft account.
        5. Must NOT be an external Microsoft Entra identity.
        6. Must NOT be a federated identity.
        7. Must NOT have any value for GuestOrExternalUserType (value MUST be 'None').

    In all other cases, the user account is considered external.


    CUSTOM CONFIGURATION SETTINGS
    =============================

    Configuration settings can be obtained from CloudAdmin_0000__Common_0000__Get-ConfigurationConstants.ps1.

.EXAMPLE
    CloudAdmin_0100__New-CloudAdministrator-Account-V1.ps1 -ReferralUserId first.last@example.com -Tier 0

.EXAMPLE
    CloudAdmin_0100__New-CloudAdministrator-Account-V1.ps1 -ReferralUserId first.last@example.com -Tier 0 -UserPhotoUrl https://example.com/assets/Tier0-Admins.png

    Provide a different URL for the photo to be uploaded to the new Cloud Administrator account.

.EXAMPLE
    $csv = Get-Content list.csv | ConvertFrom-Csv; CloudAdmin_0100__New-CloudAdministrator-Account-V1.ps1 -ReferralUserId $csv.ReferralUserId -Tier $csv.Tier -UserPhotoUrl $csv.UserPhotoUrl

    BATCH PROCESSING
    ================

    Azure Automation has limited support for regular PowerShell pipelining as it does not process inline execution of child runbooks within Begin/End blocks.
    Therefore, classic PowerShell pipelining does NOT work. Instead, an array can be used to provide the required input data.
    The advantage is that the script will run more efficient as some tasks only need to be performed once per batch instead of each individual account.

    The CSV must have the following format:

    ReferralUserId,Tier,UserPhotoUrl,
    user1@contoso.com,0,,
    user2@contoso.com,0,https://www.example.com/photo.jpg,
#>

#region TODO:
#- Check that admin unit contains only groups/users as per intention
#- Let requester decide to always create a dedicated account if desired
#- concurrent job testing
#- regex check for UPN which is currently commented out
#- find existing account not only by UPN but also extensionAttribute and manager and EmployeeType
#- Install PowerShell modules that are mentioned as "requires" but do not update existing ones, just to support the initial run of the script
#- review import modules / beta vs. v1.0 and check memory consumption in azure automation
#- review documentation
#- create visual
#endregion

[CmdletBinding()]
Param (
    [Parameter(mandatory = $true)]
    [Array]$ReferralUserId,

    [Parameter(mandatory = $true)]
    [Array]$Tier,

    [Array]$UserPhotoUrl,
    [Boolean]$OutJson,
    [Boolean]$OutText,
    [Boolean]$OutObject,
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
    'AuditLog.Read.All'
    'User.ReadWrite.All'
    'Directory.Read.All'
    'Group.ReadWrite.All'
    'Organization.Read.All'
    'OnPremDirectorySynchronization.Read.All'
    'Mail.Send'
) 1> $null
#endregion ---------------------------------------------------------------------

#region [COMMON] ENVIRONMENT ---------------------------------------------------
.\Common_0002__Import-AzAutomationVariableToPSEnv.ps1 1> $null      # Implicitly connects to Azure Cloud
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

$returnOutput = [System.Collections.ArrayList]::new()
$returnInformation = [System.Collections.ArrayList]::new()
$returnWarning = [System.Collections.ArrayList]::new()
$returnError = [System.Collections.ArrayList]::new()
$return = @{
    Job = .\Common_0003__Get-AzAutomationJobInfo.ps1
}
if ($JobReference) { $return.Job.Reference = $JobReference }
#endregion ---------------------------------------------------------------------

#region Tenant Validation ------------------------------------------------------
if (
    ($null -ne $tenant.tenantType) -and
    ($tenant.tenantType -ne 'AAD')
) {
    Throw "Tenant $($tenant.DisplayName) ($($tenant.Id)) must be of type AAD but is of type $($tenant.tenantType)."
}
elseif (
    ($null -ne $tenant.AdditionalProperties.tenantType) -and
    ($tenant.AdditionalProperties.tenantType -ne 'AAD')
) {
    Throw "Tenant $($tenant.DisplayName) ($($tenant.Id)) must be of type AAD but is of type $($tenant.AdditionalProperties.tenantType)."
}
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

        if ($GroupObj.Visibility -ne 'Private') {
            Write-Warning "Group $($GroupObj.DisplayName) ($($GroupObj.Id)): Correcting visibility to Private for Cloud Administration."
            try {
                Update-MgBetaGroup -GroupId $GroupObj.Id -Visibility 'Private' -ErrorAction Stop 1> $null
            }
            catch {
                Throw $_
            }
        }

        $GroupObj.Owners | & {
            process {
                Write-Warning "Group $($GroupObj.DisplayName) ($($GroupObj.Id)): Removing unwanted group owner $($_.Id)."
                try {
                    Remove-MgBetaGroupOwnerByRef -GroupId $GroupObj.Id -DirectoryObjectId $_.Id -ErrorAction Stop 1> $null
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
.\Common_0003__Confirm-MgAppPermission.ps1 -Permissions @( #TODO child runbook doesnt actually work
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
function ProcessReferralUser ($ReferralUserId, $LocalUserId, $Tier, $UserPhotoUrl) {
    Write-Verbose "-----STARTLOOP $ReferralUserId, Tier $Tier ---"

    #region [COMMON] LOOP HANDLING -------------------------------------------------
    # Only process items if there was no error during script initialization before
    if (($Iteration -eq 0) -and ($returnError.Count -gt 0)) { $script:persistentError = $true }
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
    $AllowFacebookAccount = Get-Variable -ValueOnly -Name "AllowFacebookAccount_Tier$Tier"
    $AllowGoogleAccount = Get-Variable -ValueOnly -Name "AllowGoogleAccount_Tier$Tier"
    $AllowMicrosoftAccount = Get-Variable -ValueOnly -Name "AllowMicrosoftAccount_Tier$Tier"
    $AllowExternalEntraAccount = Get-Variable -ValueOnly -Name "AllowExternalEntraAccount_Tier$Tier"
    $AllowFederatedAccount = Get-Variable -ValueOnly -Name "AllowFederatedAccount_Tier$Tier"
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
    if ($LocalUserId -notmatch $regex) {
        $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                    Message           = "${ReferralUserId}: LocalUserId is invalid ($LocalUserId)"
                    ErrorId           = '400'
                    Category          = 'SyntaxError'
                    TargetName        = $ReferralUserId
                    TargetObject      = $null
                    TargetType        = 'UserId'
                    RecommendedAction = 'Provide either User Principal Name, or Object ID (UUID).'
                    CategoryActivity  = 'ReferralUserId parameter validation'
                    CategoryReason    = "Parameter LocalUserId was converted from ReferralUserId and does not match $regex"
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
        UserId         = $LocalUserId
        Property       = $userProperties
        ExpandProperty = $userExpandPropeties
        ErrorAction    = 'Stop'
    }
    try {
        $refUserObj = Get-MgBetaUser @params
        $refUserObj.SignInActivity = (Get-MgBetaUser -UserId $refUserObj.Id -Property SignInActivity -ErrorAction Stop).SignInActivity
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
    if ($refUserObj.AccountEnabled -ne $true) {
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

    #TODO check
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

    $refUserTypeDetails = .\Common_0002__Get-MgUserTypeDetail.ps1 -UserObject $refUserObj
    if ($null -eq $refUserTypeDetails.IsInternal) {
        $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                    Message          = "${ReferralUserId}: Referral User ID internal/external state could not be determined."
                    ErrorId          = '403'
                    Category         = 'OperationStopped'
                    TargetName       = $refUserObj.UserPrincipalName
                    TargetObject     = $refUserObj.Id
                    TargetType       = 'UserId'
                    CategoryActivity = 'ReferralUserId user validation'
                    CategoryReason   = "Referral User ID internal/external state could not be determined."
                }))
        return
    }

    if ($refUserTypeDetails.IsInternal -eq $true) {

        #region Internal Accounts
        Write-Verbose "${ReferralUserId} is classified as internal user"

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
                        CategoryActivity = 'ReferralUserId internal user validation'
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
                        CategoryActivity = 'ReferralUserId internal user validation'
                        CategoryReason   = 'Internal Referral User ID must not use a onmicrosoft.com subdomain.'
                    }))
            return
        }

        if (
            ($tenant.OnPremisesSyncEnabled -eq $true) -and
            ($refUserObj.OnPremisesSyncEnabled -ne $true)
        ) {
            $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                        Message          = "${ReferralUserId}: Referral User ID must be a hybrid identity synced from on-premises directory."
                        ErrorId          = '403'
                        Category         = 'InvalidType'
                        TargetName       = $refUserObj.UserPrincipalName
                        TargetObject     = $refUserObj.Id
                        TargetType       = 'UserId'
                        CategoryActivity = 'ReferralUserId internal user validation'
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
                        CategoryActivity = 'ReferralUserId internal user validation'
                        CategoryReason   = 'Referral User ID must have manager property set.'
                    }))
            return
        }

        if (
            ($tenant.VerifiedDomains | Where-Object { $_.Name -eq $(($refUserObj.UserPrincipalName).Split('@')[1]) }).Capabilities.Split(', ') -contains 'Email'
        ) {
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
                            CategoryActivity = 'ReferralUserId internal user validation'
                            CategoryReason   = "Referral User ID must have a mailbox."
                        }))
                return
            }

            Write-Verbose "Found internal mailbox for $($refUserObj.UserPrincipalName) ($($refUserObj.Id)) with email $($refUserExObj.Mail) and PrimarySmtpAddress $($refUserExObj.PrimarySmtpAddress)"

            if (
                ($refUserExObj.RecipientType -notmatch '^(?:Remote)?UserMailbox$') -or
                ($refUserExObj.RecipientTypeDetails -notmatch '^(?:Remote)?UserMailbox$')
            ) {
                $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                            Message          = "${ReferralUserId}: Referral User ID mailbox must be of type UserMailbox or RemoteUserMailbox."
                            ErrorId          = '403'
                            Category         = 'InvalidType'
                            TargetName       = $refUserObj.UserPrincipalName
                            TargetObject     = $refUserObj.Id
                            TargetType       = 'UserId'
                            CategoryActivity = 'ReferralUserId internal user validation'
                            CategoryReason   = "Cloud Administrator accounts can not be created for user mailbox type of $($refUserExObj.RecipientTypeDetails)"
                        }))
                return
            }
        }
        else {
            $validateRefUserDomainMX = $false
            $refUserDomainMX = $null

            if (Get-Module -ListAvailable -Name DnsClient) {
                $validateRefUserDomainMX = $true

                .\Common_0000__Import-Module.ps1 -Modules @(
                    @{ Name = 'DnsClient'; Cmdlet = 'Resolve-DnsName'; Function = 'Resolve-DnsName' }
                ) 1> $null

                $refUserDomainMX = Resolve-DnsName (($refUserObj.Mail).Split('@')[1]) -Type MX -ErrorAction SilentlyContinue
            }
            elseif (Get-Module -ListAvailable -Name DnsClient-PS) {
                $validateRefUserDomainMX = $true

                .\Common_0000__Import-Module.ps1 -Modules @(
                    @{ Name = 'DnsClient-PS'; Cmdlet = 'Resolve-DnsName'; Function = 'Resolve-Dns' }
                ) 1> $null

                $refUserDomainMX = (Resolve-Dns -Query (($refUserObj.Mail).Split('@')[1]) -QueryType MX -Timeout (New-Timespan -Sec 30) -ContinueOnDnsError:$false -ContinueOnEmptyResponse:$false -ErrorAction SilentlyContinue).Answers
            }
            else {
                Write-Warning 'Missing PowerShell module DnsClient-PS to validate MX record.'
            }

            if ($validateRefUserDomainMX -and -not $refUserDomainMX) {
                $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                            Message          = "${ReferralUserId}: Referral User ID must be able to receive emails."
                            ErrorId          = '403'
                            Category         = 'PermissionDenied'
                            TargetName       = $refUserObj.UserPrincipalName
                            TargetObject     = $refUserObj.Id
                            TargetType       = 'UserId'
                            CategoryActivity = 'ReferralUserId internal user validation'
                            CategoryReason   = "Referral User ID domain MX record could not be found in DNS."
                        }))
                return
            }

            Write-Verbose "Implying external mailbox exists for $($refUserObj.UserPrincipalName) ($($refUserObj.Id)) with email $($refUserObj.Mail), based on existing MX DNS record"
        }

        if (
            -Not ($refUserObj.SignInActivity) -or
            -Not ($refUserObj.SignInActivity.LastSignInDateTime) -or
            -Not ($refUserObj.SignInActivity.LastNonInteractiveSignInDateTime) -or
            (
                ($refUserObj.SignInActivity.LastSignInDateTime -lt $return.Job.CreationTime.AddDays(-14)) -and
                ($refUserObj.SignInActivity.LastNonInteractiveSignInDateTime -lt $return.Job.CreationTime.AddDays(-14))
            )
        ) {
            $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                        Message           = "${ReferralUserId}: Referral User ID must be in active use within the last 14 days."
                        ErrorId           = '403'
                        Category          = 'PermissionDenied'
                        TargetName        = $refUserObj.UserPrincipalName
                        TargetObject      = $refUserObj.Id
                        TargetType        = 'UserId'
                        RecommendedAction = 'Make sure the user as logged in within the last 14 days at least once.'
                        CategoryActivity  = 'ReferralUserId internal user validation'
                        CategoryReason    = "Referral User ID must be in active use within the last 14 days."
                    }))
            return
        }
        #endregion

    }

    else {

        #region Guest or External Accounts
        Write-Verbose "${ReferralUserId} is classified as external user"

        if ($refUserTypeDetails.IsEmailOTPAuthentication -ne $false) {
            $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                        Message          = "${ReferralUserId}: Referral User ID must not use email one-time passcode authentication."
                        ErrorId          = '403'
                        Category         = 'PermissionDenied'
                        TargetName       = $refUserObj.UserPrincipalName
                        TargetObject     = $refUserObj.Id
                        TargetType       = 'UserId'
                        CategoryActivity = 'ReferralUserId external user validation'
                        CategoryReason   = 'Referral User ID has defined identity details that indicate email one-time passcode authentication.'
                    }))
            return
        }

        if (
            ($refUserTypeDetails.IsFacebookAccount -ne $false) -and
            ($AllowFacebookAccount -ne $true)
        ) {
            $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                        Message          = "${ReferralUserId}: Referral User ID must not be a facebook.com identity."
                        ErrorId          = '403'
                        Category         = 'PermissionDenied'
                        TargetName       = $refUserObj.UserPrincipalName
                        TargetObject     = $refUserObj.Id
                        TargetType       = 'UserId'
                        CategoryActivity = 'ReferralUserId external user validation'
                        CategoryReason   = 'Referral User ID has defined identity Issuer of facebook.com.'
                    }))
            return
        }

        if (
            ($refUserTypeDetails.IsGoogleAccount -ne $false) -and
            ($AllowGoogleAccount -ne $true)
        ) {
            $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                        Message          = "${ReferralUserId}: Referral User ID must not be a google.com identity."
                        ErrorId          = '403'
                        Category         = 'PermissionDenied'
                        TargetName       = $refUserObj.UserPrincipalName
                        TargetObject     = $refUserObj.Id
                        TargetType       = 'UserId'
                        CategoryActivity = 'ReferralUserId external user validation'
                        CategoryReason   = 'Referral User ID has defined identity Issuer of google.com.'
                    }))
            return
        }

        if (
            ($refUserTypeDetails.IsMicrosoftAccount -ne $false) -and
            ($AllowMicrosoftAccount -ne $true)
        ) {
            $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                        Message          = "${ReferralUserId}: Referral User ID must not be a personal Microsoft account."
                        ErrorId          = '403'
                        Category         = 'PermissionDenied'
                        TargetName       = $refUserObj.UserPrincipalName
                        TargetObject     = $refUserObj.Id
                        TargetType       = 'UserId'
                        CategoryActivity = 'ReferralUserId external user validation'
                        CategoryReason   = 'Referral User ID has defined identity Issuer of MicrosoftAccount.'
                    }))
            return
        }

        if (
            ($refUserTypeDetails.IsExternalEntraAccount -ne $false) -and
            ($AllowExternalEntraAccount -ne $true)
        ) {
            $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                        Message          = "${ReferralUserId}: Referral User ID must not be an external Microsoft Entra identity."
                        ErrorId          = '403'
                        Category         = 'PermissionDenied'
                        TargetName       = $refUserObj.UserPrincipalName
                        TargetObject     = $refUserObj.Id
                        TargetType       = 'UserId'
                        CategoryActivity = 'ReferralUserId external user validation'
                        CategoryReason   = 'Referral User ID has defined identity Issuer of ExternalAzureAD.'
                    }))
            return
        }

        if (
            ($refUserTypeDetails.IsFederated -ne $false) -and
            ($AllowFederatedAccount -ne $true) -and
            ($refUserTypeDetails.IsFacebookAccount -ne $true) -and
            ($refUserTypeDetails.IsGoogleAccount -ne $true) -and
            ($refUserTypeDetails.IsMicrosoftAccount -ne $true) -and
            ($refUserTypeDetails.IsExternalEntraAccount -ne $true)
        ) {
            $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                        Message          = "${ReferralUserId}: Referral User ID must not be a federated identity."
                        ErrorId          = '403'
                        Category         = 'PermissionDenied'
                        TargetName       = $refUserObj.UserPrincipalName
                        TargetObject     = $refUserObj.Id
                        TargetType       = 'UserId'
                        CategoryActivity = 'ReferralUserId external user validation'
                        CategoryReason   = 'Referral User ID has defined identity SignInType of federated, and issuer is not facebook.com, google.com, MicrosoftAccount, or ExternalAzureAD.'
                    }))
            return
        }

        $validateRefUserDomainMX = $false
        $refUserDomainMX = $null

        if (Get-Module -ListAvailable -Name DnsClient) {
            $validateRefUserDomainMX = $true

            .\Common_0000__Import-Module.ps1 -Modules @(
                @{ Name = 'DnsClient'; Cmdlet = 'Resolve-DnsName'; Function = 'Resolve-DnsName' }
            ) 1> $null

            $refUserDomainMX = Resolve-DnsName (($refUserObj.Mail).Split('@')[1]) -Type MX -ErrorAction SilentlyContinue
        }
        elseif (Get-Module -ListAvailable -Name DnsClient-PS) {
            $validateRefUserDomainMX = $true

            .\Common_0000__Import-Module.ps1 -Modules @(
                @{ Name = 'DnsClient-PS'; Cmdlet = 'Resolve-DnsName'; Function = 'Resolve-Dns' }
            ) 1> $null

            $refUserDomainMX = (Resolve-Dns -Query (($refUserObj.Mail).Split('@')[1]) -QueryType MX -Timeout (New-Timespan -Sec 30) -ContinueOnDnsError:$false -ContinueOnEmptyResponse:$false -ErrorAction SilentlyContinue).Answers
        }
        else {
            Write-Warning 'Missing PowerShell module DnsClient-PS to validate MX record.'
        }

        if ($validateRefUserDomainMX -and -not $refUserDomainMX) {
            $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                        Message          = "${ReferralUserId}: Referral User ID must be able to receive emails."
                        ErrorId          = '403'
                        Category         = 'PermissionDenied'
                        TargetName       = $refUserObj.UserPrincipalName
                        TargetObject     = $refUserObj.Id
                        TargetType       = 'UserId'
                        CategoryActivity = 'ReferralUserId external user validation'
                        CategoryReason   = "Referral User ID domain MX record could not be found in DNS."
                    }))
            return
        }

        Write-Verbose "Implying external mailbox exists for $($refUserObj.UserPrincipalName) ($($refUserObj.Id)) with email $($refUserObj.Mail), based on existing MX DNS record"

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
                        CategoryActivity = 'ReferralUserId external user validation'
                        CategoryReason   = "Referral User ID is of guest or external user type $($refUserTypeDetails.GuestOrExternalUserType)"
                    }))
            return
        }

        if (
            (-Not [string]::IsNullOrEmpty($refUserObj.ExternalUserState)) -and
            ($refUserObj.ExternalUserState -ne 'Accepted')
        ) {
            $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                        Message          = "${ReferralUserId}: Referral User ID is a guest or external user and must have accepted its invitation to be activated for Cloud Administration."
                        ErrorId          = '403'
                        Category         = 'PermissionDenied'
                        TargetName       = $refUserObj.UserPrincipalName
                        TargetObject     = $refUserObj.Id
                        TargetType       = 'UserId'
                        CategoryActivity = 'ReferralUserId external user validation'
                        CategoryReason   = "Referral User ID has ExternalUserState of '$($refUserObj.ExternalUserState)'"
                    }))
            return
        }

        if (
            -Not ($refUserObj.SignInActivity) -or
            -Not ($refUserObj.SignInActivity.LastSignInDateTime) -or
            -Not ($refUserObj.SignInActivity.LastNonInteractiveSignInDateTime) -or
            (
                ($refUserObj.SignInActivity.LastSignInDateTime -lt $return.Job.CreationTime.AddDays(-30)) -and
                ($refUserObj.SignInActivity.LastNonInteractiveSignInDateTime -lt $return.Job.CreationTime.AddDays(-30))
            )
        ) {
            $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                        Message           = "${ReferralUserId}: Referral User ID must be in active use within the last 30 days."
                        ErrorId           = '403'
                        Category          = 'PermissionDenied'
                        TargetName        = $refUserObj.UserPrincipalName
                        TargetObject      = $refUserObj.Id
                        TargetType        = 'UserId'
                        RecommendedAction = 'Make sure the external user as logged in to the resource tenant within the last 30 days at least once.'
                        CategoryActivity  = 'ReferralUserId external user validation'
                        CategoryReason    = "Referral User ID must be in active use within the last 30 days."
                    }))
            return
        }

        if ($DedicatedAccount -eq $true) {
            #TODO let guest users in Tier2 own dedicated accounts
            $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                        Message          = "${ReferralUserId}: Guest or external Referral User ID cannot have dedicated account created for Cloud Administration in Tier $Tier."
                        ErrorId          = '403'
                        Category         = 'PermissionDenied'
                        TargetName       = $refUserObj.UserPrincipalName
                        TargetObject     = $refUserObj.Id
                        TargetType       = 'UserId'
                        CategoryActivity = 'ReferralUserId external user validation'
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

        $userProperties | & {
            process {
                if ($null -eq $data.$_) {
                    $data.$_ = $refUserObj.$_
                }
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
        $script:persistentError = $true
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
            $script:persistentError = $true
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
        $script:persistentError = $true
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

    $userProperties | & {
        process {
            if (
                ($null -eq $BodyParams.$_) -and
                ($_ -notin @(
                    'Id'
                    'UserType'
                    'CreatedDateTime'
                    'SignInActivity'
                    'IsResourceAccount'
                    'CreationType'
                    'ExternalUserState'
                    'Identities'
                    'Mail'
                )) -and
                ($_ -notmatch '^OnPremises')
            ) {
                # Empty or null values require special handling because
                # MS Graph module momentarily does not handle them properly
                if ([string]::IsNullOrEmpty($refUserObj.$_)) {
                    Write-Verbose "Clearing property $_"
                    $BodyParamsNull.$_ = $null
                }
                else {
                    Write-Verbose "Copying property $_"
                    $BodyParams.$_ = $refUserObj.$_
                }
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
        Uri        = "https://graph.microsoft.com/v1.0/directory/deletedItems/microsoft.graph.user?`$count=true&`$filter=endsWith(UserPrincipalName,'$($BodyParams.UserPrincipalName)')"
    }
    $deletedUserList = Invoke-MgGraphRequest @params

    if ($deletedUserList) {
        $deletedUserList.Value | & {
            process {
                $script:returnInformation.Add(( .\Common_0000__Write-Information.ps1 @{
                            Message          = "${ReferralUserId}: Soft-deleted admin account $($_.UserPrincipalName) ($($_.Id)) was permanently deleted before re-creation."
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
                    Uri        = "https://graph.microsoft.com/v1.0/directory/deletedItems/$($_.Id)"
                }
                Invoke-MgGraphRequest @params 1> $null
            }
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
        $TenantLicensed = Get-MgBetaSubscribedSku -All | Where-Object { $_.SkuPartNumber -in $LicenseSkuPartNumbers } | Select-Object -Property Sku*, ConsumedUnits, ServicePlans -ExpandProperty PrepaidUnits | & {
            process {
                if ($_.ConsumedUnits -ge $_.Enabled) {
                    $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                                Message           = "${ReferralUserId}: License SkuPartNumber $($_.SkuPartNumber) has run out of free licenses."
                                ErrorId           = '503'
                                Category          = 'LimitsExceeded'
                                TargetName        = $refUserObj.UserPrincipalName
                                TargetObject      = $refUserObj.Id
                                TargetType        = 'UserId'
                                RecommendedAction = 'Purchase additional licenses to create new Cloud Administrator accounts.'
                                CategoryActivity  = 'License Availability Validation'
                                CategoryReason    = "License SkuPartNumber $($_.SkuPartNumber) has run out of free licenses."
                            }))
                    $script:persistentError = $true
                }
                else {
                    Write-Verbose "License SkuPartNumber $($_.SkuPartNumber) has at least 1 free license available to continue"
                    $_
                }
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
        $TenantLicensed = Get-MgBetaSubscribedSku -All | Where-Object { $_.SkuPartNumber -in $LicenseSkuPartNumbers } | Select-Object -Property Sku*, ConsumedUnits, ServicePlans -ExpandProperty PrepaidUnits | & {
            process {
                if ($_.ConsumedUnits -ge $_.Enabled) {
                    $script:returnError.Add(( .\Common_0000__Write-Error.ps1 @{
                                Message           = "${ReferralUserId}: License SkuPartNumber $($_.SkuPartNumber) has run out of free licenses."
                                ErrorId           = '503'
                                Category          = 'LimitsExceeded'
                                TargetName        = $refUserObj.UserPrincipalName
                                TargetObject      = $refUserObj.Id
                                TargetType        = 'UserId'
                                RecommendedAction = 'Purchase additional licenses to create new Cloud Administrator accounts.'
                                CategoryActivity  = 'License Availability Validation'
                                CategoryReason    = "License SkuPartNumber $($_.SkuPartNumber) has run out of free licenses."
                            }))
                    $script:persistentError = $true
                }
                else {
                    Write-Verbose "License SkuPartNumber $($_.SkuPartNumber) has at least 1 free license available to continue"
                    $_
                }
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
            AddLicenses    = [System.Collections.ArrayList]::new()
            RemoveLicenses = [System.Collections.ArrayList]::new()
            ErrorAction    = 'Stop'
        }

        $LicenseSkuPartNumbers | & {
            process {
                $SkuPartNumber = $_
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
    @(
        if ($PhotoUrlUser) { $PhotoUrlUser }
        if ($SquareLogoRelativeUrl) {
            $tenantBranding.CdnList | & { process { "https://$_/$SquareLogoRelativeUrl" } }
        }
    ) | & {
        process {
            if ($script:PhotoUrl) { return }

            $params = @{
                UseBasicParsing = $true
                Method          = 'GET'
                Uri             = $_
                TimeoutSec      = 10
                ErrorAction     = 'Stop'
            }

            try {
                $return = Invoke-WebRequest @params
                if ($return.StatusCode -eq 200) {
                    if ($return.Headers.'Content-Type' -notmatch '^image/') {
                        Write-Error "Photo from URL $($params.Uri) must have Content-Type 'image/*'."
                    }
                    else {
                        Write-Verbose "Successfully retrieved User Photo from $($params.Uri)"
                        $script:PhotoUrl = $params.Uri
                        $return
                    }
                }
            }
            catch {
                Write-Warning "Failed to retrieve User Photo from $($params.Uri)"
            }
        }
    } | & {
        process {
            $ExoUserPhoto = $false

            Write-Verbose 'Uploading User Photo to Microsoft Graph'
            $params = @{
                InFile      = 'nonExistat.lat'
                UserId      = $UserObj.Id
                Data        = ([System.IO.MemoryStream]::new($_.Content))
                ErrorAction = 'Stop'
            }
            try {
                Set-MgBetaUserPhotoContent @params 1> $null
            }
            catch {
                if ($AdminUnitObj) {
                    $ExoUserPhoto = $true
                    if ($Iteration -eq 1) {
                        Write-Warning "Cannot use Microsoft Graph API to update User Photo. Open feature request at Microsoft to implement Administrative Unit support in Microsoft Graph API when using Set-MgUserPhotoContent. Also see 'https://go.microsoft.com/fwlink/p/?linkid=2249705'."
                    }
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
                    Identity      = $userExObj.Identity
                    PictureData   = $_.Content
                    Confirm       = $false
                    ErrorAction   = 'Stop'
                    WarningAction = 'SilentlyContinue'
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
                if ($Iteration -eq 1) {
                    Write-Warning "User Photo update used Exchange Online cmdlet Set-UserPhoto that is announced to stop working in April 2024 due to deprecation of Exchange Online PowerShell UserPhoto cmdlets, see 'https://go.microsoft.com/fwlink/p/?linkid=2249705'."
                }
            }
        }
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

    $userProperties | & {
        process {
            if ($null -eq $data.$_) {
                $data.$_ = $UserObj.$_
            }
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

$LocalUserId = @( .\Common_0002__Convert-UserIdToLocalUserId.ps1 -UserId $ReferralUserId -VerifiedDomains $tenant.VerifiedDomains )
if ($LocalUserId.Count -ne $ReferralUserId.Count) { Throw 'ReferralUserId count must not be different after LocalUserId conversion.' }

0..$($ReferralUserId.Count) | & {
    process {
        if ([string]::IsNullOrEmpty($ReferralUserId[$_])) { return }
        if ([string]::IsNullOrEmpty($Tier[$_])) { return }
        [System.GC]::Collect()
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        $params = @{
            ReferralUserId = $ReferralUserId[$_]
            LocalUserId    = $LocalUserId[$_]
            Tier           = $Tier[$_]
            UserPhotoUrl   = if ([string]::IsNullOrEmpty($UserPhotoUrl) -or [string]::IsNullOrEmpty($UserPhotoUrl[$_])) { $null } else { $UserPhotoUrl[$_] }
        }
        $null = $returnOutput.Add((ProcessReferralUser @params))
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

Write-Verbose "Total Waittime: $([math]::Floor($return.Job.Waittime.TotalSeconds)) sec ($([math]::Round($return.Job.Waittime.TotalMinutes, 1)) min)"
Write-Verbose "Total Runtime: $([math]::Floor($return.Job.Runtime.TotalSeconds)) sec ($([math]::Round($return.Job.Runtime.TotalMinutes, 1)) min)"

if ($Webhook) { .\Common_0000__Submit-Webhook.ps1 -Uri $Webhook -Body $return 1> $null }

if (
    ($OutText -eq $true) -or
    (($PSBoundParameters.Keys -contains 'OutJson') -and ($OutJson -eq $false)) -or
    (($PSBoundParameters.Keys -contains 'OutObject') -and ($OutObject -eq $false))
) { return }

if ($OutJson) { .\Common_0000__Write-JsonOutput.ps1 $return; return }
if ($OutObject -eq $true) { return $return }
if ($VerbosePreference -ne 'Continue') { Write-Output "Success = $($return.Success)" }
#endregion ---------------------------------------------------------------------
