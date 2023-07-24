@{
    # id            = '00000000-0000-0000-0000-000000000000'
    displayName   = @(
        'TEST', # Remove line when policy is fully enabled for production
        $EntraCAPolicyTier1DisplayNamePrefix,
        (
            'Global-Block-' + `
                $EntraCAAuthContextDisplayNameSuffix + `
            ($EntraCAAuthContexts[1].default.id -replace '\D') + `
                '+' + `
            ($EntraCAAuthContexts[1].scopable.id -replace '\D') + `
                '-Tier1-Roles-Unsupported-Locations'
        )
    ) | Join-String -Separator $DisplayNameElementSeparator
    description   = "Block PIM role enablement for privileged roles that are assigned to the '$($EntraCAAuthContexts[1].default.displayName)' or '$($EntraCAAuthContexts[1].scopable.displayName)' authentication context from any location, except from those that are explicitly whitelisted. DO NOT CHANGE MANUALLY!"
    state         = 'enabledForReportingButNotEnforced'     # Change to 'enabled' when ready.
                                                            # As a best practise, update the ID parameter above at the same time.
                                                            # Also, update the displayName above and remove the 'TEST' prefix.
    conditions    = @{
        applications = @{
            includeAuthenticationContextClassReferences = @(
                $EntraCAAuthContexts[1].default.id
                $EntraCAAuthContexts[1].scopable.id
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
                $EntraCANamedLocations[1]
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
