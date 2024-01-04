<#PSScriptInfo
.VERSION 1.3.1
.GUID cf9c08b9-1649-46b4-89ca-23f58831782d
.AUTHOR Julian Pawlowski
.COMPANYNAME Workoho GmbH
.COPYRIGHT (c) 2024 Workoho GmbH. All rights reserved.
.TAGS
.LICENSEURI
.PROJECTURI
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>

<#
.SYNOPSIS
    Create a new Azure Automation Account including System-Assigned Managed Identity for IAM automations in Tier 0 environment

.DESCRIPTION
    Create a new Azure Automation Account including System-Assigned Managed Identity for IAM automations in Tier 0 environment

.PARAMETER TenantId
    Tenant ID

.PARAMETER Subscription
    Subscription Name

.PARAMETER ResourceGroupName
    ResourceGroupName

.PARAMETER Name
    Name

.PARAMETER Location
    Azure Location

.PARAMETER CloudAdministrationRestrictedAdminUnit
    Display name of the restricted management administrative unit that contains Tiering groups.

.PARAMETER CloudAdministratorsAdminUnit
    Display name of the administrative unit where the managed identity should have User Administrator role permissions to create and update dedicated Cloud Admin accounts.

.PARAMETER Plan
    Plan, defaults to Free, may upgrade to Basic

.PARAMETER Runbooks
    Path to a folder with runbooks to upload.
#>

#Requires -Version 5.1
#Requires -Modules @{ ModuleName='Az.Accounts'; ModuleVersion='2.8' }
#Requires -Modules @{ ModuleName='Az.Automation'; ModuleVersion='1.7' }
#Requires -Modules @{ ModuleName='Az.Resources'; ModuleVersion='6.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Authentication'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Identity.SignIns'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Identity.Governance'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Applications'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Beta.Applications'; ModuleVersion='2.0' }

[CmdletBinding(
    SupportsShouldProcess,
    ConfirmImpact = 'High'
)]
Param (
    [Parameter(mandatory = $true)]
    [string]$TenantId,

    [Parameter(mandatory = $true)]
    [string]$Subscription,

    [Parameter(mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(mandatory = $true)]
    [string]$Name,

    [Parameter(mandatory = $true)]
    [string]$Location,

    [Parameter(mandatory = $true)]
    [string]$CloudAdministrationRestrictedAdminUnit,

    [string]$CloudAdministratorsAdminUnit,
    [string]$Plan,
    [Array]$Runbooks = (Join-Path (Get-Item $MyInvocation.MyCommand).Directory 'Runbooks')
)

if ("AzureAutomation/" -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
    Throw 'This script must be run interactively by a privileged administrator account.'
}

$MgScopes = @(
    'AdministrativeUnit.Read.All'
    'AdministrativeUnit.ReadWrite.All'
    'Application.Read.All'
    'Application.ReadWrite.All'
    'Directory.Read.All'
    'Directory.ReadWrite.All'
    'Directory.Write.Restricted'
    'AppRoleAssignment.Read.All'
    'AppRoleAssignment.ReadWrite.All'
    'RoleManagement.Read.Directory'
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

$CloudAdminRestrictedAdminUnit = Get-MgBetaAdministrativeUnit -All -ConsistencyLevel eventual -Filter "DisplayName eq '$($CloudAdministrationRestrictedAdminUnit)'"

if (-Not $CloudAdminRestrictedAdminUnit) {
    if ($PSCmdlet.ShouldProcess(
            "Create Restricted Management Administrative Unit in Microsoft Entra",
            "Do you confirm to create Restricted Management Administrative Unit ?",
            'Create Restricted Management Administrative Unit in Microsoft Entra'
        )) {

        $params = @{
            DisplayName                  = $CloudAdministrationRestrictedAdminUnit
            Visibility                   = 'HiddenMembership'
            IsMemberManagementRestricted = $true
        }
        $CloudAdminRestrictedAdminUnit = New-MgBetaAdministrativeUnit @params

    }
    elseif ($WhatIfPreference) {
        Write-Verbose 'What If: Restricted Management Administrative Unit would have been created in Microsoft Entra.'
    }
    else {
        Write-Verbose 'Creation of Restricted Management Administrative Unit in Microsoft Entra was denied.'
    }
}

if (-Not $CloudAdminRestrictedAdminUnit.IsMemberManagementRestricted) {
    Throw "Admin Unit '$($CloudAdminRestrictedAdminUnit.DisplayName)' must be management restricted."
}

if (-Not $CloudAdminRestrictedAdminUnit.Visibility -or ($CloudAdminRestrictedAdminUnit.Visibility -ne 'HiddenMembership')) {
    Throw "Admin Unit '$($CloudAdminRestrictedAdminUnit.DisplayName)' visibility must be HiddenMembership."
}

$CloudAdminsAdminUnit = $null
if ($CloudAdministratorsAdminUnit) {
    $CloudAdminsAdminUnit = Get-MgBetaAdministrativeUnit -All -ConsistencyLevel eventual -Filter "DisplayName eq '$($CloudAdministratorsAdminUnit)'"

    if (-Not $CloudAdminsAdminUnit) {
        if ($PSCmdlet.ShouldProcess(
                "Create Cloud Admin Accounts Administrative Unit in Microsoft Entra",
                "Do you confirm to create Cloud Admin Accounts Administrative Unit ?",
                'Create Cloud Admin Accounts Administrative Unit in Microsoft Entra'
            )) {

            $params = @{
                DisplayName                  = $CloudAdministratorsAdminUnit
            }
            $CloudAdminsAdminUnit = New-MgBetaAdministrativeUnit @params

        }
        elseif ($WhatIfPreference) {
            Write-Verbose 'What If: Cloud Admin Accounts Administrative Unit would have been created in Microsoft Entra.'
        }
        else {
            Write-Verbose 'Creation of Cloud Admin Accounts Administrative Unit in Microsoft Entra was denied.'
        }
    }
}

try {
    if (
        (-Not (Get-AzContext)) -or
        ($TenantId -ne (Get-AzContext).Tenant)
    ) {
        Connect-AzAccount `
            -TenantId $TenantId `
            -Subscription $Subscription `
            -Scope Process `
            -Verbose:$Verbose `
            -ErrorAction Stop
    }
    elseif (
        ($Subscription -ne (Get-AzContext).Subscription.Name) -and
        ($Subscription -ne (Get-AzContext).Subscription.Id)
    ) {
        Set-AzContext -Subscription $Subscription -WarningAction SilentlyContinue -ErrorAction Stop
    }
}
catch {
    Throw $_
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
        "Set Automation Variables in $(..AutomationAccountName)",
        "Do you confirm to set Automation Variables in $($automationAccount.AutomationAccountName) ?",
        'Set Automation Variables in Azure Automation Account'
    )) {

    $Variables = @(
        @{
            Name  = 'AV_CloudAdmin_RestrictedAdminUnitId'
            Value = [String]''
        }
        @{
            Name  = 'AV_CloudAdmin_AccountTypeExtensionAttribute'
            Value = [String]'15'
        }
        @{
            Name  = 'AV_CloudAdmin_AccountTypeEmployeeType'
            Value = [boolean]$true
        }
        @{
            Name  = 'AV_CloudAdmin_ReferenceExtensionAttribute'
            Value = [String]'14'
        }
        @{
            Name  = 'AV_CloudAdmin_ReferenceManager'
            Value = [boolean]$false
        }
        @{
            Name  = 'AV_CloudAdmin_Webhook'
            Value = [String]''
        }
        @{
            Name  = 'AV_CloudAdminTier0_LicenseSkuPartNumber'
            Value = [String]'EXCHANGEDESKLESS'
        }
        @{
            Name  = 'AV_CloudAdminTier0_UserPhotoUrl'
            Value = [String]''
        }
        @{
            Name  = 'AV_CloudAdminTier0_GroupId'
            Value = [String]''
        }
        @{
            Name  = 'AV_CloudAdminTier1_GroupId'
            Value = [String]''
        }
        @{
            Name  = 'AV_CloudAdminTier2_GroupId'
            Value = [String]''
        }
        @{
            Name  = 'AV_CloudAdminTier0_DedicatedAccount'
            Value = [Boolean]$true
        }
        @{
            Name  = 'AV_CloudAdminTier1_DedicatedAccount'
            Value = [Boolean]$false
        }
        @{
            Name  = 'AV_CloudAdminTier2_DedicatedAccount'
            Value = [Boolean]$false
        }
    )

    $SetVariables = Get-AzAutomationVariable `
        -ResourceGroupName $automationAccount.ResourceGroupName `
        -AutomationAccountName $automationAccount.AutomationAccountName `
        -ErrorAction SilentlyContinue

    foreach ($Variable in ($Variables | Sort-Object Name)) {
        Write-Output "   $($Variable.Name)"

        $SetVariable = $SetVariables | Where-Object Name -eq $Variable.Name
        if ($SetVariable) {
            if ($SetVariable.Value.PSObject.TypeNames[0] -ne $Variable.Value.PSObject.TypeNames[0]) {
                Write-Error $($Variable.Name + ': Variable type missmatch: Should be ' + $Variable.Value.PSObject.TypeNames[0] + ', not ' + $SetVariable.Value.PSObject.TypeNames[0])
            }
            continue
        }

        $Params = @{
            ResourceGroupName     = $automationAccount.ResourceGroupName
            AutomationAccountName = $automationAccount.AutomationAccountName
            Name                  = $Variable.Name
            Value                 = $Variable.Value
        }

        if ($Variable.Description) { $Params.Description = $Variable.Description }
        $Params.Encrypted = if ($Variable.Encrypted) { $Variable.Encrypted } else { $False }
        $null = New-AzAutomationVariable @Params
    }
}
elseif ($WhatIfPreference) {
    Write-Verbose 'What If: Automation Variables would have been set.'
}
else {
    Write-Verbose 'Setting of Automation Variables was denied.'
}

if ($PSCmdlet.ShouldProcess(
        "Install PowerShell Modules in $($automationAccount.AutomationAccountName)",
        "Do you confirm to install desired PowerShell Modules in $($automationAccount.AutomationAccountName) ?",
        'Install PowerShell Modules in Azure Automation Account'
    )) {

    $PSGalleryModules = @(
        @{
            Name    = 'PackageManagement'
            Version = '1.4.8.1'
        }
        @{
            Name    = 'PowerShellGet'
            Version = '2.2.5'
        }
        @{
            Name    = 'Microsoft.Graph.Authentication'
            Version = '2.0'
        }
        @{
            Name    = 'Microsoft.Graph.Identity.SignIns'
            Version = '2.0'
        }
        @{
            Name    = 'Microsoft.Graph.Identity.DirectoryManagement'
            Version = '2.0'
        }
        @{
            Name    = 'Microsoft.Graph.Users'
            Version = '2.0'
        }
        @{
            Name    = 'Microsoft.Graph.Users.Actions'
            Version = '2.0'
        }
        @{
            Name    = 'Microsoft.Graph.Users.Functions'
            Version = '2.0'
        }
        @{
            Name    = 'Microsoft.Graph.Groups'
            Version = '2.0'
        }
        @{
            Name    = 'Microsoft.Graph.Applications'
            Version = '2.0'
        }
        @{
            Name    = 'Microsoft.Graph.Beta.Identity.SignIns'
            Version = '2.0'
        }
        @{
            Name    = 'Microsoft.Graph.Beta.Identity.DirectoryManagement'
            Version = '2.0'
        }
        @{
            Name    = 'Microsoft.Graph.Beta.Users'
            Version = '2.0'
        }
        @{
            Name    = 'Microsoft.Graph.Beta.Users.Actions'
            Version = '2.0'
        }
        @{
            Name    = 'Microsoft.Graph.Beta.Users.Functions'
            Version = '2.0'
        }
        @{
            Name    = 'Microsoft.Graph.Beta.Groups'
            Version = '2.0'
        }
        @{
            Name    = 'Microsoft.Graph.Beta.Applications'
            Version = '2.0'
        }
        @{
            Name    = 'ExchangeOnlineManagement'
            Version = '3.0'
        }
    )

    $AzPSModules = Get-AzAutomationModule `
        -ResourceGroupName $ResourceGroupName `
        -AutomationAccountName $automationAccount.AutomationAccountName

    foreach ($Module in $PSGalleryModules) {
        $AzPSModule = $AzPSModules | Where-Object Name -eq $Module.Name

        if (
                (-Not $AzPSModule) -or
                ($AzPSModule.ProvisioningState -eq 'Failed') -or
            (
                $Module.Version -and
                ([System.Version]$AzPSModule.Version -lt [System.Version]$Module.Version) -and
                $AzPSModule.ProvisioningState -ne 'Creating' -and
                $AzPSModule.ProvisioningState -ne 'Succeeded'
            )
        ) {
            Write-Output "   Creating : $($Module.Name)"
            $null = New-AzAutomationModule `
                -ResourceGroupName $automationAccount.ResourceGroupName `
                -AutomationAccountName $automationAccount.AutomationAccountName `
                -Name $Module.Name `
                -ContentLinkUri "https://www.powershellgallery.com/api/v2/package/$($Module.Name)"
        }
        else {
            Write-Output "   Succeeded: $($Module.Name)"
        }
    }
}
elseif ($WhatIfPreference) {
    Write-Verbose 'What If: PowerShell modules would have been installed.'
}
else {
    Write-Verbose 'Installation of PowerShell modules was denied.'
}

if ($PSCmdlet.ShouldProcess(
        "Upload runbooks to in $($automationAccount.AutomationAccountName)",
        "Do you confirm to upload runbooks to $($automationAccount.AutomationAccountName) ?",
        'Upload runbooks to Azure Automation Account'
    )) {

    $ExistingRunbooks = Get-AzAutomationRunbook `
        -ResourceGroupName $ResourceGroupName `
        -AutomationAccountName $automationAccount.AutomationAccountName

    $Files = Get-ChildItem $Runbooks -File -Filter *.ps1 -Depth 0 -ErrorAction SilentlyContinue

    Write-Output "   Common runbooks:"
    foreach ($File in $Files | Where-Object Name -match '^Common_[0-9]+__' | Sort-Object -Property Name) {
        $ExistingRunbook = $ExistingRunbooks | Where-Object Name -eq $File.BaseName
        $Params = @{
            ResourceGroupName     = $ResourceGroupName
            AutomationAccountName = $automationAccount.AutomationAccountName
            Name                  = $File.BaseName
            Type                  = 'PowerShell'
            Path                  = $File
        }

        if ($ExistingRunbook) {
            Write-Output "      (Update) $($File.Name)"
            $Params.Force = $true
            $Params.Publish = $true
        }
        else {
            Write-Output "      (New) $($File.Name)"
            $Params.Publish = $true
        }

        $null = Import-AzAutomationRunbook @Params
        Start-Sleep -Seconds 5
    }

    Write-Output "   Runbooks:"
    foreach ($File in $Files | Where-Object Name -notmatch '^Common_[0-9]+__' | Sort-Object -Property Name) {
        $ExistingRunbook = $ExistingRunbooks | Where-Object Name -eq $File.BaseName
        $Params = @{
            ResourceGroupName     = $ResourceGroupName
            AutomationAccountName = $automationAccount.AutomationAccountName
            Name                  = $File.BaseName
            Type                  = 'PowerShell'
            Path                  = $File
        }

        if ($ExistingRunbook) {
            Write-Output "      (Update) $($File.Name)"
            $Params.Force = $true
            $Params.Publish = $true
        }
        else {
            Write-Output "      (New) $($File.Name)"
            $Params.Publish = $true
        }

        $null = Import-AzAutomationRunbook @Params
        Start-Sleep -Seconds 5
    }
}
elseif ($WhatIfPreference) {
    Write-Verbose 'What If: Runbooks would have been uploaded.'
}
else {
    Write-Verbose 'Runbook upload was denied.'
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
    }
}

if ($automationAccount.Identity.PrincipalId) {
    if ($PSCmdlet.ShouldProcess(
            "Assign Azure Roles to System-Assigned Managed Identity of $($automationAccount.AutomationAccountName)",
            "Do you confirm to assign desired Azure Roles for $($automationAccount.AutomationAccountName) ?",
            'Assign Azure Roles to System-Assigned Managed Identity of Azure Automation Account'
        )) {

        $RgScope = '/subscriptions/' + `
            $automationAccount.SubscriptionId + `
            '/resourcegroups/' + `
            $automationAccount.ResourceGroupName

        $AzureRoleScopes = @{
            # Scope: Automation Account
            ($RgScope + '/providers/Microsoft.Automation/automationAccounts/' + $automationAccount.AutomationAccountName) = @(
                'Reader'
            )

            # # Scope: Resource Group
            # $RgScope                                                                                                      = @(
            # )
        }

        $AzureRoleDefinitions = Get-AzRoleDefinition

        $AzureRoleScopes.GetEnumerator() | ForEach-Object {
            Write-Output "   $($_.Key)"
            $AzureRoleAssignments = Get-AzRoleAssignment `
                -ObjectId $automationAccount.Identity.PrincipalId `
                -Scope $_.Key

            foreach ($AzureRole in $_.Value) {
                $AzureRoleDefinition = $AzureRoleDefinitions | Where-Object Name -eq $AzureRole

                if ($null -eq $AzureRoleDefinition) {
                    Write-Error "$($automationAccount.AutomationAccountName): No Azure Role found with name '$AzureRole'. Choose one of:`n   $(($AzureRoleDefinitions | Sort-Object Name | ForEach-Object { '{0}: {1}' -f $_.Name, $_.Description }) -join "`n   ")"
                    continue
                }

                Write-Output "      $($AzureRoleDefinition.Name)"

                if (-Not ($AzureRoleAssignments | Where-Object RoleDefinitionId -eq $AzureRoleDefinition.Id)) {
                    $null = New-AzRoleAssignment `
                        -ObjectId $automationAccount.Identity.PrincipalId `
                        -RoleDefinitionId $AzureRoleDefinition.Id `
                        -Scope $_.Key
                }
            }
        }
    }
    elseif ($WhatIfPreference) {
        Write-Verbose 'What If: Azure Roles would have been assigned.'
    }
    else {
        Write-Verbose 'Assignment of Azure Roles was denied.'
    }

    if ($PSCmdlet.ShouldProcess(
            "Assign Microsoft Entra app permissions to System-Assigned Managed Identity of $($automationAccount.AutomationAccountName)",
            "Do you confirm to assign desired Microsoft Entra permissions to apps for $($automationAccount.AutomationAccountName) ?",
            'Assign Microsoft Entra app permissions to System-Assigned Managed Identity of Azure Automation Account'
        )) {

        $AppPermissions = @{
            # Microsoft Graph
            '00000003-0000-0000-c000-000000000000' = @{
                AppRoles = @(
                    'Directory.Read.All'
                    'Directory.Write.Restricted'
                    'Group.Read.All'
                    'Group.ReadWrite.All'
                    'Mail.Send'
                    'OnPremDirectorySynchronization.Read.All'
                    'Organization.Read.All'
                    'Policy.Read.All'
                    'User.Read.All'
                    'User.ReadWrite.All'
                    'UserAuthenticationMethod.ReadWrite.All'
                )
                # Oauth2PermissionScopes = @{
                #     Admin = @(
                #         'offline_access'
                #         'openid'
                #         'profile'
                #     )
                #     '<User-ObjectId>' = @(
                #     )
                # }
            }

            # Office 365 Exchange Online
            '00000002-0000-0ff1-ce00-000000000000' = @{
                AppRoles = @(
                    'Exchange.ManageAsApp'
                )
                # Oauth2PermissionScopes = @{
                #     Admin = @(
                #     )
                #     '<User-ObjectId>' = @(
                #     )
                # }
            }
        }

        $AppPermissions.GetEnumerator() | ForEach-Object {
            $ServicePrincipal = $null
            if ($_.key -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$') {
                $ServicePrincipal = Get-MgBetaServicePrincipal -All -ConsistencyLevel eventual -Filter "ServicePrincipalType eq 'Application' and appId eq '$($_.key)'"
            }
            else {
                $ServicePrincipal = Get-MgBetaServicePrincipal -All -ConsistencyLevel eventual -Filter "ServicePrincipalType eq 'Application' and DisplayName eq '$($_.key)'"
            }
            Write-Output "   $($ServicePrincipal.DisplayName.ToUpper())"
            $AppRoleAssignments = Get-MgBetaServicePrincipalAppRoleAssignment -ServicePrincipalId $automationAccount.Identity.PrincipalId | Where-Object ResourceId -eq $ServicePrincipal.Id
            $PermissionGrants = Get-MgBetaOauth2PermissionGrant -All -Filter "ClientId eq '$($automationAccount.Identity.PrincipalId)' and ResourceId eq '$($ServicePrincipal.Id)'"

            $Permissions = $_.Value
            $Permissions.GetEnumerator() | ForEach-Object {
                $Permission = $_.value

                if ($_.Key -eq 'AppRoles') {
                    Write-Output "      Application:"

                    foreach ($Permission in ($_.Value | Select-Object -Unique | Sort-Object)) {
                        $AppRole = $ServicePrincipal.AppRoles | Where-Object { $_.Value -eq $Permission }
                        if ($null -eq $AppRole) {
                            Write-Error "$($ServicePrincipal.DisplayName): No App Role found with name '$Permission'. Choose one of:`n   $(($ServicePrincipal.AppRoles | Sort-Object Value | ForEach-Object { '{0}: {1}' -f $_.Value, $_.DisplayName }) -join "`n   ")"
                            continue
                        }
                        else {
                            Write-Output "         - $($AppRole.Value)`n           $($AppRole.DisplayName)"
                        }

                        if ($AppRoleAssignments | Where-Object AppRoleId -eq $AppRole.Id) { continue }

                        $params = @{
                            PrincipalId = $automationAccount.Identity.PrincipalId
                            ResourceId  = $ServicePrincipal.Id
                            AppRoleId   = $AppRole.Id
                        }
                        $null = New-MgBetaServicePrincipalAppRoleAssignment `
                            -ServicePrincipalId $automationAccount.Identity.PrincipalId `
                            -BodyParameter $params
                    }
                }

                if ($_.Key -eq 'Oauth2PermissionScopes') {
                    Write-Output "      Delegated:"

                    $_.Value.GetEnumerator() | ForEach-Object {
                        $ClientId = $automationAccount.Identity.PrincipalId
                        $ResourceId = $ServicePrincipal.Id
                        $PrincipalId = $_.Key
                        $ConsentType = if ($PrincipalId -eq 'Admin') { 'AllPrincipals' } else { 'Principal' }
                        Write-Output "         ${PrincipalId}:"

                        $scopes = @()
                        foreach ($Permission in ($_.Value | Select-Object -Unique | Sort-Object)) {
                            $OAuth2Permission = $ServicePrincipal.Oauth2PermissionScopes | Where-Object { $_.Value -eq $Permission }
                            if ($null -eq $OAuth2Permission) {
                                Write-Error "$($ServicePrincipal.DisplayName): No OAuth Permission found with name '$Permission'. Choose one of:`n   $(($ServicePrincipal.Oauth2PermissionScopes | Sort-Object Value | ForEach-Object { '{0}: {1}' -f $_.Value, $_.DisplayName }) -join "`n   ")"
                                continue
                            }

                            Write-Output "            - $($OAuth2Permission.Value)`n              $(if ($PrincipalId -eq 'Admin') { $OAuth2Permission.AdminConsentDisplayName } else { $OAuth2Permission.UserConsentDisplayName })"
                            $scopes += $OAuth2Permission.Value
                        }

                        if ($scopes.Count -eq 0) { continue }

                        $PermissionGrant = $PermissionGrants | Where-Object ConsentType -eq $ConsentType
                        if ($ConsentType -eq 'Principal') {
                            $PermissionGrant = $PermissionGrant | Where-Object PrincipalId -eq $PrincipalId
                        }
                        if ($PermissionGrant) {
                            $params = @{
                                Scope = $scopes -join ' '
                            }
                            Update-MgBetaOauth2PermissionGrant -OAuth2PermissionGrantId $PermissionGrant.Id -BodyParameter $params
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
                            $null = New-MgBetaOauth2PermissionGrant -BodyParameter $params
                        }
                    }
                }
            }
        }
    }
    elseif ($WhatIfPreference) {
        Write-Verbose 'What If: Microsoft Entra app permissions would have been assigned.'
    }
    else {
        Write-Verbose 'Assignment of Microsoft Entra app permissions was denied.'
    }

    if ($PSCmdlet.ShouldProcess(
            "Assign desired Microsoft Entra roles to System-Assigned Managed Identity of $($automationAccount.AutomationAccountName)",
            "Do you confirm to assign desired Microsoft Entra roles to $($automationAccount.AutomationAccountName) ?",
            'Assign Microsoft Entra roles to System-Assigned Managed Identity of Azure Automation Account'
        )) {

        $EntraRoles = @(
            @{
                DisplayName    = 'Exchange Recipient Administrator'
                roleTemplateId = '31392ffb-586c-42d1-9346-e59415a2cc4e'
            }
            @{
                DisplayName    = 'Groups Administrator'
                roleTemplateId = 'fdd7a751-b60b-444a-984c-02652fe8fa1c'
                isScopable     = $true
            }
            @{
                DisplayName    = 'License Administrator'
                roleTemplateId = '4d6ac14f-3453-41d0-bef9-a3e0c569773a'
                isScopable     = $true
            }
            @{
                DisplayName    = 'Privileged Authentication Administrator'
                roleTemplateId = '7be44c8a-adaf-4e2a-84d6-ab2649e08a13'
            }
            # @{
            #     DisplayName = 'Privileged Role Administrator'
            #     TemplateId  = 'e8611ab8-c189-46e8-94e1-60213ab1f814'
            # }
            @{
                DisplayName    = 'User Administrator'
                roleTemplateId = 'fe930be7-5e62-47db-91af-98c3a49a38b1'
                isScopable     = $true
            }
        )

        $RoleDefinitions = Get-MgBetaRoleManagementDirectoryRoleDefinition
        $RoleAssignments = Get-MgBetaRoleManagementDirectoryRoleAssignment -All -Filter "PrincipalId eq '$($automationAccount.Identity.PrincipalId)'"

        foreach ($Role in $EntraRoles) {
            $RoleDefinition = $null
            if ($Role.RoleDefinitionId) {
                $RoleDefinition = $RoleDefinitions | Where-Object { $_.RoleDefinitionId -eq $Role.RoleDefinitionId }
            }
            elseif ($Role.roleTemplateId) {
                $RoleDefinition = $RoleDefinitions | Where-Object { $_.TemplateId -eq $Role.roleTemplateId }
            }
            elseif ($Role.DisplayName) {
                $RoleDefinition = $RoleDefinitions | Where-Object { $_.DisplayName -eq $Role.DisplayName }
            }
            if ($null -eq $RoleDefinition) {
                Write-Error "$($ServicePrincipal.DisplayName): No Entra ID Role found with name '$($Role.DisplayName)'. Choose one of:`n   $(($RoleDefinitions | Sort-Object DisplayName | ForEach-Object { '{0} ({1})' -f $_.DisplayName, $_.TemplateId }) -join "`n   ")"
                continue
            }

            if ($Role.isScopable) {
                Write-Output "   - $($RoleDefinition.Id)`n     $($RoleDefinition.DisplayName)"

            }
            else {
                Write-Output "   - $($RoleDefinition.Id)`n     $($RoleDefinition.DisplayName)"
            }

            if ($RoleAssignments | Where-Object RoleDefinitionId -eq $RoleDefinition.Id) { continue }

            $params = @{
                PrincipalId      = $automationAccount.Identity.PrincipalId
                RoleDefinitionId = $RoleDefinition.Id
                DirectoryScopeId = '/'
            }
            # if ($Role.isScopable) { $params.DirectoryScopeId = $Role.DirectoryScopeId }
            $null = New-MgBetaRoleManagementDirectoryRoleAssignment `
                -BodyParameter $params
        }
    }
    elseif ($WhatIfPreference) {
        Write-Verbose 'What If: Microsoft Entra roles would have been assigned.'
    }
    else {
        Write-Verbose 'Assignment of Microsoft Entra roles was denied.'
    }
}
