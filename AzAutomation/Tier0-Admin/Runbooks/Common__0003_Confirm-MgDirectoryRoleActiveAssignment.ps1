<#
.SYNOPSIS
    Validate if current user has activated the listed roles in Microsoft Entra

.PARAMETER Roles
    Collection of desired Entra roles. Could be a mix of role display names, role template IDs, or complex hash objects.
    A hash object may look like:

    @{
        [System.String]roleTemplateId = <roleTemplateId>
        [System.String]DisplayName = <DisplayName>
        [System.Boolean]optional = <[System.Boolean]>
    }

.PARAMETER AllowGlobalAdministratorInAzureAutomation
    If this script is run in Microsoft Azure Automation, running with Global Administrator permissions is prohibited.
    Using this parameter, you may enforce running for special occasions.

.PARAMETER AllowPrivilegedRoleAdministratorInAzureAutomation
    If this script is run in Microsoft Azure Automation, running with Privileged Role Administrator permissions is prohibited.
    Using this parameter, you may enforce running for special occasions.

.NOTES
    Original name: Common__0003_Confirm-MgDirectoryRoleActiveAssignment.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
    Version: 1.0.0
#>

[CmdletBinding()]
Param(
    [Parameter(mandatory = $true)]
    [Array]$Roles,

    [Boolean]$AllowGlobalAdministratorInAzureAutomation = $false,
    [Boolean]$AllowPrivilegedRoleAdministratorInAzureAutomation = $false
)

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name) ---"

$activeRoles = @()
$missingRoles = @()
$RoleAssignment = .\Common__0002_Get-MgDirectoryRoleActiveAssignment.ps1
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
