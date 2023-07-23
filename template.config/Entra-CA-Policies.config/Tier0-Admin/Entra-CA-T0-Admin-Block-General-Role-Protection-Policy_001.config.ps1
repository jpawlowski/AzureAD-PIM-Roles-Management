@{
    # id            = '00000000-0000-0000-0000-000000000000'
    displayName   = @(
        $EntraCAPolicyTier0DisplayNamePrefix,
        'All-Entra-Roles-Except-Tier2-Block-HighRisk-SignIns'
    ) | Join-String -Separator $DisplayNameElementSeparator
    description   = 'Block access for High Risk sign-ins for accounts with any active Entra ID role, except roles from Tier 2 that could be assigned to any type of user. DO NOT CHANGE MANUALLY!'
    state         = 'enabled'       # considered to be 'safe' to enable right away
    conditions    = @{
        applications     = @{
            includeApplications = @(
                'all'
            )
        }
        users            = @{
            includeRoles  = @(
                'all'                # all roles available in the tenant, not only known roles from config file Entra-Role-Classifications.config.ps1
                'tier0_roles'
                'tier1_roles'
            )
            excludeRoles  = @(
                'tier2_roles'        # exclude Tier2 roles as these are assigned to regular user accounts and protected by common CA policies instead
            )
            excludeGroups = @(
                'breakglass_group'   # always implied by the script, only added here as reminder
            )
        }
        signInRiskLevels = @(
            'high'
        )
    }
    grantControls = @{
        operator        = 'AND'
        builtInControls = @(
            'block'
        )
    }
}
