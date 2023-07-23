@{
    # id            = '00000000-0000-0000-0000-000000000000'
    displayName   = @(
        'TEST', # Remove line when policy is fully enabled for production
        $EntraCAPolicyTier0DisplayNamePrefix,
        (
            'Global-Except-A0C-Admins-Block-' + `
                $EntraCAAuthContextDisplayNameSuffix + `
            ($EntraCAAuthContexts[0].default.id -replace '\D') + `
                '-Tier0-Roles'
        )
    ) | Join-String -Separator $DisplayNameElementSeparator
    description   = "Block PIM role enablement for privileged roles that are assigned to the '$($EntraCAAuthContexts[0].default.displayName)' authentication context for everyone, except for A0C cloud native admins. DO NOT CHANGE MANUALLY!"
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
        operator        = 'AND'
        builtInControls = @(
            'block'
        )
    }
}
