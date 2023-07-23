@{
    # id            = '00000000-0000-0000-0000-000000000000'
    displayName   = @(
        'TEST', # Remove line when policy is fully enabled for production
        $EntraCAPolicyTier2DisplayNamePrefix,
        (
            'Member-Users-Allow-' + `
                $EntraCAAuthContextDisplayNameSuffix + `
            ($EntraCAAuthContexts[2].default.id -replace '\D') + `
                '-Tier2-Roles-Require-' + `
                $EntraCAAuthStrengths[2].roleEnablement.displayName
        )
    ) | Join-String -Separator $DisplayNameElementSeparator
    description   = "Require '$($EntraCAAuthStrengths[2].roleEnablement.displayName)' authentication methods before domain member users may enable a privileged role that is assigned to the '$($EntraCAAuthContexts[2].default.displayName)' authentication context in PIM. DO NOT CHANGE MANUALLY!"
    state         = 'enabledForReportingButNotEnforced'     # Change to 'enabled' when ready.
                                                            # As a best practise, update the ID parameter above at the same time.
                                                            # Also, update the displayName above and remove the 'TEST' prefix.
    conditions    = @{
        applications = @{
            includeAuthenticationContextClassReferences = @(
                $EntraCAAuthContexts[2].default.id
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
            Id = $EntraCAAuthStrengths[2].roleEnablement
        }
    }
}
