<#
.SYNOPSIS
    Create Break Glass accounts and Break Glass group for Azure AD
.DESCRIPTION
    This script creates or updates Break Glass accounts and a Break Glass group.
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

try {
    Import-Module -Name "Microsoft.Graph.Identity.SignIns" -MinimumVersion 2.0
    Import-Module -Name "Microsoft.Graph.Identity.Governance" -MinimumVersion 2.0
}
catch {
    Write-Error "Error loading Microsoft Graph API: $_"
}

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

        ConnectMgGraph

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
        }
        else {
            Write-Output "Found Existing Break Glass Group  : $($groupObj.displayName)"
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

                Write-Output ''
                Write-Output "Created new Break Glass Account:"
                Write-Output "   UPN             : $($userObj.UserPrincipalName)"
                Write-Output "   Object ID       : $($userObj.Id)"
                Write-Output "   Display Name    : $($userObj.DisplayName)"
                Write-Output "   Directory Role  : Global Administrator of tenant ID $TenantId"
                Write-Output "   Account Enabled : Disabled; Please activate before use"
                Write-Output "   Password        : Please reset the password to configure the account"
            }
            else {
                Write-Output "Found Existing Break Glass Account: $($userObj.UserPrincipalName)"
            }
        }
    }
    * {
        Write-Output ' Aborting command.'
    }
}
