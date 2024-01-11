<#PSScriptInfo
.VERSION 1.5.3
.GUID 053d16aa-2595-4b1d-a021-41d7934a6a9b
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
    Create a Temporary Access Pass code for new hires that have not setup any Authentication Methods so far

.DESCRIPTION
    Create a Temporary Access Pass code for new hires that have not setup any Authentication Methods so far.

.PARAMETER UserId
    User account identifier. May be an Entra Identity Object ID or User Principal Name (UPN).

.PARAMETER StartDateTime
    The date and time when the Temporary Access Pass becomes available to use. Needs to be in Universal Time (UTC).

.PARAMETER LifetimeInMinutes
    The lifetime of the Temporary Access Pass in minutes starting at StartDateTime. Must be between 10 and 43200 inclusive (equivalent to 30 days).

.PARAMETER IsUsableOnce
    Determines whether the pass is limited to a one-time use. If true, the pass can be used once; if false, the pass can be used multiple times within the Temporary Access Pass lifetime.

.PARAMETER Webhook
    Send return data in JSON format as POST to this webhook URL.

.PARAMETER OutputJson
    Output the result in JSON format.
    This is automatically implied when running in Azure Automation and no Webhook parameter was set.

.PARAMETER OutputText
    Output the Temporary Access Pass only.

.PARAMETER Simulate
    Same as -WhatIf parameter but makes it available for Azure Automation.
#>

#Requires -Version 5.1
#Requires -Modules @{ ModuleName='Microsoft.Graph.Authentication'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Identity.SignIns'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Users'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Users.Actions'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Users.Functions'; ModuleVersion='2.0' }

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
    [string]$Webhook,
    [switch]$OutJson,
    [switch]$OutText,
    [switch]$Simulate,
    [switch]$Version
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

if (-Not $WhatIfPreference -and $Simulate) {
    $WhatIfPreference = $true
}

if ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
    if (-Not $Webhook) { $OutJson = $true }
    $ProgressPreference = 'SilentlyContinue'
}

$MgScopes = @(
    'User.Read.All'                             # To read user information, including EmployeeHireDate
    'UserAuthenticationMethod.ReadWrite.All'    # To update authentication methods (TAP) of the user
    'Policy.Read.All'                           # To read and validate current policy settings
    'Directory.Read.All'                        # To read directory data and settings
)
$MissingMgScopes = @()
$return = @{}
$tapConfig = $null
$userObj = $null

if (
    ($UserId -match '^A[0-9][A-Z][-_].+@.+$') -or # Tiered admin accounts, e.g. A0C_*, A1L-*, etc.
    ($UserId -match '^ADM[CL]?[-_].+@.+$') -or # Non-Tiered admin accounts, e.g. ADM_, ADMC-* etc.
    ($UserId -match '^.+#EXT#@.+\.onmicrosoft\.com$') -or # External Accounts
    ($UserId -match '^(?:SVCC?_.+|SVC[A-Z0-9]+)@.+$') -or # Service Accounts
    ($UserId -match '^(?:Sync_.+|[A-Z]+SyncServiceAccount.*)@.+$')  # Entra Sync Accounts
) {
    Write-Error 'This type of user can not have a Temporary Access Pass created using this process.'
    exit 1
}

foreach ($MgScope in $MgScopes) {
    if ($WhatIfPreference -and ($MgScope -like '*Write*')) {
        Write-Verbose "What If: Removed $MgScope from required Microsoft Graph scopes"
    }
}
if (-Not (Get-MgContext)) {
    if ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
        Connect-MgGraph -NoWelcome -Identity -ContextScope Process -ErrorAction Stop 1> $null
        Write-Verbose (Get-MgContext | ConvertTo-Json)
    }
    else {
        Write-Information 'Opening connection to Microsoft Graph ...'
        ResilientRemoteCall { Connect-MgGraph -NoWelcome -Scopes $MgScopes -ContextScope Process -ErrorAction Stop }
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
        ResilientRemoteCall { Connect-MgGraph -NoWelcome -Scopes $MgScopes -ContextScope Process -ErrorAction Stop }
    }
}

$tapConfig = ResilientRemoteCall {
    Get-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration `
        -AuthenticationMethodConfigurationId 'temporaryAccessPass' `
        -ErrorAction SilentlyContinue `
        -Debug:$DebugPreference `
        -Verbose:$false
}

if (-Not $tapConfig) {
    Throw ($Error[0].CategoryInfo.TargetName + ': ' + $Error[0].ToString())
}
elseif ($tapConfig.State -ne 'enabled') {
    Throw "Temporary Access Pass authentication method is disabled for tenant $((Get-MgContext).TenantId) ."
}

if ($StartDateTime -and ($StartDateTime.ToUniversalTime() -lt (Get-Date).ToUniversalTime().AddMinutes(1))) {
    Throw 'StartDateTime: Time can not be in the past.'
}
if ($LifetimeInMinutes) {
    if ($LifetimeInMinutes -gt $tapConfig.AdditionalProperties.maximumLifetimeInMinutes) {
        $LifetimeInMinutes = $tapConfig.AdditionalProperties.maximumLifetimeInMinutes
        Write-Warning "LifetimeInMinutes: Maximum lifetime capped at $LifetimeInMinutes minutes."
    }
    if ($LifetimeInMinutes -lt $tapConfig.AdditionalProperties.minimumLifetimeInMinutes) {
        $LifetimeInMinutes = $tapConfig.AdditionalProperties.minimumLifetimeInMinutes
        Write-Warning "LifetimeInMinutes: Minimum lifetime capped at $LifetimeInMinutes minutes."
    }
}

# If connection to Microsoft Graph seems okay
#

$userObj = ResilientRemoteCall {
    Get-MgUser `
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
    ) `
        -ExpandProperty @(
        'Manager'
    )`
        -ErrorAction SilentlyContinue `
        -Debug:$DebugPreference `
        -Verbose:$false
}

if ($null -eq $userObj) {
    Throw ($Error[0].CategoryInfo.TargetName + ': ' + $Error[0].ToString())
}

# If user details could be retrieved
#

if (-Not $userObj.AccountEnabled) {
    Write-Error 'User ID is disabled.'
    exit 1
}

if ($userObj.UserType -ne 'Member') {
    Write-Error 'User ID must be of type Member.'
    exit 1
}

$return.Data = @{
    '@odata.context'  = $userObj.AdditionalProperties.'@odata.context'
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
}

$userGroups = ResilientRemoteCall {
    Get-MgUserMemberGroup `
        -UserId $userObj.Id `
        -SecurityEnabledOnly `
        -ErrorAction SilentlyContinue `
        -Debug:$DebugPreference `
        -Verbose:$false
}

if (-Not $userGroups -and $Error) {
    Throw ($Error[0].CategoryInfo.TargetName + ': ' + $Error[0].ToString())
}

if (

    # User is excluded from Authentication Method
    (
        ($null -ne $tapConfig.ExcludeTargets) -and
        ($tapConfig.ExcludeTargets | Where-Object -FilterScript {
            ($_.targetType -eq 'group') -and
            ($_.id -in $userGroups)
        })
    ) -or

    # User is excluded from Authentication Method in AdditionalProperties
    (
        ($null -ne $tapConfig.AdditionalProperties.excludeTargets) -and
        ($tapConfig.AdditionalProperties.excludeTargets | Where-Object -FilterScript {
            ($_.targetType -eq 'group') -and
            ($_.id -in $userGroups)
        })
    ) -or

    # User is not part of a group that is allowed to use this Authentication Method,
    # or 'All Users' is not set
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
    Write-Error "Authentication method 'Temporary Access Pass' is not enabled for this user ID."
    exit 1
}

# If user is a candidate for TAP creation
#

$return.Data.AuthenticationMethods = @()
$authMethods = ResilientRemoteCall {
    Get-MgUserAuthenticationMethod `
        -UserId $userObj.Id `
        -ErrorAction SilentlyContinue `
        -Debug:$DebugPreference `
        -Verbose:$false
}

if (-Not $authMethods) {
    Throw ($Error[0].CategoryInfo.TargetName + ': ' + $Error[0].ToString())
}

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

        # If there is no other authentication methods besides password and TAP,
        # we will assume that the TAP shall be deleted for renewal
        if (
            ('password' -in $return.Data.AuthenticationMethods) -and
            ($return.Data.AuthenticationMethods.Count -le 2)
        ) {
            if (-Not $return.Data.TemporaryAccessPass.methodUsabilityReason -eq 'Expired') {
                Write-Warning 'A Temporary Access Pass code was already set before.'
            }

            if ($PSCmdlet.ShouldProcess(
                    "Delete existing Temporary Access Pass for $($userObj.UserPrincipalName)",
                    "Do you confirm to remove the existing TAP for $($userObj.UserPrincipalName) ?",
                    'Delete existing Temporary Access Pass'
                )) {

                ResilientRemoteCall {
                    Remove-MgUserAuthenticationTemporaryAccessPassMethod `
                        -UserId $userObj.Id `
                        -TemporaryAccessPassAuthenticationMethodId $return.Data.TemporaryAccessPass.Id `
                        -Confirm:$false `
                        -ErrorAction SilentlyContinue `
                        -Debug:$DebugPreference `
                        -Verbose:$false `
                        -WhatIf:$WhatIfPreference
                }
                $return.Data.Remove('TemporaryAccessPass')
            }
            elseif ($WhatIfPreference) {
                Write-Verbose 'What If: An existing Temporary Access Pass would have been deleted.'
            }
            else {
                Write-Error 'Deletion of existing Temporary Access Pass was aborted.'
                exit 1
            }
        }
        else {
            if ($return.Data.TemporaryAccessPass.methodUsabilityReason -eq 'Expired') {
                Write-Error (
                    "An expired Temporary Access Pass code was found. `n" + `
                        'However, this process cannot be used to renew the Temporary Access Pass code because you have already configured other multi-factor authentication methods. ' + `
                        'Note that a Temporary Access Pass is only required during the initial onboarding process. ' + `
                        'You can then use your existing access to register additional methods, for example a security key. ' + `
                        'However, if you later lose access to all your multi-factor authentication methods, this self-service process cannot be used to recover. ' + `
                        'In this case, please contact the Global Service Desk who will help you reset your MFA methods.'
                )
            }
            else {
                Write-Error (
                    "An active Temporary Access Pass code has already been found. `n" + `
                        'It can only be displayed once after it has been created. ' + `
                        'As you have already configured other methods of multi-factor authentication, a new Temporary Access Pass can no longer be created via this self-service process. ' + `
                        'In this case, please contact the Global Service Desk who will help you reset your MFA methods.'
                )
            }
            exit 1
        }
    }

    # Check if no other authentication methods besides password is active
    elseif (
        ($return.Data.AuthenticationMethods.Count -gt 1) -or
        ('password' -notin $return.Data.AuthenticationMethods)
    ) {
        Write-Error (
            "This process cannot be used to request a Temporary Access Pass code as you have already configured other multi-factor authentication methods. `n" + `
                'Note that a Temporary Access Pass is only required during the initial onboarding process. ' + `
                'You can then use your existing access to register additional methods, for example a security key. ' + `
                'However, if you later lose access to all your multi-factor authentication methods, this self-service process cannot be used to recover. ' + `
                'In this case, please contact the Global Service Desk who will help you reset your MFA methods.'
        )
        exit 1
    }
}

# If user can have a new TAP
#

if ($WhatIfPreference -or (-Not $return.Data.TemporaryAccessPass)) {
    $params = @{}

    if ($StartDateTime) { $params.StartDateTime = $StartDateTime }
    if ($IsUsableOnce) { $params.IsUsableOnce = $IsUsableOnce }
    if ($LifetimeInMinutes) { $params.LifetimeInMinutes = $LifetimeInMinutes }

    if ($PSCmdlet.ShouldProcess(
            "Create new Temporary Access Pass for $($userObj.UserPrincipalName)",
            "Do you confirm to create a new TAP for $($userObj.UserPrincipalName) ?",
            'New Temporary Access Pass'
        )) {

        $tap = ResilientRemoteCall {
            New-MgUserAuthenticationTemporaryAccessPassMethod `
                -UserId $userObj.Id `
                -BodyParameter $params `
                -Confirm:$false `
                -ErrorAction SilentlyContinue `
                -Debug:$DebugPreference `
                -Verbose:$false `
                -WhatIf:$WhatIfPreference
        }

        if ($tap) {
            $return.Data.TemporaryAccessPass = $tap
            if ('temporaryAccessPass' -notin $return.Data.AuthenticationMethods) { $return.Data.AuthenticationMethods += 'temporaryAccessPass' }
            Write-Verbose 'A new Temporary Access Pass code was created.'
        }
        else {
            Write-Error ($Error[0].CategoryInfo.TargetName + ': ' + $Error[0].ToString())
            exit 1
        }
    }
    elseif ($WhatIfPreference) {
        Write-Verbose "What If: A new Temporary Access Pass code would have been created with the following parameters:`n$(($params | Out-String).TrimEnd())"
        $return.WhatIf = @{
            returnCode = 0
            message    = 'A Temporary Access Pass code may be created for this user ID.'
        }
    }
    else {
        Write-Error 'Creation of new Temporary Access Pass code was aborted.'
        exit 1
    }
}


if ($return.Data.Count -eq 0) { $return.Remove('Data') }
if ($Webhook) { ResilientRemoteCall { Write-Verbose $(Invoke-WebRequest -UseBasicParsing -Uri $Webhook -Method POST -Body $($return | ConvertTo-Json -Depth 4)) } }
if ($OutText) { return Write-Output $(if ($return.Data.TemporaryAccessPass.TemporaryAccessPass) { $return.Data.TemporaryAccessPass.TemporaryAccessPass } else { $null }) }
if ($OutJson) { return Write-Output $($return | ConvertTo-Json -Depth 5 -WarningAction SilentlyContinue) }

return $return
