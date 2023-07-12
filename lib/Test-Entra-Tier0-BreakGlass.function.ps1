#Requires -Version 7.2
#Requires -Modules @{ ModuleName='Microsoft.Graph.Beta.Identity.DirectoryManagement'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Users'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Groups'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Identity.DirectoryManagement'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Identity.Governance'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Identity.SignIns'; ModuleVersion='2.0' }

function Test-Entra-Tier0-BreakGlass {
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'High'
    )]
    Param (
        $EntraCABreakGlass
    )

    $adminUnitObj = $null

    if (
        ($null -ne $EntraCABreakGlass.adminUnit.id) -and
        ($EntraCABreakGlass.adminUnit.id -notmatch '^00000000-') -and
        ($EntraCABreakGlass.adminUnit.id -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$')
    ) {
        $adminUnitObj = Get-MgBetaDirectoryAdministrativeUnit -AdministrativeUnitId $EntraCABreakGlass.adminUnit.id -ErrorAction SilentlyContinue
    }
    elseif (
        ($null -ne $EntraCABreakGlass.adminUnit.displayName) -and
        ($EntraCABreakGlass.adminUnit.displayName -ne '')
    ) {
        $adminUnitObj = Get-MgBetaDirectoryAdministrativeUnit -All -Filter "displayName eq '$($EntraCABreakGlass.adminUnit.displayName)'" -ErrorAction SilentlyContinue
    }
    elseif ($null -ne $EntraCABreakGlass.adminUnit) {
        Write-Error 'Defined Break Glass Admin Unit is incomplete'
        return
    }

    if ($null -ne $EntraCABreakGlass.adminUnit) {
        if ($null -eq $adminUnitObj) {
            Write-Error "Defined Break Glass Admin Unit $($EntraCABreakGlass.adminUnit.id) ($($EntraCABreakGlass.adminUnit.displayName)) does not exist"
            return
        }
        if (
            ($null -ne $EntraCABreakGlass.adminUnit.visibility) -and
            ($adminUnitObj.Visibility -ne $EntraCABreakGlass.adminUnit.visibility)
        ) {
            Write-Error "Break Glass Admin Unit $($adminUnitObj.id): Visibility must be $($EntraCABreakGlass.adminUnit.visibility)"
            return
        }
        if (
            ($null -ne $EntraCABreakGlass.adminUnit.isMemberManagementRestricted) -and
            ($adminUnitObj.isMemberManagementRestricted -ne $EntraCABreakGlass.adminUnit.isMemberManagementRestricted)
        ) {
            Write-Error "Break Glass Admin Unit $($adminUnitObj.id): Restricted Management must be $($EntraCABreakGlass.adminUnit.isMemberManagementRestricted)"
            return
        }
        Write-Output "Break Glass Admin Unit $($adminUnitObj.Id) ($($adminUnitObj.DisplayName)) VALIDATED"
    }

    $groupObj = $null

    if (
        ($null -ne $EntraCABreakGlass.group.id) -and
        ($EntraCABreakGlass.group.id -notmatch '^00000000-') -and
        ($EntraCABreakGlass.group.id -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$')
    ) {
        $groupObj = Get-MgGroup -GroupId $EntraCABreakGlass.group.id -ErrorAction SilentlyContinue
    }
    elseif (
        ($null -ne $EntraCABreakGlass.group.displayName) -and
        ($EntraCABreakGlass.group.displayName -ne '')
    ) {
        $groupObj = Get-MgGroup -All -Filter "displayName eq '$($EntraCABreakGlass.group.displayName)'" -ErrorAction SilentlyContinue
        Write-Warning "Break Glass Group $($groupObj.displayName): Should use explicit object ID $($groupObj.Id) in configuration"
    }
    else {
        Write-Error 'Defined Break Glass Group is incomplete'
        return
    }

    if ($null -eq $groupObj) {
        Write-Error "Defined Break Glass Group $($EntraCABreakGlass.group.id) ($($EntraCABreakGlass.group.displayName)) does not exist"
        return
    }
    if ($groupObj.SecurityEnabled -ne $true) {
        Write-Error "Break Glass Group $($EntraCABreakGlass.group.id): Must be a security group"
        return
    }
    if ($groupObj.MailEnabled -ne $false) {
        Write-Error "Break Glass Group $($EntraCABreakGlass.group.id): Can not be mail-enabled"
        return
    }
    if ($groupObj.GroupTypes.Count -ne 0) {
        Write-Error "Break Glass Group $($EntraCABreakGlass.group.id): Can not have any specific group type"
        return
    }
    if (
        ($null -ne $groupObj.MembershipRuleProcessingState) -or
        ($null -ne $groupObj.MembershipRule)
    ) {
        Write-Error "Break Glass Group $($EntraCABreakGlass.group.id): Can not have dynamic membership rules"
        return
    }
    if (
        ($EntraCABreakGlass.group.isAssignableToRole -eq $true) -and
        ($groupObj.IsAssignableToRole -ne $true)
    ) {
        Write-Error "Break Glass Group $($EntraCABreakGlass.group.id): Must be re-created with role-assignment capability enabled"
        return
    }
    if (
        ($null -ne $EntraCABreakGlass.group.visibility) -and
        ($EntraCABreakGlass.group.visibility -ne $groupObj.visibility)
    ) {
        Write-Error "Break Glass Group $($EntraCABreakGlass.group.id): Visibility must be $($EntraCABreakGlass.group.visibility)"
        return
    }
    if (
        ($null -ne $EntraCABreakGlass.group.displayName) -and
        ($groupObj.DisplayName -ne $EntraCABreakGlass.group.displayName)
    ) {
        if (
            ('Group.ReadWrite.All' -in (Get-MgContext).Scopes) -and
            (
                ($null -eq $EntraCABreakGlass.adminUnit) -or
                !$EntraCABreakGlass.adminUnit.isMemberManagementRestricted -or
                'Directory.Write.Restricted' -in (Get-MgContext).Scopes
            )
        ) {
            Write-Information "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Updating display name"
            if ($PSCmdlet.ShouldProcess($groupObj.Id)) {
                Update-MgGroup -GroupId $groupObj.Id -DisplayName $EntraCABreakGlass.group.displayName
                $groupObj.DisplayName = $EntraCABreakGlass.group.displayName
            }
        }
        else {
            Write-Warning "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Current display name does not match configuration. Run Repair-Entra-Tier0-BreakGlass.ps1 to fix."
        }
    }
    if (
        ($null -ne $EntraCABreakGlass.group.description) -and
        ($groupObj.Description -ne $EntraCABreakGlass.group.description)
    ) {
        if (
            ('Group.ReadWrite.All' -in (Get-MgContext).Scopes) -and
            (
                ($null -eq $EntraCABreakGlass.adminUnit) -or
                !$EntraCABreakGlass.adminUnit.isMemberManagementRestricted -or
                'Directory.Write.Restricted' -in (Get-MgContext).Scopes
            )
        ) {
            Write-Information "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Updating description"
            if ($PSCmdlet.ShouldProcess($groupObj.Id)) {
                Update-MgGroup -GroupId $groupObj.Id -Description $EntraCABreakGlass.group.description
                $groupObj.Description = $EntraCABreakGlass.group.description
            }
        }
        else {
            Write-Warning "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Current description not match configuration. Run Repair-Entra-Tier0-BreakGlass.ps1 to fix."
        }
    }
    #TODO: Block groups that were onboarded to PIM
    Write-Output "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)) VALIDATED"

    $validBreakGlassCount = 0
    $breakGlassAccountIds = @()

    foreach ($account in $EntraCABreakGlass.accounts) {
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
            return
        }
        $userObj = Get-MgUser -UserId $userId -Property Id, UserPrincipalName, IsResourceAccount, UserType, ExternalUserState, OnPremisesSyncEnabled, CreatedDateTime, DeletedDateTime, AccountEnabled, PasswordProfile, LastPasswordChangeDateTime, Authentication, DisplayName -ErrorAction SilentlyContinue

        if ($null -eq $userObj) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account: $userId does not exist"
            return
        }
        if ($userObj.userPrincipalName -ne $account.userPrincipalName) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): User Principal Name does not match expected value '$($account.userPrincipalName)'"
            return
        }
        if ($userObj.userPrincipalName -notmatch '^.+\.onmicrosoft\.com$') {
            Write-Warning "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): User Principal Name SHOULD use .onmicrosoft.com subdomain"
        }
        if ($null -ne $userObj.IsResourceAccount) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Can not be of type Resource Account"
            return
        }
        if ($userObj.UserType -ne 'Member') {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Must be of user type 'Member'"
            return
        }
        if ($null -ne $userObj.ExternalUserState) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Can not be external"
            return
        }
        if ($null -ne $userObj.OnPremisesSyncEnabled) {
            if ($userObj.OnPremisesSyncEnabled -eq $true) {
                Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Must be cloud-only"
            }
            else {
                Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Can never have synced with on-premises before and must be cloud-only right from the beginning"
            }
            return
        }
        if ($null -ne $userObj.DeletedDateTime) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Was deleted and can not be used as Break Glass Account"
            return
        }
        if ($userObj.AccountEnabled -ne $true) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Must be enabled for login"
            return
        }
        if ($userObj.LastPasswordChangeDateTime -le $userObj.CreatedDateTime) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Password must be changed after initial creation"
            return
        }
        if (
            ($null -ne $userObj.PasswordProfile.ForceChangePasswordNextSignIn) -or
            ($null -ne $userObj.PasswordProfile.ForceChangePasswordNextSignInWithMfa)
        ) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Temporary password must be changed to permanent password first"
            return
        }
        if (
            ($null -ne $account.displayName) -and
            ($userObj.DisplayName -ne $account.displayName)
        ) {
            Write-Information "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.DisplayName)): Updating display name"
            if ($PSCmdlet.ShouldProcess($userObj.Id)) {
                Update-MgUser -UserID $userObj.Id -DisplayName $account.displayName
                $userObj.DisplayName = $account.displayName
            }
        }

        $authMethods = Get-MgUserAuthenticationMethod -UserId $userObj.Id -ErrorAction SilentlyContinue
        foreach ($authMethodId in $account.authenticationMethods) {
            $authMethodOdataType = '#microsoft.graph.' + $authMethodId + 'AuthenticationMethod'
            if ($authMethodOdataType -notin $authMethods.AdditionalProperties.'@odata.type') {
                Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Missing Authentication Method: $authMethodId"
                return
            }
        }
        foreach ($authMethod in $authMethods) {
            $authMethodId = $null
            if ($authMethod.AdditionalProperties.'@odata.type' -match '^#microsoft\.graph\.(.+)AuthenticationMethod$') {
                $authMethodId = $Matches[1]
            }
            if (!$authMethodId -or ($authMethodId -notin $account.authenticationMethods)) {
                Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Unexpected active Authentication Method: $($authMethod.AdditionalProperties.'@odata.type')"
                return
            }
            if ($authMethodId -eq 'password') { continue }

            $authMethodConf = Get-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration -AuthenticationMethodConfigurationId $authMethodId
            if ($authMethodConf.State -ne 'enabled') {
                Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Authentication Method $authMethodId is currently not enabled for this tenant"
                return
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
                return
            }
            if (!$isBreakGlassGroupIncluded) {
                Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Break Glass group must be included to use Authentication Method $authMethodId"
                return
            }
        }

        $roleAssignments = Get-MgRoleManagementDirectoryRoleAssignmentSchedule -Filter "PrincipalId eq '$($userObj.Id)'"
        foreach ($RoleDefinitionId in $account.directoryRoles) {
            $thisRoleAssignments = $roleAssignments | Where-Object -FilterScript { $_.RoleDefinitionId -eq $RoleDefinitionId }
            if ($thisRoleAssignments.Count -lt 1) {
                Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): MUST be assigned directory role $RoleDefinitionId"
                return
            }
            foreach ($roleAssignment in $thisRoleAssignments) {
                if ('Direct' -ne $roleAssignment.MemberType) {
                    Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): $RoleDefinitionId role assignment MUST NOT use transitive role assignment via group"
                    return
                }
                if ('Assigned' -ne $roleAssignment.AssignmentType) {
                    Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): $RoleDefinitionId role assignment MUST be active"
                    return
                }
                if ('noExpiration' -ne $roleAssignment.ScheduleInfo.Expiration.Type) {
                    Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): $RoleDefinitionId role assignment MUST never expire"
                    return
                }
                if ('Provisioned' -ne $roleAssignment.Status) {
                    Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): $RoleDefinitionId role assignment was not fully provisioned yet"
                    return
                }
            }
        }

        $groupMemberOf = Get-MgUserMemberGroup -UserId $userObj.Id -SecurityEnabledOnly:$true -Confirm:$false
        if ($groupObj.Id -notin $groupMemberOf) {
            if ($PSCmdlet.ShouldProcess($groupObj.Id)) {
                Write-Warning "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Added to Break Glass Group $($groupObj.DisplayName)"
                New-MgGroupMember -GroupId $groupObj.Id -DirectoryObjectId $userObj.Id
            }
        }

        Write-Output "$($validBreakGlassCount + 1). Break Glass Account: $($userObj.Id) ($($userObj.DisplayName)) VALIDATED"
        $validBreakGlassCount++
        $breakGlassAccountIds += $userObj.Id
    }

    if ($validBreakGlassCount -lt 2) {
        Write-Error 'Break Glass account validation FAILED'
        return
    }

    $validBreakGlass = $true

    $groupOwners = Get-MgGroupOwner -GroupId $groupObj.Id
    foreach ($groupOwner in $groupOwners) {
        Remove-MgGroupOwnerByRef -GroupId $EntraCABreakGlass.group.id -DirectoryObjectId $groupOwner.Id
        Write-Warning "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Removed suspicious group owner $($groupOwner.Id)"
    }

    $groupMembers = Get-MgGroupMember -GroupId $groupObj.Id
    foreach ($groupMember in $groupMembers) {
        if ($groupMember.Id -notin $breakGlassAccountIds) {
            Remove-MgGroupMemberByRef -GroupId $EntraCABreakGlass.group.id -DirectoryObjectId $groupMember.Id
            Write-Warning "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Removed unexpected group member $($groupMember.Id)"
        }
    }

}

$validBreakGlass = $false
