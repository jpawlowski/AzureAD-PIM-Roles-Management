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

$missingRoles = @()
$RoleAssignments = .\Common_0002__Get-MgDirectoryRoleActiveAssignment.ps1
$GlobalAdmin = $RoleAssignments | Where-Object { $_.RoleDefinition.TemplateId -eq '62e90394-69f5-4237-9190-012177145e10' }
$PrivRoleAdmin = $RoleAssignments | Where-Object { $_.RoleDefinition.TemplateId -eq 'e8611ab8-c189-46e8-94e1-60213ab1f814' }

if ($GlobalAdmin) {
    if ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
        if (-Not $AllowGlobalAdministratorInAzureAutomation) {
            Throw 'Running this script with Global Administrator permissions in Azure Automation is prohibited.'
        }
        Write-Warning 'Runbooks running with Global Administrator permissions in Azure Automation is a HIGH RISK!' -Verbose -WarningAction Continue
    }
    else {
        Write-Warning 'Running with Global Administrator permissions: You should reconsider following the principle of least privilege.' -Verbose -WarningAction Continue
    }

    if (-Not $AllowGlobalAdministratorInAzureAutomation -and
        -Not (
            $Roles | Where-Object {
                (
                    ($_.GetType().Name -eq 'String') -and
                    $_ -eq 'Global Administrator'
                ) -or
                (
                    ($_.GetType().Name -ne 'String') -and
                    (
                        ($_.TemplateId -eq '62e90394-69f5-4237-9190-012177145e10') -or
                        ($_.DisplayName -eq 'Global Administrator')
                    )
                )
            }
        )
    ) {
        Write-Warning '+++ATTENTION+++ Running with active Global Administrator permissions, but it was not explicitly requested by the script!' -Verbose -WarningAction Continue
    }
}

if ($PrivRoleAdmin) {
    if ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT -or $PSPrivateMetadata.JobId) {
        if (-Not $AllowPrivilegedRoleAdministratorInAzureAutomation) {
            Throw 'Running this script with Privileged Role Administrator permissions in Azure Automation is prohibited.'
        }
        Write-Verbose 'WARNING: Runbooks running with Privileged Role Administrator permissions in Azure Automation is a HIGH RISK!' -Verbose
    }

    if (-Not $AllowPrivilegedRoleAdministratorInAzureAutomation -and
        -Not (
            $Roles | Where-Object {
                (
                    ($_.GetType().Name -eq 'String') -and
                    $_ -eq 'Privileged Role Administrator'
                ) -or
                (
                    ($_.GetType().Name -ne 'String') -and
                    (
                        ($_.TemplateId -eq 'e8611ab8-c189-46e8-94e1-60213ab1f814') -or
                        ($_.DisplayName -eq 'Privileged Role Administrator')
                    )
                )
            }
        )
    ) {
        Write-Warning '+++ATTENTION+++ Running with active Privileged Role Administrator permissions, but it was not explicitly requested by the script!' -Verbose -WarningAction Continue
    }
}

foreach (
    $Item in (
        # Roles may either be defined by a simple string, or hash.
        # Make this array containing unique role definitions only.
        $Roles | Group-Object -Property { $_.GetType().Name } | ForEach-Object {
            if ($_.Name -eq 'String') {
                $_.Group | Select-Object -Unique
            }
            else {
                $_.Group | Group-Object -Property DisplayName, TemplateId, DirectoryScopeId | ForEach-Object {
                    $_.Group[0]
                }
            }
        }
    )
) {
    $DirectoryScopeId = if ($Item -is [String]) { '/' } elseif ($Item.DirectoryScopeId) { $Item.DirectoryScopeId } else { '/' }
    $TemplateId = if ($Item -is [String]) { if ($Item -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$') { $Item } else { $null } } else { $Item.TemplateId }
    $DisplayName = if ($Item -is [String]) { if ($Item -notmatch '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$') { $Item } else { $null } } else { $Item.DisplayName }
    $Optional = if ($Item -is [String]) { $false } else { $Item.Optional }
    $AssignedRole = $RoleAssignments | Where-Object { ($_.DirectoryScopeId -eq $DirectoryScopeId) -and (($_.RoleDefinition.TemplateId -eq $TemplateId) -or ($_.RoleDefinition.DisplayName -eq $DisplayName)) }
    $superseededRole = $false
    if (-Not $AssignedRole -and $DirectoryScopeId -ne '/') {
        $superseededRole = $true
        $AssignedRole = $RoleAssignments | Where-Object { ($_.DirectoryScopeId -eq '/') -and (($_.RoleDefinition.TemplateId -eq $TemplateId) -or ($_.RoleDefinition.DisplayName -eq $DisplayName)) }
    }
    if ($AssignedRole) {
        if ($superseededRole) {
            Write-Warning "Superseeded directory role by root directory scope: $($AssignedRole.RoleDefinition.DisplayName) ($($AssignedRole.RoleDefinition.TemplateId)), Directory Scope: $($AssignedRole.DirectoryScopeId). You might want to reduce permission scope to Administrative Unit $DirectoryScopeId only."
        }
        else {
            Write-Verbose "Confirmed directory role: $($AssignedRole.RoleDefinition.DisplayName) ($($AssignedRole.RoleDefinition.TemplateId)), Directory Scope: $($AssignedRole.DirectoryScopeId)"
        }
    }
    else {
        if ($Optional) {
            Write-Verbose "Missing optional directory role permission: $DisplayName $(if ($TemplateId -and ($TemplateId -ne $DisplayName)) { "($TemplateId)" }), Directory Scope: $DirectoryScopeId"
        }
        elseif ($GlobalAdmin -and $DirectoryScopeId -ne '/') {
            Write-Warning "Missing scoped directory role permission: $DisplayName $(if ($TemplateId -and ($TemplateId -ne $DisplayName)) { "($TemplateId)" }), Directory Scope: $DirectoryScopeId"
        }
        elseif ($GlobalAdmin) {
            Write-Warning "Superseeded directory role by active Global Administrator: $DisplayName $(if ($TemplateId -and ($TemplateId -ne $DisplayName)) { "($TemplateId)" }), Directory Scope: $DirectoryScopeId"
        }
        else {
            $missingRoles += @{ DirectoryScopeId = $DirectoryScopeId; TemplateId = $TemplateId; DisplayName = $DisplayName }
        }
    }
}

if ($missingRoles.Count -gt 0) {
    Throw "Missing mandatory directory role permissions:`n$($missingRoles | ConvertTo-Json)"
}

Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
return $RoleAssignments
