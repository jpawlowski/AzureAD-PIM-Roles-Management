<#
.SYNOPSIS
    Remove a Temporary Access Pass code that was set before

.DESCRIPTION
    Remove a Temporary Access Pass code that was set before
    NOTE: Requires to run Connect-MgGraph command before.

.PARAMETER UserId
    User account identifier. May be an Entra Identity Object ID or User Principal Name (UPN).

.PARAMETER OutputJson
    Output the result in JSON format

.PARAMETER OutputText
    Output the Temporary Access Pass only.

.NOTES
    Filename: Remove-Temporary-Access-Pass.ps1
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
    [switch]$OutJson,
    [switch]$OutText
)

$MgScopes = @(
    'User.Read.All'                             # To read user information, inlcuding EmployeeHireDate
    'UserAuthenticationMethod.Read.All'         # To read authentication methods of the user
    'UserAuthenticationMethod.ReadWrite.All'    # To update authentication methods (TAP) of the user
)
$MissingMgScopes = @()
$return = @{
    Errors       = @()
    Warnings     = @()
    Informations = @()
    Data         = @{}
}
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
    $return.Data = @{
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

    $return.Data.AuthenticationMethods = @()
    $authMethods = Get-MgUserAuthenticationMethod `
        -UserId $userObj.Id `
        -ErrorAction SilentlyContinue `
        -Debug:$DebugPreference `
        -Verbose:$VerbosePreference

    $foundTAP = $false
    foreach ($authMethod in $authMethods) {
        if ($authMethod.AdditionalProperties.'@odata.type' -match '^#microsoft\.graph\.(.+)AuthenticationMethod$') {
            if ($Matches[1] -eq 'temporaryAccessPass') {
                $foundTAP = $true
                Write-Verbose "Found existing TAP Id $($authMethod.Id)"

                if ($PSCmdlet.ShouldProcess(
                        "Delete existing Temporary Access Pass $($authMethod.Id) for $($userObj.UserPrincipalName)",
                        "Do you confirm to delete TAP with ID $($authMethod.Id) for $($userObj.UserPrincipalName) ?",
                        'DeleteTemporary Access Pass'
                    )) {
                    $null = Remove-MgUserAuthenticationTemporaryAccessPassMethod `
                        -TemporaryAccessPassAuthenticationMethodId $authMethod.Id `
                        -UserId $userObj.Id `
                        -Confirm:$false `
                        -ErrorAction SilentlyContinue `
                        -Debug:$DebugPreference `
                        -Verbose:$VerbosePreference `
                        -WhatIf:$WhatIfPreference

                    $return.Informations += @{ message = "Temporary Access Pass with ID $($authMethod.Id) was deleted." }
                }
                elseif ($WhatIfPreference) {
                    $return.Informations += @{ message = "Simulation Mode: Existing Temporary Access Pass with ID $($authMethod.Id) would have been deleted." }
                }
                else {
                    $return.Errors += @{ message = 'Deletion of existing Temporary Access Pass was aborted.' }
                }
            }
            else {
                $return.Data.AuthenticationMethods += $Matches[1]
            }
        }
    }

    if (-Not $foundTAP) {
        $return.Informations += @{ message = "No Temporary Access Pass was found." }
    }
}

if (-Not $return.Informations) { $return.Remove('Informations') } else { $return.Informations | ForEach-Object { Write-Verbose $_.message; Write-Information $_.message } }
if (-Not $return.Warnings) { $return.Remove('Warnings') } else { $return.Warnings | ForEach-Object { Write-Warning $_.message } }
if (-Not $return.Errors) { $return.Remove('Errors') } else { $return.Errors | ForEach-Object { Write-Error $_.message } }
if ($return.Data.Count -eq 0) { $return.Remove('Data') }

if ($OutJson) { return $($return | ConvertTo-Json -Depth 4) }
if ($OutText) { return $return.Data.TemporaryAccessPass.TemporaryAccessPass ? $return.Data.TemporaryAccessPass.TemporaryAccessPass : $null }
return $return
