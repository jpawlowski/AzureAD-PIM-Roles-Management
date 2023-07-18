@(
    @{
        # id            = '00000000-0000-0000-0000-000000000000'
        displayName   = @(
            'TEST', # Remove line when policy is fully enabled for production
            $EntraCAPolicyTier0DisplayNamePrefix,
            'Entra-Roles-Except-Scopable-Block-Unsupported-Devices'
        ) | Join-String -Separator $DisplayNameElementSeparator
        description   = "Block access for users with active, non-scopable Tier 0 Roles from any device, except when using a Privileged Access Workstation (PAW).`nScopable Tier 0 Roles are excluded because they can be used in Tier 1 under the condition that an appropriate Administrative Unit restricts access to required objects only."
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
                excludeRoles  = @(
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
                    'Windows'
                )
            }
            devices      = @{
                deviceFilter = @{
                    mode = 'exclude'
                    rule = 'device.extensionAttribute1 -eq "PAW"'
                }
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
