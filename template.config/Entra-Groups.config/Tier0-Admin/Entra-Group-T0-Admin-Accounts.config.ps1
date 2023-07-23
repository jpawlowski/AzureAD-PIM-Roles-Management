@{
    # id                            = '00000000-0000-0000-0000-000000000000'
    displayName                   = @($EntraGroupsTier0DisplayNamePrefix, 'S-Entra-Privileged-Role-Tier0-Users') | Join-String -Separator $DisplayNameElementSeparator
    description                   = 'All A0C cloud native admin users with Microsoft Entra ID Premium P2 license that could enable a privileged role assigned to them either in Tier0, Tier1, or Tier2.'
    visibility                    = 'Private'
    securityEnabled               = $true
    isAssignableToRole            = $false  # We use Admin Unit with isMemberManagementRestricted=$true instead. Using both together is cumbersome when new Tier0 admins need to be added.
    mailEnabled                   = $false
    GroupTypes                    = @(
    )

    # Make sure this group is a member of these Administrative Units
    administrativeUnits           = @(
        @{
            # Id                           = '00000000-0000-0000-0000-000000000000'
            displayName                  = @($EntraGroupsTier0DisplayNamePrefix, 'S-Entra-Privileged-Role-Admin-Groups', 'RestrictedAdminUnit') | Join-String -Separator $DisplayNameElementSeparator
            isMemberManagementRestricted = $true    # This is important to this group, so this property shall be validated
        }
    )
}
