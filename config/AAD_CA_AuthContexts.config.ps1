$AADCAAuthContextDisplayNameSuffix = ''

$AADCAAuthContexts = @(
    #:-------------------------------------------------------------------------
    # Tier 0 Authentication Contexts
    #
    @{
        default  = @{
            id          = 'c1'
            displayName = @($AADCAAuthContextDisplayNameSuffix, 'Tier0-Admin-AuthCon') | Join-String -Separator '-'
            description = 'Tier0 administration using Privileged Identity Management'
            isAvailable = $true
        }
        scopable = @{
            id          = 'c4'
            displayName = @($AADCAAuthContextDisplayNameSuffix, 'Tier0-Scoped-Admin-AuthCon') | Join-String -Separator '-'
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
            displayName = @($AADCAAuthContextDisplayNameSuffix, 'Tier1-Admin-AuthCon') | Join-String -Separator '-'
            description = 'Tier1 administration using Privileged Identity Management'
            isAvailable = $true
        }
        scopable = @{
            id          = 'c5'
            displayName = @($AADCAAuthContextDisplayNameSuffix, 'Tier1-Scoped-Admin-AuthCon') | Join-String -Separator '-'
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
            displayName = @($AADCAAuthContextDisplayNameSuffix, 'Tier2-Admin-AuthCon') | Join-String -Separator '-'
            description = 'Tier2 administration using Privileged Identity Management'
            isAvailable = $true
        }
    }
)
