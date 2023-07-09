#Requires -Version 7.2
#Requires -Modules @{ ModuleName='Microsoft.Graph.Beta.Identity.DirectoryManagement'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Groups'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Users'; ModuleVersion='2.0' }
function New-AAD-Tier0-BreakGlass {
    $adminUnitObj = $null
    $createAdminUnit = $false

    if (
        ($null -ne $AADCABreakGlass.adminUnit.id) -and
        ($AADCABreakGlass.adminUnit.id -notmatch '^00000000-') -and
        ($AADCABreakGlass.adminUnit.id -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$')
    ) {
        $createAdminUnit = $true
        $adminUnitObj = Get-MgBetaDirectoryAdministrativeUnit -AdministrativeUnitId $AADCABreakGlass.adminUnit.id -ErrorAction SilentlyContinue
    }
    elseif (
        ($null -ne $AADCABreakGlass.adminUnit.displayName) -and
        ($AADCABreakGlass.adminUnit.displayName -ne '')
    ) {
        $createAdminUnit = $true
        $adminUnitObj = Get-MgBetaDirectoryAdministrativeUnit -All -Filter "displayName eq '$($AADCABreakGlass.adminUnit.displayName)'" -ErrorAction SilentlyContinue
    }

    if ($null -ne $adminUnitObj) {
        Write-Output "Found existing Break Glass Administrative Unit :  $($adminUnitObj.displayName)"
    }
    elseif ($createAdminUnit) {
        $params = @{
            displayName                  = $AADCABreakGlass.adminUnit.displayName
            description                  = $AADCABreakGlass.adminUnit.description
            visibility                   = $AADCABreakGlass.adminUnit.visibility
            isMemberManagementRestricted = $AADCABreakGlass.adminUnit.isMemberManagementRestricted
        }
        $adminUnitObj = New-MgBetaDirectoryAdministrativeUnit -BodyParameter $params -ErrorAction Stop
        Write-Output "Created new Break Glass Administrative Unit: '$($adminUnitObj.displayName)' ($($adminUnitObj.Id))"
    }

    $groupObj = $null

    if (
        ($null -ne $AADCABreakGlass.group.id) -and
        ($AADCABreakGlass.group.id -notmatch '^00000000-') -and
        ($AADCABreakGlass.group.id -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$')
    ) {
        $groupObj = Get-MgGroup -GroupId $AADCABreakGlass.group.id -ErrorAction SilentlyContinue
    }
    elseif (
        ($null -ne $AADCABreakGlass.group.displayName) -and
        ($AADCABreakGlass.group.displayName -ne '')
    ) {
        $groupObj = Get-MgGroup -All -Filter "displayName eq '$($AADCABreakGlass.group.displayName)'"
    }
    else {
        Write-Error 'Defined Break Glass Group is incomplete'
        return
    }

    if ($null -eq $groupObj) {
        $groupObj = New-MgGroup -SecurityEnabled `
            -IsAssignableToRole `
            -MailEnabled:$false `
            -MailNickname $((Get-RandomPassword -lowerChars 3 -upperChars 3 -numbers 2 -symbols 0) + '-f') `
            -DisplayName $AADCABreakGlass.group.displayName `
            -Description $AADCABreakGlass.group.description
        Write-Output "Created new Break Glass Group: '$($groupObj.displayName)' ($($groupObj.Id))"
        if ($null -ne $adminUnitObj) {
            $params = @{
                "@odata.id" = "https://graph.microsoft.com/beta/groups/$($groupObj.Id)"
            }
            $null = New-MgBetaDirectoryAdministrativeUnitMemberByRef -AdministrativeUnitId $adminUnitObj.Id -BodyParameter $params
            Write-Output "   Added to Administrative Unit: '$($adminUnitObj.displayName)' ($($adminUnitObj.Id))"
        }
    }
    else {
        Write-Output "Found existing Break Glass Group               :  $($groupObj.displayName)"
    }

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
            $userId = $account.userPrincipalName
        }
        else {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account is incomplete"
            return
        }
        $userObj = Get-MgUser -UserId $userId -ErrorAction SilentlyContinue

        if ($null -eq $userObj) {
            $pos = $account.userPrincipalName.IndexOf('@')
            $userObj = New-MgUser `
                -UserPrincipalName $account.userPrincipalName `
                -DisplayName $account.displayName `
                -AccountEnabled:$false `
                -MailNickname $((Get-RandomPassword -lowerChars 3 -upperChars 3 -numbers 2 -symbols 0) + '-f') `
                -PasswordProfile @{
                Password                             = Get-RandomPassword -lowerChars 32 -upperChars 32 -numbers 32 -symbols 32
                ForceChangePasswordNextSignIn        = $true
                ForceChangePasswordNextSignInWithMfa = $true
            }
            $null = New-MgGroupMember -GroupId $groupObj.Id -DirectoryObjectId $userObj.Id

            $params = @{
                "@odata.type"    = '#microsoft.graph.unifiedRoleAssignment'
                RoleDefinitionId = '62e90394-69f5-4237-9190-012177145e10'   # Global Administrator
                PrincipalId      = $userObj.Id
                DirectoryScopeId = '/'
            }
            $null = New-MgRoleManagementDirectoryRoleAssignment -BodyParameter $params
            if ($null -ne $adminUnitObj) {
                $params = @{
                    "@odata.id" = "https://graph.microsoft.com/beta/users/$($userObj.Id)"
                }
                $null = New-MgBetaDirectoryAdministrativeUnitMemberByRef -AdministrativeUnitId $adminUnitObj.Id -BodyParameter $params
            }

            Write-Output ''
            Write-Output "Created new Break Glass Account:"
            Write-Output "   UPN             :  $($userObj.UserPrincipalName)"
            Write-Output "   Object ID       :  $($userObj.Id)"
            Write-Output "   Display Name    :  $($userObj.DisplayName)"
            Write-Output "   Directory Role  :  Global Administrator of tenant ID $TenantId"
            Write-Output "   Account Enabled :  Disabled. Please activate before use."
            Write-Output "   Password        :  Please reset the password to configure the account."
            if ($null -ne $adminUnitObj) {
                Write-Output "   Admin Unit      :  $($adminUnitObj.DisplayName)"
                if ($adminUnitObj.IsMemberManagementRestricted) {
                    Write-Output "                      HINT: Management Restriction requires temporary removal"
                    Write-Output "                            of the account from this administrative unit, for example,"
                    Write-Output "                            to activate the account and reset the original password."
                }
            }
        }
        else {
            Write-Output "Found existing Break Glass Account             :  $($userObj.UserPrincipalName)"
        }
    }
}
