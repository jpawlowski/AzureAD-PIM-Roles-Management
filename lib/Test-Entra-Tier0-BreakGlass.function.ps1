<#
.SYNOPSIS

.DESCRIPTION

.LINK
    https://github.com/jpawlowski/AzureAD-PIM-Roles-Management

.NOTES
    Filename: Test-Entra-Tier0-BreakGlass.function.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
#>
#Requires -Version 7.2
#Requires -Modules @{ ModuleName='Microsoft.Graph.Beta.Identity.DirectoryManagement'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Users'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Groups'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Identity.DirectoryManagement'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Identity.Governance'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Identity.SignIns'; ModuleVersion='2.0' }

$MgScopes += 'User.ReadWrite.All'
$MgScopes += 'UserAuthenticationMethod.Read.All'
$MgScopes += 'Group.ReadWrite.All'
$MgScopes += 'AdministrativeUnit.ReadWrite.All'
$MgScopes += 'Directory.Write.Restricted'
$MgScopes += 'RoleManagement.ReadWrite.Directory'

function Test-Entra-Tier0-BreakGlass {
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'High'
    )]
    [OutputType([Int])]
    Param (
        [hashtable]$Config,
        [switch]$Repair
    )

    $adminUnitObj = $null

    if (
        ($null -ne $Config.adminUnit.id) -and
        ($Config.adminUnit.id -notmatch '^00000000-') -and
        ($Config.adminUnit.id -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$')
    ) {
        $adminUnitObj = Get-MgBetaDirectoryAdministrativeUnit -AdministrativeUnitId $Config.adminUnit.id -ErrorAction Stop
    }
    elseif (
        ($null -ne $Config.adminUnit.displayName) -and
        ($Config.adminUnit.displayName -ne '')
    ) {
        $adminUnitObj = Get-MgBetaDirectoryAdministrativeUnit -All -Filter "displayName eq '$($Config.adminUnit.displayName)'" -ErrorAction Stop
    }
    elseif ($null -ne $Config.adminUnit) {
        Write-Error 'Defined Break Glass Admin Unit is incomplete'
        return 1
    }

    if ($null -eq $adminUnitObj) {
        Write-Error "Defined Break Glass Admin Unit $($Config.adminUnit.id) ($($Config.adminUnit.displayName)) does not exist"
        return 1
    }
    if (
        ($null -ne $Config.adminUnit.visibility) -and
        ($adminUnitObj.Visibility -ne $Config.adminUnit.visibility)
    ) {
        Write-Error "Break Glass Admin Unit $($adminUnitObj.id): Visibility must be $($Config.adminUnit.visibility)"
        return 1
    }
    if (
        ($null -ne $Config.adminUnit.isMemberManagementRestricted) -and
        ($adminUnitObj.isMemberManagementRestricted -ne $Config.adminUnit.isMemberManagementRestricted)
    ) {
        Write-Error "Break Glass Admin Unit $($adminUnitObj.id): Restricted Management must be $($Config.adminUnit.isMemberManagementRestricted)"
        return 1
    }
    Write-Verbose "Break Glass Admin Unit $($adminUnitObj.Id) ($($adminUnitObj.DisplayName)) VALIDATED"

    $groupObj = $null

    if (
        ($null -ne $Config.group.id) -and
        ($Config.group.id -notmatch '^00000000-') -and
        ($Config.group.id -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$')
    ) {
        $groupObj = Get-MgGroup -GroupId $Config.group.id -ErrorAction Stop
    }
    elseif (
        ($null -ne $Config.group.displayName) -and
        ($Config.group.displayName -ne '')
    ) {
        $groupObj = Get-MgGroup -All -Filter "displayName eq '$($Config.group.displayName)'" -ErrorAction Stop
        Write-Warning "Break Glass Group $($groupObj.displayName): Should use explicit object ID $($groupObj.Id) in configuration"
    }
    else {
        Write-Error 'Defined Break Glass Group is incomplete'
        return 1
    }

    if ($null -eq $groupObj) {
        Write-Error "Defined Break Glass Group $($Config.group.id) ($($Config.group.displayName)) does not exist"
        return 1
    }
    if ($groupObj.SecurityEnabled -ne $true) {
        Write-Error "Break Glass Group $($Config.group.id): Must be a security group"
        return 1
    }
    if ($groupObj.MailEnabled -ne $false) {
        Write-Error "Break Glass Group $($Config.group.id): Can not be mail-enabled"
        return 1
    }
    if ($groupObj.GroupTypes.Count -ne 0) {
        Write-Error "Break Glass Group $($Config.group.id): Can not have any specific group type"
        return 1
    }
    if (
        ($null -ne $groupObj.MembershipRuleProcessingState) -or
        ($null -ne $groupObj.MembershipRule)
    ) {
        Write-Error "Break Glass Group $($Config.group.id): Can not have dynamic membership rules"
        return 1
    }
    if (
        ($Config.group.isAssignableToRole -eq $true) -and
        ($groupObj.IsAssignableToRole -ne $true)
    ) {
        Write-Error "Break Glass Group $($Config.group.id): Must be re-created with role-assignment capability enabled"
        return 1
    }
    if (
        ($null -ne $Config.group.visibility) -and
        ($Config.group.visibility -ne $groupObj.visibility)
    ) {
        Write-Error "Break Glass Group $($Config.group.id): Visibility must be $($Config.group.visibility)"
        return 1
    }
    if (
        ($null -ne $Config.group.displayName) -and
        ($groupObj.DisplayName -ne $Config.group.displayName)
    ) {
        if ($Repair) {
            if ($PSCmdlet.ShouldProcess(
                "Update display name of Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName))",
                'Confirm updating the display name of the Break Glass Group?',
                "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Updating display name"
            )) {
                Write-Output "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Updating display name"
                Update-MgGroup -GroupId $groupObj.Id -DisplayName $Config.group.displayName -ErrorAction Continue -Confirm:$false
                if ($?) {
                    $groupObj.DisplayName = $Config.group.displayName
                }
            }
        }
        else {
            Write-Warning "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Current display name does not match configuration. Run Repair-Entra-Tier0-BreakGlass.ps1 to fix."
        }
    }
    if (
        ($null -ne $Config.group.description) -and
        ($groupObj.Description -ne $Config.group.description)
    ) {
        if ($Repair) {
            if ($PSCmdlet.ShouldProcess(
                "Update description of Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName))",
                'Confirm updating the description of the Break Glass Group?',
                "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Updating description"
            )) {
                Write-Output "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Updating description"
                Update-MgGroup -GroupId $groupObj.Id -Description $Config.group.description -ErrorAction Continue -Confirm:$false
                if ($?) {
                    $groupObj.Description = $Config.group.Description
                }
            }
        }
        else {
            Write-Warning "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Current description not match configuration. Run Repair-Entra-Tier0-BreakGlass.ps1 to fix."
        }
    }
    #TODO: Block role-enabled groups that were onboarded/registered to PIM
    Write-Verbose "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)) VALIDATED"

    $validBreakGlassCount = 0
    $breakGlassAccountIds = @()

    foreach ($account in $Config.accounts) {
        $userId = $null
        if (
            ($null -ne $account.id) -and
            ($account.id -notmatch '^00000000-') -and
            ($account.id -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$') -and
            ($null -ne $account.directoryRoles)
        ) {
            $userId = $account.id
        }
        elseif (
            ($null -ne $account.userPrincipalName) -and
            ($account.userPrincipalName -match "[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?") -and
            ($null -ne $account.directoryRoles)
        ) {
            Write-Warning "$($validBreakGlassCount + 1). Break Glass Account $($account.userPrincipalName): SHOULD use explicit object ID in configuration"
            $userId = $account.userPrincipalName
        }
        else {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account is incomplete"
            return 1
        }
        $userObj = Get-MgUser -UserId $userId -Property Id, UserPrincipalName, IsResourceAccount, UserType, ExternalUserState, OnPremisesSyncEnabled, CreatedDateTime, DeletedDateTime, AccountEnabled, PasswordProfile, LastPasswordChangeDateTime, Authentication, DisplayName -ErrorAction Stop

        if ($null -eq $userObj) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account: $userId does not exist"
            return 1
        }
        if ($userObj.userPrincipalName -ne $account.userPrincipalName) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): User Principal Name does not match expected value '$($account.userPrincipalName)'"
            return 1
        }
        if ($userObj.userPrincipalName -notmatch '^.+\.onmicrosoft\.com$') {
            Write-Warning "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): User Principal Name SHOULD use .onmicrosoft.com subdomain"
        }
        if ($null -ne $userObj.IsResourceAccount) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Can not be of type Resource Account"
            return 1
        }
        if ($userObj.UserType -ne 'Member') {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Must be of user type 'Member'"
            return 1
        }
        if ($null -ne $userObj.ExternalUserState) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Can not be external"
            return 1
        }
        if ($null -ne $userObj.OnPremisesSyncEnabled) {
            if ($userObj.OnPremisesSyncEnabled -eq $true) {
                Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Must be cloud-only"
            }
            else {
                Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Can never have synced with on-premises before and must be cloud-only right from the beginning"
            }
            return 1
        }
        if ($null -ne $userObj.DeletedDateTime) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Was deleted and can not be used as Break Glass Account"
            return 1
        }
        if ($userObj.AccountEnabled -ne $true) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Must be enabled for login"
            return 1
        }
        if ($userObj.LastPasswordChangeDateTime -le $userObj.CreatedDateTime) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Password must be changed after initial creation"
            return 1
        }
        if (
            ($null -ne $userObj.PasswordProfile.ForceChangePasswordNextSignIn) -or
            ($null -ne $userObj.PasswordProfile.ForceChangePasswordNextSignInWithMfa)
        ) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Temporary password must be changed to permanent password first"
            return 1
        }
        if (
            ($null -ne $account.displayName) -and
            ($userObj.DisplayName -ne $account.displayName)
        ) {
            Write-Verbose "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.DisplayName)): Updating display name"
            if ($PSCmdlet.ShouldProcess($userObj.Id)) {
                Update-MgUser -UserID $userObj.Id -DisplayName $account.displayName -ErrorAction Continue
                $userObj.DisplayName = $account.displayName
            }
        }

        $authMethods = Get-MgUserAuthenticationMethod -UserId $userObj.Id -ErrorAction Stop
        foreach ($authMethodId in $account.authenticationMethods) {
            $authMethodOdataType = '#microsoft.graph.' + $authMethodId + 'AuthenticationMethod'
            if ($authMethodOdataType -notin $authMethods.AdditionalProperties.'@odata.type') {
                Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Missing Authentication Method: $authMethodId"
                return 1
            }
        }
        foreach ($authMethod in $authMethods) {
            $authMethodId = $null
            if ($authMethod.AdditionalProperties.'@odata.type' -match '^#microsoft\.graph\.(.+)AuthenticationMethod$') {
                $authMethodId = $Matches[1]
            }
            if (!$authMethodId -or ($authMethodId -notin $account.authenticationMethods)) {
                Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Unexpected active Authentication Method: $($authMethod.AdditionalProperties.'@odata.type')"
                return 1
            }
            if ($authMethodId -eq 'password') { continue }

            $authMethodConf = Get-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration -AuthenticationMethodConfigurationId $authMethodId -ErrorAction Stop
            if ($authMethodConf.State -ne 'enabled') {
                Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Authentication Method $authMethodId is currently not enabled for this tenant"
                return 1
            }

            $isBreakGlassGroupExcluded = $false
            if (
                (
                    ($null -eq $authMethodConf.ExcludeTargets) -and
                    ($null -eq $authMethodConf.AdditionalProperties.excludeTargets)
                ) -or
                (
                    ($null -ne $authMethodConf.ExcludeTargets) -and
                    ($authMethodConf.ExcludeTargets | Where-Object -FilterScript {
                        ($_.targetType -eq 'group') -and
                        ($_.id -eq $groupObj.Id)
                    })
                ) -or
                (
                    ($null -ne $authMethodConf.AdditionalProperties.excludeTargets) -and
                    ($authMethodConf.AdditionalProperties.excludeTargets | Where-Object -FilterScript {
                        ($_.targetType -eq 'group') -and
                        ($_.id -eq $groupObj.Id)
                    })
                )
            ) {
                $isBreakGlassGroupExcluded = $true
            }

            $isBreakGlassGroupIncluded = $false
            if (
                (
                    ($null -ne $authMethodConf.IncludeTargets) -and
                    ($authMethodConf.IncludeTargets | Where-Object -FilterScript {
                        ($_.targetType -eq 'group') -and
                        (
                            ($_.id -eq 'all_users') -or
                            ($_.id -eq $groupObj.Id)
                        )
                    })
                ) -or
                (
                    ($null -ne $authMethodConf.AdditionalProperties.includeTargets) -and
                    ($authMethodConf.AdditionalProperties.includeTargets | Where-Object -FilterScript {
                        ($_.targetType -eq 'group') -and
                        (
                            ($_.id -eq 'all_users') -or
                            ($_.id -eq $groupObj.Id)
                        )
                    })
                )
            ) {
                $isBreakGlassGroupIncluded = $true
            }

            if ($isBreakGlassGroupExcluded) {
                Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Break Glass group must not be excluded to use Authentication Method $authMethodId"
                return 1
            }
            if (!$isBreakGlassGroupIncluded) {
                Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Break Glass group must be included to use Authentication Method $authMethodId"
                return 1
            }
        }

        $roleAssignments = Get-MgRoleManagementDirectoryRoleAssignmentSchedule -Filter "PrincipalId eq '$($userObj.Id)'" -ErrorAction Stop
        foreach ($RoleDefinitionId in $account.directoryRoles) {
            $thisRoleAssignments = $roleAssignments | Where-Object -FilterScript { $_.RoleDefinitionId -eq $RoleDefinitionId }
            if ($thisRoleAssignments.Count -lt 1) {
                Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): MUST be assigned directory role $RoleDefinitionId"
                return 1
            }
            foreach ($roleAssignment in $thisRoleAssignments) {
                if ('Direct' -ne $roleAssignment.MemberType) {
                    Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): $RoleDefinitionId role assignment MUST NOT use transitive role assignment via group"
                    return 1
                }
                if ('Assigned' -ne $roleAssignment.AssignmentType) {
                    Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): $RoleDefinitionId role assignment MUST be active"
                    return 1
                }
                if ('noExpiration' -ne $roleAssignment.ScheduleInfo.Expiration.Type) {
                    Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): $RoleDefinitionId role assignment MUST never expire"
                    return 1
                }
                if ('Provisioned' -ne $roleAssignment.Status) {
                    Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): $RoleDefinitionId role assignment was not fully provisioned yet"
                    return 1
                }
            }
        }

        $groupMemberOf = Get-MgUserMemberGroup -UserId $userObj.Id -SecurityEnabledOnly:$true -Confirm:$false -ErrorAction Stop
        if ($groupObj.Id -notin $groupMemberOf) {
            if ($PSCmdlet.ShouldProcess($groupObj.Id)) {
                Write-Warning "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Added to Break Glass Group $($groupObj.DisplayName)"
                New-MgGroupMember -GroupId $groupObj.Id -DirectoryObjectId $userObj.Id -ErrorAction Stop
            }
        }

        Write-Verbose "$($validBreakGlassCount + 1). Break Glass Account: $($userObj.Id) ($($userObj.DisplayName)) VALIDATED"
        $validBreakGlassCount++
        $breakGlassAccountIds += $userObj.Id
    }

    if ($validBreakGlassCount -lt 2) {
        Write-Error 'Break Glass account validation FAILED'
        return 1
    }

    $validBreakGlass = $true

    $groupOwners = Get-MgGroupOwner -GroupId $groupObj.Id -ErrorAction Stop
    foreach ($groupOwner in $groupOwners) {
        Remove-MgGroupOwnerByRef -GroupId $Config.group.id -DirectoryObjectId $groupOwner.Id -Confirm:$false
        Write-Warning "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Removed suspicious group owner $($groupOwner.Id)"
    }

    $groupMembers = Get-MgGroupMember -GroupId $groupObj.Id -ErrorAction Stop
    foreach ($groupMember in $groupMembers) {
        if ($groupMember.Id -notin $breakGlassAccountIds) {
            Remove-MgGroupMemberByRef -GroupId $Config.group.id -DirectoryObjectId $groupMember.Id -Confirm:$false
            Write-Warning "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Removed unexpected group member $($groupMember.Id)"
        }
    }

    return 0
}

$validBreakGlass = $false
