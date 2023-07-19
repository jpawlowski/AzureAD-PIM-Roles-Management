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
                    '-Tier1-Roles-MediumHighRisk-Users'
            )
        ) | Join-String -Separator $DisplayNameElementSeparator
        description   = "Block PIM role enablement for privileged roles that are assigned to the '$($EntraCAAuthContexts[1].default.displayName)' or '$($EntraCAAuthContexts[1].scopable.displayName)' authentication context when the account is flagged as Medium or High Risk User. DO NOT CHANGE MANUALLY!"
        state         = 'enabled'       # considered to be 'safe' to enable right away
        conditions    = @{
            applications   = @{
                includeAuthenticationContextClassReferences = @(
                    $EntraCAAuthContexts[1].default.id
                    $EntraCAAuthContexts[1].scopable.id
                )
            }
            users          = @{
                includeUsers  = @(
                    'all'
                )
                excludeGroups = @(
                    'breakglass_group'   # always implied by the script, only added here as reminder
                )
            }
            userRiskLevels = @(
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
)
