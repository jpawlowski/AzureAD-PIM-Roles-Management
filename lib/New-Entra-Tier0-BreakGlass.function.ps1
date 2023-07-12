#Requires -Version 7.2
#Requires -Modules @{ ModuleName='Microsoft.Graph.Beta.Identity.DirectoryManagement'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Users'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Groups'; ModuleVersion='2.0' }

function New-Entra-Tier0-BreakGlass {
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'High'
    )]
    Param (
        $EntraCABreakGlass
    )
    $adminUnitObj = $null
    $createAdminUnit = $false

    if (
        ($null -ne $EntraCABreakGlass.adminUnit.id) -and
        ($EntraCABreakGlass.adminUnit.id -notmatch '^00000000-') -and
        ($EntraCABreakGlass.adminUnit.id -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$')
    ) {
        $createAdminUnit = $true
        $adminUnitObj = Get-MgBetaDirectoryAdministrativeUnit -AdministrativeUnitId $EntraCABreakGlass.adminUnit.id -ErrorAction SilentlyContinue
    }
    elseif (
        ($null -ne $EntraCABreakGlass.adminUnit.displayName) -and
        ($EntraCABreakGlass.adminUnit.displayName -ne '')
    ) {
        $createAdminUnit = $true
        $adminUnitObj = Get-MgBetaDirectoryAdministrativeUnit -All -Filter "displayName eq '$($EntraCABreakGlass.adminUnit.displayName)'" -ErrorAction SilentlyContinue
    }

    if ($null -ne $adminUnitObj) {
        Write-Information "Found existing Break Glass Administrative Unit :  $($adminUnitObj.displayName)"
    }
    elseif ($createAdminUnit) {
        $EntraCABreakGlass['adminUnit'].Remove('id')
        if ($PSCmdlet.ShouldProcess(
                "Create new Administrative Unit '$($EntraCABreakGlass.adminUnit.displayName)' to consolidate Break Glass objects",
                'Confirm creation of Administrative Unit?',
                "Administrative Unit: $($EntraCABreakGlass.adminUnit.displayName)"
            )) {
            $adminUnitObj = New-MgBetaDirectoryAdministrativeUnit -BodyParameter $EntraCABreakGlass.adminUnit -ErrorAction Stop -Confirm:$false
            Write-Output "Created new Break Glass Administrative Unit: '$($adminUnitObj.displayName)' ($($adminUnitObj.Id))"
        }
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
        $groupObj = Get-MgGroup -All -Filter "displayName eq '$($EntraCABreakGlass.group.displayName)'"
    }
    else {
        Write-Error 'Defined Break Glass Group is incomplete'
        return
    }

    if ($null -eq $groupObj) {
        if ($PSCmdlet.ShouldProcess(
                "Create new Break Glass Group '$($EntraCABreakGlass.group.displayName)' for Break Glass accounts",
                'Confirm creation of Break Glass Group?',
                "Break Glass Group: $($EntraCABreakGlass.group.displayName)"
            )) {
            $groupObj = New-MgGroup `
                -SecurityEnabled `
                -Visibility $EntraCABreakGlass.group.visibility `
                -IsAssignableToRole:$EntraCABreakGlass.group.isAssignableToRole `
                -MailEnabled:$false `
                -MailNickname $((Get-RandomPassword -lowerChars 3 -upperChars 3 -numbers 2 -symbols 0) + '-f') `
                -DisplayName $EntraCABreakGlass.group.displayName `
                -Description $EntraCABreakGlass.group.description `
                -ErrorAction Stop `
                -Confirm:$false
            Write-Output "Created new Break Glass Group: '$($groupObj.displayName)' ($($groupObj.Id))"
            if ($null -ne $adminUnitObj) {
                $params = @{
                    "@odata.id" = "https://graph.microsoft.com/beta/groups/$($groupObj.Id)"
                }
                $null = New-MgBetaDirectoryAdministrativeUnitMemberByRef -AdministrativeUnitId $adminUnitObj.Id -BodyParameter $params -ErrorAction Stop
                Write-Output "   Added to Administrative Unit: '$($adminUnitObj.displayName)' ($($adminUnitObj.Id))"
            }
        }
    }
    else {
        Write-Information "Found existing Break Glass Group               :  $($groupObj.displayName)"
    }
    $EntraCABreakGlass.group.id = $groupObj.Id

    $validBreakGlassCount = 0

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
            $userId = $account.userPrincipalName
        }
        else {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account is incomplete"
            return
        }
        $userObj = Get-MgUser -UserId $userId -ErrorAction SilentlyContinue

        if ($null -eq $userObj) {
            if ($PSCmdlet.ShouldProcess(
                    "Create new Break Glass Account '$($account.userPrincipalName)'",
                    'Confirm creation of new Break Glass Account?',
                    "Break Glass Account: $($account.userPrincipalName)"
                )) {
                $userObj = New-MgUser `
                    -UserPrincipalName $account.userPrincipalName `
                    -DisplayName $account.displayName `
                    -AccountEnabled:$false `
                    -MailNickname $((Get-RandomPassword -lowerChars 3 -upperChars 3 -numbers 2 -symbols 0) + '-f') `
                    -PasswordProfile @{
                    Password                             = Get-RandomPassword -lowerChars 32 -upperChars 32 -numbers 32 -symbols 32
                    ForceChangePasswordNextSignIn        = $true
                    ForceChangePasswordNextSignInWithMfa = $true
                } `
                    -ErrorAction Stop `
                    -Confirm:$false
                $null = New-MgGroupMember -GroupId $groupObj.Id -DirectoryObjectId $userObj.Id -ErrorAction Stop

                foreach ($RoleDefinitionId in $account.directoryRoles) {
                    $params = @{
                        "@odata.type"    = '#microsoft.graph.unifiedRoleAssignment'
                        RoleDefinitionId = $RoleDefinitionId
                        PrincipalId      = $userObj.Id
                        DirectoryScopeId = '/'
                    }
                    if ($PSCmdlet.ShouldProcess(
                            "Assign Microsoft Entra ID Role $($params.RoleDefinitionId)",
                            'Confirm assigning Microsoft Entra ID Role to Break Glass Account?',
                            "Microsoft Entra ID Role $($params.RoleDefinitionId) for $($account.userPrincipalName)"
                        )) {
                        $null = New-MgRoleManagementDirectoryRoleAssignment -BodyParameter $params -ErrorAction Stop -Confirm:$false
                    }
                }

                if ($null -ne $adminUnitObj) {
                    $params = @{
                        "@odata.id" = "https://graph.microsoft.com/beta/users/$($userObj.Id)"
                    }
                    $null = New-MgBetaDirectoryAdministrativeUnitMemberByRef -AdministrativeUnitId $adminUnitObj.Id -BodyParameter $params -ErrorAction Stop
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
        }
        else {
            Write-Information "Found existing Break Glass Account             :  $($userObj.UserPrincipalName)"
        }
        $account.id = $userObj.Id
        $validBreakGlassCount++
    }

    foreach ($caPolicy in $EntraCABreakGlass.caPolicies) {
        $caPolicyObj = $null
        $createCaPolicy = $false

        if (
            ($null -ne $caPolicy.id) -and
            ($caPolicy.id -notmatch '^00000000-') -and
            ($caPolicy.id -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$')
        ) {
            $createCaPolicy = $true
            $caPolicyObj = Get-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $caPolicy.id -ErrorAction SilentlyContinue
        }
        elseif (
            ($null -ne $caPolicy.displayName) -and
            ($caPolicy.displayName -ne '')
        ) {
            $createCaPolicy = $true
            $caPolicyObj = Get-MgIdentityConditionalAccessPolicy -All -Filter "displayName eq '$($caPolicy.displayName)'" -ErrorAction SilentlyContinue
        }

        if ($null -ne $caPolicyObj) {
            Write-Information "Found existing Break Glass Microsoft Entra CA Policy  :  $($caPolicyObj.displayName)"
        }
        elseif ($createCaPolicy) {
            $caPolicy.Remove('id')
            $caPolicy.Remove('description')   # not supported (yet)
            $caPolicy.state = 'enabledForReportingButNotEnforced'   # protect from accidential lockout during initial creation
            $caPolicy.conditions = @{
                applications = @{
                    includeApplications = @( 'All' )
                }
                users        = @{
                    includeUsers  = @()
                    excludeUsers  = @()
                    includeGroups = @()
                }
            }

            if ($null -ne $caPolicy.breakGlassIncludeUsers) {
                foreach ($item in $caPolicy.breakGlassIncludeUsers) {
                    if ($item -eq 'group') {
                        $caPolicy.conditions.users.includeGroups = @($groupObj.Id)
                    }
                    elseif ($item -eq 'primary') {
                        $caPolicy.conditions.users.includeUsers += $EntraCABreakGlass.accounts[0].id
                    }
                    elseif ($item -eq 'backup') {
                        $caPolicy.conditions.users.includeUsers += $EntraCABreakGlass.accounts[1].id
                    }
                }
                $caPolicy.Remove('breakGlassIncludeUsers')
            }
            if ($null -ne $caPolicy.breakGlassExcludeUsers) {
                foreach ($item in $caPolicy.breakGlassExcludeUsers) {
                    if ($item -eq 'group') {
                        $caPolicy.conditions.users.excludeGroups = @($groupObj.Id)
                    }
                    elseif ($item -eq 'primary') {
                        $caPolicy.conditions.users.excludeUsers += $EntraCABreakGlass.accounts[0].id
                    }
                    elseif ($item -eq 'backup') {
                        $caPolicy.conditions.users.excludeUsers += $EntraCABreakGlass.accounts[1].id
                    }
                }
                $caPolicy.Remove('breakGlassExcludeUsers')
            }

            if ($PSCmdlet.ShouldProcess(
                    "Create new Conditional Access Policy '$($caPolicy.displayName)' to protect Break Glass Accounts",
                    'Confirm creation of Conditional Access Policy?',
                    "Conditional Access Policy: $($caPolicy.displayName)"
                )) {
                $caPolicyObj = New-MgIdentityConditionalAccessPolicy -BodyParameter $caPolicy -ErrorAction Stop -Confirm:$false
                Write-Output "Created new Break Glass Microsoft Entra CA Policy     : '$($caPolicyObj.displayName)' ($($caPolicyObj.Id))"
            }
        }
    }
}
