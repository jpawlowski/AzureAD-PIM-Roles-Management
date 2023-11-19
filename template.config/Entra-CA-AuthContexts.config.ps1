#Requires -Version 7.2

$EntraCAAuthContextDisplayNamePrefix = $null
$EntraCAAuthContextDisplayNameSuffix = 'AuthCon'

$EntraCAAuthContexts = @(
    #:-------------------------------------------------------------------------
    # Tier 0 Authentication Contexts
    #
    @{
        default  = @{
            id          = 'c1'
            displayName = @($EntraCAAuthContextDisplayNamePrefix, 'Tier0-Admin', $EntraCAAuthContextDisplayNameSuffix) | Join-String -Separator $DisplayNameElementSeparator
            description = 'Tier0 administration using Privileged Identity Management'
            isAvailable = $true
        }
        scopable = @{
            id          = 'c4'
            displayName = @($EntraCAAuthContextDisplayNamePrefix, 'Tier0-Scoped-Admin', $EntraCAAuthContextDisplayNameSuffix) | Join-String -Separator $DisplayNameElementSeparator
            description = 'Tier 0 administration for scope-enabled roles that could also be used in Tier 1 when scope was assigned'
            isAvailable = $true
        }
    },

    #:-------------------------------------------------------------------------
    # Tier 1 Authentication Contexts
    #
    @{
        default  = @{
            id          = 'c2'
            displayName = @($EntraCAAuthContextDisplayNamePrefix, 'Tier1-Admin', $EntraCAAuthContextDisplayNameSuffix) | Join-String -Separator $DisplayNameElementSeparator
            description = 'Tier1 administration using Privileged Identity Management'
            isAvailable = $true
        }
        scopable = @{
            id          = 'c5'
            displayName = @($EntraCAAuthContextDisplayNamePrefix, 'Tier1-Scoped-Admin', $EntraCAAuthContextDisplayNameSuffix) | Join-String -Separator $DisplayNameElementSeparator
            description = 'Tier 1 administration for scope-enabled roles that could also be used in Tier 2 when scope was assigned'
            isAvailable = $true
        }
    },

    #:-------------------------------------------------------------------------
    # Tier 2 Authentication Contexts
    #
    @{
        default = @{
            id          = 'c3'
            displayName = @($EntraCAAuthContextDisplayNamePrefix, 'Tier2-Admin', $EntraCAAuthContextDisplayNameSuffix) | Join-String -Separator $DisplayNameElementSeparator
            description = 'Tier2 administration using Privileged Identity Management'
            isAvailable = $true
        }
    }

    #:-------------------------------------------------------------------------
    # Common Authentication Contexts for regular user accounts
    #
    @{
    }
)
