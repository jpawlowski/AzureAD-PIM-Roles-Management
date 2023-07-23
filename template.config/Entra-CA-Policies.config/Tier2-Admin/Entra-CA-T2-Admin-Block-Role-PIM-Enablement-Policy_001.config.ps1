@{
    # id            = '00000000-0000-0000-0000-000000000000'
    displayName   = @(
        $EntraCAPolicyTier2DisplayNamePrefix,
        (
            'Global-Block-' + `
                $EntraCAAuthContextDisplayNameSuffix + `
            ($EntraCAAuthContexts[2].default.id -replace '\D') + `
                '-Tier2-Roles-MediumHighRisk-SignIns'
        )
    ) | Join-String -Separator $DisplayNameElementSeparator
    description   = "Block PIM role enablement for privileged roles that are assigned to the '$($EntraCAAuthContexts[2].default.displayName)' authentication context when the user is flagged for medium or high sign-in risk. DO NOT CHANGE MANUALLY!"
    state         = 'enabled'       # considered to be 'safe' to enable right away
    conditions    = @{
        applications     = @{
            includeAuthenticationContextClassReferences = @(
                $EntraCAAuthContexts[2].default.id
            )
        }
        users            = @{
            includeUsers  = @(
                'all'
            )
            excludeGroups = @(
                'breakglass_group'   # always implied by the script, only added here as reminder
            )
        }
        signInRiskLevels = @(
            'high'
            'medium'
        )
    }
    grantControls = @{
        operator        = 'AND'
        builtInControls = @(
            'block'
        )
    }
}
