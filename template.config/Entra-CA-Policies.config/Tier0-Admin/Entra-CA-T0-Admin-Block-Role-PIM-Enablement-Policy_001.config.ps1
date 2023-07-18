@(
    @{
        # id            = '00000000-0000-0000-0000-000000000000'
        displayName   = @(
            $EntraCAPolicyTier0DisplayNamePrefix,
            (
                'Global-Block-' + `
                    $EntraCAAuthContextDisplayNameSuffix + `
                ($EntraCAAuthContexts[0].default.id -replace '\D') + `
                    '+' + `
                ($EntraCAAuthContexts[0].scopable.id -replace '\D') + `
                    '-Tier0-Roles-LowMediumHighRisk-SignIns'
            )
        ) | Join-String -Separator $DisplayNameElementSeparator
        description   = "Block PIM role enablement for privileged roles that are assigned to the '$($EntraCAAuthContexts[0].default.displayName)' or '$($EntraCAAuthContexts[0].scopable.displayName)' authentication context when the user is flagged for any sign-in risk."
        state         = 'enabled'       # considered to be 'safe' to enable right away
        conditions    = @{
            applications     = @{
                includeAuthenticationContextClassReferences = @(
                    $EntraCAAuthContexts[0].default.id
                    $EntraCAAuthContexts[0].scopable.id
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
