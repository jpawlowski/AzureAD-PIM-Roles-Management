$AADCABreakGlass = @{
    accounts = @(
        #:-------------------------------------------------------------------------
        # Primary Break Glass Account to exclude from ALL Conditional Access Policies
        #
        # The account MUST be created manually before, and the object ID MUST be given here.
        # The account MUST have Global Administrator role permanently assigned and active.
        # The account MUST be cloud-only, NOT a synced/federated account.
        #
        # See https://learn.microsoft.com/en-us/azure/active-directory/roles/security-emergency-access
        #
        # It is highly recommended to have a dedicated CA policy targeted to this account
        # to have specific MFA methods applied.
        # The backup break glass admin account MUST be excluded from this policy.
        #
        @{
            id                = '00000000-0000-0000-0000-000000000000'
            displayName       = 'COMPANY Emergency Admin (Primary)'
            description       = ''
            userPrincipalName = 'admc-emergency911@tenantname.onmicrosoft.com'
        }

        #:-------------------------------------------------------------------------
        # Backup Break Glass Account to exclude from ALL Conditional Access Policies
        #
        # The account MUST be created manually before, and the object ID MUST be given here.
        # The account MUST have Global Administrator role permanently assigned and active.
        # The account MUST be cloud-only, NOT a synced/federated account.
        #
        # See https://learn.microsoft.com/en-us/azure/active-directory/roles/security-emergency-access
        #
        # This backup break glass admin account MUST be excluded from _ALL_ Conditional Access policies,
        # including the CA policy that is protecting the primary break glass admin account from above.
        #
        @{
            id                = '00000000-0000-0000-0000-000000000000'
            displayName       = 'COMPANY Emergency Admin (Backup)'
            description       = ''
            userPrincipalName = 'admc-emergency912@tenantname.onmicrosoft.com'
        }
    )

    #:-------------------------------------------------------------------------
    # Role-enabled Break Glass Group containing all Break Glass Accounts
    #
    # The group MUST be created manually before with role-assignment capability.
    # The group object ID MUSt be given here.
    # The script will only ensure all break glass accounts are member of this group.
    # The script will also REMOVE any other account from that group.
    #
    group    = @{
        id             = '00000000-0000-0000-0000-000000000000'
        displayName    = 'COMPANY-T0-S-Break-Glass-Admins'
        description    = ''
        roleAssignable = $true
    }
}
