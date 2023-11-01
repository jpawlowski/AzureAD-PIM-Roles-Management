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
    Version: 1.1
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
    Errors   = @()
    Warnings = @()
    Verbose  = @()
    Data     = @{}
}
$tapConfig = $null
$userObj = $null

if (-Not (Get-MgContext)) {
    if ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
        Write-Verbose (Connect-MgGraph -Identity -ContextScope Process)
        Write-Verbose (Get-MgContext | ConvertTo-Json)
    }
    else {
        $return.Errors += @{
            Code    = 401
            Message = "Run 'Connect-MgGraph' first. The following scopes are required for this script to run:`n`n$($MissingMgScopes -join "`n")"
        }
    }
}

if (-Not $return.Errors) {
    foreach ($MgScope in $MgScopes) {
        if ($WhatIfPreference -and ($MgScope -like '*Write*')) {
            Write-Verbose "WhatIf: Removed $MgScope from required Microsoft Graph scopes"
        }
        elseif ($MgScope -notin @((Get-MgContext).Scopes)) {
            $MissingMgScopes += $MgScope
        }
    }

    if ($MissingMgScopes) {
        $return.Errors += @{
            Code    = 403
            Message = "Missing Microsoft Graph authorization scopes:`n`n$($MissingMgScopes -join "`n")"
            Context = Get-MgContext
        }
    }
}

if (-Not $return.Errors) {
    $tapConfig = Get-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration `
        -AuthenticationMethodConfigurationId 'temporaryAccessPass' `
        -ErrorAction SilentlyContinue `
        -Debug:$DebugPreference `
        -Verbose:$false

    if (-Not $tapConfig) {
        $return.Errors += @{
            Code       = 403
            Message    = $Error[0].CategoryInfo.TargetName + ': ' + $Error[0].ToString()
            Activity   = $Error[0].CategoryInfo.Activity
            Category   = $Error[0].CategoryInfo.Category
            Reason     = $Error[0].CategoryInfo.Reason
            TargetName = $Error[0].CategoryInfo.TargetName
            Context    = Get-MgContext
        }
    }
    elseif ($tapConfig.State -ne 'enabled') {
        $return.Errors += @{
            Code    = 500
            message = "Temporary Access Pass authentication method is disabled for tenant $((Get-MgContext).TenantId) ."
        }
    }
}

if ($StartDateTime -and ($StartDateTime.ToUniversalTime() -lt (Get-Date).ToUniversalTime().AddMinutes(1))) {
    $return.Errors += @{
        Code    = 412
        message = 'StartDateTime: Time can not be in the past.'
    }
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
        if ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
            $return.Data.PSPrivateMetadata = $PSPrivateMetadata
        }
        $return.Data.UserId = $UserId
        $return.Errors += @{
            Code       = 404
            Message    = $Error[0].CategoryInfo.TargetName + ': ' + $Error[0].ToString()
            Activity   = $Error[0].CategoryInfo.Activity
            Category   = $Error[0].CategoryInfo.Category
            Reason     = $Error[0].CategoryInfo.Reason
            TargetName = $Error[0].CategoryInfo.TargetName
            Context    = Get-MgContext
        }
    }
}

# If user details could be retrieved
if (-Not $return.Errors) {
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

    if ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
        $return.Data.PSPrivateMetadata = $PSPrivateMetadata
    }

    if (-Not $userObj.AccountEnabled) {
        $return.Errors += @{
            Code    = 503
            message = 'User account is disabled.'
        }
    }

    if ($userObj.UserType -ne 'Member') {
        $return.Errors += @{
            Code    = 503
            message = 'User needs to be of type Member.'
        }
    }

    if ($userObj.UserType -match '^.+#EXT#@.+\.onmicrosoft\.com$') {
        $return.Errors += @{
            Code    = 503
            message = 'User can not be a guest.'
        }
    }

    $userGroups = Get-MgUserMemberGroup `
        -UserId $userObj.Id `
        -SecurityEnabledOnly `
        -ErrorAction SilentlyContinue `
        -Debug:$DebugPreference `
        -Verbose:$false

    if (-Not $userGroups) {
        $return.Errors += @{
            Code       = 503
            Message    = $Error[0].CategoryInfo.TargetName + ': ' + $Error[0].ToString()
            Activity   = $Error[0].CategoryInfo.Activity
            Category   = $Error[0].CategoryInfo.Category
            Reason     = $Error[0].CategoryInfo.Reason
            TargetName = $Error[0].CategoryInfo.TargetName
            Context    = Get-MgContext
        }
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
        $return.Errors += @{
            Code    = 503
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
        -Verbose:$false

    if (-Not $authMethods) {
        $return.Errors += @{
            Code       = 404
            Message    = $Error[0].CategoryInfo.TargetName + ': ' + $Error[0].ToString()
            Activity   = $Error[0].CategoryInfo.Activity
            Category   = $Error[0].CategoryInfo.Category
            Reason     = $Error[0].CategoryInfo.Reason
            TargetName = $Error[0].CategoryInfo.TargetName
            Context    = Get-MgContext
        }
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
                        -Verbose:$false `
                        -WhatIf:$WhatIfPreference
                    $return.Data.Remove('TemporaryAccessPass')
                }
                elseif ($WhatIfPreference) {
                    $return.Verbose += @{ message = 'Simulation Mode: An existing Temporary Access Pass would have been deleted.' }
                }
                else {
                    $return.Errors += @{
                        Code    = 500
                        message = 'Deletion of existing Temporary Access Pass was aborted.'
                    }
                }
            }
            else {
                $return.Errors += @{
                    Code    = 503
                    message = 'A Temporary Access Pass code was already set before. It can only be displayed once it is generated.'
                }
            }
        }
        elseif (
            ($return.Data.AuthenticationMethods.Count -gt 1) -or
            ('password' -notin $return.Data.AuthenticationMethods)
        ) {
            $return.Errors += @{
                Code    = 503
                message = 'This process cannot be used to request a Temporary Access Pass code because other multifactor authentication methods are already configured. Instead, contact Global Service Desk to reset MFA methods.'
            }
        }
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
            -Verbose:$false `
            -WhatIf:$WhatIfPreference

        if ($tap) {
            $return.Data.TemporaryAccessPass = $tap
            if ('temporaryAccessPass' -notin $return.Data.AuthenticationMethods) { $return.Data.AuthenticationMethods += 'temporaryAccessPass' }
            $return.Verbose += @{ message = 'New Temporary Access Pass code was generated.' }
        }
        else {
            $return.Errors += @{
                Code       = 500
                Message    = $Error[0].CategoryInfo.TargetName + ': ' + $Error[0].ToString()
                Activity   = $Error[0].CategoryInfo.Activity
                Category   = $Error[0].CategoryInfo.Category
                Reason     = $Error[0].CategoryInfo.Reason
                TargetName = $Error[0].CategoryInfo.TargetName
                Context    = Get-MgContext
            }
        }
    }
    elseif ($WhatIfPreference) {
        $return.Verbose += @{ message = "Simulation Mode: A new Temporary Access Pass would have been generated with the following parameters:`n$(($BodyParameter | Out-String).TrimEnd())" }
    }
    else {
        $return.Errors += @{
            Code    = 412
            message = 'Creation of new Temporary Access Pass was aborted.' 
        }
    }
}


if (-Not $return.Verbose) { $return.Remove('Verbose') } else { $return.Verbose | ForEach-Object { Write-Verbose $_.message; Write-Information $_.message } }
if (-Not $return.Warnings) { $return.Remove('Warnings') } else { $return.Warnings | ForEach-Object { Write-Warning $_.message } }
if (-Not $return.Errors) { $return.Remove('Errors') } else { $return.Errors | ForEach-Object { Write-Error $($_.message + ( if ($_.Reason) { $_.Reason } else { '' })) } }
if ($return.Data.Count -eq 0) { $return.Remove('Data') }

if ($OutJson) { return Write-Output $($return | ConvertTo-Json -Depth 4) }
if ($OutText) { return Write-Output (if ($return.Data.TemporaryAccessPass.TemporaryAccessPass) { $return.Data.TemporaryAccessPass.TemporaryAccessPass } else { $null }) }
return $return
