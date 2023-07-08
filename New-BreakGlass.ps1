<#
.SYNOPSIS
    Create Break Glass accounts and Break Glass group for Azure AD
.DESCRIPTION
    This script creates Break Glass accounts and a Break Glass group.
    These can then be excluded in Azure AD Conditional Access policies to prevent lockout.

    Also see https://learn.microsoft.com/en-us/azure/active-directory/roles/security-emergency-access
#>
[CmdletBinding()]
Param (
    [Parameter(HelpMessage = "Azure AD tenant ID.")]
    [string]$TenantId,
    [Parameter(HelpMessage = "Folder path to configuration files in PS1 format. Default: './config/'.")]
    [string]$ConfigPath,
    [Parameter(HelpMessage = "Do not prompt for user interaction.")]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$LibFiles = @(
    'Common.functions.ps1'
    'Load.config.ps1'
)
foreach ($FileName in $LibFiles) {
    $FilePath = Join-Path $(Join-Path $PSScriptRoot 'lib') $FileName
    if (Test-Path -Path $FilePath -PathType Leaf) {
        try {
            . $FilePath
        }
        catch {
            Throw "Error loading file: $_"
        }
    }
    else {
        Throw "File not found: $FilePath"
    }
}

$title = 'Break Glass Account + Break Glass Group creation'
$message = 'Do you confirm to create new Break Glass Accounts and Break Glass Group if they are not existing?'
$result = $host.ui.PromptForChoice($title, $message, $choices, 1)
switch ($result) {
    0 {
        Write-Output ' Yes: Starting Break Glass creation now'
        Write-Output ''

        $MgScopes += 'User.ReadWrite.All'
        $MgScopes += 'Group.ReadWrite.All'
        $MgScopes += 'AdministrativeUnit.ReadWrite.All'
        $MgScopes += 'Directory.Write.Restricted'
        $MgScopes += 'RoleManagement.ReadWrite.Directory'

        ConnectMgGraph

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
                -MailNickname 'Break-Glass-Admin-Group' `
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
            Write-Output "Found existing Break Glass Group  :  $($groupObj.displayName)"
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
                $mailNickname = $account.userPrincipalName.Substring(0, $pos)
                $userObj = New-MgUser `
                    -UserPrincipalName $account.userPrincipalName `
                    -DisplayName $account.displayName `
                    -AccountEnabled:$false `
                    -MailNickname $mailNickname `
                    -PasswordProfile @{
                    Password                             = Get-RandomPassword
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
                Write-Output "   UPN             : $($userObj.UserPrincipalName)"
                Write-Output "   Object ID       : $($userObj.Id)"
                Write-Output "   Display Name    : $($userObj.DisplayName)"
                Write-Output "   Directory Role  : Global Administrator of tenant ID $TenantId"
                Write-Output "   Account Enabled : Disabled; Please activate before use"
                Write-Output "   Password        : Please reset the password to configure the account"
                if ($null -ne $adminUnitObj) {
                    Write-Output "   Admin Unit      : $($adminUnitObj.DisplayName)"
                    if ($adminUnitObj.IsMemberManagementRestricted) {
                        Write-Output "                     HINT: Management Restriction requires to temporarily"
                        Write-Output "                           remove the account from this Admin Unit, e.g. to"
                        Write-Output "                           enable the account and reset the initial password."
                    }
                }
            }
            else {
                Write-Output "Found existing Break Glass Account :  $($userObj.UserPrincipalName)"
            }
        }
    }
    * {
        Write-Output ' Aborting command.'
    }
}
