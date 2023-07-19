@(
    @{
        # id            = '00000000-0000-0000-0000-000000000000'
        displayName   = @(
            $EntraCAPolicyTier2DisplayNamePrefix,
            (
                'Global-Block-' + `
                    $EntraCAAuthContextDisplayNameSuffix + `
                ($EntraCAAuthContexts[2].default.id -replace '\D') + `
                    '-Tier2-Roles-HighRisk-Users'
            )
        ) | Join-String -Separator $DisplayNameElementSeparator
        description   = "Block PIM role enablement for privileged roles that are assigned to the '$($EntraCAAuthContexts[2].default.displayName)' authentication context when the account is flagged as High Risk User. DO NOT CHANGE MANUALLY!"
        state         = 'enabled'       # considered to be 'safe' to enable right away
        conditions    = @{
            applications   = @{
                includeAuthenticationContextClassReferences = @(
                    $EntraCAAuthContexts[2].default.id
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
