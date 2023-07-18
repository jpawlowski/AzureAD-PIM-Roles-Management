@(
    @{
        # id            = '00000000-0000-0000-0000-000000000000'
        displayName   = @($EntraCAPolicyTier0DisplayNamePrefix, 'Scopable-Entra-Roles-Block-Unsupported-Devices') | Join-String -Separator $DisplayNameElementSeparator
        description   = "Block access for users with active, scopable Tier 0 Roles from any device, except those that are explicitly whitelisted for access.`nUsing a Privileged Access Workstation is not required here under the condition that role assignments to A1C cloud-only admin accounts are always restricted to a specific Administration Unit so only a defined set of objects can be changed."
        state         = 'enabledForReportingButNotEnforced'       # change to 'enabled' when ready. As a best practise, update the ID parameter above at the same time.
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
