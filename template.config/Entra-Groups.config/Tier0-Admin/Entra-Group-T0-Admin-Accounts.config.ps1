@{
    # id                 = '00000000-0000-0000-0000-000000000000'
    displayName        = @($EntraGroupsTier0DisplayNamePrefix, 'S-Entra-Privileged-Role-Tier0-Admins') | Join-String -Separator $DisplayNameElementSeparator
    description        = 'All A0C cloud native admin users that could enable a privileged role assigned to them either in Tier0, Tier1, or Tier2.'
    visibility         = 'Private'
    securityEnabled    = $true
    isAssignableToRole = $true   # Only Global Administrator and Privileged Role Administrator can change this group
    mailEnabled        = $false
    GroupTypes         = @(
    )

    # Make sure this group is a member of these Administrative Units
    administrativeUnit = @(
        @{
            # Id          = '00000000-0000-0000-0000-000000000000'
            displayName = @($EntraGroupsTier0DisplayNamePrefix, 'S-Entra-Privileged-Role-Admin-Groups', 'RestrictedAdminUnit') | Join-String -Separator $DisplayNameElementSeparator
        }
    )
}
