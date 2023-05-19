<#
.SYNOPSIS
    Implement a Security Tiering Model for Azure AD Privileged Roles using Azure AD Privileged Identity Management.
.DESCRIPTION
    This script combines the following Microsoft Azure components to harden Privileged Roles in Azure Active Directory:

    - Azure AD Privileged Identity Management (AAD PIM; requires Azure AD Premium Plan 2 license)
    - Azure AD Conditional Access (AAD CA; requires Azure AD Premium Plan 1 or Plan 2 license):
        - Authentication Contexts
        - Authentication Strengths
        - Conditional Access Policies
#>

[CmdletBinding()]
Param (
    [Parameter(HelpMessage = "Azure AD tenant ID.")]
    [string]$TenantId,
    [Parameter(HelpMessage = "Path to configuration file in PS1 format. Default: './AzureAD-Roles-Management.config.ps1'.")]
    [string]$Config,
    [Parameter(HelpMessage = "Update all Azure AD roles that are classified as Tier0.")]
    [switch]$Tier0,
    [Parameter(HelpMessage = "Update all Azure AD roles that are classified as Tier1.")]
    [switch]$Tier1,
    [Parameter(HelpMessage = "Update all Azure AD roles that are classified as Tier2.")]
    [switch]$Tier2,
    [Parameter(HelpMessage = "Update specified list of Azure AD roles. When combined with -Tier0, -Tier1, or -Tier2 parameter, roles outside these tiers are ignored.")]
    [array]$Roles,
    [Parameter(HelpMessage = "Update Azure AD Authentication Contexts")]
    [switch]$UpdateAuthContext,
    [Parameter(HelpMessage = "Create or update Azure AD Authentication Strengths")]
    [switch]$CreateAuthStrength
)

$MgVersion = Get-Module -ListAvailable -Name "Microsoft.Graph"
if (
    (-Not $MgVersion) -or
    ($MgVersion.Version -lt [System.Version]'2.0')
) {
    Write-Error "This script requies Microsoft Graph PowerShell module to be installed."
    exit 1
}

if (
    ($null -eq $Config) -or
    ($Config -eq '')
) {
    $Config = Join-Path $PSScriptRoot 'AzureAD-Roles-Management.config.ps1'
}

try {
    . $Config
}
catch {
    Write-Error "Missing configuration file $config"
    exit
}

if (
    ($null -eq $TenantId) -or
    ($TenantId -eq '')
) {
    if (
        ($null -ne $env:TenantId) -and
        ($env:TenantId -ne '')
    ) {
        $TenantId = $env:TenantId
    }
    else {
        Write-Error "Missing `$env:TenantId environment variable or -TenantId parameter"
        exit
    }
}

$MgScopes = @()
if (
    $Tier0 -or
    $Tier1 -or
    $Tier2 -or
    $Roles
) {
    $MgScopes += "RoleManagement.ReadWrite.Directory"
}
if ($UpdateAuthContext) {
    $MgScopes += "AuthenticationContext.ReadWrite.All"
}
if ($CreateAuthStrength) {
    $MgScopes += "Policy.ReadWrite.ConditionalAccess"
}

$reauth = $false
foreach ($MgScope in $MgScopes) {
    if ($MgScope -notin @((Get-MgContext).Scopes)) {
        $reauth = $true
    }
}

if (
    $reauth -or
    ((Get-MgContext).TenantId -ne $TenantId)
) {
    Write-Output "Connecting to tenant $TenantId ..."
    Connect-MgGraph -TenantId $TenantId -Scopes $MgScopes
    if (-Not $?) {
        exit
    }
}

$RoleTemplateIDsWhitelist = @();
$RoleNamesWhitelist = @();
foreach ($role in $Roles) {
    if ($role.GetType().Name -eq 'String') {
        if ($role -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$') {
            $RoleTemplateIDsWhitelist += $role
        }
        else {
            $RoleNamesWhitelist += $role
        }
    }
    elseif ($role.GetType().Name -eq 'Hashtable') {
        if ($role.TemplateId) {
            $RoleTemplateIDsWhitelist += $role.TemplateId
        }
        elseif ($role.displayName) {
            $RoleNamesWhitelist += $role.displayName
        }
    }
}

if ($UpdateAuthContext) {
    $AuthContextTiers = @();
    if ($Tier0) {
        $AuthContextTiers += 0
    }
    if ($Tier1) {
        $AuthContextTiers += 1
    }
    if ($Tier2) {
        $AuthContextTiers += 2
    }
    if (-Not $AuthContextTiers) {
        $AuthContextTiers = @(0, 1, 2)
    }

    foreach ($tier in $AuthContextTiers) {
        foreach ($key in $AADCAAuthContexts[$tier].Keys) {
            foreach ($authContext in $AADCAAuthContexts[$tier][$key]) {
                Write-Output "`n[Tier $tier] Updating authentication context class reference $($authContext.id) ($($authContext.displayName))"
                try {
                    Update-MgIdentityConditionalAccessAuthenticationContextClassReference `
                        -AuthenticationContextClassReferenceId $authContext.id `
                        -DisplayName $authContext.displayName `
                        -Description $authContext.description `
                        -IsAvailable:$true
                }
                catch {
                    Write-Output $_
                    break
                }

                Start-Sleep -Seconds 0.5
            }
        }
    }
}

if ($CreateAuthStrength) {
    $AuthStrengthTiers = @();
    if ($Tier0) {
        $AuthStrengthTiers += 0
    }
    if ($Tier1) {
        $AuthStrengthTiers += 1
    }
    if ($Tier2) {
        $AuthStrengthTiers += 2
    }
    if (-Not $AuthStrengthTiers) {
        $AuthStrengthTiers = @(0, 1, 2)
    }

    $authStrengthPolicies = Get-MgPolicyAuthenticationStrengthPolicy -Filter "PolicyType eq 'custom'"

    foreach ($tier in $AuthStrengthTiers) {
        foreach ($key in $AADCAAuthStrengths[$tier].Keys) {
            foreach ($authStrength in $AADCAAuthStrengths[$tier][$key]) {
                $updateOnly = $false

                if ($authStrength.id) {
                    if ($authStrengthPolicies | Where-Object -FilterScript {$_.Id -eq $authStrength.id}) {
                        $updateOnly = $true
                    } else {
                        Write-Warning "`n[Tier $tier] SKIPPED AuthStrength ID $($authStrength.id) Authentication Strength: No Authentication Strength definition found"
                        continue
                    }
                }
                else {
                    $obj = $authStrengthPolicies | Where-Object -FilterScript {$_.DisplayName -eq $authStrength.displayName}
                    if ($obj) {
                        $authStrength.id = $obj.Id
                        $updateOnly = $true
                    }
                }

                if ($updateOnly) {
                    Write-Output "`n[Tier $tier] Updating authentication strength policy"
                    Update-MgPolicyAuthenticationStrengthPolicy `
                        -AuthenticationStrengthPolicyId  $authStrength.id `
                        -DisplayName $authStrength.displayName `
                        -Description $authStrength.description
                    # Update-MgPolicyAuthenticationStrengthPolicyAllowedCombination
                } else {
                    Write-Output "`n[Tier $tier] Creating authentication strength policy"
                    New-MgPolicyAuthenticationStrengthPolicy `
                        -DisplayName $authStrength.displayName `
                        -Description $authStrength.description
                }
            }
        }
    }
}

$PolicyTiers = @();
if ($Tier0) {
    $PolicyTiers += 0
}
if ($Tier1) {
    $PolicyTiers += 1
}
if ($Tier2) {
    $PolicyTiers += 2
}
if (-Not $PolicyTiers -and $Roles) {
    $PolicyTiers = @(0, 1, 2)
}

foreach ($tier in $PolicyTiers) {
    $i = 0
    foreach ($role in $AADRoleClassifications[$tier]) {
        if (
            ($null -eq $role.IsBuiltIn) -or
            (
                -Not $role.TemplateId -and
                -Not $role.displayName
            )
        ) {
            Write-Warning "[Tier $tier] Incomplete role definition ignored at array position $i"
            continue
        }

        if ($RoleTemplateIDsWhitelist -or $RoleNamesWhitelist) {
            $found = $false
            if (
                $RoleTemplateIDsWhitelist -and
                $role.TemplateId -and
                ($role.TemplateId -in $RoleTemplateIDsWhitelist)
            ) {
                $found = $true
            }
            elseif (
                $RoleNamesWhitelist -and
                $role.displayName -and
                ($role.displayName -in $RoleNamesWhitelist)
            ) {
                $found = $true
            }
            if (-Not $found) {
                continue
            }
        }

        if ($role.TemplateId) {
            $filter = "TemplateId eq '$($role.TemplateId)' and IsBuiltIn eq " + (($role.IsBuiltIn).ToString()).ToLower()
        }
        else {
            $filter = "displayName eq '$($role.displayName)' and IsBuiltIn eq " + (($role.IsBuiltIn).ToString()).ToLower()
        }
        $roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -Filter $filter
        if (-Not $roleDefinition) {
            Write-Warning "`n[Tier $tier] SKIPPED $($role.displayName): No role definition found"
            continue
        }

        $filter = "scopeId eq '/' and scopeType eq 'DirectoryRole' and RoleDefinitionId eq '$($roleDefinition.Id)'"
        $policyAssignment = Get-MgPolicyRoleManagementPolicyAssignment -Filter $filter
        if (-Not $policyAssignment) {
            Write-Warning "`n[Tier $tier] SKIPPED $($role.displayName): No policy assignment found"
            continue
        }

        Write-Output "`n[Tier $tier] Updating management policy rules for role $($roleDefinition.TemplateId) ($($roleDefinition.displayName)):"
        foreach ($rolePolicyRuleTemplate in $AADRoleManagementRulesDefaults[$tier]) {
            $rolePolicyRule = $rolePolicyRuleTemplate.PsObject.Copy()

            if ($role.ContainsKey($rolePolicyRule.Id)) {
                Write-Output "          [Deviating] $($rolePolicyRule.Id)"
                foreach ($key in $item.$($rolePolicyRule.Id).Keys) {
                    $rolePolicyRule.$key = $item.$($rolePolicyRule.Id).$key
                }
            }
            else {
                Write-Output "          [Default]   $($rolePolicyRule.Id)"
            }

            try {
                Update-MgPolicyRoleManagementPolicyRule `
                    -UnifiedRoleManagementPolicyId $policyAssignment.PolicyId `
                    -UnifiedRoleManagementPolicyRuleId $rolePolicyRule.Id `
                    -BodyParameter $rolePolicyRule
            }
            catch {
                Write-Output $_
                break
            }

            Start-Sleep -Seconds 0.5
        }

        $i++
    }
}
