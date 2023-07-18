@(
    @{
        # id            = '00000000-0000-0000-0000-000000000000'
        displayName   = @($EntraCAPolicyTier0DisplayNamePrefix, 'Entra-Roles-Allow-Require-Tier0-Admin-Role-AuthStr') | Join-String -Separator $DisplayNameElementSeparator
        description   = "Require '$($EntraCAAuthStrengths[0].activeRole.displayName)' authentication methods for users with active Tier 0 Roles."
        state         = 'enabledForReportingButNotEnforced'       # change to 'enabled' when ready. As a best practise, update the ID parameter above at the same time.
        conditions    = @{
            applications = @{
                includeApplications = @(
                    'all'
                )

                # # Avoid issues during Windows Enterprise license activation during Windows Autopilot setup of PAW devices.
                # # Only required if Tier0 admin has active Tier0 role during Autopilot setup. Best practise is to remove any active Tier0 role beforehand so this policy does not apply.
                # excludeApplications = @(
                #     '45a330b1-b1ec-4cc1-9161-9f03992aa49f'   # Universal Store Service APIs and Web Application
                # )
            }
            users        = @{
                includeRoles  = @(
                    'tier0_roles'
                )
                excludeGroups = @(
                    'breakglass_group'   # always implied by the script, only added here as reminder
                )
            }
        }
        grantControls = @{
            operator        = 'AND'
            AuthenticationStrength = @{
                Id = $EntraCAAuthStrengths[0].activeRole.Id
            }
        }
    }
)
