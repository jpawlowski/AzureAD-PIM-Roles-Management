<#
.SYNOPSIS

.DESCRIPTION

.LINK
    https://github.com/jpawlowski/AzureAD-PIM-Roles-Management

.NOTES
    Filename: New-Entra-Tier0-BreakGlass.function.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
#>
#Requires -Version 7.2
#Requires -Modules @{ ModuleName='Microsoft.Graph.Beta.Identity.DirectoryManagement'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Users'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Groups'; ModuleVersion='2.0' }

$MgScopes += 'AdministrativeUnit.Read.All'
$MgScopes += 'AdministrativeUnit.ReadWrite.All'
$MgScopes += 'Directory.Write.Restricted'
$MgScopes += 'User.Read.All'
$MgScopes += 'User.ReadWrite.All'
$MgScopes += 'Group.Read.All'
$MgScopes += 'Group.ReadWrite.All'
$MgScopes += 'RoleManagement.Read.All'
$MgScopes += 'RoleManagement.ReadWrite.Directory'
$MgScopes += 'Policy.Read.All'
$MgScopes += 'Policy.ReadWrite.ConditionalAccess'
$MgScopes += 'Application.Read.All'

function New-Entra-Tier0-BreakGlass {
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'High'
    )]
    [OutputType([Int])]
    Param (
        [hashtable]$Config
    )

    $params = @{
        Activity         = 'Break Glass Creation'
        Status           = " 0% Complete: Administrative Unit"
        PercentComplete  = 0
        CurrentOperation = 'BreakGlassCreation'
    }
    Write-Progress @params

    $adminUnitObj = $null
    $createAdminUnit = $false

    if (
        ($null -ne $Config.adminUnit.id) -and
        ($Config.adminUnit.id -notmatch '^00000000-') -and
        ($Config.adminUnit.id -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$')
    ) {
        $createAdminUnit = $true
        $adminUnitObj = Get-MgBetaDirectoryAdministrativeUnit -AdministrativeUnitId $Config.adminUnit.id -ErrorAction Stop
    }
    elseif (
        ($null -ne $Config.adminUnit.displayName) -and
        ($Config.adminUnit.displayName -ne '')
    ) {
        $createAdminUnit = $true
        $adminUnitObj = Get-MgBetaDirectoryAdministrativeUnit -All -Filter "displayName eq '$($Config.adminUnit.displayName)'" -ErrorAction Stop
    }

    if ($null -ne $adminUnitObj) {
        Write-Verbose "Found existing Break Glass Administrative Unit :  $($adminUnitObj.displayName)"
    }
    elseif ($createAdminUnit) {
        $Config['adminUnit'].Remove('id')
        if ($PSCmdlet.ShouldProcess(
                "Create new Administrative Unit '$($Config.adminUnit.displayName)' to consolidate Break Glass objects",
                'Confirm creation of Administrative Unit?',
                "Administrative Unit: $($Config.adminUnit.displayName)"
            )) {
            $adminUnitObj = New-MgBetaDirectoryAdministrativeUnit -BodyParameter $Config.adminUnit -ErrorAction Stop -Confirm:$false
            Write-Output "Created new Break Glass Administrative Unit: '$($adminUnitObj.displayName)' ($($adminUnitObj.Id))"
        }
    }

    $params = @{
        Activity         = 'Break Glass Creation'
        Status           = " 25% Complete: User Group"
        PercentComplete  = 25
        CurrentOperation = 'BreakGlassCreation'
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
    }
    else {
        Write-Error 'Defined Break Glass Group is incomplete'
        return
    }

    if ($null -eq $groupObj) {
        if ($PSCmdlet.ShouldProcess(
                "Create new Break Glass Group '$($Config.group.displayName)' for Break Glass accounts",
                'Confirm creation of Break Glass Group?',
                "Break Glass Group: $($Config.group.displayName)"
            )) {
            $groupObj = New-MgGroup `
                -SecurityEnabled `
                -Visibility $Config.group.visibility `
                -IsAssignableToRole:$Config.group.isAssignableToRole `
                -MailEnabled:$false `
                -MailNickname (New-Guid).Guid.Substring(0, 10) `
                -DisplayName $Config.group.displayName `
                -Description $Config.group.description `
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
        Write-Verbose "Found existing Break Glass Group               :  $($groupObj.displayName)"
    }
    $Config.group.id = $groupObj.Id

    $params = @{
        Activity         = 'Break Glass Creation'
        Status           = " 50% Complete: User Accounts"
        PercentComplete  = 50
        CurrentOperation = 'BreakGlassCreation'
    }
    Write-Progress @params

    $validBreakGlassCount = 0

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
            $userId = $account.userPrincipalName
        }
        else {
            Write-Error "$($validBreakGlassCount + 1). Break Glass Account is incomplete"
            return
        }
        $userObj = Get-MgUser -UserId $userId -ErrorAction Stop

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
                    -MailNickname (New-Guid).Guid.Substring(0, 10) `
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
                Write-Output "   Directory Role  :  Global Administrator of tenant ID $((Get-MgContext).TenantId)"
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
            Write-Verbose "Found existing Break Glass Account             :  $($userObj.UserPrincipalName)"
        }
        $account.id = $userObj.Id
        $validBreakGlassCount++
    }

    $params = @{
        Activity         = 'Break Glass Creation'
        Status           = " 75% Complete: Conditional Access Policies"
        PercentComplete  = 75
        CurrentOperation = 'BreakGlassCreation'
    }
    Write-Progress @params

    foreach ($caPolicy in $Config.caPolicies) {
        $caPolicyObj = $null
        $createCaPolicy = $false

        if (
            ($null -ne $caPolicy.id) -and
            ($caPolicy.id -notmatch '^00000000-') -and
            ($caPolicy.id -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$')
        ) {
            $createCaPolicy = $true
            $caPolicyObj = Get-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $caPolicy.id -ErrorAction Stop
        }
        elseif (
            ($null -ne $caPolicy.displayName) -and
            ($caPolicy.displayName -ne '')
        ) {
            $createCaPolicy = $true
            $caPolicyObj = Get-MgIdentityConditionalAccessPolicy -All -Filter "displayName eq '$($caPolicy.displayName)'" -ErrorAction Stop
        }

        if ($null -ne $caPolicyObj) {
            Write-Verbose "Found existing Break Glass CA Policy           :  $($caPolicyObj.displayName)"
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
                        $caPolicy.conditions.users.includeUsers += $Config.accounts[0].id
                    }
                    elseif ($item -eq 'backup') {
                        $caPolicy.conditions.users.includeUsers += $Config.accounts[1].id
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
                        $caPolicy.conditions.users.excludeUsers += $Config.accounts[0].id
                    }
                    elseif ($item -eq 'backup') {
                        $caPolicy.conditions.users.excludeUsers += $Config.accounts[1].id
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

    $params = @{
        Activity         = 'Break Glass Creation'
        Status           = " 100% Complete"
        PercentComplete  = 100
        CurrentOperation = 'BreakGlassCreation'
    }
    Write-Progress @params
}
