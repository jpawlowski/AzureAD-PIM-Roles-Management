@{
    # id            = '00000000-0000-0000-0000-000000000000'
    displayName   = @(
        'TEST', # Remove line when policy is fully enabled for production
        $EntraCAPolicyTier0DisplayNamePrefix,
        ('Admin-Users-Allow-Require-' + $EntraCAAuthStrengths[0].account.displayName)
    ) | Join-String -Separator $DisplayNameElementSeparator
    description   = "Require '$($EntraCAAuthStrengths[0].account.displayName)' authentication methods for users without active Tier 0 Roles. DO NOT CHANGE MANUALLY!"
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
            includeGroups  = @(
            )
            excludeGroups = @(
                'breakglass_group'   # always implied by the script, only added here as reminder
            )
        }
    }
    grantControls = @{
        operator               = 'AND'
        AuthenticationStrength = @{
            Id = $EntraCAAuthStrengths[0].account
        }
    }
}
