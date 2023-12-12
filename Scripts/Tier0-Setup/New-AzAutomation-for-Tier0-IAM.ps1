<#
.SYNOPSIS
    Create a new Azure Automation Account including Managed Identity for IAM automations in Tier 0 environment

.DESCRIPTION
    Create a new Azure Automation Account including Managed Identity for IAM automations in Tier 0 environment

.PARAMETER TenantId
    Tenant ID

.PARAMETER Subscription
    Subscription Name

.PARAMETER ResourceGroupName
    ResourceGroupName

.PARAMETER Name
    Name

.PARAMETER Location
    Location

.PARAMETER Plan
    Plan, defaults to Basic

.PARAMETER Tags
    Tags

.PARAMETER DirectoryScopeID
    Scope ID to limit access for Microsoft Entra roles, e.g. '/administrativeUnits/2c7399f0-42dd-40de-b20b-b986ab85045c'

.NOTES
    Filename: New-AzAutomation-for-Tier0-IAM.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
    Version: 1.2
#>
#Requires -Version 5.1
#Requires -Modules @{ ModuleName='Az.Accounts'; ModuleVersion='2.12' }
#Requires -Modules @{ ModuleName='Az.Automation'; ModuleVersion='1.9' }
#Requires -Modules @{ ModuleName='Az.Resources'; ModuleVersion='6.8' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Authentication'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Identity.SignIns'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Identity.Governance'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Applications'; ModuleVersion='2.0' }

[CmdletBinding(
    SupportsShouldProcess,
    ConfirmImpact = 'High'
)]
Param (
    [Parameter(Position = 0, mandatory = $true)]
    [string]$TenantId,
    [Parameter(Position = 1, mandatory = $true)]
    [string]$Subscription,
    [Parameter(Position = 2, mandatory = $true)]
    [string]$ResourceGroupName,
    [Parameter(Position = 3, mandatory = $true)]
    [string]$Name,
    [Parameter(Position = 4, mandatory = $true)]
    [string]$Location,
    [string]$Plan = 'Basic',
    [System.Collections.Generic.Dictionary[string, object]]$Tags,
    [string]$DirectoryScopeID = '/administrativeUnits/2c7399f0-42dd-40de-b20b-b986ab85045c'
)

if ("AzureAutomation/" -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
    Throw 'This script must be run interactively by a privileged administrator account.'
}

if (
    (-Not (Get-AzContext)) -or
    ($TenantId -ne (Get-AzContext).Tenant)
) {
    Connect-AzAccount `
        -TenantId $TenantId `
        -Subscription $Subscription `
        -Scope Process `
        -Verbose:$Verbose
}
elseif (
    ($Subscription -ne (Get-AzContext).Subscription.Name) -and
    ($Subscription -ne (Get-AzContext).Subscription.Id)
) {
    Set-AzContext -Subscription $Subscription -WarningAction SilentlyContinue
}

$automationAccount = Get-AzAutomationAccount `
    -ResourceGroupName $ResourceGroupName `
    -Name $Name `
    -ErrorAction SilentlyContinue

if (-Not $automationAccount) {
    if ($PSCmdlet.ShouldProcess(
            "Create Azure Automation Account $($Name)",
            "Do you confirm to create new Azure Automation Account $($Name) ?",
            'Create new Azure Automation Account'
        )) {

        $Params = @{
            ResourceGroupName = $ResourceGroupName
            Name              = $Name
            Location          = $Location
        }
        if ($Plan) { $Params.Plan = $Plan }
        if ($Verbose) { $Params.Verbose = $Verbose }
        $automationAccount = New-AzAutomationAccount @Params
    }
    elseif ($WhatIfPreference) {
        Write-Verbose 'What If: A new Azure Automation account would have been created.'
    }
    else {
        Write-Verbose 'Creation of new Azure Automation account was aborted.'
        exit
    }
}

if ($PSCmdlet.ShouldProcess(
        "Install PowerShell Modules in $($automationAccount.AutomationAccountName)",
        "Do you confirm to install desired PowerShell Modules in $($automationAccount.AutomationAccountName) ?",
        'Install PowerShell Modules in Azure Automation Account'
    )) {

    $PSGalleryModules = @(
        @{
            ModuleName    = 'PackageManagement'
            ModuleVersion = '1.4.8.1'
        }
        @{
            ModuleName    = 'PowerShellGet'
            ModuleVersion = '2.2.5'
        }
        @{
            ModuleName    = 'Microsoft.Graph.Authentication'
            ModuleVersion = '2.0'
        }
        @{
            ModuleName    = 'Microsoft.Graph.Identity.SignIns'
            ModuleVersion = '2.0'
        }
        @{
            ModuleName    = 'Microsoft.Graph.Users'
            ModuleVersion = '2.0'
        }
        @{
            ModuleName    = 'Microsoft.Graph.Users.Actions'
            ModuleVersion = '2.0'
        }
        @{
            ModuleName    = 'Microsoft.Graph.Users.Functions'
            ModuleVersion = '2.0'
        }
        @{
            ModuleName    = 'ExchangeOnlineManagement'
            ModuleVersion = '3.0'
        }
    )

    foreach ($Module in $PSGalleryModules) {
        $AzPSModule = Get-AzAutomationModule `
            -ResourceGroupName $ResourceGroupName `
            -AutomationAccountName $automationAccount.AutomationAccountName `
            -Name $Module.ModuleName

        if (
                (-Not $AzPSModule) -or
                ($AzPSModule.ProvisioningState -eq 'Failed') -or
            (
                $Module.ModuleVersion -and
                ([System.Version]$AzPSModule.ModuleVersion -lt [System.Version]$Module.ModuleVersion) -and
                $AzPSModule.ProvisioningState -ne 'Creating'
            )
        ) {
            Write-Output "   Installing: $($Module.ModuleName)"
            $null = New-AzAutomationModule `
                -ResourceGroupName $automationAccount.ResourceGroupName `
                -AutomationAccountName $automationAccount.AutomationAccountName `
                -Name $Module.ModuleName `
                -ContentLinkUri "https://www.powershellgallery.com/api/v2/package/$($Module.ModuleName)"
        }
        else {
            Write-Output "   Installed: $($Module.ModuleName)"
        }
    }
}
elseif ($WhatIfPreference) {
    Write-Verbose 'What If: PowerShell modules would have been installed.'
}
else {
    Write-Verbose 'Installation of PowerShell modules was denied.'
}

if (-Not $automationAccount.Identity) {
    if ($PSCmdlet.ShouldProcess(
            "Enable System-Assigned Managed Identity for $($automationAccount.AutomationAccountName)",
            "Do you confirm to enable a system-assigned Managed Identity for $($automationAccount.AutomationAccountName) ?",
            'Enable System-Assigned Managed Identity for Azure Automation Account'
        )) {
        $automationAccount = Set-AzAutomationAccount `
            -ResourceGroupName $automationAccount.ResourceGroupName `
            -Name $automationAccount.AutomationAccountName `
            -AssignSystemIdentity
    }
    elseif ($WhatIfPreference) {
        Write-Verbose 'What If: System-Assigned Managed Identity would have been enabled.'
    }
    else {
        Write-Verbose 'Enablement of System-Assigned Managed Identity was aborted.'
        exit
    }
}

if ($PSCmdlet.ShouldProcess(
        "Assign app permissions to System-Assigned Managed Identity of $($automationAccount.AutomationAccountName)",
        "Do you confirm to assign desired permissions to apps for $($automationAccount.AutomationAccountName) ?",
        'Assign app permissions to System-Assigned Managed Identity of Azure Automation Account'
    )) {

    $MgScopes = @(
        'Application.ReadWrite.All'
        'Directory.ReadWrite.All'
        'AppRoleAssignment.ReadWrite.All'
        'RoleManagement.ReadWrite.Directory'
    )
    $MissingMgScopes = @()

    foreach ($MgScope in $MgScopes) {
        if ($WhatIfPreference -and ($MgScope -like '*Write*')) {
            Write-Verbose "WhatIf: Removed $MgScope from required Microsoft Graph scopes"
        }
    }

    if (-Not (Get-MgContext)) {
        Connect-MgGraph `
            -Scopes $MgScopes `
            -ContextScope Process `
            -Verbose:$Verbose
    }

    foreach ($MgScope in $MgScopes) {
        if ($MgScope -notin @((Get-MgContext).Scopes)) {
            $MissingMgScopes += $MgScope
        }
    }

    if ($MissingMgScopes) {
        Throw "Missing Microsoft Graph authorization scopes:`n`n$($MissingMgScopes -join "`n")"
    }

    $ManagedIdentity = Get-MgServicePrincipal -ConsistencyLevel eventual -Filter "ServicePrincipalType eq 'ManagedIdentity' and DisplayName eq '$Name'"

    $AppPermissions = @{
        # Microsoft Graph
        '00000003-0000-0000-c000-000000000000' = @{
            # Oauth2PermissionScopes = @{
            #     Admin             = @(
            #     )
            #     '<User-ObjectId>' = @(
            #     )
            # }
            AppRoles = @(
                'Directory.Read.All'
                'Directory.ReadWrite.All'
                'Mail.Send'
                'OnPremDirectorySynchronization.Read.All'
                'Organization.Read.All'
                'Policy.Read.All'
                'RoleManagement.ReadWrite.Directory'
                'User.Read.All'
                'User.ReadWrite.All'
                'UserAuthenticationMethod.Read.All'
                'UserAuthenticationMethod.ReadWrite.All'
            )
        }

        # Office 365 Exchange Online
        '00000002-0000-0ff1-ce00-000000000000' = @{
            Oauth2PermissionScopes = @{
                Admin = @(
                    'Organization.Read.All'
                    'User.Read.All'
                )
                # '<User-ObjectId>' = @(
                # )
            }
            AppRoles               = @(
                'Exchange.ManageAsApp'
                'full_access_as_app'
                'MailboxSettings.ReadWrite'
                'Organization.Read.All'
                'User.Read.All'
            )
        }
    }

    $AppPermissions.GetEnumerator() | ForEach-Object {
        $ServicePrincipal = $null
        if ($_.key -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$') {
            $ServicePrincipal = Get-MgServicePrincipal -ConsistencyLevel eventual -Filter "ServicePrincipalType eq 'Application' and appId eq '$($_.key)'"
        }
        else {
            $ServicePrincipal = Get-MgServicePrincipal -ConsistencyLevel eventual -Filter "ServicePrincipalType eq 'Application' DisplayName eq '$($_.key)'"
        }
        Write-Output "   $($ServicePrincipal.DisplayName)"
        $PermissionGrants = Get-MgOauth2PermissionGrant -All -Filter "ClientId eq '$($ManagedIdentity.Id)' and ResourceId eq '$($ServicePrincipal.Id)'"
        $AppRoleAssignments = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ManagedIdentity.Id | Where-Object ResourceId -eq $ServicePrincipal.Id

        $Permissions = $_.Value
        $Permissions.GetEnumerator() | ForEach-Object {
            $Permission = $_.value

            if ($_.Key -eq 'Oauth2PermissionScopes') {
                Write-Output "      Delegated"

                $_.Value.GetEnumerator() | ForEach-Object {
                    $ClientId = $ManagedIdentity.Id
                    $ResourceId = $ServicePrincipal.Id
                    $PrincipalId = $_.Key
                    $ConsentType = if ($PrincipalId -eq 'Admin') { 'AllPrincipals' } else { 'Principal' }
                    Write-Output "         ${PrincipalId}:"

                    $scopes = @()
                    foreach ($Permission in ($_.Value | Select-Object -Unique | Sort-Object)) {
                        $OAuth2Permission = $ServicePrincipal.Oauth2PermissionScopes | Where-Object { $_.Value -eq $Permission }
                        if ($null -eq $OAuth2Permission) {
                            Write-Error "$($ServicePrincipal.DisplayName): No OAuth Permission found with name $Permission"
                        }
                        else {
                            Write-Output "            $($OAuth2Permission.Value)`n               ($(if ($PrincipalId -eq 'Admin') { $OAuth2Permission.AdminConsentDisplayName } else { $OAuth2Permission.UserConsentDisplayName }))"
                            $scopes += $OAuth2Permission.Value
                        }
                    }

                    if ($scopes.Count -gt 0) {
                        $PermissionGrant = $PermissionGrants | Where-Object ConsentType -eq $ConsentType
                        if ($ConsentType -eq 'Principal') {
                            $PermissionGrant = $PermissionGrant | Where-Object PrincipalId -eq $PrincipalId
                        }
                        if ($PermissionGrant) {
                            $params = @{
                                Scope = $scopes -join ' '
                            }
                            Update-MgOauth2PermissionGrant -OAuth2PermissionGrantId $PermissionGrant.Id -BodyParameter $params
                        }
                        else {
                            $params = @{
                                ClientId    = $ClientId
                                ConsentType = $ConsentType
                                ResourceId  = $ResourceId
                                Scope       = $scopes -join ' '
                            }
                            if ($PrincipalId -ne 'Admin') {
                                $params.PrincipalId = $PrincipalId
                            }
                            New-MgOauth2PermissionGrant -BodyParameter $params
                        }
                    }
                }
            }

            if ($_.Key -eq 'AppRoles') {
                Write-Output "      Application"

                foreach ($Permission in ($_.Value | Select-Object -Unique | Sort-Object)) {
                    $AppRole = $ServicePrincipal.AppRoles | Where-Object { $_.Value -eq $Permission }
                    if ($null -eq $AppRole) {
                        Write-Error "$($ServicePrincipal.DisplayName): No App Role found with name $Permission"
                    }
                    else {
                        Write-Output "         $($AppRole.Value)`n            ($($AppRole.DisplayName))"
                    }

                    if (-Not ($AppRoleAssignments | Where-Object AppRoleId -eq $AppRole.Id)) {
                        $params = @{
                            PrincipalId = $ManagedIdentity.Id
                            ResourceId  = $ServicePrincipal.Id
                            AppRoleId   = $AppRole.Id
                        }
                        $null = New-MgServicePrincipalAppRoleAssignment `
                            -ServicePrincipalId $ManagedIdentity.Id `
                            -BodyParameter $params
                    }
                }
            }
        }
    }
}
elseif ($WhatIfPreference) {
    Write-Verbose 'What If: App permissions would have been assigned.'
}
else {
    Write-Verbose 'Assignment of app permissions was denied.'
}

if ($PSCmdlet.ShouldProcess(
        "Assign desired Microsoft Entra roles to System-Assigned Managed Identity of $($automationAccount.AutomationAccountName)",
        "Do you confirm to assign desired Microsoft Entra roles to $($automationAccount.AutomationAccountName) ?",
        'Assign Microsoft Entra roles to System-Assigned Managed Identity of Azure Automation Account'
    )) {

    $EntraRoles = @(
        @{
            DisplayName      = 'Authentication Administrator'
            RoleDefinitionId = 'c4e39bd9-1100-46d3-8c65-fb160da0071f'
            DirectoryScopeId = $DirectoryScopeID
        }
        @{
            DisplayName      = 'Privileged Authentication Administrator'
            RoleDefinitionId = '7be44c8a-adaf-4e2a-84d6-ab2649e08a13'
        }
        @{
            DisplayName      = 'Privileged Role Administrator'
            RoleDefinitionId = 'e8611ab8-c189-46e8-94e1-60213ab1f814'
        }
        @{
            DisplayName      = 'Exchange Recipient Administrator'
            RoleDefinitionId = '31392ffb-586c-42d1-9346-e59415a2cc4e'
        }
        @{
            DisplayName      = 'User Administrator'
            RoleDefinitionId = 'fe930be7-5e62-47db-91af-98c3a49a38b1'
            DirectoryScopeId = $DirectoryScopeID
        }
        @{
            DisplayName      = 'Global Reader'
            RoleDefinitionId = 'f2ef992c-3afb-46b9-b7cf-a126ee74c451'
        }
    )

    foreach ($Role in $EntraRoles) {
        $params = @{
            PrincipalId      = $automationAccount.Identity.PrincipalId
            RoleDefinitionId = $Role.RoleDefinitionId
            Justification    = 'Automate Tier0 IAM tasks with PowerShell'
            DirectoryScopeId = '/'
            Action           = 'AdminAssign'
            scheduleInfo     = @{
                startDateTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                expiration    = @{
                    type = 'NoExpiration'
                }
            }
        }
        if ($Role.DirectoryScopeId) { $params.DirectoryScopeId = $Role.DirectoryScopeId }
        Write-Output "   Assigning: $($Role.RoleDefinitionId) ($($Role.DisplayName))"
        New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest `
            -BodyParameter $params `
            -ErrorAction SilentlyContinue
    }
}
elseif ($WhatIfPreference) {
    Write-Verbose 'What If: Microsoft Entra roles would have been assigned.'
}
else {
    Write-Verbose 'Assignment of Microsoft Entra roles was denied.'
}
