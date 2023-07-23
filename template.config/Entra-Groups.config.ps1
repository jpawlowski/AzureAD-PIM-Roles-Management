#Requires -Version 7.2

$EntraGroupsDisplayNamePrefix = $CompanyNameShort
$EntraGroupsTier0DisplayNamePrefix = @($EntraGroupsDisplayNamePrefix, 'T0') | Join-String -Separator $DisplayNameElementSeparator
$EntraGroupsTier1DisplayNamePrefix = @($EntraGroupsDisplayNamePrefix, 'T1') | Join-String -Separator $DisplayNameElementSeparator
$EntraGroupsTier2DisplayNamePrefix = @($EntraGroupsDisplayNamePrefix, 'T2') | Join-String -Separator $DisplayNameElementSeparator

$EntraGroupsConfigSubfolder = 'Entra-Groups.config'

$Tier0AdminAccountRegex = '^A0C_.+@' + [regex]::Escape($TenantName) + '$'
$Tier1AdminAccountRegex = '^A1C_.+@' + [regex]::Escape($TenantName) + '$'

$EntraGroupsPrivilegedRoleUserGroups = @(
    @{
        # id                            = '00000000-0000-0000-0000-000000000000'
        displayName         = @($EntraGroupsTier0DisplayNamePrefix, 'S-Entra-Privileged-Role-Tier0-Users') | Join-String -Separator $DisplayNameElementSeparator
        description         = 'All A0C cloud native admin users with Microsoft Entra ID Premium P2 license that could enable a privileged role assigned to them either in Tier0, Tier1, or Tier2.'
        visibility          = 'Private'
        securityEnabled     = $true
        isAssignableToRole  = $false  # We use Admin Unit with isMemberManagementRestricted=$true instead. Using both together is cumbersome when new Tier0 admins need to be added.
        mailEnabled         = $false
        GroupTypes          = @(
        )

        # Make sure this group is a member of these Administrative Units
        administrativeUnits = @(
            @{
                # Id                           = '00000000-0000-0000-0000-000000000000'
                displayName                  = @($EntraGroupsTier0DisplayNamePrefix, 'S-Entra-Privileged-Role-Admin-Groups', 'RestrictedAdminUnit') | Join-String -Separator $DisplayNameElementSeparator
                isMemberManagementRestricted = $true    # This is important to this group, so this property shall be validated
            }
        )
    }

    @{
        # id                            = '00000000-0000-0000-0000-000000000000'
        displayName                   = @($EntraGroupsTier1DisplayNamePrefix, 'D-Entra-Privileged-Role-Tier1-Users') | Join-String -Separator $DisplayNameElementSeparator
        description                   = 'All A1C cloud native admin users with Microsoft Entra ID Premium P2 license that could enable a privileged role assigned to them either in Tier1 or Tier2.'
        visibility                    = 'Private'
        securityEnabled               = $true
        isAssignableToRole            = $false
        mailEnabled                   = $false
        GroupTypes                    = @(
            'DynamicMembership'
        )

        # Using a dynamic group is more convenient and should be okay for Tier1 admin accounts
        membershipRule                = @(
            '(user.objectId -ne null) and'
            '(user.userType -eq "Member") and'
            '(user.userPrincipalName -match "' + $Tier1AdminAccountRegex + '") and'
            '(user.userPrincipalName -notMatch "^.+#EXT#@.+\.onmicrosoft\.com$") and'   # B2B accounts could also have userType=Member, so explicitly exclude them here
            '(user.assignedPlans -any (assignedPlan.servicePlanId -eq "eec0eb4f-6444-4f95-aba0-50c24d67f998" -and assignedPlan.capabilityStatus -eq "Enabled"))'
        ) | Join-String -Separator " `n"
        membershipRuleProcessingState = 'On';

        # Make sure this group is a member of these Administrative Units
        administrativeUnits           = @(
            @{
                # Id                           = '00000000-0000-0000-0000-000000000000'
                displayName                  = @($EntraGroupsTier0DisplayNamePrefix, 'S-Entra-Privileged-Role-Admin-Groups', 'RestrictedAdminUnit') | Join-String -Separator $DisplayNameElementSeparator
                isMemberManagementRestricted = $true    # This is important to this group, so this property shall be validated
            }
        )
    }

    @{
        # id                            = '00000000-0000-0000-0000-000000000000'
        displayName                   = @($EntraGroupsTier2DisplayNamePrefix, 'D-Entra-Privileged-Role-Tier2-Users') | Join-String -Separator $DisplayNameElementSeparator
        description                   = 'All member users in the tenant with Microsoft Entra ID Premium P2 license that could enable a privileged role assigned to them in Tier2.'
        visibility                    = 'Private'
        securityEnabled               = $true
        isAssignableToRole            = $false
        mailEnabled                   = $false
        GroupTypes                    = @(
            'DynamicMembership'
        )

        # Using a dynamic group is more convenient and should be okay for Tier1 admin accounts
        membershipRule                = @(
            '(user.objectId -ne null) and'
            '(user.userType -eq "Member") and'
            '(user.userPrincipalName -notMatch "' + $Tier0AdminAccountRegex + '") and'
            '(user.userPrincipalName -notMatch "' + $Tier1AdminAccountRegex + '") and'
            '(user.userPrincipalName -notMatch "^.+#EXT#@.+\.onmicrosoft\.com$") and'   # B2B accounts could also have userType=Member, so explicitly exclude them here
            '(user.assignedPlans -any (assignedPlan.servicePlanId -eq "eec0eb4f-6444-4f95-aba0-50c24d67f998" -and assignedPlan.capabilityStatus -eq "Enabled"))'
        ) | Join-String -Separator " `n"
        membershipRuleProcessingState = 'On';

        # Make sure this group is a member of these Administrative Units
        administrativeUnits           = @(
            @{
                # Id                           = '00000000-0000-0000-0000-000000000000'
                displayName                  = @($EntraGroupsTier0DisplayNamePrefix, 'S-Entra-Privileged-Role-Admin-Groups', 'RestrictedAdminUnit') | Join-String -Separator $DisplayNameElementSeparator
                isMemberManagementRestricted = $true    # This is important to this group, so this property shall be validated
            }
        )
    }
)
