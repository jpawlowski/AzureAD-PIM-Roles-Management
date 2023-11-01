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
    Plan

.PARAMETER Tags
    Tags

.NOTES
    Filename: New-AzAutomation-for-Tier0-IAM.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
    Version: 1.0
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
    [string]$Plan,
    [System.Collections.Generic.Dictionary[string, object]]$Tags
)

if ("AzureAutomation/" -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
    Throw 'This script must be run interactively by a privileged administrator account.'
}

if (
    (-Not (Get-AzContext)) -or
    ($TenantId -ne (Get-AzContext).Tenant)
) {
    Connect-AzAccount `
        -UseDeviceAuthentication `
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
        Write-Verbose 'Simulation Mode: A new Azure Automation account would have been created.'
    }
    else {
        Write-Verbose 'Creation of new Azure Automation account was aborted.'
        exit
    }
}

$PSGalleryModules = @(
    'Microsoft.Graph.Authentication'
    'Microsoft.Graph.Identity.SignIns'
    'Microsoft.Graph.Users'
    'Microsoft.Graph.Users.Actions'
    'Microsoft.Graph.Users.Functions'
)

if ($PSCmdlet.ShouldProcess(
        "Install PowerShell Modules in $($automationAccount.AutomationAccountName)",
        "Do you confirm to install desired PowerShell Modules in $($automationAccount.AutomationAccountName) ?",
        'Install PowerShell Modules in Azure Automation Account'
    )) {
    foreach ($ModuleName in $PSGalleryModules) {
        $Module = Get-AzAutomationModule `
            -ResourceGroupName $ResourceGroupName `
            -AutomationAccountName $automationAccount.AutomationAccountName `
            -Name $ModuleName `
            -ErrorAction SilentlyContinue

        if (
                (-Not $Module) -or
                ($Module.ProvisioningState -eq 'Failed')
        ) {
            Write-Output "   ${ModuleName}: Installing"
            $null = New-AzAutomationModule `
                -ResourceGroupName $automationAccount.ResourceGroupName `
                -AutomationAccountName $automationAccount.AutomationAccountName `
                -Name $ModuleName `
                -ContentLinkUri "https://www.powershellgallery.com/api/v2/package/$ModuleName"
        }
        else {
            Write-Output "   ${ModuleName}: Installed"
        }
    }
}
elseif ($WhatIfPreference) {
    Write-Verbose 'Simulation Mode: PowerShell modules would have been installed.'
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
            -AssignSystemIdentity `
            -Verbose:$Verbose
    }
    elseif ($WhatIfPreference) {
        Write-Verbose 'Simulation Mode: System-Assigned Managed Identity would have been enabled.'
    }
    else {
        Write-Verbose 'Enablement of System-Assigned Managed Identity was aborted.'
        exit
    }
}

if ($PSCmdlet.ShouldProcess(
        "Assign Microsoft Graph permissions to System-Assigned Managed Identity of $($automationAccount.AutomationAccountName)",
        "Do you confirm to assign desired permissions to Microsoft Graph for $($automationAccount.AutomationAccountName) ?",
        'Assign Microsoft Graph permissions to System-Assigned Managed Identity of Azure Automation Account'
    )) {

    $MgScopes = @(
        'Application.Read.All'
        'Directory.Read.All'
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
            -DeviceCode `
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

    $AzAutomationPermissions = @(
        'Directory.Read.All'                        # To read directory data and settings
        'Policy.Read.All'                           # To read and validate current policy settings
        'User.Read.All'                             # To read user information
        'UserAuthenticationMethod.Read.All'         # To read authentication methods of the user
        'UserAuthenticationMethod.ReadWrite.All'    # To update authentication methods of the user
    )

    $MgGraphAppId = "00000003-0000-0000-c000-000000000000"
    $MgGraphServicePrincipal = Get-AzADServicePrincipal -Filter "appId eq '$MgGraphAppId'"
    $MgGraphAppRoles = $MgGraphServicePrincipal.AppRole | Where-Object { ($_.Value -in $AzAutomationPermissions) -and ($_.AllowedMemberType -contains 'Application') }

    foreach ($AppRole in $MgGraphAppRoles) {
        $params = @{
            "PrincipalId" = $automationAccount.Identity.PrincipalId
            "ResourceId"  = $MgGraphServicePrincipal.Id
            "AppRoleId"   = $AppRole.Id
        }

        $null = New-MgServicePrincipalAppRoleAssignment `
            -ServicePrincipalId $params.PrincipalId `
            -BodyParameter $params `
            -ErrorAction SilentlyContinue
    }
}
elseif ($WhatIfPreference) {
    Write-Verbose 'Simulation Mode: Microsoft Graph permissions would have been assigned.'
}
else {
    Write-Verbose 'Assignment of Microsoft Graph permissions was denied.'
}

$EntraRoles = @(
    @{
        displayName      = 'Authentication Administrator'
        RoleDefinitionId = 'c4e39bd9-1100-46d3-8c65-fb160da0071f'
        DirectoryScopeId = '/administrativeUnits/2c7399f0-42dd-40de-b20b-b986ab85045c'
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
    New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $params
}
