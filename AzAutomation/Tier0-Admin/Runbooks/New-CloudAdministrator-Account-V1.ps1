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
    Version: 0.9.0


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

    In case an existing Cloud Administrator account was found for referral user ID, it must by a cloud native account to be updated. Otherwise an error is returned and manual cleanup of the on-premises synced account is required to resolve the conflict.
    If an existing Cloud administrator account was soft-deleted before, it will be permanently deleted before re-creating the account. A soft-deleted mailbox will be permanently deleted in that case as well.
    The user part of the Cloud Administrator account must be mutually exclusive to the tenant. A warning will be generated if there is other accounts using either a similar User Principal Name or same Display Name, Mail, Mail Nickname, or ProxyAddress.


    CUSTOM CONFIGURATION SETTINGS
    =============================

    Variables for custom configuration settings, either from $env:<VariableName>,
    or Azure Automation Account Variables, whose will automatically be published in $env.

    .VARIABLE AV_CloudAdmin_Webhook - [String]
        Send return data in JSON format as POST to this webhook URL.

    .VARIABLE AV_CloudAdminTier<Tier>_UserPhotoUrl - [String]
        Default value for script parameter UserPhotoUrl. If no parameter was provided, this value will be used instead.

    .VARIABLE AV_CloudAdminTier<Tier>_LicenseSkuPartNumber - [String]
        License assigned to the user. The license SKU part number must contain an Exchange Online service plan to generate a mailbox for the user (see https://learn.microsoft.com/en-us/entra/identity/users/licensing-service-plan-reference).
        If GroupId is also provided, group-based licensing is implied and license assignment will only be monitored before continuing.
        This parameter has a default value for Exchange Online Kiosk license (SkuPartNumber EXCHANGEDESKLESS) and only Exchange license plan will be enabled in it.

    .VARIABLE AV_CloudAdminTier<Tier>_GroupId - [String]
        Entra Group Object ID where the user shall be added. If the group is dynamic, group membership update will only be monitored before continuing.

    .VARIABLE AV_CloudAdminTier<Tier>_GroupDescription - [String]
        ...

    .VARIABLE AV_CloudAdminTier<Tier>_DedicatedAccount - [Boolean]
        ...

    Please note that <Tier> in the variable name must be replaced by the intended Tier level 0, 1, or 2.
    For example:

        AV_CloudAdminTier0_GroupId
        AV_CloudAdminTier2_GroupId
        AV_CloudAdminTier2_GroupId

.EXAMPLE
    PS> .\New-CloudAdministrator-Account-V1.ps1 -ReferralUserId first.last@example.com -Tier 0

.EXAMPLE
    PS> .\New-CloudAdministrator-Account-V1.ps1 -ReferralUserId first.last@example.com -Tier 0 -UserPhotoUrl https://example.com/assets/Tier0-Admins.png

.EXAMPLE
    BATCH PROCESSING
    ================

    Azure Automation has limited support for regular PowerShell pipelining as it does not process inline execution of child runbooks within Begin/End blocks.
    Therefore, classic PowerShell pipelining like this does NOT work:

        PS> Get-Content list.csv | ConvertFrom-Csv | .\New-CloudAdministrator-Account-V1.ps1

    Instead, a collection can be used to provide the required input data:

        PS> $csv = Get-Content list.csv | ConvertFrom-Csv
        PS> .\New-CloudAdministrator-Account-V1.ps1 -ReferralUserId $csv.ReferralUserId -Tier $csv.Tier -UserPhotoUrl $csv.UserPhotoUrl

    The advantage is that the script will run more efficient as some tasks only need to be performed once per batch instead of each individual account.
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
#- only create user based on dedicated parmeter, also dont update photo
#- admin prefix separator as variable
#- Multiple licenses support
#- variable for dedicated account yes/no per tier
#- Variable for extension attribute
#- Check refUser for extensionAttribute and EmployeeType
#- Send emails were applicable
#- find existing account not only by UPN but also extensionAttribute and EmployeeType
#- Install PowerShell modules that are mentioned as "requires" but do not update existing ones, just to support the initial run of the script
#endregion

[CmdletBinding()]
Param (
    [Parameter(Position = 0, mandatory = $true)]
    [String[]]$ReferralUserId,

    [Parameter(Position = 1, mandatory = $true)]
    [Int32[]]$Tier,

    [Parameter(Position = 2)]
    [AllowEmptyString()]
    [String[]]$UserPhotoUrl,

    [Boolean]$OutJson,
    [Boolean]$OutText
)

#region [COMMON] SCRIPT CONFIGURATION PARAMETERS -------------------------------
$ConfigurationVariables = @(
    #region General
    @{
        sourceName             = "AV_CloudAdmin_Webhook"
        respectScriptParameter = $null
        mapToVariable          = 'Webhook'
        defaultValue           = $null
        Regex                  = '^https:\/\/.+$'
    }
    #endregion

    #region Tier 0
    @{
        sourceName             = "AV_CloudAdminTier0_LicenseSkuPartNumber"
        respectScriptParameter = $null
        mapToVariable          = 'LicenseSkuPartNumber_Tier0'
        defaultValue           = 'EXCHANGEDESKLESS'
        Regex                  = '^[A-Z][A-Z_ ]+[A-Z]$'
    }
    @{
        sourceName             = "AV_CloudAdminTier0_GroupId"
        respectScriptParameter = $null
        mapToVariable          = 'GroupId_Tier0'
        defaultValue           = $null
        Regex                  = '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$'
    }
    @{
        sourceName             = "AV_CloudAdminTier0_GroupDescription"
        respectScriptParameter = $null
        mapToVariable          = 'GroupDescription_Tier0'
        defaultValue           = 'Tier 0 Cloud Administrators'
        Regex                  = '^[^\s]+.*[^\s]+$'
    }
    @{
        sourceName             = "AV_CloudAdminTier0_UserPhotoUrl"
        respectScriptParameter = 'UserPhotoUrl'
        mapToVariable          = 'PhotoUrl_Tier0'
        defaultValue           = $null
        Regex                  = '^https:\/\/.+(?:\.png|\.jpg|\.jpeg|\?.+)$'
    }
    @{
        sourceName             = "AV_CloudAdminTier0_DedicatedAccount"
        respectScriptParameter = $null
        mapToVariable          = 'DedicatedAccount_Tier0'
        defaultValue           = $null
        Type                   = [boolean]
    }
    @{
        sourceName             = "AV_CloudAdminTier0_UserDisplayNamePrefix"
        respectScriptParameter = $null
        mapToVariable          = 'UserDisplayNamePrefix_Tier0'
        defaultValue           = 'A0C'
        Regex                  = '^[^\s]+.*[^\s]+$'
    }
    @{
        sourceName             = "AV_CloudAdminTier0_UserDisplayNamePrefixSeparator"
        respectScriptParameter = $null
        mapToVariable          = 'UserDisplayNamePrefixSeparator_Tier0'
        defaultValue           = '-'
        Regex                  = '^.$'
    }
    @{
        sourceName             = "AV_CloudAdminTier0_UserDisplayNameSuffix"
        respectScriptParameter = $null
        mapToVariable          = 'UserDisplayNameSuffix_Tier0'
        defaultValue           = $null
        Regex                  = '^[^\s]+.*[^\s]+$'
    }
    @{
        sourceName             = "AV_CloudAdminTier0_UserDisplayNameSuffixSeparator"
        respectScriptParameter = $null
        mapToVariable          = 'UserDisplayNameSuffixSeparator_Tier0'
        defaultValue           = ' '
        Regex                  = '^.$'
    }
    @{
        sourceName             = "AV_CloudAdminTier0_GivenNamePrefix"
        respectScriptParameter = $null
        mapToVariable          = 'GivenNamePrefix_Tier0'
        defaultValue           = 'A0C'
        Regex                  = '^[^\s]+.*[^\s]+$'
    }
    @{
        sourceName             = "AV_CloudAdminTier0_GivenNamePrefixSeparator"
        respectScriptParameter = $null
        mapToVariable          = 'GivenNamePrefixSeparator_Tier0'
        defaultValue           = '-'
        Regex                  = '^.$'
    }
    @{
        sourceName             = "AV_CloudAdminTier0_GivenNameSuffix"
        respectScriptParameter = $null
        mapToVariable          = 'GivenNameSuffix_Tier0'
        defaultValue           = $null
        Regex                  = '^[^\s]+.*[^\s]+$'
    }
    @{
        sourceName             = "AV_CloudAdminTier0_GivenNameSuffixSeparator"
        respectScriptParameter = $null
        mapToVariable          = 'GivenNameSuffixSeparator_Tier0'
        defaultValue           = '-'
        Regex                  = '^.$'
    }
    @{
        sourceName             = "AV_CloudAdminTier0_UserPrincipalNamePrefix"
        respectScriptParameter = $null
        mapToVariable          = 'UserPrincipalNamePrefix_Tier0'
        defaultValue           = 'A0C'
        Regex                  = '^[^\s]+.*[^\s]+$'
    }
    @{
        sourceName             = "AV_CloudAdminTier0_UserPrincipalNamePrefixSeparator"
        respectScriptParameter = $null
        mapToVariable          = 'UserPrincipalNamePrefixSeparator_Tier0'
        defaultValue           = '-'
        Regex                  = '^.$'
    }
    @{
        sourceName             = "AV_CloudAdminTier0_UserPrincipalNameSuffix"
        respectScriptParameter = $null
        mapToVariable          = 'UserPrincipalNameSuffix_Tier0'
        defaultValue           = $null
        Regex                  = '^[^\s]+.*[^\s]+$'
    }
    @{
        sourceName             = "AV_CloudAdminTier0_UserPrincipalNameSuffixSeparator"
        respectScriptParameter = $null
        mapToVariable          = 'UserPrincipalNameSuffixSeparator_Tier0'
        defaultValue           = '-'
        Regex                  = '^.$'
    }
    #endregion

    #region Tier 1
    @{
        sourceName             = "AV_CloudAdminTier1_LicenseSkuPartNumber"
        respectScriptParameter = $null
        mapToVariable          = 'LicenseSkuPartNumber_Tier1'
        defaultValue           = 'EXCHANGEDESKLESS'
        Regex                  = '^[A-Z][A-Z_ ]+[A-Z]$'
    }
    @{
        sourceName             = "AV_CloudAdminTier2_GroupId"
        respectScriptParameter = $null
        mapToVariable          = 'GroupId_Tier1'
        defaultValue           = $null
        Regex                  = '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$'
    }
    @{
        sourceName             = "AV_CloudAdminTier1_GroupDescription"
        respectScriptParameter = $null
        mapToVariable          = 'GroupDescription_Tier1'
        defaultValue           = 'Tier 1 Cloud Administrators'
        Regex                  = '^[^\s]+.*[^\s]+$'
    }
    @{
        sourceName             = "AV_CloudAdminTier1_UserPhotoUrl"
        respectScriptParameter = 'UserPhotoUrl'
        mapToVariable          = 'PhotoUrl_Tier1'
        defaultValue           = $null
        Regex                  = '^https:\/\/.+(?:\.png|\.jpg|\.jpeg|\?.+)$'
    }
    @{
        sourceName             = "AV_CloudAdminTier1_DedicatedAccount"
        respectScriptParameter = $null
        mapToVariable          = 'DedicatedAccount_Tier1'
        defaultValue           = $false
        Type                   = [boolean]
    }
    @{
        sourceName             = "AV_CloudAdminTier1_UserDisplayNamePrefix"
        respectScriptParameter = $null
        mapToVariable          = 'UserDisplayNamePrefix_Tier1'
        defaultValue           = 'A1C'
        Regex                  = '^[^\s]+.*[^\s]+$'
    }
    @{
        sourceName             = "AV_CloudAdminTier1_UserDisplayNamePrefixSeparator"
        respectScriptParameter = $null
        mapToVariable          = 'UserDisplayNamePrefixSeparator_Tier1'
        defaultValue           = '-'
        Regex                  = '^.$'
    }
    @{
        sourceName             = "AV_CloudAdminTier1_UserDisplayNameSuffix"
        respectScriptParameter = $null
        mapToVariable          = 'UserDisplayNameSuffix_Tier1'
        defaultValue           = $null
        Regex                  = '^[^\s]+.*[^\s]+$'
    }
    @{
        sourceName             = "AV_CloudAdminTier1_UserDisplayNameSuffixSeparator"
        respectScriptParameter = $null
        mapToVariable          = 'UserDisplayNameSuffixSeparator_Tier1'
        defaultValue           = ' '
        Regex                  = '^.$'
    }
    @{
        sourceName             = "AV_CloudAdminTier1_GivenNamePrefix"
        respectScriptParameter = $null
        mapToVariable          = 'GivenNamePrefix_Tier1'
        defaultValue           = 'A1C'
        Regex                  = '^[^\s]+.*[^\s]+$'
    }
    @{
        sourceName             = "AV_CloudAdminTier1_GivenNamePrefixSeparator"
        respectScriptParameter = $null
        mapToVariable          = 'GivenNamePrefixSeparator_Tier1'
        defaultValue           = '-'
        Regex                  = '^.$'
    }
    @{
        sourceName             = "AV_CloudAdminTier1_GivenNameSuffix"
        respectScriptParameter = $null
        mapToVariable          = 'GivenNameSuffix_Tier1'
        defaultValue           = $null
        Regex                  = '^[^\s]+.*[^\s]+$'
    }
    @{
        sourceName             = "AV_CloudAdminTier1_GivenNameSuffixSeparator"
        respectScriptParameter = $null
        mapToVariable          = 'GivenNameSuffixSeparator_Tier1'
        defaultValue           = '-'
        Regex                  = '^.$'
    }
    @{
        sourceName             = "AV_CloudAdminTier1_UserPrincipalNamePrefix"
        respectScriptParameter = $null
        mapToVariable          = 'UserPrincipalNamePrefix_Tier1'
        defaultValue           = 'A1C'
        Regex                  = '^[^\s]+.*[^\s]+$'
    }
    @{
        sourceName             = "AV_CloudAdminTier1_UserPrincipalNamePrefixSeparator"
        respectScriptParameter = $null
        mapToVariable          = 'UserPrincipalNamePrefixSeparator_Tier1'
        defaultValue           = '-'
        Regex                  = '^.$'
    }
    @{
        sourceName             = "AV_CloudAdminTier1_UserPrincipalNameSuffix"
        respectScriptParameter = $null
        mapToVariable          = 'UserPrincipalNameSuffix_Tier1'
        defaultValue           = $null
        Regex                  = '^[^\s]+.*[^\s]+$'
    }
    @{
        sourceName             = "AV_CloudAdminTier1_UserPrincipalNameSuffixSeparator"
        respectScriptParameter = $null
        mapToVariable          = 'UserPrincipalNameSuffixSeparator_Tier1'
        defaultValue           = '-'
        Regex                  = '^.$'
    }
    #endregion

    #region Tier 2
    @{
        sourceName             = "AV_CloudAdminTier2_LicenseSkuPartNumber"
        respectScriptParameter = $null
        mapToVariable          = 'LicenseSkuPartNumber_Tier2'
        defaultValue           = ''
        Regex                  = '^[A-Z][A-Z_ ]+[A-Z]$'
    }
    @{
        sourceName             = "AV_CloudAdminTier2_GroupId"
        respectScriptParameter = $null
        mapToVariable          = 'GroupId_Tier2'
        defaultValue           = $null
        Regex                  = '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$'
    }
    @{
        sourceName             = "AV_CloudAdminTier2_GroupDescription"
        respectScriptParameter = $null
        mapToVariable          = 'GroupDescription_Tier2'
        defaultValue           = 'Tier 2 Cloud Administrators'
        Regex                  = '^[^\s]+.*[^\s]+$'
    }
    @{
        sourceName             = "AV_CloudAdminTier2_UserPhotoUrl"
        respectScriptParameter = 'UserPhotoUrl'
        mapToVariable          = 'PhotoUrl_Tier2'
        defaultValue           = $null
        Regex                  = '^https:\/\/.+(?:\.png|\.jpg|\.jpeg|\?.+)$'
    }
    @{
        sourceName             = "AV_CloudAdminTier2_DedicatedAccount"
        respectScriptParameter = $null
        mapToVariable          = 'DedicatedAccount_Tier2'
        defaultValue           = $false
        Type                   = [boolean]
    }
    @{
        sourceName             = "AV_CloudAdminTier2_UserDisplayNamePrefix"
        respectScriptParameter = $null
        mapToVariable          = 'UserDisplayNamePrefix_Tier2'
        defaultValue           = 'A2C'
        Regex                  = '^[^\s]+.*[^\s]+$'
    }
    @{
        sourceName             = "AV_CloudAdminTier2_UserDisplayNamePrefixSeparator"
        respectScriptParameter = $null
        mapToVariable          = 'UserDisplayNamePrefixSeparator_Tier2'
        defaultValue           = '-'
        Regex                  = '^.$'
    }
    @{
        sourceName             = "AV_CloudAdminTier2_UserDisplayNameSuffix"
        respectScriptParameter = $null
        mapToVariable          = 'UserDisplayNameSuffix_Tier2'
        defaultValue           = $null
        Regex                  = '^[^\s]+.*[^\s]+$'
    }
    @{
        sourceName             = "AV_CloudAdminTier2_UserDisplayNameSuffixSeparator"
        respectScriptParameter = $null
        mapToVariable          = 'UserDisplayNameSuffixSeparator_Tier2'
        defaultValue           = ' '
        Regex                  = '^.$'
    }
    @{
        sourceName             = "AV_CloudAdminTier2_GivenNamePrefix"
        respectScriptParameter = $null
        mapToVariable          = 'GivenNamePrefix_Tier2'
        defaultValue           = 'A2C'
        Regex                  = '^[^\s]+.*[^\s]+$'
    }
    @{
        sourceName             = "AV_CloudAdminTier2_GivenNamePrefixSeparator"
        respectScriptParameter = $null
        mapToVariable          = 'GivenNamePrefixSeparator_Tier2'
        defaultValue           = '-'
        Regex                  = '^.$'
    }
    @{
        sourceName             = "AV_CloudAdminTier2_GivenNameSuffix"
        respectScriptParameter = $null
        mapToVariable          = 'GivenNameSuffix_Tier2'
        defaultValue           = $null
        Regex                  = '^[^\s]+.*[^\s]+$'
    }
    @{
        sourceName             = "AV_CloudAdminTier2_GivenNameSuffixSeparator"
        respectScriptParameter = $null
        mapToVariable          = 'GivenNameSuffixSeparator_Tier2'
        defaultValue           = '-'
        Regex                  = '^.$'
    }
    @{
        sourceName             = "AV_CloudAdminTier2_UserPrincipalNamePrefix"
        respectScriptParameter = $null
        mapToVariable          = 'UserPrincipalNamePrefix_Tier2'
        defaultValue           = 'A2C'
        Regex                  = '^[^\s]+.*[^\s]+$'
    }
    @{
        sourceName             = "AV_CloudAdminTier2_UserPrincipalNamePrefixSeparator"
        respectScriptParameter = $null
        mapToVariable          = 'UserPrincipalNamePrefixSeparator_Tier2'
        defaultValue           = '-'
        Regex                  = '^.$'
    }
    @{
        sourceName             = "AV_CloudAdminTier2_UserPrincipalNameSuffix"
        respectScriptParameter = $null
        mapToVariable          = 'UserPrincipalNameSuffix_Tier2'
        defaultValue           = $null
        Regex                  = '^[^\s]+.*[^\s]+$'
    }
    @{
        sourceName             = "AV_CloudAdminTier2_UserPrincipalNameSuffixSeparator"
        respectScriptParameter = $null
        mapToVariable          = 'UserPrincipalNameSuffixSeparator_Tier2'
        defaultValue           = '-'
        Regex                  = '^.$'
    }
    #endregion
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
.\Common__0001_Add-AzAutomationVariableToPSEnv.ps1 1> $null
.\Common__0000_Convert-PSEnvToPSLocalVariable.ps1 -Variable $ConfigurationVariables 1> $null
#endregion ---------------------------------------------------------------------

#region [COMMON] INITIALIZE SCRIPT VARIABLES -----------------------------------
$persistentError = $false
$Iteration = 0
$return = @{
    Information = @()
    Warning     = @()
    Error       = @()
    Job         = @{
        AutomationAccount = @{}
        Runbook           = @{}
        StartTime         = (Get-Date).ToUniversalTime()
        EndTime           = @{}
        RunTime           = @{}
    }
}
if ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
    if ($PSPrivateMetadata.JobId) { $return.Job.Id = $PSPrivateMetadata.JobId }
    $return.Job.AutomationAccount = Get-AzAutomationAccount
    $params = @{
        ResourceGroupName     = $return.Job.AutomationAccount.ResourceGroupName
        AutomationAccountName = $return.Job.AutomationAccount.AutomationAccountName
        RunbookName           = (Get-Item $MyInvocation.MyCommand).BaseName
    }
    $return.Job.Runbook = Get-AzAutomationRunbook @params
}
else {
    $return.Job.Runbook.RunbookName = (Get-Item $MyInvocation.MyCommand).BaseName
}
#endregion ---------------------------------------------------------------------

#region [COMMON] CONCURRENT JOBS -----------------------------------------------
if (-Not (.\Common__0001_Wait-AzAutomationConcurrentJob.ps1)) {
    $return.Error += .\Common__0000_Write-Error.ps1 @{
        Message           = "Maximum job runtime was reached."
        ErrorId           = '504'
        Category          = 'OperationTimeout'
        RecommendedAction = 'Try again later.'
        CategoryActivity  = 'Job Concurrency Check'
        CategoryReason    = "Maximum job runtime was reached."
    }
}
#endregion ---------------------------------------------------------------------

#region [COMMON] OPEN CONNECTIONS ----------------------------------------------
.\Common__0000_Connect-MgGraph.ps1 -Scopes $MgGraphScopes 1> $null
$tenant = Get-MgOrganization -OrganizationId (Get-MgContext).TenantId
$tenantDomain = $tenant.VerifiedDomains | Where-Object IsInitial -eq true
$tenantBranding = Get-MgOrganizationBranding -OrganizationId $tenant.Id
.\Common__0002_Confirm-MgDirectoryRoleActiveAssignment.ps1 -Roles $MgGraphDirectoryRoles 1> $null
.\Common__0002_Confirm-MgAppPermission.ps1 -Permissions $MgAppPermissions 1> $null
.\Common__0000_Connect-ExchangeOnline.ps1 -Organization $tenantDomain.Name 1> $null
#endregion ---------------------------------------------------------------------

#region Group Validation -------------------------------------------------------
ForEach (
    $GroupId in @(
        ($GroupId_Tier0, $GroupId_Tier2, $GroupId_Tier2) | Select-Object -Unique
    )
) {
    if ([string]::IsNullOrEmpty($GroupId)) { continue }
    $params = @{
        GroupId        = $GroupId
        ExpandProperty = 'Owners'
        ErrorAction    = 'SilentlyContinue'
    }
    $GroupObj = Get-MgBetaGroup @params

    if (-Not $GroupObj) {
        Throw "GroupId $($GroupId) does not exist."
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
    elseif ($GroupObj.IsAssignableToRole) {
        .\Common__0002_Confirm-MgDirectoryRoleActiveAssignment.ps1 -WarningAction SilentlyContinue -Roles @(
            @{
                DisplayName = 'Privileged Role Administrator'
                TemplateId  = 'e8611ab8-c189-46e8-94e1-60213ab1f814'
            }
        ) 1> $null
    }
    if ('Private' -ne $GroupObj.Visibility) {
        Write-Warning "Group $($GroupObj.DisplayName) ($($GroupObj.Id)): Correcting visibility to Private for Cloud Administration."
        Update-MgBetaGroup -GroupId $GroupObj.Id -Visibility 'Private' 1> $null
    }
    #TODO check for assigned roles and remove them
    if ($GroupObj.Owners) {
        foreach ($owner in $GroupObj.Owners) {
            Write-Warning "Group $($GroupObj.DisplayName) ($($GroupObj.Id)): Removing unwanted group owner $($owner.Id)"
            Remove-MgGroupOwnerByRef -GroupId $GroupObj.Id -DirectoryObjectId $owner.Id 1> $null
        }
    }

    $GroupDescription = "Tier $Tier Cloud Administrators"
    if (-Not $GroupObj.Description) {
        Write-Warning "Group $($GroupObj.DisplayName) ($($GroupObj.Id)): Adding missing description for Tier $Tier identification"
        Update-MgGroup -GroupId -Description $GroupDescription 1> $null
    }
    elseif ($GroupObj.Description -ne $GroupDescription) {
        Throw "Group $($GroupObj.DisplayName) ($($GroupObj.Id)): The description does not clearly identify this group as a Tier $Tier Administrators group. To avoid incorrect group assignments, please check that you are using the correct group. To use this group for Tier $Tier management, set the description property to '$GroupDescription'."
    }
}
#endregion ---------------------------------------------------------------------

#region License Existance Validation -------------------------------------------
ForEach (
    $SkuPartNumber in @(
        ($LicenseSkuPartNumber_Tier0, $LicenseSkuPartNumber_Tier2, $LicenseSkuPartNumber_Tier2) | Select-Object -Unique
    )
) {
    if ([String]::IsNullOrEmpty($SkuPartNumber)) { continue }
    $Sku = Get-MgSubscribedSku -All | Where-Object SkuPartNumber -eq $SkuPartNumber | Select-Object -Property Sku*, ServicePlans

    if (-Not $Sku) {
        Throw "License SkuPartNumber $LicenseSkuPartNumber is not available to this tenant."
    }
    if (-Not ($Sku.ServicePlans | Where-Object -FilterScript { ($_.AppliesTo -eq 'User') -and ($_.ServicePlanName -Match 'EXCHANGE') })) {
        Throw "License SkuPartNumber $LicenseSkuPartNumber does not contain an Exchange Online service plan."
    }
}
#endregion ---------------------------------------------------------------------

#region Process Referral User --------------------------------------------------
function ProcessItem ($ReferralUserId, $Tier, $UserPhotoUrl) {
    Write-Verbose "-----STARTLOOP $ReferralUserId ---"

    #region [COMMON] LOOP HANDLING -------------------------------------------------
    # Only process items if there was no error during script initialization before
    if (($Iteration -eq 0) -and ($return.Error.Count -gt 0)) { $persistentError = $true }
    if ($persistentError) {
        $return.Error += .\Common__0000_Write-Error.ps1 @{
            Message           = "${ReferralUserId}: Skipped processing."
            ErrorId           = '500'
            Category          = 'OperationStopped'
            TargetName        = $ReferralUserId
            TargetObject      = $null
            RecommendedAction = 'Try again later.'
            CategoryActivity  = 'Persisent Error'
            CategoryReason    = "No other items are processed due to persisent error before."
        }
        return
    }

    $Iteration++
    #endregion ---------------------------------------------------------------------

    #region [COMMON] LOOP ENVIRONMENT ----------------------------------------------
    .\Common__0000_Convert-PSEnvToPSLocalVariable.ps1 -Variable $ConfigurationVariables -scriptParameterOnly $true 1> $null

    $LicenseSkuPartNumber = Get-Variable -ValueOnly -Name "LicenseSkuPartNumber_Tier$Tier"
    $GroupId = Get-Variable -ValueOnly -Name "GroupId_Tier$Tier"
    $PhotoUrl = Get-Variable -ValueOnly -Name "PhotoUrl_Tier$Tier"
    $GroupObj = $null
    $UserObj = $null
    $License = $null

    if (-Not [string]::IsNullOrEmpty($GroupId)) {
        $GroupObj = Get-MgGroup -GroupId $GroupId
    }
    #endregion ---------------------------------------------------------------------

    #region [COMMON] PARAMETER VALIDATION ------------------------------------------
    $regex = '^(?:.+@.{3,}\..{2,}|[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12})$'
    if ($ReferralUserId -notmatch $regex) {
        $return.Error += .\Common__0000_Write-Error.ps1 @{
            Message           = "${ReferralUserId}: ReferralUserId is invalid"
            ErrorId           = '400'
            Category          = 'SyntaxError'
            TargetName        = $ReferralUserId
            TargetObject      = $null
            TargetType        = 'UserId'
            RecommendedAction = 'Provide either User Principal Name, or Object ID (UUID).'
            CategoryActivity  = 'ReferralUserId parameter validation'
            CategoryReason    = "Parameter ReferralUserId does not match $regex"
        }
        return
    }
    $regex = '^[0-2]$'
    if ($Tier -notmatch $regex) {
        $return.Error += .\Common__0000_Write-Error.ps1 @{
            Message           = "${ReferralUserId}: Tier $Tier is invalid"
            ErrorId           = '400'
            Category          = 'SyntaxError'
            TargetName        = $ReferralUserId
            TargetObject      = $null
            TargetType        = 'Retry again later'
            RecommendedAction = 'Provide a Tier level of 0, 1, or 2.'
            CategoryActivity  = 'Tier parameter validation'
            CategoryReason    = "Parameter Tier does not match $regex"
        }
        return
    }
    $regex = '(?:^https:\/\/.+(?:\.png|\.jpg|\.jpeg|\?.+)$|^$)'
    if ($UserPhotoUrl -notmatch $regex) {
        $return.Error += .\Common__0000_Write-Error.ps1 @{
            Message           = "${ReferralUserId}: UserPhotoUrl $UserPhotoUrl is invalid"
            ErrorId           = '400'
            Category          = 'SyntaxError'
            TargetName        = $ReferralUserId
            TargetObject      = $null
            TargetType        = 'UserId'
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

    $params = @{
        UserId         = $ReferralUserId
        Property       = $userProperties
        ExpandProperty = $userExpandPropeties
        ErrorAction    = 'SilentlyContinue'
    }
    $refUserObj = Get-MgUser @params

    if ($null -eq $refUserObj) {
        $return.Error += .\Common__0000_Write-Error.ps1 @{
            Message           = "${ReferralUserId}: Referral User ID does not exist in directory."
            ErrorId           = '404'
            Category          = 'ObjectNotFound'
            TargetName        = $ReferralUserId
            TargetObject      = $null
            TargetType        = 'UserId'
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
        $return.Error += .\Common__0000_Write-Error.ps1 @{
            Message          = "${ReferralUserId}: This type of user name can not have a Cloud Administrator account created."
            ErrorId          = '403'
            Category         = 'PermissionDenied'
            TargetName       = $refUserObj.UserPrincipalName
            TargetObject     = $refUserObj.Id
            TargetType       = 'UserId'
            CategoryActivity = 'ReferralUserId user validation'
            CategoryReason   = 'Referral User ID is listed as not capable of having a Cloud Administrator account.'
        }
        return
    }

    if (($refUserObj.UserPrincipalName).Split('@')[1] -match '^.+\.onmicrosoft\.com$') {
        $return.Error += .\Common__0000_Write-Error.ps1 @{
            Message          = "${ReferralUserId}: Referral User ID must not use a onmicrosoft.com subdomain."
            ErrorId          = '403'
            Category         = 'PermissionDenied'
            TargetName       = $refUserObj.UserPrincipalName
            TargetObject     = $refUserObj.Id
            TargetType       = 'UserId'
            CategoryActivity = 'ReferralUserId user validation'
            CategoryReason   = 'Referral User ID must not use a onmicrosoft.com subdomain.'
        }
        return
    }

    if (-Not $refUserObj.AccountEnabled) {
        $return.Error += .\Common__0000_Write-Error.ps1 @{
            Message          = "${ReferralUserId}: Referral User ID is disabled. A Cloud Administrator account can only be set up for active accounts."
            ErrorId          = '403'
            Category         = 'NotEnabled'
            TargetName       = $refUserObj.UserPrincipalName
            TargetObject     = $refUserObj.Id
            TargetType       = 'UserId'
            CategoryActivity = 'ReferralUserId user validation'
            CategoryReason   = 'Referral User ID is disabled. A Cloud Administrator account can only be set up for active accounts.'
        }
        return
    }

    if ($refUserObj.UserType -ne 'Member') {
        $return.Error += .\Common__0000_Write-Error.ps1 @{
            Message          = "${ReferralUserId}: Referral User ID must be of type Member."
            ErrorId          = '403'
            Category         = 'InvalidType'
            TargetName       = $refUserObj.UserPrincipalName
            TargetObject     = $refUserObj.Id
            TargetType       = 'UserId'
            CategoryActivity = 'ReferralUserId user validation'
            CategoryReason   = 'Referral User ID is disabled. A Cloud Administrator account can only be set up for active accounts.'
        }
        return
    }

    if (
        (-Not $refUserObj.Manager) -or
        (-Not $refUserObj.Manager.Id)
    ) {
        $return.Error += .\Common__0000_Write-Error.ps1 @{
            Message          = "${ReferralUserId}: Referral User ID must have manager property set."
            ErrorId          = '403'
            Category         = 'ResourceUnavailable'
            TargetName       = $refUserObj.UserPrincipalName
            TargetObject     = $refUserObj.Id
            TargetType       = 'UserId'
            CategoryActivity = 'ReferralUserId user validation'
            CategoryReason   = 'Referral User ID must have manager property set.'
        }
        return
    }

    $timeNow = (Get-Date).ToUniversalTime()

    if (
        ($null -ne $refUserObj.EmployeeHireDate) -and
        ($timeNow -lt $refUserObj.EmployeeHireDate)
    ) {
        $return.Error += .\Common__0000_Write-Error.ps1 @{
            Message          = "${ReferralUserId}: Referral User ID will start to work at $($refUserObj.EmployeeHireDate | Get-Date -Format 'o') Universal Time. A Cloud Administrator account can only be set up for active employees."
            ErrorId          = '403'
            Category         = 'ResourceUnavailable'
            TargetName       = $refUserObj.UserPrincipalName
            TargetObject     = $refUserObj.Id
            TargetType       = 'UserId'
            CategoryActivity = 'ReferralUserId user validation'
            CategoryReason   = "Referral User ID will start to work at $($refUserObj.EmployeeHireDate | Get-Date -Format 'o') Universal Time. A Cloud Administrator account can only be set up for active employees."
        }
        return
    }

    if (
        ($null -ne $refUserObj.EmployeeLeaveDateTime) -and
        ($timeNow -ge $refUserObj.EmployeeLeaveDateTime.AddDays(-45))
    ) {
        $return.Error += .\Common__0000_Write-Error.ps1 @{
            Message          = "${ReferralUserId}: Referral User ID is scheduled for deactivation at $($refUserObj.EmployeeLeaveDateTime | Get-Date -Format 'o') Universal Time. A Cloud Administrator account can only be set up a maximum of 45 days before the planned leaving date."
            ErrorId          = '403'
            Category         = 'OperationStopped'
            TargetName       = $refUserObj.UserPrincipalName
            TargetObject     = $refUserObj.Id
            TargetType       = 'UserId'
            CategoryActivity = 'ReferralUserId user validation'
            CategoryReason   = "Referral User ID is scheduled for deactivation at $($refUserObj.EmployeeLeaveDateTime | Get-Date -Format 'o') Universal Time. A Cloud Administrator account can only be set up a maximum of 45 days before the planned leaving date."
        }
        return
    }

    $tenant = Get-MgOrganization
    $tenantDomain = $tenant.VerifiedDomains | Where-Object IsInitial -eq true

    if ($true -eq $tenant.OnPremisesSyncEnabled -and ($true -ne $refUserObj.OnPremisesSyncEnabled)) {
        $return.Error += .\Common__0000_Write-Error.ps1 @{
            Message          = "${ReferralUserId}: Referral User ID must be a hybrid identity synced from on-premises directory."
            ErrorId          = '403'
            Category         = 'InvalidType'
            TargetName       = $refUserObj.UserPrincipalName
            TargetObject     = $refUserObj.Id
            TargetType       = 'UserId'
            CategoryActivity = 'ReferralUserId user validation'
            CategoryReason   = "Referral User ID must be a hybrid identity synced from on-premises directory."
        }
        return
    }

    $refUserExObj = Get-EXOMailbox -ExternalDirectoryObjectId $refUserObj.Id -ErrorAction SilentlyContinue

    if ($null -eq $refUserExObj) {
        $return.Error += .\Common__0000_Write-Error.ps1 @{
            Message          = "${ReferralUserId}: Referral User ID must have a mailbox."
            ErrorId          = '403'
            Category         = 'NotEnabled'
            TargetName       = $refUserObj.UserPrincipalName
            TargetObject     = $refUserObj.Id
            TargetType       = 'UserId'
            CategoryActivity = 'ReferralUserId user validation'
            CategoryReason   = "Referral User ID must have a mailbox."
        }
        return
    }

    if ('UserMailbox' -ne $refUserExObj.RecipientType -or 'UserMailbox' -ne $refUserExObj.RecipientTypeDetails) {
        $return.Error += .\Common__0000_Write-Error.ps1 @{
            Message          = "${ReferralUserId}: Referral User ID mailbox must be of type UserMailbox. Cloud Administrator accounts can not be created for user mailbox types of $($refUserExObj.RecipientTypeDetails)"
            ErrorId          = '403'
            Category         = 'InvalidType'
            TargetName       = $refUserObj.UserPrincipalName
            TargetObject     = $refUserObj.Id
            TargetType       = 'UserId'
            CategoryActivity = 'ReferralUserId user validation'
            CategoryReason   = "Referral User ID mailbox must be of type UserMailbox. Cloud Administrator accounts can not be created for user mailbox types of $($refUserExObj.RecipientTypeDetails)"
        }
        return
    }
    #endregion ---------------------------------------------------------------------

    #region Prepare New User Account Properties ------------------------------------
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
        EmployeeType                  = "Tier $Tier Cloud Administrator"
        UserPrincipalName             = $UserPrefix + ($refUserObj.UserPrincipalName).Split('@')[0] + $UserSuffix + '@' + $tenantDomain.Name
        Mail                          = $UserPrefix + ($refUserObj.UserPrincipalName).Split('@')[0] + $UserSuffix + '@' + $tenantDomain.Name
        MailNickname                  = $UserPrefix + $refUserObj.MailNickname + $UserSuffix
        PasswordProfile               = @{
            Password                             = .\Common__0000_Get-RandomPassword.ps1 -lowerChars 32 -upperChars 32 -numbers 32 -symbols 32
            ForceChangePasswordNextSignIn        = $false
            ForceChangePasswordNextSignInWithMfa = $false
        }
        PasswordPolicies              = 'DisablePasswordExpiration'
    }

    if ([string]::IsNullOrEmpty($refUserObj.OnPremisesExtensionAttributes.extensionAttribute15)) {
        Write-Verbose 'Creating property extensionAttribute15'
        $BodyParams.OnPremisesExtensionAttributes.extensionAttribute15 = if (Get-Variable -ValueOnly -Name "ExtensionAttributePrefix_Tier$Tier") {
            (Get-Variable -ValueOnly -Name "ExtensionAttributePrefix_Tier$Tier")
        }
        elseif (Get-Variable -ValueOnly -Name "ExtensionAttributeSuffix_Tier$Tier") {
            (Get-Variable -ValueOnly -Name "ExtensionAttributeSuffix_Tier$Tier")
        }
        else { $null }
    }
    else {
        Write-Verbose 'Copying property extensionAttribute15'
        $BodyParams.OnPremisesExtensionAttributes.extensionAttribute15 = $(
            if (Get-Variable -ValueOnly -Name "ExtensionAttributePrefix_Tier$Tier") {
                Write-Verbose 'Adding prefix to property extensionAttribute15'
                (Get-Variable -ValueOnly -Name "ExtensionAttributePrefix_Tier$Tier")
                (if (Get-Variable -ValueOnly -Name "ExtensionAttributePrefixSeparator_Tier$Tier") { Get-Variable -ValueOnly -Name "ExtensionAttributePrefixSeparator_Tier$Tier" } else { '' } )
            }
            else { '' }
        ) + $refUserObj.OnPremisesExtensionAttributes.extensionAttribute15 + $(
            if (Get-Variable -ValueOnly -Name "ExtensionAttributeSuffix_Tier$Tier") {
                Write-Verbose 'Adding suffix to property extensionAttribute15'
                (if (Get-Variable -ValueOnly -Name "ExtensionAttributeSuffixSeparator_Tier$Tier") { Get-Variable -ValueOnly -Name "ExtensionAttributeSuffixSeparator_Tier$Tier" } else { '' } )
                (Get-Variable -ValueOnly -Name "ExtensionAttributeSuffix_Tier$Tier")
            }
            else { '' }
        )
    }

    if (-Not [string]::IsNullOrEmpty($refUserObj.DisplayName)) {
        Write-Verbose 'Copying property DisplayName'
        $BodyParams.DisplayName = $(
            Write-Verbose 'Adding prefix to property DisplayName'
            if (Get-Variable -ValueOnly -Name "UserDisplayNamePrefix_Tier$Tier") {
                (Get-Variable -ValueOnly -Name "UserDisplayNamePrefix_Tier$Tier") +
                $(if (Get-Variable -ValueOnly -Name "UserDisplayNamePrefixSeparator_Tier$Tier") { Get-Variable -ValueOnly -Name "UserDisplayNamePrefixSeparator_Tier$Tier" } else { '' } )
            }
            else { '' }
        ) + $refUserObj.DisplayName + $(
            if (Get-Variable -ValueOnly -Name "UserDisplayNameSuffix_Tier$Tier") {
                Write-Verbose 'Adding suffix to property DisplayName'
                $(if (Get-Variable -ValueOnly -Name "UserDisplayNameSuffixSeparator_Tier$Tier") { Get-Variable -ValueOnly -Name "UserDisplayNameSuffixSeparator_Tier$Tier" } else { '' } ) +
                (Get-Variable -ValueOnly -Name "UserDisplayNameSuffix_Tier$Tier")
            }
            else { '' }
        )
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
            ($property -notin @('Id', 'Mail', 'UserType')) -and
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
        foreach ($deletedUserObj in $deletedUserList.Value) {
            $return.Information += .\Common__0000_Write-Information.ps1 @{
                Message          = "${ReferralUserId}: Soft-deleted admin account $($deletedUserObj.UserPrincipalName) ($($deletedUserObj.Id)) was permanently deleted before re-creation."
                Category         = 'ResourceExists'
                TargetName       = $refUserObj.UserPrincipalName
                TargetObject     = $refUserObj.Id
                TargetType       = 'UserId'
                CategoryActivity = 'Account Provisioning'
                CategoryReason   = "An existing admin account was deleted before."
                Tags             = 'UserId', 'Account Provisioning'
            }

            $params = @{
                OutputType = 'PSObject'
                Method     = 'DELETE'
                Uri        = "https://graph.microsoft.com/beta/directory/deletedItems/$($deletedUserObj.Id)"
            }
            Invoke-MgGraphRequest @params
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
    $duplicatesObj = Get-MgUser @params

    if ($userCount -gt 1) {
        Write-Warning "Admin account $($BodyParams.UserPrincipalName) is not mutually exclusive. $userCount existing accounts found: $( $duplicatesObj.UserPrincipalName )"

        $return.Warning += .\Common__0000_Write-Warning.ps1 @{
            Message           = "${ReferralUserId}: Admin account must be mutually exclusive."
            ErrorId           = '103'
            Category          = 'ResourceExists'
            TargetName        = $refUserObj.UserPrincipalName
            TargetObject      = $refUserObj.Id
            TargetType        = 'UserId'
            RecommendedAction = "Delete conflicting administration account to comply with corporate compliance policy: $($duplicatesObj.UserPrincipalName)"
            CategoryActivity  = 'Account Compliance'
            CategoryReason    = "Other accounts were found using the same namespace."
        }
    }
    #endregion ---------------------------------------------------------------------

    #region Create or Update User Account ------------------------------------------
    $params = @{
        UserId         = $BodyParams.UserPrincipalName
        Property       = $userProperties
        ExpandProperty = $userExpandPropeties
        ErrorAction    = 'SilentlyContinue'
    }
    $existingUserObj = Get-MgUser @params

    if ($null -ne $existingUserObj) {
        if ($null -ne $existingUserObj.OnPremisesSyncEnabled) {
            $return.Error += .\Common__0000_Write-Error.ps1 @{
                Message           = "${ReferralUserId}: Conflicting Admin account $($existingUserObj.UserPrincipalName) ($($existingUserObj.Id)) $( if ($existingUserObj.OnPremisesSyncEnabled) { 'is' } else { 'was' } ) synced from on-premises."
                ErrorId           = '500'
                Category          = 'ResourceExists'
                TargetName        = $refUserObj.UserPrincipalName
                TargetObject      = $refUserObj.Id
                TargetType        = 'UserId'
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
        $params = @{
            UserId        = $existingUserObj.Id
            BodyParameter = $BodyParams
            Confirm       = $false
        }
        Update-MgUser @params 1> $null

        if ($BodyParamsNull.Count -gt 0) {
            # Workaround as properties cannot be nulled using Update-MgUser at the moment ...
            $params = @{
                OutputType = 'PSObject'
                Method     = 'PATCH'
                Uri        = "https://graph.microsoft.com/v1.0/users/$($existingUserObj.Id)"
                Body       = $BodyParamsNull
            }
            Invoke-MgGraphRequest @params 1> $null
        }
        $UserObj = Get-MgUser -UserId $existingUserObj.Id -ErrorAction SilentlyContinue
    }
    else {
        #region License Availability Validation ----------------------------------------
        $License = Get-MgSubscribedSku -All | Where-Object SkuPartNumber -eq $LicenseSkuPartNumber | Select-Object -Property Sku*, ConsumedUnits, ServicePlans -ExpandProperty PrepaidUnits
        if ($License.ConsumedUnits -ge $License.Enabled) {
            $return.Error += .\Common__0000_Write-Error.ps1 @{
                Message           = "${ReferralUserId}: License SkuPartNumber $LicenseSkuPartNumber has run out of free licenses."
                ErrorId           = '503'
                Category          = 'LimitsExceeded'
                TargetName        = $refUserObj.UserPrincipalName
                TargetObject      = $refUserObj.Id
                TargetType        = 'UserId'
                RecommendedAction = 'Purchase additional licenses to create new Cloud Administrator accounts.'
                CategoryActivity  = 'License Availability Validation'
                CategoryReason    = "License SkuPartNumber $LicenseSkuPartNumber has run out of free licenses."
            }
            $persistentError = $true
            return
        }
        #endregion ---------------------------------------------------------------------

        $UserObj = New-MgUser -BodyParameter $BodyParams -ErrorAction SilentlyContinue -Confirm:$false

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
            $UserObj = Get-MgUser @params

            if ($null -ne $UserObj) {
                $DoLoop = $false
            }
            elseif ($RetryCount -ge $MaxRetry) {
                Remove-MgUser -UserId $newUser.Id -ErrorAction SilentlyContinue -Confirm:$false 1> $null
                $DoLoop = $false

                $return.Error += .\Common__0000_Write-Error.ps1 @{
                    Message           = "${ReferralUserId}: Account provisioning consistency timeout for $($newUser.UserPrincipalName)."
                    ErrorId           = '504'
                    Category          = 'OperationTimeout'
                    TargetName        = $refUserObj.UserPrincipalName
                    TargetObject      = $refUserObj.Id
                    TargetType        = 'UserId'
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

        Write-Verbose "Created Tier $Tier Cloud Administrator account $($UserObj.UserPrincipalName) ($($UserObj.Id)) with information from $($refUserObj.UserPrincipalName) ($($refUserObj.Id))"
    }

    if ($null -eq $UserObj) {
        $return.Error += .\Common__0000_Write-Error.ps1 @{
            Message          = "${ReferralUserId}: Could not create or update Tier $Tier Cloud Administrator account $($BodyParams.UserPrincipalName): $($Error[0].Message)"
            ErrorId          = '503'
            Category         = 'NotSpecified'
            TargetName       = "$($refUserObj.UserPrincipalName): $($Error[0].CategoryInfo.TargetName)"
            TargetObject     = $refUserObj.Id
            TargetType       = 'UserId'
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
        Set-MgUserManagerByRef -UserId $UserObj.Id -BodyParameter $NewManager 1> $null
    }
    #endregion ---------------------------------------------------------------------

    #region License Availability Validation ----------------------------------------
    if (-Not $License) {
        $License = Get-MgSubscribedSku -All | Where-Object SkuPartNumber -eq $LicenseSkuPartNumber | Select-Object -Property Sku*, ConsumedUnits, ServicePlans -ExpandProperty PrepaidUnits
        if ($License.ConsumedUnits -ge $License.Enabled) {
            $return.Error += .\Common__0000_Write-Error.ps1 @{
                Message           = "${ReferralUserId}: License SkuPartNumber $LicenseSkuPartNumber has run out of free licenses."
                ErrorId           = '503'
                Category          = 'LimitsExceeded'
                TargetName        = $refUserObj.UserPrincipalName
                TargetObject      = $refUserObj.Id
                TargetType        = 'UserId'
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
    $userLicObj = Get-MgUserLicenseDetail -UserId $UserObj.Id
    if ($GroupObj) {
        #TODO remove any direct license assignment to enforce group-based licensing
    }
    elseif (-Not ($userLicObj | Where-Object SkuPartNumber -eq $LicenseSkuPartNumber)) {
        Write-Verbose "Implying direct license assignment is required as no GroupId was provided for group-based licensing."
        $params = @{
            UserId         = $UserObj.Id
            AddLicenses    = @(
                @{
                    SkuId         = $License.SkuId
                    DisabledPlans = $License.ServicePlans | Where-Object -FilterScript { ($_.AppliesTo -eq 'User') -and ($_.ServicePlanName -NotMatch 'EXCHANGE') } | Select-Object -ExpandProperty ServicePlanId
                }
            )
            RemoveLicenses = @()
        }
        Set-MgUserLicense @params 1> $null
    }
    #endregion ---------------------------------------------------------------------

    #region Group Membership Assignment --------------------------------------------
    if ($GroupObj) {
        if (
            $GroupObj.GroupType -NotContains 'DynamicMembership' -or
            ($GroupObj.MembershipRuleProcessingState -ne 'On')
        ) {
            $params = @{
                ConsistencyLevel = 'eventual'
                GroupId          = $GroupObj.Id
                CountVariable    = 'CountVar'
                Filter           = "Id eq '$($UserObj.Id)'"
            }
            if (-Not (Get-MgGroupMember @params)) {
                Write-Verbose "Implying manually adding user to static group $($GroupObj.DisplayName) ($($GroupObj.Id))"
                New-MgBetaGroupMember -GroupId $GroupObj.Id -DirectoryObjectId $UserObj.Id
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
            if ($null -ne (Get-MgGroupMember @params)) {
                Write-Verbose "OK: Detected group memnbership."
                $DoLoop = $false
            }
            elseif ($RetryCount -ge $MaxRetry) {
                Remove-MgUser -UserId $UserObj.Id -ErrorAction SilentlyContinue -Confirm:$false 1> $null
                $DoLoop = $false

                $return.Error += .\Common__0000_Write-Error.ps1 @{
                    Message           = "${ReferralUserId}: Group assignment timeout for $($newUser.UserPrincipalName)."
                    ErrorId           = '504'
                    Category          = 'OperationTimeout'
                    TargetName        = $refUserObj.UserPrincipalName
                    TargetObject      = $refUserObj.Id
                    TargetType        = 'UserId'
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
        $userLicObj = Get-MgUserLicenseDetail -UserId $UserObj.Id
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
            Write-Verbose "OK: Detected license provisioning completion."
            $DoLoop = $false
        }
        elseif ($RetryCount -ge $MaxRetry) {
            Remove-MgUser -UserId $UserObj.Id -ErrorAction SilentlyContinue -Confirm:$false 1> $null
            $DoLoop = $false

            $return.Error += .\Common__0000_Write-Error.ps1 @{
                Message           = "${ReferralUserId}: Exchange Online license activation timeout for $($newUser.UserPrincipalName)."
                ErrorId           = '504'
                Category          = 'OperationTimeout'
                TargetName        = $refUserObj.UserPrincipalName
                TargetObject      = $refUserObj.Id
                TargetType        = 'UserId'
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
        $userExObj = Get-EXOMailbox -ExternalDirectoryObjectId $UserObj.Id -ErrorAction SilentlyContinue
        if ($null -ne $userExObj) {
            Write-Verbose "OK: Detected mailbox provisioning completion."
            $DoLoop = $false
        }
        elseif ($RetryCount -ge $MaxRetry) {
            Remove-MgUser -UserId $UserObj.Id -ErrorAction SilentlyContinue -Confirm:$false 1> $null
            $DoLoop = $false

            $return.Error += .\Common__0000_Write-Error.ps1 @{
                Message           = "${ReferralUserId}: Mailbox provisioning timeout for $($newUser.UserPrincipalName)."
                ErrorId           = '504'
                Category          = 'OperationTimeout'
                TargetName        = $refUserObj.UserPrincipalName
                TargetObject      = $refUserObj.Id
                TargetType        = 'UserId'
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
    $params = @{
        Identity                      = $userExObj.Identity
        ForwardingAddress             = $refUserExObj.Identity
        ForwardingSmtpAddress         = $null
        DeliverToMailboxAndForward    = $false
        HiddenFromAddressListsEnabled = $true
        WarningAction                 = 'SilentlyContinue'
    }
    Set-Mailbox @params 1> $null

    $userExMbObj = Get-Mailbox -Identity $userExObj.Identity
    $UserObj = Get-MgUser -UserId $UserObj.Id -Property $userProperties -ExpandProperty $userExpandPropeties
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
        $params = @{
            UseBasicParsing = $true
            Method          = 'GET'
            Uri             = $Url
            TimeoutSec      = 10
            ErrorAction     = 'SilentlyContinue'
            OutVariable     = 'UserPhoto'
        }
        Invoke-WebRequest @params 1> $null

        if (
            (-Not $UserPhoto) -or
            ($UserPhoto.StatusCode -ne 200) -or
            (-Not $UserPhoto.Content)
        ) {
            Write-Error "Unable to download photo from URL '$($Url)'"
        }
        elseif (
            $UserPhoto.Headers.'Content-Type' -notmatch '^image/'
        ) {
            Write-Error "Photo from URL '$($Url)' must have Content-Type 'image/*'."
        }
        else {
            Write-Verbose 'Updating user photo'
            $params = @{
                InFile = 'nonExistat.lat'
                UserId = $UserObj.Id
                Data   = ([System.IO.MemoryStream]::new($UserPhoto.Content))
            }
            Set-MgUserPhotoContent @params 1> $null
        }
    }
    #endregion ---------------------------------------------------------------------

    #region Add Return Data --------------------------------------------------------
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
            Id                = $UserObj.Manager.Id
            UserPrincipalName = $UserObj.manager.AdditionalProperties.userPrincipalName
            Mail              = $UserObj.manager.AdditionalProperties.mail
            DisplayName       = $UserObj.manager.AdditionalProperties.displayName
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
    if ($PhotoUrl ) { $data.UserPhotoUrl = $PhotoUrl }

    if (-Not $return.Data) { $return.Data = @() }
    $return.Data += $data

    if ($OutText) {
        Write-Output $(if ($data.UserPrincipalName) { $data.UserPrincipalName } else { $null })
    }
    #endregion ---------------------------------------------------------------------

    Write-Verbose "-------ENDLOOP $ReferralUserId ---"
}

0..$($ReferralUserId.Count) | ForEach-Object {
    if ([string]::IsNullOrEmpty($ReferralUserId[$_])) { return }
    if ([string]::IsNullOrEmpty($Tier[$_])) { return }
    $params = @{
        ReferralUserId = $ReferralUserId[$_]
        Tier           = $Tier[$_]
        UserPhotoUrl   = if ([string]::IsNullOrEmpty($UserPhotoUrl)) { $null } else { $UserPhotoUrl[$_] }
    }
    ProcessItem @params
}
#endregion ---------------------------------------------------------------------

#region Send and Output Return Data --------------------------------------------
$return.Job.EndTime = (Get-Date).ToUniversalTime()
$return.Job.Runtime = $return.Job.EndTime - $return.Job.StartTime

if ($Webhook) { .\Common__0000_Submit-Webhook.ps1 -Uri $Webhook -Body $return 1> $null }
$InformationPreference = $origInformationPreference
if (($true -eq $OutText) -or ($PSBoundParameters.Keys -contains 'OutJson') -and ($false -eq $OutJson)) { return }
if ($OutJson) { .\Common__0000_Write-JsonOutput.ps1 $return; return }

return $return
#endregion ---------------------------------------------------------------------
