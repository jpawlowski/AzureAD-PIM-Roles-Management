@(
    @{
        # id            = '00000000-0000-0000-0000-000000000000'
        displayName   = @(
            'TEST', # Remove line when policy is fully enabled for production
            $EntraCAPolicyTier1DisplayNamePrefix,
            'Entra-Roles-Allow-Require-' + $EntraCAAuthStrengths[1].activeRole.displayName
        ) | Join-String -Separator $DisplayNameElementSeparator
        description   = "Require '$($EntraCAAuthStrengths[1].activeRole.displayName)' authentication methods for A1C cloud-only admins and users with active Tier 1 Roles."
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
                excludeGroups = @(
                    'breakglass_group'   # always implied by the script, only added here as reminder
                )
            }
        }
        grantControls = @{
            operator               = 'AND'
            AuthenticationStrength = @{
                Id = $EntraCAAuthStrengths[1].activeRole.Id
            }
        }
    }
)
