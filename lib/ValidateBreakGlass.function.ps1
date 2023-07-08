function ValidateBreakGlass {
    if (!$CreateAdminCAPolicies -and !$CreateGeneralCAPolicies -and !$ValidateBreakGlass -and !$SkipBreakGlassValidation) { return }

    if ($SkipBreakGlassValidation -and !$ValidateBreakGlass) {
        Write-Warning "Break Glass Account validation SKIPPED"
        $validBreakGlass = $true
        return
    }

    $validBreakGlassCount = 0
    $groupObj = $null

    if (
        ($null -ne $AADCABreakGlass.group.id) -and
        ($AADCABreakGlass.group.id -notmatch '^00000000-') -and
        ($AADCABreakGlass.group.id -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$')
    ) {
        $groupObj = Get-MgGroup -GroupId $AADCABreakGlass.group.id -ErrorAction SilentlyContinue
    }
    else {
        Write-Error 'Defined Break Glass Group is incomplete'
        return
    }

    if ($null -eq $groupObj) {
        Write-Error "Defined Break Glass Group $($AADCABreakGlass.group.id) does not exist"
        return
    }
    if ($groupObj.SecurityEnabled -ne $true) {
        Write-Error "Break Glass Group $($AADCABreakGlass.group.id): Must be a security group"
        return
    }
    if ($groupObj.MailEnabled -ne $false) {
        Write-Error "Break Glass Group $($AADCABreakGlass.group.id): Can not be mail-enabled"
        return
    }
    if ($groupObj.GroupTypes.Count -ne 0) {
        Write-Error "Break Glass Group $($AADCABreakGlass.group.id): Can not have any specific group type"
        return
    }
    if (
        ($null -ne $groupObj.MembershipRuleProcessingState) -or
        ($null -ne $groupObj.MembershipRule)
    ) {
        Write-Error "Break Glass Group $($AADCABreakGlass.group.id): Can not have dynamic membership rules"
        return
    }
    if (
        ($AADCABreakGlass.group.isAssignableToRole -eq $true) -and
        ($groupObj.IsAssignableToRole -ne $true)
    ) {
        Write-Error "Break Glass Group $($AADCABreakGlass.group.id): Must be re-created with role-assignment capability enabled"
        return
    }
    if (
        ($null -ne $AADCABreakGlass.group.displayName) -and
        ($groupObj.DisplayName -ne $AADCABreakGlass.group.displayName)
    ) {
        Write-Information "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Updating display name"
        Update-MgGroup -GroupId $groupObj.Id -DisplayName $AADCABreakGlass.group.displayName
        $groupObj.DisplayName = $AADCABreakGlass.group.displayName
    }
    if (
        ($null -ne $AADCABreakGlass.group.description) -and
        ($groupObj.Description -ne $AADCABreakGlass.group.description)
    ) {
        Write-Information "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Updating description"
        Update-MgGroup -GroupId $groupObj.Id -Description $AADCABreakGlass.group.description
        $groupObj.Description = $AADCABreakGlass.group.description
    }
    #TODO: Block groups that were onboarded to PIM
    Write-Output "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)) VALIDATED"

    $breakGlassAccountIds = @()

    foreach ($account in $AADCABreakGlass.accounts) {
        $userId = $null
        if (
            ($null -ne $account.id) -and
            ($account.id -notmatch '^00000000-') -and
            ($account.id -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$')
        ) {
            $userId = $account.id
        }
        elseif (
            ($null -ne $account.userPrincipalName) -and
            ($account.userPrincipalName -match "[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?")
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
            Update-MgUser -UserID $userObj.Id -DisplayName $account.displayName
            $userObj.DisplayName = $account.displayName
        }

        $authMethods = Get-MgUserAuthenticationMethod -UserId $userObj.Id
        foreach ($authMethod in $authMethods) {
            if ($authMethod.AdditionalProperties.'@odata.type' -notin $account.authenticationMethods) {
                Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Unexpected active Authentication Method: $($authMethod.AdditionalProperties.'@odata.type')"
                return
            }
        }
        foreach ($authMethod in $account.authenticationMethods) {
            if ($authMethod -notin $authMethods.AdditionalProperties.'@odata.type') {
                Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Missing Authentication Method: $authMethod"
                return
            }
        }

        $roleAssignment = Get-MgRoleManagementDirectoryRoleAssignmentSchedule -Filter "(RoleDefinitionId eq '62e90394-69f5-4237-9190-012177145e10') and (PrincipalId eq '$($userObj.Id)')"
        if ($userObj.Id -ne $roleAssignment.PrincipalId) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): MUST be assigned Global Administrator role"
            return
        }
        if ('Direct' -ne $roleAssignment.MemberType) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Global Administrator role assignment MUST NOT use transitive role assignment via group"
            return
        }
        if ('Assigned' -ne $roleAssignment.AssignmentType) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Global Administrator role assignment MUST be active"
            return
        }
        if ('noExpiration' -ne $roleAssignment.ScheduleInfo.Expiration.Type) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Global Administrator role assignment MUST never expire"
            return
        }
        if ('Provisioned' -ne $roleAssignment.Status) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Global Administrator role assignment was not fully provisioned yet"
            return
        }

        $groupMemberOf = Get-MgUserMemberGroup -UserId $userObj.Id -SecurityEnabledOnly:$true
        if ($groupObj.Id -notin $groupMemberOf) {
            New-MgGroupMember -GroupId $groupObj.Id -DirectoryObjectId $userObj.Id
            Write-Warning "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)): Added to Break Glass Group $($groupObj.DisplayName)"
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
        Remove-MgGroupOwnerByRef -GroupId $AADCABreakGlass.group.id -DirectoryObjectId $groupOwner.Id
        Write-Warning "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Removed suspicious group owner $($groupOwner.Id)"
    }

    $groupMembers = Get-MgGroupMember -GroupId $groupObj.Id
    foreach ($groupMember in $groupMembers) {
        if ($groupMember.Id -notin $breakGlassAccountIds) {
            Remove-MgGroupMemberByRef -GroupId $AADCABreakGlass.group.id -DirectoryObjectId $groupMember.Id
            Write-Warning "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Removed unexpected group member $($groupMember.Id)"
        }
    }
}

$validBreakGlass = $false
