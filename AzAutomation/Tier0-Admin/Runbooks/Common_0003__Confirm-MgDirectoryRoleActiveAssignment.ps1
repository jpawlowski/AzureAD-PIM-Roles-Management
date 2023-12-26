<#PSScriptInfo
.VERSION 1.0.0
.GUID a71f281b-4d20-4829-a814-18baff4dade7
.AUTHOR Julian Pawlowski
.COMPANYNAME Workoho GmbH
.COPYRIGHT (c) 2024 Workoho GmbH. All rights reserved.
.TAGS
.LICENSEURI
.PROJECTURI
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS Common_0002__Get-MgDirectoryRoleActiveAssignment.ps1
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>

<#
.SYNOPSIS
    Validate if current user has activated the listed roles in Microsoft Entra

.DESCRIPTION
    Common runbook that can be used by other runbooks. It can not be started as an Azure Automation job directly.

.PARAMETER Roles
    Collection of desired Entra roles. Could be a mix of role display names, role template IDs, or complex hash objects.
    A hash object may look like:

    @{
        roleTemplateId = <roleTemplateId>
        DisplayName = <DisplayName>
        optional = <[System.Boolean]>
    }

.PARAMETER AllowGlobalAdministratorInAzureAutomation
    If this script is run in Microsoft Azure Automation, running with Global Administrator permissions is prohibited.
    Using this parameter, you may enforce running for special occasions.

.PARAMETER AllowPrivilegedRoleAdministratorInAzureAutomation
    If this script is run in Microsoft Azure Automation, running with Privileged Role Administrator permissions is prohibited.
    Using this parameter, you may enforce running for special occasions.
#>

[CmdletBinding()]
Param(
    [Parameter(mandatory = $true)]
    [Array]$Roles,

    [Boolean]$AllowGlobalAdministratorInAzureAutomation = $false,
    [Boolean]$AllowPrivilegedRoleAdministratorInAzureAutomation = $false
)

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | ForEach-Object { $_.PSObject.Properties | ForEach-Object { $_.Name + ': ' + $_.Value } }) -join ', ') ---"

$activeRoles = @()
$missingRoles = @()
$RoleAssignment = .\Common_0002__Get-MgDirectoryRoleActiveAssignment.ps1
$GlobalAdmin = $RoleAssignment | Where-Object roleTemplateId -eq '62e90394-69f5-4237-9190-012177145e10'
$PrivRoleAdmin = $RoleAssignment | Where-Object roleTemplateId -eq 'e8611ab8-c189-46e8-94e1-60213ab1f814'

Write-Verbose "Detected assigned directory roles: $($RoleAssignment.DisplayName -join ', ')"

if ($GlobalAdmin) {
    if ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
        if (-Not $AllowGlobalAdministratorInAzureAutomation) {
            Throw 'Running this script with Global Administrator permissions in Azure Automation is prohibited.'
        }
        Write-Verbose 'WARNING: Runbooks running with Global Administrator permissions in Azure Automation is a HIGH RISK!'
    }
    else {
        Write-Warning 'Running with Global Administrator permissions: You should reconsider following the principle of least privilege.'
    }
    $activeRoles = $RoleAssignment
}
else {
    if ($PrivRoleAdmin) {
        if ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
            if (-Not $AllowPrivilegedRoleAdministratorInAzureAutomation) {
                Throw 'Running this script with Privileged Role Administrator permissions in Azure Automation is prohibited.'
            }
            Write-Verbose 'WARNING: Runbooks running with Privileged Role Administrator permissions in Azure Automation is a HIGH RISK!'
        }
        $activeRoles += $PrivRoleAdmin
    }

    foreach ($Item in $Roles) {
        $roleTemplateId = if ($Item -is [String]) { $Item } elseif ($Item.roleTemplateId) { $Item.roleTemplateId } else { $Item.TemplateId }
        $DisplayName = if ($Item -is [String]) { $Item } else { $Item.DisplayName }
        $Optional = if ($Item -is [String]) { $false } else { $Item.Optional }
        $AssignedRole = $RoleAssignment | Where-Object { ($_.roleTemplateId -eq $roleTemplateId) -or ($_.DisplayName -eq $DisplayName) }
        if ($AssignedRole) {
            Write-Verbose "Confirmed directory role $($AssignedRole.DisplayName) ($($AssignedRole.roleTemplateId))"
            $activeRoles += $AssignedRole
        }
        elseif ($Optional) {
            Write-Warning "Missing optional directory role permission: $DisplayName $(if ($roleTemplateId -and ($roleTemplateId -ne $DisplayName)) { "($roleTemplateId)" })"
        }
        else {
            Write-Error "Missing mandatory directory role permission: $DisplayName $(if ($roleTemplateId -and ($roleTemplateId -ne $DisplayName)) { "($roleTemplateId)" })"
            $missingRoles += @{ roleTemplateId = $roleTemplateId; DisplayName = $DisplayName; Optional = $Optional }
        }
    }
}

if ($missingRoles.Count -gt 0) {
    Throw $("Missing mandatory directory role permissions: " + $($missingRoles.DisplayName -join ', '))
}

Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
return $activeRoles
