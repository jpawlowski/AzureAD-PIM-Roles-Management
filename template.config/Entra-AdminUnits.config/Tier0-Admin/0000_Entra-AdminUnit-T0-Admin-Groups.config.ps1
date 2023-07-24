@{
    # id                           = '00000000-0000-0000-0000-000000000000'
    displayName                  = @($EntraAdminUnitsTier0DisplayNamePrefix, 'S-Entra-Privileged-Role-Admin-Groups', $EntraAdminUnitsRestrictedDisplayNameSuffix) | Join-String -Separator $DisplayNameElementSeparator
    description                  = 'Security groups for Privileged Role Management that can only be changed from Tier0. DO NOT CHANGE!'
    visibility                   = 'HiddenMembership'
    isMemberManagementRestricted = $true
}
