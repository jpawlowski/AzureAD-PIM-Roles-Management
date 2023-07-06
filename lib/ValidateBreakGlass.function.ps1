function ValidateBreakGlass {
    if (!$CreateCAPolicies) { return }

    $validBreakGlassCount = 0
    $groupObj = $null

    if (
        ($null -ne $AADCABreakGlass.group.id) -and
        ($AADCABreakGlass.group.id -ne '00000000-0000-0000-0000-000000000000') -and
        ($AADCABreakGlass.group.id -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$')
    ) {
        $groupObj = Get-MgGroup -GroupId $AADCABreakGlass.group.id -ErrorAction SilentlyContinue
    } else {
        Write-Error 'Defined Break Glass Group is incomplete'
        return
    }

    if ($null -eq $groupObj) {
        Write-Error "Defined Break Glass Group $($AADCABreakGlass.group.id) does not exist"
        return
    }
    if (
        ($AADCABreakGlass.group.isAssignableToRole -eq $true) -and
        ($groupObj.IsAssignableToRole -ne $true)
    ) {
        Write-Error "Break Glass Group $($AADCABreakGlass.group.id) must be re-created with role-assignment capability enabled"
        return
    }
    if (
        ($null -ne $AADCABreakGlass.group.displayName) -and
        ($groupObj.DisplayName -ne $AADCABreakGlass.group.displayName)
    ) {
        Write-Output "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Updating display name"
        Update-MgGroup -GroupId $groupObj.Id -DisplayName $AADCABreakGlass.group.displayName
        $groupObj.DisplayName = $AADCABreakGlass.group.displayName
    }
    if (
        ($null -ne $AADCABreakGlass.group.description) -and
        ($groupObj.Description -ne $AADCABreakGlass.group.description)
    ) {
        Write-Output "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)): Updating description"
        Update-MgGroup -GroupId $groupObj.Id -Description $AADCABreakGlass.group.description
        $groupObj.Description = $AADCABreakGlass.group.description
    }
    Write-Information "Break Glass Group $($groupObj.Id) ($($groupObj.DisplayName)) VALIDATED"

    $groupOwners = Get-MgGroupOwner -GroupId $groupObj.Id
    $groupMembers = Get-MgGroupMember -GroupId $groupObj.Id

    foreach ($account in $AADCABreakGlass.accounts) {
        $userId = $null
        if (
            ($null -ne $account.id) -and
            ($account.id -ne '00000000-0000-0000-0000-000000000000') -and
            ($account.id -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$')
        ) {
            $userId = $account.id
        } elseif (
            ($null -ne $account.userPrincipalName) -and
            ($account.userPrincipalName -match "[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?")
        ) {
            Write-Warning "$($validBreakGlassCount + 1). Break Glass Account: $($account.userPrincipalName) SHOULD use explicit object ID in configuration"
            $userId = $account.userPrincipalName
        } else {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account is incomplete"
            return
        }
        $userObj = Get-MgUser -UserId $userId -Property Id,UserPrincipalName,IsResourceAccount,UserType,ExternalUserState,OnPremisesSyncEnabled,CreatedDateTime,DeletedDateTime,AccountEnabled,LastPasswordChangeDateTime,Authentication,DisplayName -ErrorAction SilentlyContinue

        if ($null -eq $userObj) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account: $userId does not exist"
            return
        }
        if ($userObj.userPrincipalName -ne $account.userPrincipalName) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account: $($userObj.Id) ($($userObj.userPrincipalName)) User Principal Name does not match expected value '$($account.userPrincipalName)'"
            return
        }
        if ($userObj.userPrincipalName -notmatch '^.+\.onmicrosoft\.com$') {
            Write-Warning "$($validBreakGlassCount + 1). Break Glass Account: $($userObj.Id) ($($userObj.userPrincipalName)) User Principal Name SHOULD use .onmicrosoft.com subdomain"
        }
        if ($null -ne $userObj.IsResourceAccount) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account: $($userObj.Id) ($($userObj.userPrincipalName)) can not be of type Resource Account"
            return
        }
        if ($userObj.UserType -ne 'Member') {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account: $($userObj.Id) ($($userObj.userPrincipalName)) must be of user type 'Member'"
            return
        }
        if ($null -ne $userObj.ExternalUserState) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account: $($userObj.Id) ($($userObj.userPrincipalName)) can not be external"
            return
        }
        if ($null -ne $userObj.OnPremisesSyncEnabled) {
            if ($userObj.OnPremisesSyncEnabled -eq $true) {
                Write-Error "$($validBreakGlassCount + 1). Break Glass Account: $($userObj.Id) ($($userObj.userPrincipalName)) must be cloud-only"
            } else {
                Write-Error "$($validBreakGlassCount + 1). Break Glass Account: $($userObj.Id) ($($userObj.userPrincipalName)) can never have synced with on-premises before and must be cloud-only right from the beginning"
            }
            return
        }
        if ($null -ne $userObj.DeletedDateTime) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account: $($userObj.Id) ($($userObj.userPrincipalName)) was deleted and can not be used as Break Glass Account"
            return
        }
        if ($userObj.AccountEnabled -ne $true) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account: $($userObj.Id) ($($userObj.userPrincipalName)) must be enabled for login"
            return
        }
        if ($userObj.LastPasswordChangeDateTime -le $userObj.CreatedDateTime) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account $($userObj.Id) ($($userObj.userPrincipalName)) password must be changed after initial creation"
            return
        }
        if (
            ($null -ne $account.displayName) -and
            ($userObj.DisplayName -ne $account.displayName)
        ) {
            Write-Information "$($validBreakGlassCount + 1). Break Glass Account: Updating display name for $($userObj.Id) ($($userObj.DisplayName))"
            Update-MgUser -UserID $userObj.Id -DisplayName $account.displayName
            $userObj.DisplayName = $account.displayName
        }

        $roleAssignment = Get-MgRoleManagementDirectoryRoleAssignmentSchedule -Filter "(RoleDefinitionId eq '62e90394-69f5-4237-9190-012177145e10') and (PrincipalId eq '$($userObj.Id)')"
        if ($userObj.Id -ne $roleAssignment.PrincipalId) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account: $($userObj.Id) ($($userObj.userPrincipalName)) must be assigned Global Administrator role"
            return
        }
        if ('Direct' -ne $roleAssignment.MemberType) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account: $($userObj.Id) ($($userObj.userPrincipalName)) Global Administrator role MUST NOT use transitive role assignment via group"
            return
        }
        if ('Assigned' -ne $roleAssignment.AssignmentType) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account: $($userObj.Id) ($($userObj.userPrincipalName)) Global Administrator role assignment must be active"
            return
        }
        if ('noExpiration' -ne $roleAssignment.ScheduleInfo.Expiration.Type) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account: $($userObj.Id) ($($userObj.userPrincipalName)) Global Administrator role assignment must never expire"
            return
        }
        if ('Provisioned' -ne $roleAssignment.Status) {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account: $($userObj.Id) ($($userObj.userPrincipalName)) Global Administrator role assignment was not fully provisioned yet"
            return
        }

        $groupMemberOf = Get-MgUserMemberGroup -UserId $userObj.Id -SecurityEnabledOnly:$true
        if ($groupObj.Id -notin $groupMemberOf) {
            New-MgGroupMember -GroupId $groupObj.Id -DirectoryObjectId $userObj.Id
            Write-Warning "$($validBreakGlassCount + 1). Break Glass Account: $($userObj.Id) ($($userObj.userPrincipalName)) was added to Break Glass Group $($groupObj.DisplayName)"
        }

        Write-Information "$($validBreakGlassCount + 1). Break Glass Account: $($userObj.Id) ($($userObj.DisplayName)) VALIDATED"
        $validBreakGlassCount++
    }

    if ($validBreakGlassCount -lt 2) {
        Write-Error 'Break Glass account validation FAILED'
        return
    }

    $validBreakGlass = $true
}

$validBreakGlass = $false
