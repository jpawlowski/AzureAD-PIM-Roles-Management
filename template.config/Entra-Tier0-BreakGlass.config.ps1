#Requires -Version 7.2

$EntraTier0BreakGlassGroupDisplayNamePrefix = $EntraGroupsTier0DisplayNamePrefix

$EntraTier0BreakGlass = @{

    # Also see https://learn.microsoft.com/en-us/azure/active-directory/roles/security-emergency-access
    #
    accounts   = @(
        #:-------------------------------------------------------------------------
        # Primary Break Glass Account to exclude from MOST Conditional Access Policies
        #
        # The account MUST be created manually before, and the object ID SHOULD be given here.
        # The account SHOULD use the .onmicrosoft.com subdomain as User Principal Name.
        # The account MUST have Global Administrator role permanently assigned and active.
        # The account CAN NOT use transitive role assignment via group.
        # The account MUST be cloud native, NOT a synced/federated account.
        # The account MUST have configured methods for Multi-Factor Authentication.
        #
        # It is highly recommended to have a dedicated CA policy targeted to this account
        # to have specific authentication methods applied.
        # The backup break glass admin account MUST be excluded from that policy.
        #
        @{
            id                    = '00000000-0000-0000-0000-000000000000'
            displayName           = "$CompanyNameShort Emergency Admin (Primary)"
            userPrincipalName     = 'admc-emergency911@tenant.onmicrosoft.com'
            authenticationMethods = @(
                'password'         # Can not be removed as of today, and required to use TOTP
                # 'fido2'          # Replace softwareOathAuthenticationMethod with FIDO2 for phishing resistant authentication without password
                'softwareOath'     # Allows a shared secret, e.g. using a password manager with TOTP support, or printout for temporal setup of a TOTP generator app
            )
            directoryRoles        = @(
                '62e90394-69f5-4237-9190-012177145e10'     # Global Administrator
                # 'e8611ab8-c189-46e8-94e1-60213ab1f814'   # Privileged Role Administrator
            )
        }

        #:-------------------------------------------------------------------------
        # Backup Break Glass Account to exclude from ALL Conditional Access Policies
        #
        # The account MUST be created manually before, and the object ID SHOULD be given here.
        # The account SHOULD use the .onmicrosoft.com subdomain as User Principal Name.
        # The account MUST have Global Administrator role permanently assigned and active.
        # The account CAN NOT use transitive role assignment via group.
        # The account MUST be cloud native, NOT a synced/federated account.
        # The account SHOULD have configured methods for Multi-Factor Authentication.
        #
        # This backup break glass admin account MUST be excluded from _ALL_ Conditional Access policies,
        # including the CA policy that is protecting the primary break glass admin account from above.
        # Authentication methods for this account are not enforced via CA, but SHOULD be set nevertheless.
        #
        @{
            id                    = '00000000-0000-0000-0000-000000000000'
            displayName           = "$CompanyNameShort Emergency Admin (Backup)"
            userPrincipalName     = 'admc-emergency912@tenant.onmicrosoft.com'
            authenticationMethods = @(
                'password'         # Can not be removed as of today
                'fido2'            # Use phishing resistant authentication without password
                # 'softwareOath'   # Replace fido2AuthenticationMethod with TOTP to use a shared secret with decreased security level
            )
            directoryRoles        = @(
                '62e90394-69f5-4237-9190-012177145e10'     # Global Administrator
                # 'e8611ab8-c189-46e8-94e1-60213ab1f814'   # Privileged Role Administrator
            )
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
    group      = @{
        id                 = '00000000-0000-0000-0000-000000000000'
        displayName        = @($EntraTier0BreakGlassGroupDisplayNamePrefix, 'S-Break-Glass-Admins') | Join-String -Separator $DisplayNameElementSeparator
        description        = 'Global group for emergency Break Glass accounts. DO NOT CHANGE!'
        visibility         = 'Private'
        isAssignableToRole = $true
    }

    #:-------------------------------------------------------------------------
    # Administrative Unit to contain the Break Glass objects
    #
    # The admin unit SHOULD have hidden membership configured.
    # The admin unit SHOULD have Management Restrictions enabled.
    # The script might be limited to validate Break Glass with Management Restrictions turned on.
    #
    adminUnit  = @{
        id                           = '00000000-0000-0000-0000-000000000000'
        displayName                  = @($EntraTier0BreakGlassGroupDisplayNamePrefix, 'S-Break-Glass', 'RestrictedAdminUnit') | Join-String -Separator $DisplayNameElementSeparator
        description                  = 'Tier0 objects for Break Glass access. DO NOT CHANGE!'
        visibility                   = 'HiddenMembership'
        isMemberManagementRestricted = $true
    }

    #:-------------------------------------------------------------------------
    # Conditional Access Policies to protect Break Glass Group and Break Glass Backup Account
    #
    caPolicies = @(
        @{
            id                     = '00000000-0000-0000-0000-000000000000'
            displayName            = @($EntraTier0BreakGlassGroupDisplayNamePrefix, 'Break-Glass-Admins-Except-Backup-Allow-Require-MFA') | Join-String -Separator $DisplayNameElementSeparator
            description            = 'Protect Tier0 Break Glass Accounts with MFA, but still exclude a single Backup Breaking Glass Account. DO NOT CHANGE!'
            state                  = 'enabledForReportingButNotEnforced'   # change to 'enabled' when ready
            grantControls          = @{
                operator               = 'OR'
                AuthenticationStrength = @{
                    Id = '00000000-0000-0000-0000-000000000002'     # Built-in Multi-Factor Authentication Strength
                    # Id = '00000000-0000-0000-0000-000000000003'   # Built-in Passwordless MFA Strength
                    # Id = '00000000-0000-0000-0000-000000000004'   # Built-in Phishing Resistant MFA Strength
                }
            }
            breakGlassIncludeUsers = @( 'group', 'primary' )
            breakGlassExcludeUsers = @( 'backup' )   # Separate monitor-only CA policy for the backup Break Glass account
        }
        @{
            id                     = '00000000-0000-0000-0000-000000000000'
            displayName            = @($EntraTier0BreakGlassGroupDisplayNamePrefix, 'Backup-Break-Glass-Admin-Allow-ReportOnly-MFA') | Join-String -Separator $DisplayNameElementSeparator
            description            = 'Monitor Backup Tier0 Break Glass account, but do not protect. DO NOT CHANGE!'
            state                  = 'enabledForReportingButNotEnforced'   # keep this state, it is for monitoring the backup Break Glass account only
            grantControls          = @{
                operator               = 'OR'
                AuthenticationStrength = @{
                    Id = '00000000-0000-0000-0000-000000000002'     # Built-in Multi-Factor Authentication Strength
                    # Id = '00000000-0000-0000-0000-000000000003'   # Built-in Passwordless MFA Strength
                    # Id = '00000000-0000-0000-0000-000000000004'   # Built-in Phishing Resistant MFA Strength
                }
            }
            breakGlassIncludeUsers = @( 'backup' )
            breakGlassExcludeUsers = @( 'none' )
        }
    )
}
