@{
    # id            = '00000000-0000-0000-0000-000000000000'
    displayName   = @(
        'TEST', # Remove line when policy is fully enabled for production
        $EntraCAPolicyTier1DisplayNamePrefix,
        (
            'A0C+A1C+Other-Admins-Allow-' + `
                $EntraCAAuthContextDisplayNameSuffix + `
            ($EntraCAAuthContexts[1].scopable.id -replace '\D') + `
                '-Tier1-Scopable-Roles-Require-' + `
                $EntraCAAuthStrengths[1].scopableRoleEnablement.displayName
        )
    ) | Join-String -Separator $DisplayNameElementSeparator
    description   = "Require '$($EntraCAAuthStrengths[1].scopableRoleEnablement.displayName)' authentication methods before A0C or A1C cloud native admin users may enable a privileged role that is assigned to the '$($EntraCAAuthContexts[1].scopable.displayName)' authentication context in PIM. DO NOT CHANGE MANUALLY!"
    state         = 'enabledForReportingButNotEnforced'     # Change to 'enabled' when ready.
                                                            # As a best practise, update the ID parameter above at the same time.
                                                            # Also, update the displayName above and remove the 'TEST' prefix.
    conditions    = @{
        applications = @{
            includeAuthenticationContextClassReferences = @(
                $EntraCAAuthContexts[1].scopable.id
            )
        }
        users        = @{
            includeUsers  = @(
                'all'
            )
            excludeGroups = @(
                '00000000-0000-0000-0000-000000000001'   # This MUST be a role-assignable group containing all your Tier0 admin (A0C) user accounts. This ensures the group is manually managed by admins with either Global Administrator or Privileged Role Administrator privileges only.
                '00000000-0000-0000-0000-000000000002'   # This SHOULD be a dynamic group containing all your Tier1 admin (A1C) user accounts, e.g. named like CTSO-IAM-D-Entra-Privileged-Role-Tier1-Users. As a best practise, include the condition that the user also needs to have an Entra ID P2 license assigned with enabled service plan.
                '00000000-0000-0000-0000-000000000003'   # This SHOULD be a dynamic group containing all your Tier2 admin (usually any tenant member) user accounts, e.g. named like CTSO-IAM-D-Entra-Privileged-Role-Tier2-Users. As a best practise, include the condition that the user also needs to have an Entra ID P2 license assigned with enabled service plan.
                'breakglass_group'   # always implied by the script, only added here as reminder
            )
        }
    }
    grantControls = @{
        operator               = 'AND'
        AuthenticationStrength = @{
            Id = $EntraCAAuthStrengths[1].scopableRoleEnablement
        }
    }
}
