<#PSScriptInfo
.VERSION 0.0.1
.GUID c9836025-b441-474a-8c61-f7c3d17ebb23
.AUTHOR Julian Pawlowski
.COMPANYNAME Workoho GmbH
.COPYRIGHT (c) 2024 Workoho GmbH. All rights reserved.
.TAGS
.LICENSEURI
.PROJECTURI
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>

<#
.SYNOPSIS
    Get all dedicated cloud administrator accounts for a user ID.

.DESCRIPTION
    Searches for any dedicated cloud administrator account that is tied to the given user ID.

    NOTE: This script uses the Microsoft Graph Beta API as it requires support for Restricted Management Administrative Units which is not available in the stable API.

.PARAMETER ReferralUserId
    User account identifier of the main user account. May be an Entra Identity Object ID or User Principal Name (UPN).

.PARAMETER Tier
    The Tier level where the Cloud Administrator account shall be searched in.

.PARAMETER JobReference
    This information may be added for back reference in other IT systems. It will simply be added to the Job data.

.PARAMETER OutputJson
    Output the result in JSON format.
    This is useful when output data needs to be processed in other IT systems after the job was completed.

.PARAMETER OutputText
    Output the found User Principal Names only.
#>

[CmdletBinding()]
Param (
    [Parameter(Position = 0, mandatory = $true)]
    [Array]$ReferralUserId,

    [Parameter(Position = 1, mandatory = $false)]
    [Array]$Tier,

    [Boolean]$OutJson,
    [Boolean]$OutText,
    [Object]$JobReference
)

if ($PSCommandPath) {
    Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | ForEach-Object { $_.PSObject.Properties | ForEach-Object { $_.Name + ': ' + $_.Value } }) -join ', ') ---"
}

#region [COMMON] SCRIPT CONFIGURATION PARAMETERS -------------------------------
#
# IMPORTANT: You should actually NOT change these parameters here. Instead, use the environment variables described above.
# These parameters here exist quite far up in this file so that you get a quick idea of some
# interesting aspects of the dependencies, e.g. when performing a code audit for security reasons.

$ImportPsModules = @(
    @{ Name = 'Microsoft.Graph.Beta.Users'; MinimumVersion = '2.0'; MaximumVersion = '2.65535' }
    @{ Name = 'Microsoft.Graph.Beta.Groups'; MinimumVersion = '2.0'; MaximumVersion = '2.65535' }
)

$MgGraphScopes = @(
    'User.Read.All'
    'Directory.Read.All'
    'Organization.Read.All'
    'OnPremDirectorySynchronization.Read.All'
)

$MgGraphDirectoryRoles = @(
    @{
        DisplayName = 'User Administrator'
        TemplateId  = 'fe930be7-5e62-47db-91af-98c3a49a38b1'
    }
)
#endregion ---------------------------------------------------------------------

#region [COMMON] PARAMETER COUNT VALIDATION ------------------------------------
if (
    ($ReferralUserId.Count -gt 1) -and
    ($ReferralUserId.Count -ne $Tier.Count)
) {
    Throw 'ReferralUserId and Tier must contain the same number of items for batch processing.'
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
.\Common_0000__Import-Modules.ps1 -Modules $ImportPsModules 1> $null
.\Common_0003__Import-AzAutomationVariableToPSEnv.ps1 1> $null
.\Common_0000__Convert-PSEnvToPSLocalVariable.ps1 -Variable (.\CloudAdmin_0000__Common_0000__Get-ConfigurationConstants.ps1) 1> $null
#endregion ---------------------------------------------------------------------

#region [COMMON] INITIALIZE SCRIPT VARIABLES -----------------------------------
$persistentError = $false
$Iteration = 0

# To improve memory usage, return arrays are kept separate until the very end
$returnOutput = @()
$returnInformation = @()
$returnWarning = @()
$returnError = @()
$return = @{
    Job = @{
        Runbook   = @{}
        StartTime = (Get-Date).ToUniversalTime()
        EndTime   = @{}
        RunTime   = @{}
    }
}
if ($JobReference) { $return.Job.Reference = $JobReference }
#endregion ---------------------------------------------------------------------

#region [COMMON] CONCURRENT JOBS -----------------------------------------------
if (-Not (.\Common_0002__Wait-AzAutomationConcurrentJob.ps1)) {
    $script:returnError += .\Common_0000__Write-Error.ps1 @{
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
.\Common_0001__Connect-MgGraph.ps1 -Scopes $MgGraphScopes 1> $null
$tenant = Get-MgOrganization -OrganizationId (Get-MgContext).TenantId
$tenantDomain = $tenant.VerifiedDomains | Where-Object IsInitial -eq true
$tenantBranding = Get-MgOrganizationBranding -OrganizationId $tenant.Id
.\Common_0003__Confirm-MgDirectoryRoleActiveAssignment.ps1 -Roles $MgGraphDirectoryRoles 1> $null
.\Common_0003__Confirm-MgAppPermission.ps1 -Permissions $MgAppPermissions 1> $null
.\Common_0001__Connect-ExchangeOnline.ps1 -Organization $tenantDomain.Name 1> $null
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
        ErrorAction    = 'Stop'
    }

    try {
        $GroupObj = Get-MgBetaGroup @params
    }
    catch {
        Throw $_
    }

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
        .\Common_0003__Confirm-MgDirectoryRoleActiveAssignment.ps1 -WarningAction SilentlyContinue -Roles @(
            @{
                DisplayName = 'Privileged Role Administrator'
                TemplateId  = 'e8611ab8-c189-46e8-94e1-60213ab1f814'
            }
        ) 1> $null
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
    #TODO check for assigned roles and remove them
    if ($GroupObj.Owners) {
        foreach ($owner in $GroupObj.Owners) {
            Write-Warning "Group $($GroupObj.DisplayName) ($($GroupObj.Id)): Removing unwanted group owner $($owner.Id)"
            try {
                Remove-MgBetaGroupOwnerByRef -GroupId $GroupObj.Id -DirectoryObjectId $owner.Id -ErrorAction Stop 1> $null
            }
            catch {
                Throw $_
            }
        }
    }
}
#endregion ---------------------------------------------------------------------

#region License Existance Validation -------------------------------------------
$TenantLicensed = Get-MgSubscribedSku -All
$SkuPartNumberWithExchangeServicePlan = $null
ForEach (
    $SkuPartNumber in @(
        @(($LicenseSkuPartNumber_Tier0 -split ' '); ($LicenseSkuPartNumber_Tier1 -split ' '); ($LicenseSkuPartNumber_Tier2 -split ' ')) | Select-Object -Unique
    )
) {
    if ([String]::IsNullOrEmpty($SkuPartNumber)) { continue }
    $Sku = $TenantLicensed | Where-Object SkuPartNumber -eq $SkuPartNumber | Select-Object -Property Sku*, ServicePlans

    if (-Not $Sku) {
        Throw "License SkuPartNumber $LicenseSkuPartNumber is not available to this tenant. Licenses must be purchased to before creating Cloud Administrator accounts."
    }
    if ($Sku.ServicePlans | Where-Object -FilterScript { ($_.AppliesTo -eq 'User') -and ($_.ServicePlanName -Match 'EXCHANGE') }) {
        if ($null -eq $SkuPartNumberWithExchangeServicePlan) {
            $SkuPartNumberWithExchangeServicePlan = $Sku.SkuPartNumber
            Write-Verbose "Detected Exchange Online service plan in SkuPartNumber $SkuPartNumberWithExchangeServicePlan."
        }
        else {
            Throw "There can only be one license configured containing an Exchange Online service plan: Make your choice between $SkuPartNumberWithExchangeServicePlan and $($Sku.SkuPartNumber)."
        }
    }
}
if ($null -eq $SkuPartNumberWithExchangeServicePlan) {
    Throw "One of the configured SkuPartNumbers must contain an Exchange Online service plan."
}
#endregion ---------------------------------------------------------------------

#region Process Referral User --------------------------------------------------
function ProcessReferralUser ($ReferralUserId, $Tier, $UserPhotoUrl) {
    Write-Verbose "-----STARTLOOP $ReferralUserId, Tier $Tier ---"

    #region [COMMON] LOOP HANDLING -------------------------------------------------
    # Only process items if there was no error during script initialization before
    if (($Iteration -eq 0) -and ($returnError.Count -gt 0)) { $persistentError = $true }
    if ($persistentError) {
        $script:returnError += .\Common_0000__Write-Error.ps1 @{
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
    .\Common_0000__Convert-PSEnvToPSLocalVariable.ps1 -Variable $Constants -scriptParameterOnly $true 1> $null

    $DedicatedAccount = Get-Variable -ValueOnly -Name "DedicatedAccount_Tier$Tier"
    $UpdatedUserOnly = $false
    $LicenseSkuPartNumber = Get-Variable -ValueOnly -Name "LicenseSkuPartNumber_Tier$Tier"
    $GroupId = Get-Variable -ValueOnly -Name "GroupId_Tier$Tier"
    $PhotoUrlUser = Get-Variable -ValueOnly -Name "PhotoUrl_Tier$Tier"
    $GroupObj = $null
    $UserObj = $null
    $TenantLicensed = $null

    if (-Not [string]::IsNullOrEmpty($GroupId)) {
        $GroupObj = Get-MgBetaGroup -GroupId $GroupId
    }
    #endregion ---------------------------------------------------------------------

    #region Group Validation -------------------------------------------------------
    if ($GroupObj) {
        $GroupDescription = Get-Variable -ValueOnly -name "GroupDescription_Tier$Tier"
        if (-Not $GroupObj.Description) {
            Write-Warning "Group $($GroupObj.DisplayName) ($($GroupObj.Id)): Adding missing description for Tier $Tier identification"
            try {
                Update-MgBetaGroup -GroupId -Description $GroupDescription -ErrorAction Stop 1> $null
            }
            catch {
                $script:returnError += .\Common_0000__Write-Error.ps1 @{
                    Message          = $Error[0].Exception.Message
                    ErrorId          = '500'
                    Category         = $Error[0].CategoryInfo.Category
                    TargetName       = $refUserObj.UserPrincipalName
                    TargetObject     = $refUserObj.Id
                    TargetType       = 'UserId'
                    CategoryActivity = 'Account Provisioning'
                    CategoryReason   = $Error[0].CategoryInfo.Reason
                }
                $persistentError = $true
                return
            }
        }
        elseif ($GroupObj.Description -ne $GroupDescription) {
            $script:returnError += .\Common_0000__Write-Error.ps1 @{
                Message          = "${ReferralUserId}: Internal configuration error."
                ErrorId          = '500'
                Category         = 'InvalidData'
                TargetName       = $refUserObj.UserPrincipalName
                TargetObject     = $refUserObj.Id
                TargetType       = 'UserId'
                CategoryActivity = 'Account Provisioning'
                CategoryReason   = "Group $($GroupObj.DisplayName) ($($GroupObj.Id)): The description does not clearly identify this group as a Tier $Tier Administrators group. To avoid incorrect group assignments, please check that you are using the correct group. To use this group for Tier $Tier management, set the description property to '$GroupDescription'."
            }
            $persistentError = $true
            return
        }

        if (($DedicatedAccount -eq $false) -and
            ($GroupObj.GroupType -Contains 'DynamicMembership') -and
            ($GroupObj.MembershipRuleProcessingState -eq 'On')
        ) {
            $script:returnError += .\Common_0000__Write-Error.ps1 @{
                Message          = "${ReferralUserId}: Internal configuration error."
                ErrorId          = '500'
                Category         = 'InvalidData'
                TargetName       = $refUserObj.UserPrincipalName
                TargetObject     = $refUserObj.Id
                TargetType       = 'UserId'
                CategoryActivity = 'Cloud Administrator Creation'
                CategoryReason   = "Group for Tier $Tier Cloud Administration must not use Dynamic Membership."
            }
            return
        }
    }
    #endregion

    #region [COMMON] PARAMETER VALIDATION ------------------------------------------
    $regex = '^[^\s]+@[^\s]+\.[^\s]+$|^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$'
    if ($ReferralUserId -notmatch $regex) {
        $script:returnError += .\Common_0000__Write-Error.ps1 @{
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
        $script:returnError += .\Common_0000__Write-Error.ps1 @{
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
        $script:returnError += .\Common_0000__Write-Error.ps1 @{
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
        'CreatedDateTime'
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
        ErrorAction    = 'Stop'
    }
    try {
        $refUserObj = Get-MgBetaUser @params
    }
    catch {
        $script:returnError += .\Common_0000__Write-Error.ps1 @{
            Message          = $Error[0].Exception.Message
            ErrorId          = '500'
            Category         = $Error[0].CategoryInfo.Category
            TargetName       = $refUserObj.UserPrincipalName
            TargetObject     = $refUserObj.Id
            TargetType       = 'UserId'
            CategoryActivity = 'ReferralUserId user validation'
            CategoryReason   = $Error[0].CategoryInfo.Reason
        }
        return
    }

    if ($null -eq $refUserObj) {
        $script:returnError += .\Common_0000__Write-Error.ps1 @{
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
        $script:returnError += .\Common_0000__Write-Error.ps1 @{
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
        $script:returnError += .\Common_0000__Write-Error.ps1 @{
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
        $script:returnError += .\Common_0000__Write-Error.ps1 @{
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
        $script:returnError += .\Common_0000__Write-Error.ps1 @{
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

    if ([string]::IsNullOrEmpty($refUserObj.DisplayName)) {
        $script:returnError += .\Common_0000__Write-Error.ps1 @{
            Message          = "${ReferralUserId}: Referral User ID must have display name set."
            ErrorId          = '403'
            Category         = 'InvalidType'
            TargetName       = $refUserObj.UserPrincipalName
            TargetObject     = $refUserObj.Id
            TargetType       = 'UserId'
            CategoryActivity = 'ReferralUserId user validation'
            CategoryReason   = 'Referral User ID must have DisplayName property set.'
        }
        return
    }

    if ($refUserObj.DisplayName -match '^[^\s]+@[^\s]+\.[^\s]+$') {
        $script:returnError += .\Common_0000__Write-Error.ps1 @{
            Message          = "${ReferralUserId}: Referral User ID display name must be an e-mail address."
            ErrorId          = '403'
            Category         = 'InvalidType'
            TargetName       = $refUserObj.UserPrincipalName
            TargetObject     = $refUserObj.Id
            TargetType       = 'UserId'
            CategoryActivity = 'ReferralUserId user validation'
            CategoryReason   = 'Referral User ID must have a DisplayName containing given name and last name.'
        }
        return
    }

    if (
        (-Not $refUserObj.Manager) -or
        (-Not $refUserObj.Manager.Id)
    ) {
        $script:returnError += .\Common_0000__Write-Error.ps1 @{
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

    if (
        ($null -ne $refUserObj.EmployeeHireDate) -and
        ($return.Job.StartTime -lt $refUserObj.EmployeeHireDate)
    ) {
        $script:returnError += .\Common_0000__Write-Error.ps1 @{
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
        ($return.Job.StartTime -ge $refUserObj.EmployeeLeaveDateTime.AddDays(-45))
    ) {
        $script:returnError += .\Common_0000__Write-Error.ps1 @{
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

    if ($true -eq $tenant.OnPremisesSyncEnabled -and ($true -ne $refUserObj.OnPremisesSyncEnabled)) {
        $script:returnError += .\Common_0000__Write-Error.ps1 @{
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
        $script:returnError += .\Common_0000__Write-Error.ps1 @{
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
        $script:returnError += .\Common_0000__Write-Error.ps1 @{
            Message          = "${ReferralUserId}: Referral User ID mailbox must be of type UserMailbox."
            ErrorId          = '403'
            Category         = 'InvalidType'
            TargetName       = $refUserObj.UserPrincipalName
            TargetObject     = $refUserObj.Id
            TargetType       = 'UserId'
            CategoryActivity = 'ReferralUserId user validation'
            CategoryReason   = "Cloud Administrator accounts can not be created for user mailbox types of $($refUserExObj.RecipientTypeDetails)"
        }
        return
    }
    #endregion ---------------------------------------------------------------------

    #region No Dedicated User Account required -------------------------------------
    if ($DedicatedAccount -eq $false) {
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
            $script:returnError += .\Common_0000__Write-Error.ps1 @{
                Message          = "${ReferralUserId}: Internal configuration error."
                ErrorId          = '500'
                Category         = 'InvalidData'
                TargetName       = $refUserObj.UserPrincipalName
                TargetObject     = $refUserObj.Id
                TargetType       = 'UserId'
                CategoryActivity = 'Cloud Administrator Creation'
                CategoryReason   = "A group must be configured for Tier $Tier Cloud Administration in variable AV_CloudAdminTier${Tier}_GroupId."
            }
            return
        }
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

        if ($UserPhotoUrl ) { $data.Input.UserPhotoUrl = $UserPhotoUrl }

        if ($OutText) {
            Write-Output $(if ($data.UserPrincipalName) { $data.UserPrincipalName } else { $null })
        }
        #endregion ---------------------------------------------------------------------

        Write-Verbose "-------ENDLOOP $ReferralUserId ---"
        return $data
    }
    #endregion

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
        UserPrincipalName             = $UserPrefix + ($refUserObj.UserPrincipalName).Split('@')[0] + $UserSuffix + '@' + $tenantDomain.Name
        Mail                          = $UserPrefix + ($refUserObj.UserPrincipalName).Split('@')[0] + $UserSuffix + '@' + $tenantDomain.Name
        MailNickname                  = $UserPrefix + $refUserObj.MailNickname + $UserSuffix
        PasswordProfile               = @{
            Password                             = .\Common_0000__Get-RandomPassword.ps1 -lowerChars 32 -upperChars 32 -numbers 32 -symbols 32
            ForceChangePasswordNextSignIn        = $false
            ForceChangePasswordNextSignInWithMfa = $false
        }
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
        $script:returnError += .\Common_0000__Write-Error.ps1 @{
            Message          = "${ReferralUserId}: Internal configuration error."
            ErrorId          = '500'
            Category         = 'InvalidData'
            TargetName       = $refUserObj.UserPrincipalName
            TargetObject     = $refUserObj.Id
            TargetType       = 'UserId'
            CategoryActivity = 'Cloud Administrator Creation'
            CategoryReason   = "Either EmployeeType or extensionAttribute method must be configured to store account type."
        }
        $persistentError = $true
        return
    }

    $extAttrRef = 'extensionAttribute' + $ReferenceExtensionAttribute
    if (-Not [string]::IsNullOrEmpty($ReferenceExtensionAttribute)) {
        if (
            (-Not [string]::IsNullOrEmpty($BodyParams.OnPremisesExtensionAttributes.$extAttrRef)) -or
            (-Not [string]::IsNullOrEmpty($refUserObj.OnPremisesExtensionAttributes.$extAttrRef))
        ) {
            $script:returnError += .\Common_0000__Write-Error.ps1 @{
                Message          = "${ReferralUserId}: Internal configuration error."
                ErrorId          = '500'
                Category         = 'ResourceExists'
                TargetName       = $refUserObj.UserPrincipalName
                TargetObject     = $refUserObj.Id
                TargetType       = 'UserId'
                CategoryActivity = 'Cloud Administrator Creation'
                CategoryReason   = "Reference extension attribute '$extAttrRef' must not be used by other IT services."
            }
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
        $script:returnError += .\Common_0000__Write-Error.ps1 @{
            Message          = "${ReferralUserId}: Internal configuration error."
            ErrorId          = '500'
            Category         = 'InvalidData'
            TargetName       = $refUserObj.UserPrincipalName
            TargetObject     = $refUserObj.Id
            TargetType       = 'UserId'
            CategoryActivity = 'Cloud Administrator Creation'
            CategoryReason   = "Either EmployeeType or extensionAttribute method must be configured to store account type."
        }
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
            $script:returnInformation += .\Common_0000__Write-Information.ps1 @{
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

        $script:returnWarning += .\Common_0000__Write-Warning.ps1 @{
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
    $existingUserObj = Get-MgBetaUser @params

    if ($null -ne $existingUserObj) {
        if ($null -ne $existingUserObj.OnPremisesSyncEnabled) {
            $script:returnError += .\Common_0000__Write-Error.ps1 @{
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

        $BodyParams.Remove('UserPrincipalName')
        $BodyParams.Remove('AccountEnabled')
        $BodyParams.Remove('PasswordProfile')
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
            $script:returnError += .\Common_0000__Write-Error.ps1 @{
                Message          = $Error[0].Exception.Message
                ErrorId          = '500'
                Category         = $Error[0].CategoryInfo.Category
                TargetName       = $refUserObj.UserPrincipalName
                TargetObject     = $refUserObj.Id
                TargetType       = 'UserId'
                CategoryActivity = 'Account Provisioning'
                CategoryReason   = $Error[0].CategoryInfo.Reason
            }
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
                $script:returnError += .\Common_0000__Write-Error.ps1 @{
                    Message          = $Error[0].Exception.Message
                    ErrorId          = '500'
                    Category         = $Error[0].CategoryInfo.Category
                    TargetName       = $refUserObj.UserPrincipalName
                    TargetObject     = $refUserObj.Id
                    TargetType       = 'UserId'
                    CategoryActivity = 'Account Provisioning'
                    CategoryReason   = $Error[0].CategoryInfo.Reason
                }
                return
            }
        }
        $UserObj = Get-MgBetaUser -UserId $existingUserObj.Id
        $UpdatedUserOnly = $true
        Write-Verbose "Updated existing Tier $Tier Cloud Administrator account $($UserObj.UserPrincipalName) ($($UserObj.Id)) with information from $($refUserObj.UserPrincipalName) ($($refUserObj.Id))" -Verbose
    }
    else {
        #region License Availability Validation ----------------------------------------
        $TenantLicensed = Get-MgSubscribedSku -All | Where-Object SkuPartNumber -in @($LicenseSkuPartNumber -split ' ') | Select-Object -Property Sku*, ConsumedUnits, ServicePlans -ExpandProperty PrepaidUnits
        foreach ($Sku in $TenantLicensed) {
            if ($Sku.ConsumedUnits -ge $Sku.Enabled) {
                $script:returnError += .\Common_0000__Write-Error.ps1 @{
                    Message           = "${ReferralUserId}: License SkuPartNumber $($Sku.SkuPartNumber) has run out of free licenses."
                    ErrorId           = '503'
                    Category          = 'LimitsExceeded'
                    TargetName        = $refUserObj.UserPrincipalName
                    TargetObject      = $refUserObj.Id
                    TargetType        = 'UserId'
                    RecommendedAction = 'Purchase additional licenses to create new Cloud Administrator accounts.'
                    CategoryActivity  = 'License Availability Validation'
                    CategoryReason    = "License SkuPartNumber $($Sku.SkuPartNumber) has run out of free licenses."
                }
                $persistentError = $true
            }
            else {
                Write-Verbose "License SkuPartNumber $($Sku.SkuPartNumber) has at least 1 free license available to continue"
            }
        }
        if ($persistentError) { return }
        #endregion ---------------------------------------------------------------------

        try {
            $UserObj = New-MgBetaUser -BodyParameter $BodyParams -ErrorAction Stop
        }
        catch {
            $script:returnError += .\Common_0000__Write-Error.ps1 @{
                Message          = $Error[0].Exception.Message
                ErrorId          = '500'
                Category         = $Error[0].CategoryInfo.Category
                TargetName       = $refUserObj.UserPrincipalName
                TargetObject     = $refUserObj.Id
                TargetType       = 'UserId'
                CategoryActivity = 'Account Provisioning'
                CategoryReason   = $Error[0].CategoryInfo.Reason
            }
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

                $script:returnError += .\Common_0000__Write-Error.ps1 @{
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

        Write-Verbose "Created new Tier $Tier Cloud Administrator account $($UserObj.UserPrincipalName) ($($UserObj.Id)) with information from $($refUserObj.UserPrincipalName) ($($refUserObj.Id))" -Verbose
    }

    if ($null -eq $UserObj) {
        $script:returnError += .\Common_0000__Write-Error.ps1 @{
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
                $script:returnError += .\Common_0000__Write-Error.ps1 @{
                    Message          = $Error[0].Exception.Message
                    ErrorId          = '500'
                    Category         = $Error[0].CategoryInfo.Category
                    TargetName       = $refUserObj.UserPrincipalName
                    TargetObject     = $refUserObj.Id
                    TargetType       = 'UserId'
                    CategoryActivity = 'Account Provisioning'
                    CategoryReason   = $Error[0].CategoryInfo.Reason
                }
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
            $script:returnError += .\Common_0000__Write-Error.ps1 @{
                Message          = $Error[0].Exception.Message
                ErrorId          = '500'
                Category         = $Error[0].CategoryInfo.Category
                TargetName       = $refUserObj.UserPrincipalName
                TargetObject     = $refUserObj.Id
                TargetType       = 'UserId'
                CategoryActivity = 'Account Provisioning'
                CategoryReason   = $Error[0].CategoryInfo.Reason
            }
            return
        }
    }
    #endregion ---------------------------------------------------------------------

    #region License Availability Validation ----------------------------------------
    if (-Not $TenantLicensed) {
        $TenantLicensed = Get-MgSubscribedSku -All | Where-Object SkuPartNumber -in @($LicenseSkuPartNumber -split ' ' | Select-Object -Unique) | Select-Object -Property Sku*, ConsumedUnits, ServicePlans -ExpandProperty PrepaidUnits
        foreach ($Sku in $TenantLicensed) {
            if ($Sku.ConsumedUnits -ge $Sku.Enabled) {
                $script:returnError += .\Common_0000__Write-Error.ps1 @{
                    Message           = "${ReferralUserId}: License SkuPartNumber $($Sku.SkuPartNumber) has run out of free licenses."
                    ErrorId           = '503'
                    Category          = 'LimitsExceeded'
                    TargetName        = $refUserObj.UserPrincipalName
                    TargetObject      = $refUserObj.Id
                    TargetType        = 'UserId'
                    RecommendedAction = 'Purchase additional licenses to create new Cloud Administrator accounts.'
                    CategoryActivity  = 'License Availability Validation'
                    CategoryReason    = "License SkuPartNumber $($Sku.SkuPartNumber) has run out of free licenses."
                }
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
            AddLicenses    = @()
            RemoveLicenses = @()
            ErrorAction    = 'Stop'
        }

        foreach ($SkuPartNumber in @($LicenseSkuPartNumber -split ' ' | Select-Object -Unique)) {
            if (-Not ($UserLicensed | Where-Object SkuPartNumber -eq $SkuPartNumber)) {
                Write-Verbose "Adding missing license $SkuPartNumber"
                $Sku = $TenantLicensed | Where-Object SkuPartNumber -eq $SkuPartNumber
                $license = @{
                    SkuId = $Sku.SkuId
                }
                if ($SkuPartNumber -eq $SkuPartNumberWithExchangeServicePlan) {
                    $license.DisabledPlans = $Sku.ServicePlans | Where-Object -FilterScript { ($_.AppliesTo -eq 'User') -and ($_.ServicePlanName -NotMatch 'EXCHANGE') } | Select-Object -ExpandProperty ServicePlanId
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
                $script:returnError += .\Common_0000__Write-Error.ps1 @{
                    Message          = $Error[0].Exception.Message
                    ErrorId          = '500'
                    Category         = $Error[0].CategoryInfo.Category
                    TargetName       = $refUserObj.UserPrincipalName
                    TargetObject     = $refUserObj.Id
                    TargetType       = 'UserId'
                    CategoryActivity = 'Account Provisioning'
                    CategoryReason   = $Error[0].CategoryInfo.Reason
                }
                return
            }
        }
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
            if (-Not (Get-MgBetaGroupMember @params)) {
                Write-Verbose "Implying manually adding user to static group $($GroupObj.DisplayName) ($($GroupObj.Id))"
                try {
                    New-MgBetaGroupMember -GroupId $GroupObj.Id -DirectoryObjectId $UserObj.Id -ErrorAction Stop
                }
                catch {
                    $script:returnError += .\Common_0000__Write-Error.ps1 @{
                        Message          = $Error[0].Exception.Message
                        ErrorId          = '500'
                        Category         = $Error[0].CategoryInfo.Category
                        TargetName       = $refUserObj.UserPrincipalName
                        TargetObject     = $refUserObj.Id
                        TargetType       = 'UserId'
                        CategoryActivity = 'Account Provisioning'
                        CategoryReason   = $Error[0].CategoryInfo.Reason
                    }
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

                $script:returnError += .\Common_0000__Write-Error.ps1 @{
                    Message           = "${ReferralUserId}: Group assignment timeout for $($UserObj.UserPrincipalName)."
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
        $UserLicensed = Get-MgBetaUserLicenseDetail -UserId $UserObj.Id
        if (
            ($null -ne $UserLicensed) -and
            (
                $UserLicensed.ServicePlans | Where-Object -FilterScript {
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

            $script:returnError += .\Common_0000__Write-Error.ps1 @{
                Message           = "${ReferralUserId}: Exchange Online license activation timeout for $($UserObj.UserPrincipalName)."
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
            if (-Not $UpdatedUserOnly) {
                Remove-MgBetaUser -UserId $UserObj.Id -ErrorAction SilentlyContinue 1> $null
            }
            $DoLoop = $false

            $script:returnError += .\Common_0000__Write-Error.ps1 @{
                Message           = "${ReferralUserId}: Mailbox provisioning timeout for $($UserObj.UserPrincipalName)."
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
        ErrorAction                   = 'Stop'
    }
    try {
        Set-Mailbox @params 1> $null
    }
    catch {
        $script:returnError += .\Common_0000__Write-Error.ps1 @{
            Message          = $Error[0].Exception.Message
            ErrorId          = '500'
            Category         = $Error[0].CategoryInfo.Category
            TargetName       = $refUserObj.UserPrincipalName
            TargetObject     = $refUserObj.Id
            TargetType       = 'UserId'
            CategoryActivity = 'Account Provisioning'
            CategoryReason   = $Error[0].CategoryInfo.Reason
        }
        return
    }

    $userExMbObj = Get-Mailbox -Identity $userExObj.Identity
    $UserObj = Get-MgBetaUser -UserId $UserObj.Id -Property $userProperties -ExpandProperty $userExpandPropeties
    #endregion ---------------------------------------------------------------------

    #region Set User Photo ---------------------------------------------------------
    $PhotoUrls = @()
    if ($PhotoUrlUser) { $PhotoUrls += $PhotoUrlUser }

    $SquareLogoRelativeUrl = if ($tenantBranding.SquareLogoRelativeUrl) {
        $tenantBranding.SquareLogoRelativeUrl
    }
    elseif ($tenantBranding.SquareLogoDarkRelativeUrl) {
        $tenantBranding.SquareLogoDarkRelativeUrl
    }
    else { $null }
    if ($SquareLogoRelativeUrl) {
        foreach ($Cdn in $tenantBranding.CdnList) {
            $PhotoUrls += 'https://' + $Cdn + '/' + $SquareLogoRelativeUrl
        }
    }

    $PhotoUrl = $null
    $response = $null
    foreach ($url in $PhotoUrls) {
        try {
            $params = @{
                UseBasicParsing = $true
                Method          = 'GET'
                Uri             = $url
                TimeoutSec      = 10
                ErrorAction     = 'Stop'
            }
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
            $script:returnError += .\Common_0000__Write-Warning.ps1 @{
                Message          = $Error[0].Exception.Message
                ErrorId          = '500'
                Category         = $Error[0].CategoryInfo.Category
                TargetName       = $refUserObj.UserPrincipalName
                TargetObject     = $refUserObj.Id
                TargetType       = 'UserId'
                CategoryActivity = 'Account Provisioning'
                CategoryReason   = $Error[0].CategoryInfo.Reason
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

    if ($UserPhotoUrl ) { $data.Input.UserPhotoUrl = $UserPhotoUrl }
    if ($PhotoUrl ) { $data.UserPhotoUrl = $PhotoUrl }

    if ($OutText) {
        Write-Output $(if ($data.UserPrincipalName) { $data.UserPrincipalName } else { $null })
    }
    #endregion ---------------------------------------------------------------------

    Write-Verbose "-------ENDLOOP $ReferralUserId ---"

    return $data
}

0..$($ReferralUserId.Count) | ForEach-Object {
    if ([string]::IsNullOrEmpty($ReferralUserId[$_])) { return }
    if ([string]::IsNullOrEmpty($Tier[$_])) { return }
    [System.GC]::Collect()
    $params = @{
        ReferralUserId = $ReferralUserId[$_]
        Tier           = $Tier[$_]
        UserPhotoUrl   = if ([string]::IsNullOrEmpty($UserPhotoUrl) -or [string]::IsNullOrEmpty($UserPhotoUrl[$_])) { $null } else { $UserPhotoUrl[$_] }
    }
    $returnOutput += ProcessReferralUser @params
}
#endregion ---------------------------------------------------------------------

#region Output Return Data -----------------------------------------------------
$return.Output = $returnOutput
$return.Information = $returnInformation
$return.Warning = $returnWarning
$return.Error = $returnError
$return.Job.EndTime = (Get-Date).ToUniversalTime()
$return.Job.Runtime = $return.Job.EndTime - $return.Job.StartTime

if ($Webhook) { .\Common_0000__Submit-Webhook.ps1 -Uri $Webhook -Body $return 1> $null }
$InformationPreference = $origInformationPreference
if (($true -eq $OutText) -or ($PSBoundParameters.Keys -contains 'OutJson') -and ($false -eq $OutJson)) { return }
if ($OutJson) { .\Common_0000__Write-JsonOutput.ps1 $return; return }

return $return
#endregion ---------------------------------------------------------------------
