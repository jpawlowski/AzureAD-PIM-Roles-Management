@(
    @{
        # id            = '00000000-0000-0000-0000-000000000000'
        displayName   = @(
            'TEST', # Remove line when policy is fully enabled for production
            $EntraCAPolicyTier0DisplayNamePrefix,
            'Scopable-Entra-Roles-Block-Unsupported-Devices'
        ) | Join-String -Separator $DisplayNameElementSeparator
        description   = "Block access for users with active, scopable Tier 0 Roles from any device, except those that are explicitly whitelisted for access.`nUsing a Privileged Access Workstation is not required here under the condition that role assignments to A1C cloud native admin accounts are always restricted to a specific Administration Unit so only a defined set of objects can be changed. DO NOT CHANGE MANUALLY!"
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
                    'tier0_scopable_roles'
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
