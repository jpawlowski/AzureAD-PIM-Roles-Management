@(
    @{
        # id            = '00000000-0000-0000-0000-000000000000'
        displayName   = @(
            'TEST', # Remove line when policy is fully enabled for production
            $EntraCAPolicyTier0DisplayNamePrefix,
            (
                'A0C-Admins-Allow-' + `
                    $EntraCAAuthContextDisplayNameSuffix + `
                ($EntraCAAuthContexts[0].default.id -replace '\D') + `
                    '-Tier0-Roles-Require-' + `
                    $EntraCAAuthStrengths[0].roleEnablement.displayName
            )
        ) | Join-String -Separator $DisplayNameElementSeparator
        description   = "Require '$($EntraCAAuthStrengths[0].roleEnablement.displayName)' authentication methods before A0C cloud native admin users may enable a privileged role that is assigned to the '$($EntraCAAuthContexts[0].default.displayName)' authentication context in PIM. DO NOT CHANGE MANUALLY!"
        state         = 'enabledForReportingButNotEnforced'     # Change to 'enabled' when ready.
                                                                # As a best practise, update the ID parameter above at the same time.
                                                                # Also, update the displayName above and remove the 'TEST' prefix.
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
                    '00000000-0000-0000-0000-000000000001'   # This MUST be a role-assignable group containing all your Tier0 admin (A0C) user accounts. This ensures the group is manually managed by admins with either Global Administrator or Privileged Role Administrator privileges only.
                    'breakglass_group'   # always implied by the script, only added here as reminder
                )
            }
        }
        grantControls = @{
            operator               = 'AND'
            AuthenticationStrength = @{
                Id = $EntraCAAuthStrengths[0].roleEnablement.Id
            }
        }
    }
)
