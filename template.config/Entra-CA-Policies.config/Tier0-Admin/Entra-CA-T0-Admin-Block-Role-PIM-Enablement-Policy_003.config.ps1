@(
    @{
        # id            = '00000000-0000-0000-0000-000000000000'
        displayName   = @(
            'TEST', # Remove line when policy is fully enabled for production
            $EntraCAPolicyTier0DisplayNamePrefix,
            (
                'Global-Block-' + `
                    $EntraCAAuthContextDisplayNameSuffix + `
                ($EntraCAAuthContexts[0].default.id -replace '\D') + `
                    '+' + `
                ($EntraCAAuthContexts[0].scopable.id -replace '\D') + `
                    '-Tier0-Roles-Unsupported-Locations'
            )
        ) | Join-String -Separator $DisplayNameElementSeparator
        description   = "Block PIM role enablement for privileged roles that are assigned to the '$($EntraCAAuthContexts[0].default.displayName)' or '$($EntraCAAuthContexts[0].scopable.displayName)' authentication context from any location, except from those that are explicitly whitelisted."
        state         = 'enabledForReportingButNotEnforced'       # change to 'enabled' when ready. As a best practise, update the ID parameter above at the same time. Also, update the displayName above and remove the 'TEST' prefix.
        conditions    = @{
            applications = @{
                includeAuthenticationContextClassReferences = @(
                    $EntraCAAuthContexts[0].default.id
                    $EntraCAAuthContexts[0].scopable.id
                )
            }
            users        = @{
                includeUsers  = @(
                    'all'
                )
                excludeGroups = @(
                    'breakglass_group'   # always implied by the script, only added here as reminder
                )
            }
            locations    = @{
                includeLocations = @(
                    'all'
                )
                excludeLocations = @(
                    $EntraCANamedLocations[0]
                )
            }
        }
        grantControls = @{
            operator        = 'AND'
            builtInControls = @(
                'block'
            )
        }
    }
)
