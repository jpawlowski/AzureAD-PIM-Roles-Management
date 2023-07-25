<#
.SYNOPSIS
    Create a Temporary Access Pass code for new hires that have not setup any Authentication Methods so far

.DESCRIPTION
    Create a Temporary Access Pass code for new hires that have not setup any Authentication Methods so far.
    NOTE: Requires to run Connect-MgGraph command before.

.PARAMETER UserId
    User account identifier. May be an Entra Identity Object ID or User Principal Name (UPN).

.PARAMETER StartDateTime
    The date and time when the Temporary Access Pass becomes available to use. Needs to be in Universal Time (UTC).

.PARAMETER LifetimeInMinutes
    The lifetime of the Temporary Access Pass in minutes starting at StartDateTime. Must be between 10 and 43200 inclusive (equivalent to 30 days).
    If used with -IsNewHire, a lifetime of 8 hours is implied if not explicitly set otherwise.

.PARAMETER IsUsableOnce
    Determines whether the pass is limited to a one-time use. If true, the pass can be used once; if false, the pass can be used multiple times within the Temporary Access Pass lifetime.
    If used with -IsNewHire, this will be ignored.

.PARAMETER IsNewHire
    When set together with -StartDateTime, the start date is also written to the EmployeeHireDate property of the user account in Entra ID.
    This allows any pre-scheduled Temporary Access Pass codes to be replaced by this script until and including the set EmployeeHireDate has reached.
    Once the EmployeeHireDate has reached, it is no longer updated by this script. This script will only continue to allow setting new
    Temporary Access Pass codes afterwards unless the user has configured other MFA methods already.
    If the user has configured MFA methods and lost access to the account, this script will not create any new Temporary Access Pass codes.
    Instead, the user is expected to consult Global Service Desk to run the official MFA reset process that includes extended
    identity validation of the user.

.PARAMETER OutputJson
    Output the result in JSON format

.PARAMETER OutputText
    Output the Temporary Access Pass only.

.NOTES
    Filename: New-Hire-Temporary-Access-Pass.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
    Version: 1.0
#>
#Requires -Version 7.2
#Requires -Modules @{ ModuleName='Microsoft.Graph.Users'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Identity.SignIns'; ModuleVersion='2.0' }

[CmdletBinding(
    SupportsShouldProcess,
    ConfirmImpact = 'Medium'
)]
Param (
    [Parameter(Position = 0, mandatory = $true)]
    [string]$UserId,
    [datetime]$StartDateTime,
    [int32]$LifetimeInMinutes,
    [switch]$IsUsableOnce,
    [switch]$IsNewHire,
    [switch]$OutJson,
    [switch]$OutText
)

$MgScopes = @(
    'User.Read.All'                             # To read user information, inlcuding EmployeeHireDate
    'UserAuthenticationMethod.Read.All'         # To read authentication methods of the user
    'UserAuthenticationMethod.ReadWrite.All'    # To update authentication methods (TAP) of the user
    'Policy.Read.All'                           # To read and validate current policy settings
)
if ($IsNewHire -and $StartDateTime) { $MgScopes += 'User.ReadWrite.All' }   # To update user information (EmployeeHireDate)
$MissingMgScopes = @()
$return = @{
    Errors       = @()
    Warnings     = @()
    Informations = @()
    Data         = @{}
}
$tapConfig = $null
$userObj = $null

foreach ($MgScope in $MgScopes) {
    if ($WhatIfPreference -and ($MgScope -like '*Write*')) {
        Write-Debug "WhatIf: Removed $MgScope from required Microsoft Graph scopes"
    }
    elseif ($MgScope -notin @((Get-MgContext).Scopes)) {
        $MissingMgScopes += $MgScope
    }
}

if ($MissingMgScopes) {
    $return.Errors += @{
        Message = "Missing Microsoft Graph authorization scopes:`n`n$($MissingMgScopes -join "`n")"
        Context = Get-MgContext
    }
}

if (-Not $return.Errors) {
    $tapConfig = Get-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration `
        -AuthenticationMethodConfigurationId 'temporaryAccessPass' `
        -ErrorAction SilentlyContinue `
        -Debug:$DebugPreference `
        -Verbose:$VerbosePreference

    if (-Not $tapConfig) {
        $return.Errors += @{
            message = "Failed to retrieve tenant configuration for Temporary Access Pass authentication method."
        }
    }
    elseif ($tapConfig.State -ne 'enabled') {
        $return.Errors += @{
            message = "Temporary Access Pass authentication method is disabled for tenant $((Get-MgContext).TenantId) ."
        }
    }
}

if ($IsNewHire -and -Not $StartDateTime) {
    $return.Errors += @{
        message = 'IsNewHire: Missing StartDateTime parameter'
    }
}
if ($StartDateTime) {
    if ($StartDateTime.ToUniversalTime() -lt (Get-Date).ToUniversalTime().AddMinutes(1)) {
        $return.Errors += @{
            message = 'StartDateTime: Time can not be in the past.'
        }
    }

    $MorningTime = $StartDateTime.ToUniversalTime() | Get-Date -Hour 6 -Minute 0 -Second 0 -Millisecond 0
    if ($IsNewHire -and ($StartDateTime.ToUniversalTime() -ne $MorningTime)) {
        $StartDateTime = $MorningTime
        $return.Informations += @{
            message = "StartDateTime: Workday start time was corrected to $($MorningTime.TimeOfDay.ToString()) for -IsNewHire"
        }
    }
}
if ($IsNewHire -and -Not $LifetimeInMinutes) {
    $LifetimeInMinutes = 12 * 60
    $return.Informations += @{
        message = "IsNewHire: Missing LifetimeInMinutes parameter: Implied $LifetimeInMinutes minutes ($($LifetimeInMinutes / 60) hours)"
    }
}
if ($IsUsableOnce -and $IsNewHire) {
    $return.Warnings += @{
        message = 'IsUsableOnce: Parameter ignored for -IsNewHire'
    }
    $IsUsableOnce = $false
}
if ($LifetimeInMinutes) {
    if ($LifetimeInMinutes -gt $tapConfig.AdditionalProperties.maximumLifetimeInMinutes) {
        $LifetimeInMinutes = $tapConfig.AdditionalProperties.maximumLifetimeInMinutes
        $return.Warnings += @{
            message = "LifetimeInMinutes: Maximum lifetime capped at $LifetimeInMinutes minutes."
        }
    }
    if ($LifetimeInMinutes -lt $tapConfig.AdditionalProperties.minimumLifetimeInMinutes) {
        $LifetimeInMinutes = $tapConfig.AdditionalProperties.minimumLifetimeInMinutes
        $return.Warnings += @{
            message = "LifetimeInMinutes: Minimum lifetime capped at $LifetimeInMinutes minutes."
        }
    }
}


# If connection to Microsoft Graph seems okay
if (-Not $return.Errors) {
    $userObj = Get-MgBetaUser `
        -UserId $UserId `
        -Property @(
        'Id'
        'UserPrincipalName'
        'Mail'
        'DisplayName'
        'EmployeeHireDate'
        'UserType'
        'AccountEnabled'
        'UsageLocation'
        'Manager'
    ) `
        -ExpandProperty @(
        'Manager'
    )`
        -ErrorAction SilentlyContinue `
        -Debug:$DebugPreference `
        -Verbose:$VerbosePreference

    if ($null -eq $userObj) {
        $return.Data.UserId = $UserId
        $return.Errors += @{
            Message    = $Error[0].ToString()
            Activity   = $Error[0].CategoryInfo.Activity
            Category   = $Error[0].CategoryInfo.Category
            Reason     = $Error[0].CategoryInfo.Reason
            TargetName = $Error[0].CategoryInfo.TargetName
            Context    = Get-MgContext
        }
    }
    else {
        $userObj.Sponsors = (
            Get-MgBetaUser `
                -UserId $userObj.Id `
                -Property Sponsors `
                -ExpandProperty Sponsors `
                -ErrorAction SilentlyContinue `
                -Debug:$DebugPreference `
                -Verbose:$VerbosePreference
        ).Sponsors
    }
}

# If user details could be retrieved
if (-Not $return.Errors) {
    $return.Data.User = @{
        Id                = $userObj.Id
        UserPrincipalName = $userObj.UserPrincipalName
        Mail              = $userObj.Mail
        DisplayName       = $userObj.DisplayName
        EmployeeHireDate  = $userObj.EmployeeHireDate
        UserType          = $userObj.UserType
        AccountEnabled    = $userObj.AccountEnabled
        Manager           = @{
            Id                = $userObj.Manager.Id
            UserPrincipalName = $userObj.manager.AdditionalProperties.userPrincipalName
            Mail              = $userObj.manager.AdditionalProperties.mail
            DisplayName       = $userObj.manager.AdditionalProperties.displayName
        }
        Sponsors          = $userObj.Sponsors
    }

    if (-Not $userObj.AccountEnabled) {
        $return.Errors += @{
            message = 'User account is disabled.'
        }
    }

    if ($userObj.UserType -ne 'Member') {
        $return.Errors += @{
            message = 'User needs to be of type Member.'
        }
    }

    if ($userObj.UserType -match '^.+#EXT#@.+\.onmicrosoft\.com$') {
        $return.Errors += @{
            message = 'User can not be a guest.'
        }
    }

    $userGroups = Get-MgUserMemberGroup `
        -UserId $userObj.Id `
        -SecurityEnabledOnly `
        -ErrorAction SilentlyContinue `
        -Debug:$DebugPreference `
        -Verbose:$VerbosePreference

    if (
        (
            ($null -ne $tapConfig.ExcludeTargets) -and
            ($tapConfig.ExcludeTargets | Where-Object -FilterScript {
                ($_.targetType -eq 'group') -and
                ($_.id -in $userGroups)
            })
        ) -or
        (
            ($null -ne $tapConfig.AdditionalProperties.excludeTargets) -and
            ($tapConfig.AdditionalProperties.excludeTargets | Where-Object -FilterScript {
                ($_.targetType -eq 'group') -and
                ($_.id -in $userGroups)
            })
        ) -or
        (
            -Not (
            ($null -ne $tapConfig.IncludeTargets) -and
            ($tapConfig.IncludeTargets | Where-Object -FilterScript {
                ($_.targetType -eq 'group') -and
                    (
                    ($_.id -eq 'all_users') -or
                    ($_.id -in $userGroups)
                    )
                })
            ) -and
            -Not (
            ($null -ne $tapConfig.AdditionalProperties.includeTargets) -and
            ($tapConfig.AdditionalProperties.includeTargets | Where-Object -FilterScript {
                ($_.targetType -eq 'group') -and
                    (
                    ($_.id -eq 'all_users') -or
                    ($_.id -in $userGroups)
                    )
                })
            )
        )
    ) {
        $return.Errors += @{
            message = "Authentication method 'Temporary Access Pass' is not enabled for this user."
        }
    }
}

# If user is a candidate for TAP generation
if (-Not $return.Errors) {
    $return.Data.AuthenticationMethods = @()
    $authMethods = Get-MgUserAuthenticationMethod `
        -UserId $userObj.Id `
        -ErrorAction SilentlyContinue `
        -Debug:$DebugPreference `
        -Verbose:$VerbosePreference

    foreach ($authMethod in $authMethods) {
        if ($authMethod.AdditionalProperties.'@odata.type' -match '^#microsoft\.graph\.(.+)AuthenticationMethod$') {
            $return.Data.AuthenticationMethods += $Matches[1]
            if ($Matches[1] -eq 'temporaryAccessPass') {
                Write-Verbose "Found existing TAP Id $($authMethod.Id)"
                $return.Data.TemporaryAccessPass = $authMethod.AdditionalProperties
                $return.Data.TemporaryAccessPass.Id = $authMethod.Id
            }
        }
    }

    if ($return.Data.AuthenticationMethods) {
        if ('temporaryAccessPass' -in $return.Data.AuthenticationMethods) {
            if (
                ('password' -in $return.Data.AuthenticationMethods) -and
                ($return.Data.AuthenticationMethods.Count -le 2)
            ) {
                $return.Warnings += @{
                    message = 'A Temporary Access Pass code was already set before.'
                }

                if ($PSCmdlet.ShouldProcess(
                        "Delete existing Temporary Access Pass for $($userObj.UserPrincipalName)",
                        "Do you confirm to remove the existing TAP for $($userObj.UserPrincipalName) ?",
                        'Delete existing Temporary Access Pass'
                    )) {

                    Remove-MgUserAuthenticationTemporaryAccessPassMethod `
                        -UserId $userObj.Id `
                        -TemporaryAccessPassAuthenticationMethodId $return.Data.TemporaryAccessPass.Id `
                        -Confirm:$false `
                        -ErrorAction SilentlyContinue `
                        -Debug:$DebugPreference `
                        -Verbose:$VerbosePreference `
                        -WhatIf:$WhatIfPreference
                    $return.Data.Remove('TemporaryAccessPass')
                }
                elseif ($WhatIfPreference) {
                    $return.Informations += @{ message = 'Simulation Mode: An existing Temporary Access Pass would have been deleted.' }
                }
                else {
                    $return.Errors += @{ message = 'Deletion of existing Temporary Access Pass was aborted.' }
                }
            }
            else {
                $return.Errors += @{
                    message = 'A Temporary Access Pass code was already set before. It can only be displayed once it is generated.'
                }
            }
        }
        elseif (
            ($return.Data.AuthenticationMethods.Count -gt 1) -or
            ('password' -notin $return.Data.AuthenticationMethods)
        ) {
            $return.Errors += @{
                message = 'This process cannot be used to request a Temporary Access Pass code because other multifactor authentication methods are already configured. Instead, contact Global Service Desk to reset MFA methods.'
            }
        }
    }
}

# If user is an actual new hire that hasn't started yet
if ((-Not $return.Errors) -and ($WhatIfPreference -or (-Not $return.Data.TemporaryAccessPass)) -and $IsNewHire) {
    $EmployeeHireDate = Get-Date $StartDateTime.ToUniversalTime() -Hour 0 -Minute 0 -Second 0 -Millisecond 0

    if ($userObj.EmployeeHireDate -lt (Get-Date (Get-Date).ToUniversalTime().AddDays(1) -Hour 0 -Minute 0 -Second 0 -Millisecond 0)) {
        $return.Warnings += @{ message = "Currently set EmployeeHireDate $($userObj.EmployeeHireDate) has passed and will not be updated anymore." }
    }
    elseif ($PSCmdlet.ShouldProcess(
            "Update EmployeeHireDate for $($userObj.UserPrincipalName) to $(Get-Date $EmployeeHireDate -UFormat '+%Y-%m-%dT%H:%M:%S.000Z')",
            "Do you confirm to set employee hire date for $($userObj.UserPrincipalName) to $(Get-Date $EmployeeHireDate -UFormat '+%Y-%m-%dT%H:%M:%S.000Z') ?",
            'Update Employee Hire Date'
        )) {

        $null = Update-MgUser `
            -UserId $userObj.Id `
            -EmployeeHireDate $EmployeeHireDate `
            -Confirm:$false `
            -ErrorAction SilentlyContinue `
            -Debug:$DebugPreference `
            -Verbose:$VerbosePreference `
            -WhatIf:$WhatIfPreference

        $userObj.EmployeeHireDate = $EmployeeHireDate
        $return.Data.User.EmployeeHireDate = $EmployeeHireDate

        $return.Informations += @{
            message = "EmployeeHireDate: EmployeeHireDate updated to $(Get-Date $EmployeeHireDate -UFormat '+%Y-%m-%dT%H:%M:%S.000Z')"
        }
    }
    elseif ($WhatIfPreference) {
        $return.Informations += @{ message = "Simulation Mode: EmployeeHireDate would have been updated to $(Get-Date $EmployeeHireDate -UFormat '+%Y-%m-%dT%H:%M:%S.000Z')." }
    }
    else {
        $return.Errors += @{ message = 'Update of EmployeeHireDate was aborted.' }
    }
}

# If user can have a new TAP
if ((-Not $return.Errors) -and ($WhatIfPreference -or (-Not $return.Data.TemporaryAccessPass))) {
    $BodyParameter = @{}

    if ($StartDateTime) { $BodyParameter.StartDateTime = $StartDateTime }
    if ($IsUsableOnce) { $BodyParameter.IsUsableOnce = $IsUsableOnce }
    if ($LifetimeInMinutes) { $BodyParameter.LifetimeInMinutes = $LifetimeInMinutes }

    if ($PSCmdlet.ShouldProcess(
            "Create new Temporary Access Pass for $($userObj.UserPrincipalName)",
            "Do you confirm to generate a new TAP for $($userObj.UserPrincipalName) ?",
            'New Temporary Access Pass'
        )) {

        $tap = New-MgUserAuthenticationTemporaryAccessPassMethod `
            -UserId $userObj.Id `
            -BodyParameter $BodyParameter `
            -Confirm:$false `
            -ErrorAction SilentlyContinue `
            -Debug:$DebugPreference `
            -Verbose:$VerbosePreference `
            -WhatIf:$WhatIfPreference

        if ($tap) {
            $return.Data.TemporaryAccessPass = $tap
            if ('temporaryAccessPass' -notin $return.Data.AuthenticationMethods) { $return.Data.AuthenticationMethods += 'temporaryAccessPass' }
            $return.Informations += @{ message = 'New Temporary Access Pass code was generated.' }
        }
        else {
            $return.Errors += @{
                Message    = $Error[0].ToString()
                Activity   = $Error[0].CategoryInfo.Activity
                Category   = $Error[0].CategoryInfo.Category
                Reason     = $Error[0].CategoryInfo.Reason
                TargetName = $Error[0].CategoryInfo.TargetName
                Context    = Get-MgContext
            }
        }
    }
    elseif ($WhatIfPreference) {
        $return.Informations += @{ message = "Simulation Mode: A new Temporary Access Pass would have been generated with the following parameters:`n$(($BodyParameter | Out-String).TrimEnd())" }
    }
    else {
        $return.Errors += @{ message = 'Creation of new Temporary Access Pass was aborted.' }
    }
}


if (-Not $return.Informations) { $return.Remove('Informations') } else { $return.Informations | ForEach-Object { Write-Verbose $_.message; Write-Information $_.message } }
if (-Not $return.Warnings) { $return.Remove('Warnings') } else { $return.Warnings | ForEach-Object { Write-Warning $_.message } }
if (-Not $return.Errors) { $return.Remove('Errors') } else { $return.Errors | ForEach-Object { Write-Error $_.message } }
if ($return.Data.Count -eq 0) { $return.Remove('Data') }

if ($OutJson) { return $($return | ConvertTo-Json -Depth 4) }
if ($OutText) { return $return.Data.TemporaryAccessPass.TemporaryAccessPass ? $return.Data.TemporaryAccessPass.TemporaryAccessPass : $null }
return $return
