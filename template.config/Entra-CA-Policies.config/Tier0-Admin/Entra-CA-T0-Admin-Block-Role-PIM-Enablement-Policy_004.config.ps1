@(
    @{
        # id            = '00000000-0000-0000-0000-000000000000'
        displayName   = @(
            $EntraCAPolicyTier0DisplayNamePrefix,
            "Global-Block-" + `
                $EntraCAAuthContextDisplayNameSuffix + `
            ($EntraCAAuthContexts[0].default.id -replace '\D') + `
                '-Tier0-Roles-Unsupported-Devices'
        ) | Join-String -Separator $DisplayNameElementSeparator
        description   = "Block PIM role enablement for privileged roles that are assigned to the '$($EntraCAAuthContexts[0].default.displayName)' authentication context from any device, except when using a Privileged Access Workstation (PAW)."
        state         = 'enabledForReportingButNotEnforced'       # change to 'enabled' when ready. As a best practise, update the ID parameter above at the same time.
        conditions    = @{
            applications = @{
                includeAuthenticationContextClassReferences = @(
                    $EntraCAAuthContexts[0].default.id
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
