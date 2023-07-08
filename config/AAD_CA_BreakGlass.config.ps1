$AADCABreakGlassGroupDisplayNamePrefix = $AADGroupDisplayNamePrefix

$AADCABreakGlass = @{

    # Also see https://learn.microsoft.com/en-us/azure/active-directory/roles/security-emergency-access
    #
    accounts = @(
        #:-------------------------------------------------------------------------
        # Primary Break Glass Account to exclude from MOST Conditional Access Policies
        #
        # The account MUST be created manually before, and the object ID SHOULD be given here.
        # The account SHOULD use the .onmicrosoft.com subdomain as User Principal Name.
        # The account MUST have Global Administrator role permanently assigned and active.
        # The account CAN NOT use transitive role assignment via group.
        # The account MUST be cloud-only, NOT a synced/federated account.
        # The account MUST have configured methods for Multi-Factor Authentication.
        #
        # It is highly recommended to have a dedicated CA policy targeted to this account
        # to have specific authentication methods applied.
        # The backup break glass admin account MUST be excluded from that policy.
        #
        @{
            id                    = '00000000-0000-0000-0000-000000000000'
            displayName           = "$CompanyName Emergency Admin (Primary)"
            userPrincipalName     = 'admc-emergency911@vxdc2.onmicrosoft.com'
            authenticationMethods = @(
                '#microsoft.graph.passwordAuthenticationMethod'         # Can not be removed as of today, and required to use TOTP
                # '#microsoft.graph.fido2AuthenticationMethod'          # Replace softwareOathAuthenticationMethod with FIDO2 for phishing resistant authentication without password
                '#microsoft.graph.softwareOathAuthenticationMethod'     # Allows a shared secret, e.g. using a password manager with TOTP support, or printout for temporal setup of a TOTP generator app
            )
        }

        #:-------------------------------------------------------------------------
        # Backup Break Glass Account to exclude from ALL Conditional Access Policies
        #
        # The account MUST be created manually before, and the object ID SHOULD be given here.
        # The account SHOULD use the .onmicrosoft.com subdomain as User Principal Name.
        # The account MUST have Global Administrator role permanently assigned and active.
        # The account CAN NOT use transitive role assignment via group.
        # The account MUST be cloud-only, NOT a synced/federated account.
        # The account SHOULD have configured methods for Multi-Factor Authentication.
        #
        # This backup break glass admin account MUST be excluded from _ALL_ Conditional Access policies,
        # including the CA policy that is protecting the primary break glass admin account from above.
        # Authentication methods for this account are not enforced via CA, but SHOULD be set nevertheless.
        #
        @{
            id                            = '00000000-0000-0000-0000-000000000000'
            displayName                   = "$CompanyName Emergency Admin (Backup)"
            userPrincipalName             = 'admc-emergency912@vxdc2.onmicrosoft.com'
            authenticationMethods         = @(
                '#microsoft.graph.passwordAuthenticationMethod'         # Can not be removed as of today
                '#microsoft.graph.fido2AuthenticationMethod'            # Use phishing resistant authentication without password
                # '#microsoft.graph.softwareOathAuthenticationMethod'   # Replace fido2AuthenticationMethod with TOTP to use a shared secret with decreased security level
            )
            excludeFromBreakGlassCAPolicy = $true
        }
    )

    #:-------------------------------------------------------------------------
    # Role-enabled Break Glass Group containing all Break Glass Accounts
    #
    # The group MUST be created manually before with role-assignment capability.
    # The group CAN NOT be onboarded to Privileged Identity Management.
    # The group object ID MUST be given here.
    # The script will only ensure all break glass accounts are member of this group.
    # The script will also REMOVE any other account from that group.
    #
    group    = @{
        id                 = '84218b7e-344e-4a3f-a4e2-049bfb1f3059'
        displayName        = @($AADCABreakGlassGroupDisplayNamePrefix, 'T0-S-Break-Glass-Admins') | Join-String -Separator $DisplayNameElementSeparator
        description        = 'Global group for emergency Break Glass accounts. DO NOT CHANGE!'
        isAssignableToRole = $true
    }
}