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

.PARAMETER OutputJson
    Output the result in JSON format

.PARAMETER OutputText
    Output the Temporary Access Pass only.

.NOTES
    Filename: New-Temporary-Access-Pass-for-Initial-MFA-Setup.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
    Version: 1.2
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
    [switch]$OutJson,
    [switch]$OutText
)

if ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
    $OutJson = $true
}

$MgScopes = @(
    'User.Read.All'                             # To read user information, inlcuding EmployeeHireDate
    'UserAuthenticationMethod.Read.All'         # To read authentication methods of the user
    'UserAuthenticationMethod.ReadWrite.All'    # To update authentication methods (TAP) of the user
    'Policy.Read.All'                           # To read and validate current policy settings
    'Directory.Read.All'                        # To read directory data and settings
)
$MissingMgScopes = @()
$return = @{
    Data = @{}
}
$tapConfig = $null
$userObj = $null

if (-Not (Get-MgContext)) {
    if ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
        Write-Verbose (Connect-MgGraph -Identity -ContextScope Process)
        Write-Verbose (Get-MgContext | ConvertTo-Json)
    }
    else {
        Throw "Run 'Connect-MgGraph' first. The following scopes are required for this script to run:`n`n$($MissingMgScopes -join "`n")"
    }
}

foreach ($MgScope in $MgScopes) {
    if ($WhatIfPreference -and ($MgScope -like '*Write*')) {
        Write-Verbose "WhatIf: Removed $MgScope from required Microsoft Graph scopes"
    }
    elseif ($MgScope -notin @((Get-MgContext).Scopes)) {
        $MissingMgScopes += $MgScope
    }
}

if ($MissingMgScopes) {
    Throw "Missing Microsoft Graph authorization scopes:`n`n$($MissingMgScopes -join "`n")"
}

$tapConfig = Get-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration `
    -AuthenticationMethodConfigurationId 'temporaryAccessPass' `
    -ErrorAction SilentlyContinue `
    -Debug:$DebugPreference `
    -Verbose:$false

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
$userObj = Get-MgUser `
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

if ($null -eq $userObj) {
    Throw ($Error[0].CategoryInfo.TargetName + ': ' + $Error[0].ToString())
}

# If user details could be retrieved
if (-Not $userObj.AccountEnabled) {
    Write-Error 'User account is disabled.'
    Throw
}

if ($userObj.UserType -ne 'Member') {
    Write-Error 'User needs to be of type Member.'
    Throw
}

if ($userObj.UserType -match '^.+#EXT#@.+\.onmicrosoft\.com$') {
    Write-Error 'User can not be a guest.'
    Throw
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

$userGroups = Get-MgUserMemberGroup `
    -UserId $userObj.Id `
    -SecurityEnabledOnly `
    -ErrorAction SilentlyContinue `
    -Debug:$DebugPreference `
    -Verbose:$false

if (-Not $userGroups) {
    Throw ($Error[0].CategoryInfo.TargetName + ': ' + $Error[0].ToString())
}

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
    Write-Error "Authentication method 'Temporary Access Pass' is not enabled for this user."
    Throw
}

# If user is a candidate for TAP generation
$return.Data.AuthenticationMethods = @()
$authMethods = Get-MgUserAuthenticationMethod `
    -UserId $userObj.Id `
    -ErrorAction SilentlyContinue `
    -Debug:$DebugPreference `
    -Verbose:$false

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
        # we will assume that the TAP shall be re-newed
        if (
            ('password' -in $return.Data.AuthenticationMethods) -and
            ($return.Data.AuthenticationMethods.Count -le 2)
        ) {
            Write-Warning 'A Temporary Access Pass code was already set before.'

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
                    -Verbose:$false `
                    -WhatIf:$WhatIfPreference
                $return.Data.Remove('TemporaryAccessPass')
            }
            elseif ($WhatIfPreference) {
                Write-Verbose 'Simulation Mode: An existing Temporary Access Pass would have been deleted.'
            }
            else {
                Write-Error 'Deletion of existing Temporary Access Pass was aborted.'
                Throw
            }
        }
        else {
            Write-Error 'A Temporary Access Pass code was already set before. It can only be displayed once it is generated.'
            Throw
        }
    }

    # Check if no other authentication methods besides password is active
    elseif (
        ($return.Data.AuthenticationMethods.Count -gt 1) -or
        ('password' -notin $return.Data.AuthenticationMethods)
    ) {
        Write-Error 'This process cannot be used to request a Temporary Access Pass code because other multifactor authentication methods are already configured. Instead, contact Global Service Desk to reset MFA methods.'
        Throw
    }
}

# If user can have a new TAP
if ($WhatIfPreference -or (-Not $return.Data.TemporaryAccessPass)) {
    $params = @{}

    if ($StartDateTime) { $params.StartDateTime = $StartDateTime }
    if ($IsUsableOnce) { $params.IsUsableOnce = $IsUsableOnce }
    if ($LifetimeInMinutes) { $params.LifetimeInMinutes = $LifetimeInMinutes }

    if ($PSCmdlet.ShouldProcess(
            "Create new Temporary Access Pass for $($userObj.UserPrincipalName)",
            "Do you confirm to generate a new TAP for $($userObj.UserPrincipalName) ?",
            'New Temporary Access Pass'
        )) {

        $tap = New-MgUserAuthenticationTemporaryAccessPassMethod `
            -UserId $userObj.Id `
            -BodyParameter $params `
            -Confirm:$false `
            -ErrorAction SilentlyContinue `
            -Debug:$DebugPreference `
            -Verbose:$false `
            -WhatIf:$WhatIfPreference

        if ($tap) {
            $return.Data.TemporaryAccessPass = $tap
            if ('temporaryAccessPass' -notin $return.Data.AuthenticationMethods) { $return.Data.AuthenticationMethods += 'temporaryAccessPass' }
            Write-Verbose 'New Temporary Access Pass code was generated.'
        }
        else {
            Write-Error ($Error[0].CategoryInfo.TargetName + ': ' + $Error[0].ToString())
            Throw
        }
    }
    elseif ($WhatIfPreference) {
        Write-Verbose "Simulation Mode: A new Temporary Access Pass would have been generated with the following parameters:`n$(($BodyParameter | Out-String).TrimEnd())"
    }
    else {
        Write-Error 'Creation of new Temporary Access Pass was aborted.'
        Throw
    }
}


if ($return.Data.Count -eq 0) { $return.Remove('Data') }
if ($OutText) { return Write-Output (if ($return.Data.TemporaryAccessPass.TemporaryAccessPass) { $return.Data.TemporaryAccessPass.TemporaryAccessPass } else { '' }) }
if ($OutJson) { return Write-Output $($return | ConvertTo-Json -Depth 4) }

return $return
