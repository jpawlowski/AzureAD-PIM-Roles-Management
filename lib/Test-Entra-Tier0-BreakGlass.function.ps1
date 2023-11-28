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

$MgScopes += 'User.Read.All'
$MgScopes += 'User.ReadWrite.All'
$MgScopes += 'UserAuthenticationMethod.Read.All'
$MgScopes += 'Group.Read.All'
$MgScopes += 'Group.ReadWrite.All'
$MgScopes += 'AdministrativeUnit.Read.All'
$MgScopes += 'AdministrativeUnit.ReadWrite.All'
$MgScopes += 'Directory.Write.Restricted'
$MgScopes += 'RoleManagement.Read.All'
$MgScopes += 'RoleManagement.ReadWrite.Directory'

function Test-Entra-Tier0-BreakGlass {
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'High'
    )]
    Param (
        [hashtable]$Config,
        [switch]$Repair
    )

    $params = @{
        Activity         = 'Break Glass Validation'
        Status           = " 0% Complete: Administrative Unit"
        PercentComplete  = 0
        CurrentOperation = 'BreakGlassCheck'
    }
    Write-Progress @params

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
        return
    }

    if ($null -eq $adminUnitObj) {
        Write-Error "Defined Break Glass Admin Unit $($Config.adminUnit.id) ($($Config.adminUnit.displayName)) does not exist"
        return
    }
    if (
        ($null -ne $Config.adminUnit.visibility) -and
        ($adminUnitObj.Visibility -ne $Config.adminUnit.visibility)
    ) {
        Write-Error "Break Glass Admin Unit $($adminUnitObj.id): Visibility must be $($Config.adminUnit.visibility)"
        return
    }
    if (
        ($null -ne $Config.adminUnit.isMemberManagementRestricted) -and
        ($adminUnitObj.isMemberManagementRestricted -ne $Config.adminUnit.isMemberManagementRestricted)
    ) {
        Write-Error "Break Glass Admin Unit $($adminUnitObj.id): Restricted Management must be $($Config.adminUnit.isMemberManagementRestricted)"
        return
    }
    Write-Verbose "Break Glass Admin Unit $($adminUnitObj.Id) ($($adminUnitObj.DisplayName)) VALIDATED"

    $params = @{
        Activity         = 'Break Glass Validation'
        Status           = " 20% Complete: User Group"
        PercentComplete  = 20
        CurrentOperation = 'BreakGlassCheck'
    }
    Write-Progress @params

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
        return
    }

    if ($null -eq $groupObj) {
        Write-Error "Defined Break Glass Group $($Config.group.id) ($($Config.group.displayName)) does not exist"
        return
    }
    if ($groupObj.SecurityEnabled -ne $true) {
        Write-Error "Break Glass Group $($groupObj.id) ($($groupObj.DisplayName)): Must be a security group"
        return
    }
    if ($groupObj.MailEnabled -ne $false) {
        Write-Error "Break Glass Group $($groupObj.id) ($($groupObj.DisplayName)): Can not be mail-enabled"
        return
    }
    if ($groupObj.GroupTypes.Count -ne 0) {
        Write-Error "Break Glass Group $($groupObj.id) ($($groupObj.DisplayName)): Can not have any specific group type"
        return
    }
    if (
        ($null -ne $groupObj.MembershipRuleProcessingState) -or
        ($null -ne $groupObj.MembershipRule)
    ) {
        Write-Error "Break Glass Group $($groupObj.id) ($($groupObj.DisplayName)): Can not have dynamic membership rules"
        return
    }
    if (
        ($Config.group.isAssignableToRole -eq $true) -and
        ($groupObj.IsAssignableToRole -ne $true)
    ) {
        Write-Error "Break Glass Group $($groupObj.id) ($($groupObj.DisplayName)): Must be re-created with role-assignment capability enabled"
        return
    }
    if (
        ($null -ne $Config.group.visibility) -and
        ($Config.group.visibility -ne $groupObj.visibility)
    ) {
        Write-Error "Break Glass Group $($groupObj.id) ($($groupObj.DisplayName)): Visibility must be $($Config.group.visibility)"
        return
    }
    $groupMemberOfAdminUnit = Get-MgGroupMemberOfAsAdministrativeUnit -DirectoryObjectId $adminUnitObj.Id -GroupId $groupObj.Id -ErrorAction SilentlyContinue
    if (-Not $groupMemberOfAdminUnit -and $adminUnitObj.isMemberManagementRestricted) {
        Write-Warning "Break Glass Group $($groupObj.id) ($($groupObj.DisplayName)): Not a member of defined Break Glass Admin Unit $($adminUnitObj.Id) ($($adminUnitObj.DisplayName)). To complete GROUP PROTECTION, please manually add group to admin unit!"
    }
    if (
        ($null -ne $Config.group.displayName) -and
        ($groupObj.DisplayName -ne $Config.group.displayName)
    ) {
        if ($Repair) {
            if ($groupMemberOfAdminUnit -and $adminUnitObj.isMemberManagementRestricted) {
                Write-Warning "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Restricted Admin Unit in use: Display name can not be corrected to '$($Config.group.displayName)' automatically."
            }
            elseif ($PSCmdlet.ShouldProcess(
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
            elseif ($WhatIfPreference) {
                Write-Verbose "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Display name would have been updated"
            }
            else {
                Write-Warning "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Display name update was denied"
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
            if ($groupMemberOfAdminUnit -and $adminUnitObj.isMemberManagementRestricted) {
                Write-Warning "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Restricted Admin Unit in use: Description can not be corrected automatically."
            }
            elseif ($PSCmdlet.ShouldProcess(
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
            elseif ($WhatIfPreference) {
                Write-Verbose "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Description would have been updated"
            }
            else {
                Write-Warning "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Description update was denied"
            }
        }
        else {
            Write-Warning "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Current description not match configuration. Run Repair-Entra-Tier0-BreakGlass.ps1 to fix."
        }
    }
    #TODO: Block role-enabled groups that were onboarded/registered to PIM
    Write-Verbose "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)) VALIDATED"

    $params = @{
        Activity         = 'Break Glass Validation'
        Status           = " 40% Complete: User Accounts"
        PercentComplete  = 40
        CurrentOperation = 'BreakGlassCheck'
    }
    Write-Progress @params

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
                Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Must be cloud native"
            }
            else {
                Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Can never have synced with on-premises before and must be cloud native right from the beginning"
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

        $userMemberOfAdminUnit = Get-MgUserMemberOfAsAdministrativeUnit -DirectoryObjectId $adminUnitObj.Id -UserId $userObj.Id -ErrorAction SilentlyContinue
        if (-Not $userMemberOfAdminUnit -and $adminUnitObj.isMemberManagementRestricted) {
            Write-Warning "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Not a member of defined Break Glass Admin Unit $($adminUnitObj.Id) ($($adminUnitObj.DisplayName)). To complete ACCOUNT PROTECTION, please manually add account to admin unit!"
        }

        if (
            ($null -ne $account.displayName) -and
            ($userObj.DisplayName -ne $account.displayName)
        ) {
            if ($userMemberOfAdminUnit -and $adminUnitObj.isMemberManagementRestricted) {
                Write-Warning "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.DisplayName)): Restricted Admin Unit in use: Display name can not be corrected to '$($account.displayName)' automatically."
            }
            elseif ($PSCmdlet.ShouldProcess(
                    "Update display name of $($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.DisplayName))",
                    'Confirm updating the display name of the Break Glass Account?',
                    "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Updating display name"
                )) {
                Write-Output "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.DisplayName)): Updating display name"
                Update-MgUser -UserID $userObj.Id -DisplayName $account.displayName -ErrorAction Continue
                $userObj.DisplayName = $account.displayName
            }
            elseif ($WhatIfPreference) {
                Write-Verbose "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Display name would have been updated"
            }
            else {
                Write-Warning "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Display name update was denied"
            }
        }

        if ($userMemberOfAdminUnit -and $adminUnitObj.isMemberManagementRestricted) {
            Write-Output "INFORMATION: $($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Restricted Admin Unit in use: Skipping validation of Authentication Methods. Regular manual control procedures do apply!"
        }
        else {
            $authMethods = Get-MgUserAuthenticationMethod -UserId $userObj.Id -ErrorAction Stop
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

                $authMethodConf = Get-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration -AuthenticationMethodConfigurationId $authMethodId -ErrorAction Stop
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
        }

        $roleAssignments = Get-MgRoleManagementDirectoryRoleAssignmentSchedule -Filter "PrincipalId eq '$($userObj.Id)'" -ErrorAction Stop
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

        $groupMemberOf = Get-MgUserMemberGroup -UserId $userObj.Id -SecurityEnabledOnly:$true -Confirm:$false -ErrorAction Stop
        if ($groupObj.Id -notin $groupMemberOf) {
            if (($userMemberOfAdminUnit -or $groupMemberOfAdminUnit) -and $adminUnitObj.isMemberManagementRestricted) {
                Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Restricted Admin Unit in use: Missing Break Glass Group membership can not be corrected automatically."
                return
            }
            elseif ($PSCmdlet.ShouldProcess(
                    "Add $($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.DisplayName)) to Break Glass Group $($groupObj.DisplayName)",
                    'Confirm adding Break Glass Account to Break Glass Group?',
                    "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Adding to Break Glass Group $($groupObj.DisplayName)"
                )) {
                Write-Verbose "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Added to Break Glass Group $($groupObj.DisplayName)"
                New-MgGroupMember -GroupId $groupObj.Id -DirectoryObjectId $userObj.Id -ErrorAction Stop
            }
            elseif ($WhatIfPreference) {
                Write-Verbose "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Would have been added to Break Glass Group $($groupObj.DisplayName)"
            }
            else {
                Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Missing Break Glass Group membership MUST be fixed to continue."
                return
            }
        }

        Write-Verbose "$($validBreakGlassCount + 1). Break Glass Account: $($userObj.Id) ($($userObj.DisplayName)) VALIDATED"
        $validBreakGlassCount++
        $breakGlassAccountIds += $userObj.Id
    }

    if ($validBreakGlassCount -lt 2) {
        Write-Error 'Break Glass account validation FAILED'
        return
    }

    $params = @{
        Activity         = 'Break Glass Validation'
        Status           = " 60% Complete: Remove suspicious owners and unexpected members from User Group"
        PercentComplete  = 60
        CurrentOperation = 'BreakGlassCheck'
    }
    Write-Progress @params

    $groupOwners = Get-MgGroupOwner -GroupId $groupObj.Id -ErrorAction Stop
    foreach ($groupOwner in $groupOwners) {
        if ($groupMemberOfAdminUnit -and $adminUnitObj.isMemberManagementRestricted) {
            Write-Error "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Restricted Admin Unit in use: Suspicious group owner $($groupOwner.Id) MUST be removed manually to continue!"
            return
        }
        else {
            Remove-MgGroupOwnerByRef -GroupId $Config.group.id -DirectoryObjectId $groupOwner.Id -Confirm:$false
            Write-Warning "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Removed suspicious group owner $($groupOwner.Id)"
        }
    }

    $groupMembers = Get-MgGroupMember -GroupId $groupObj.Id -ErrorAction Stop
    foreach ($groupMember in $groupMembers) {
        if ($groupMember.Id -notin $breakGlassAccountIds) {
            if ($groupMemberOfAdminUnit -and $adminUnitObj.isMemberManagementRestricted) {
                Write-Error "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Restricted Admin Unit in use: Unexpected group member $($groupMember.Id) MUST be removed manually to continue!"
                return
            }
            else {
                Remove-MgGroupMemberByRef -GroupId $Config.group.id -DirectoryObjectId $groupMember.Id -Confirm:$false
                Write-Warning "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Removed unexpected group member $($groupMember.Id)"
            }
        }
    }

    $params = @{
        Activity         = 'Break Glass Validation'
        Status           = " 80% Complete: Conditional Access for Break Glass"
        PercentComplete  = 80
        CurrentOperation = 'BreakGlassCheck'
    }
    Write-Progress @params

    foreach ($policy in $Config.caPolicies) {
        if (
            ($null -ne $policy.id) -and
            ($policy.id -notmatch '^00000000-') -and
            ($policy.id -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$')
        ) {
            Write-Debug "Detected Break Glass CA Policy object ID: $($policy.id)"
        }
        elseif ($policy.displayName) {
            $result = Get-MgIdentityConditionalAccessPolicy -All -Filter "displayName eq '$($policy.displayName)'"
            if (($result | Measure-Object).Count -gt 1) {
                Write-Error "Break Glass CA Policy displayName is not unique!"
                return
            }
            if ($result.Id) {
                Write-Warning "Break Glass Conditional Access Policy $($result.DisplayName): You are STRONGLY advised to complete your Break Glass CA definition by adding the unique object ID '$($result.Id)' to the configuration file before implementing other Conditional Access Policies !"
                $policy.Id = $result.Id
            }
            else {
                Write-Error "FATAL: Could not find defined Break Glass CA Policy '$($policy.displayName)' ! You may run New-Entra-Tier0-BreakGlass.ps1 to create it."
                return
            }
        }
        else {
            Write-Error "FATAL: Break Glass CA Policy definition in configuration file is incomplete."
            return
        }

        $result = Get-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $policy.Id -ErrorAction SilentlyContinue
        if ($null -eq $result.Id) {
            Write-Error "FATAL: Could not find defined Break Glass CA Policy with ID $($policy.id) ($($policy.displayName)) that is defined in configuration file."
            return
        }
        if ($policy.State -ne $result.State) {
            if ($Repair) {
                if ($PSCmdlet.ShouldProcess(
                        "Update enablement state of Break Glass Conditional Access policy $($policy.Id) ($($policy.DisplayName))",
                        'Confirm updating the enablement state of this Break Glass Conditional Access policy?',
                        "Break Glass Conditional Access policy $($policy.Id) ($($policy.DisplayName)): Updating enablement state to '$($policy.State)'"
                    )) {
                    Write-Output "Break Glass Conditional Access policy $($policy.Id) ($($policy.DisplayName)): Updating enablement state to '$($policy.State)'"
                    Update-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $result.Id -State $policy.State -ErrorAction Stop
                    $result.State = $policy.State
                }
                elseif ($WhatIfPreference) {
                    Write-Verbose "Break Glass Group $($policy.Id) ($($policy.DisplayName)): Enablement state would have been updated"
                }
                else {
                    Write-Warning "Break Glass Group $($policy.Id) ($($policy.DisplayName)): Enablement state update was denied"
                }
            }
            else {
                Write-Warning "Break Glass Conditional Access Policy $($result.DisplayName): Current enablement state '$($result.State)' differs from desired state '$($policy.State)'. You may run Repair-Entra-Tier0-BreakGlass.ps1 to fix this."
            }
        }
        if ($result.DisplayName -notmatch 'ReportOnly' -and ('enabled' -ne $result.State)) {
            Write-Warning "Break Glass Conditional Access Policy $($result.DisplayName): Policy still in state '$($result.State)', set to 'enabled' before production use. Make sure your Break Glass Accounts were properly configured with required authentication methods before!"
        }
        elseif ($result.DisplayName -match 'ReportOnly' -and ('enabledForReportingButNotEnforced' -ne $result.State)) {
            Write-Warning "Break Glass Conditional Access Policy $($result.DisplayName): Policy still in state '$($result.State)', set to 'enabledForReportingButNotEnforced' before production use."
        }
    }

    $params = @{
        Activity         = 'Break Glass Validation'
        Status           = " 100% Complete"
        PercentComplete  = 100
        CurrentOperation = 'BreakGlassCheck'
    }
    Write-Progress @params
    Start-Sleep -Milliseconds 25
}
