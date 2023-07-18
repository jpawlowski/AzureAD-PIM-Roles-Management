@(
    @{
        # id            = '00000000-0000-0000-0000-000000000000'
        displayName   = @(
            $EntraCAPolicyTier0DisplayNamePrefix,
            "Global-Block-" + `
                $EntraCAAuthContextDisplayNameSuffix + `
            ($EntraCAAuthContexts[0].scopable.id -replace '\D') + `
                '-Tier0-Scopable-Roles-Unsupported-Devices'
        ) | Join-String -Separator $DisplayNameElementSeparator
        description   = "Block PIM role enablement for privileged roles that are assigned to the '$($EntraCAAuthContexts[0].scopable.displayName)' authentication context from any device, except those that are explicitly whitelisted."
        state         = 'enabledForReportingButNotEnforced'       # change to 'enabled' when ready. As a best practise, update the ID parameter above at the same time.
        conditions    = @{
            applications = @{
                includeAuthenticationContextClassReferences = @(
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
            platforms    = @{
                includePlatforms = @(
                    'all'
                )
                excludePlatforms = @(
                    'windows'
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
