@(
    @{
        # id            = '00000000-0000-0000-0000-000000000000'
        displayName   = @(
            'TEST',   # Remove line when policy is fully enabled for production
            $EntraCAPolicyTier1DisplayNamePrefix,
            'Entra-Roles-Except-Scopable-Block-Unsupported-Devices'
        ) | Join-String -Separator $DisplayNameElementSeparator
        description   = "Block access for users with active, non-scopable Tier 1 Roles from any device, except those that are explicitly whitelisted for access.`nScopable Tier 1 Roles are excluded because they can be used in Tier 2 under the condition that an appropriate Administrative Unit restricts access to required objects only. DO NOT CHANGE MANUALLY!"
        state         = 'enabledForReportingButNotEnforced'     # Change to 'enabled' when ready.
                                                                # As a best practise, update the ID parameter above at the same time.
                                                                # Also, update the displayName above and remove the 'TEST' prefix.
        conditions    = @{
            applications = @{
                includeApplications = @(
                    'all'
                )
            }
            users        = @{
                includeRoles  = @(
                    'tier1_roles'
                )
                excludeRoles  = @(
                    'tier1_scopable_roles'
                )
                excludeGroups = @(
                    'breakglass_group'   # always implied by the script, only added here as reminder
                )
            }
            platforms    = @{
                includePlatforms = @(
                    'all'
                )
                excludePlatforms = @(
                    'windows'
                    'macOS'
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
