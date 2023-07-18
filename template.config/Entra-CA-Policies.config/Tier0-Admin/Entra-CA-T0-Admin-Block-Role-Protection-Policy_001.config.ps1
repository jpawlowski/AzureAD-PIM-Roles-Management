@(
    @{
        # id            = '00000000-0000-0000-0000-000000000000'
        displayName   = @(
            'TEST', # Remove line when policy is fully enabled for production
            $EntraCAPolicyTier0DisplayNamePrefix,
            'Entra-Roles-Block-Unsupported-Locations'
        ) | Join-String -Separator $DisplayNameElementSeparator
        description   = 'Block access for users with active Tier 0 Roles from any country IPv4 and IPv6 address, except from those that are explicitly whitelisted.'
        state         = 'enabledForReportingButNotEnforced'       # change to 'enabled' when ready. As a best practise, update the ID parameter above at the same time. Also, update the displayName above and remove the 'TEST' prefix.
        conditions    = @{
            applications = @{
                includeApplications = @(
                    'all'
                )
            }
            users        = @{
                includeRoles  = @(
                    'tier0_roles'
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
