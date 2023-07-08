$AADCAAuthContextDisplayNamePrefix = $null
$AADCAAuthContextDisplayNameSuffix = 'AuthCon'

$AADCAAuthContexts = @(
    #:-------------------------------------------------------------------------
    # Tier 0 Authentication Contexts
    #
    @{
        default  = @{
            id          = 'c1'
            displayName = @($AADCAAuthContextDisplayNamePrefix, 'Tier0-Admin', $AADCAAuthContextDisplayNameSuffix) | Join-String -Separator $DisplayNameElementSeparator
            description = 'Tier0 administration using Privileged Identity Management'
            isAvailable = $true
        }
        scopable = @{
            id          = 'c4'
            displayName = @($AADCAAuthContextDisplayNamePrefix, 'Tier0-Scoped-Admin', $AADCAAuthContextDisplayNameSuffix) | Join-String -Separator $DisplayNameElementSeparator
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
            displayName = @($AADCAAuthContextDisplayNamePrefix, 'Tier1-Admin', $AADCAAuthContextDisplayNameSuffix) | Join-String -Separator $DisplayNameElementSeparator
            description = 'Tier1 administration using Privileged Identity Management'
            isAvailable = $true
        }
        scopable = @{
            id          = 'c5'
            displayName = @($AADCAAuthContextDisplayNamePrefix, 'Tier1-Scoped-Admin', $AADCAAuthContextDisplayNameSuffix) | Join-String -Separator $DisplayNameElementSeparator
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
            displayName = @($AADCAAuthContextDisplayNamePrefix, 'Tier2-Admin', $AADCAAuthContextDisplayNameSuffix) | Join-String -Separator $DisplayNameElementSeparator
            description = 'Tier2 administration using Privileged Identity Management'
            isAvailable = $true
        }
    }
)
