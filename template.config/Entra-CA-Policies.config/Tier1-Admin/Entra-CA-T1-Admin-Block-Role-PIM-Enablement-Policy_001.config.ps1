@(
    @{
        # id            = '00000000-0000-0000-0000-000000000000'
        displayName   = @(
            $EntraCAPolicyTier1DisplayNamePrefix,
            (
                'Global-Block-' + `
                    $EntraCAAuthContextDisplayNameSuffix + `
                ($EntraCAAuthContexts[1].default.id -replace '\D') + `
                    '+' + `
                ($EntraCAAuthContexts[1].scopable.id -replace '\D') + `
                    '-Tier1-Roles-LowMediumHighRisk-SignIns'
            )
        ) | Join-String -Separator $DisplayNameElementSeparator
        description   = "Block PIM role enablement for privileged roles that are assigned to the '$($EntraCAAuthContexts[1].default.displayName)' or '$($EntraCAAuthContexts[1].scopable.displayName)' authentication context when the user is flagged for any sign-in risk. DO NOT CHANGE MANUALLY!"
        state         = 'enabled'       # considered to be 'safe' to enable right away
        conditions    = @{
            applications     = @{
                includeAuthenticationContextClassReferences = @(
                    $EntraCAAuthContexts[1].default.id
                    $EntraCAAuthContexts[1].scopable.id
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
                'low'
            )
        }
        grantControls = @{
            operator        = 'AND'
            builtInControls = @(
                'block'
            )
        }
    }
)
