#Requires -Version 7.2

@(
    @{
        # id            = '00000000-0000-0000-0000-000000000000'
        displayName   = @($EntraCAPolicyDisplayNameSuffix, 'CA Name1') | Join-String -Separator $DisplayNameElementSeparator
        description   = ''
        state         = 'enabledForReportingButNotEnforced'
        conditions    = @{
            applications     = @{
                includeApplications = @(
                )
                excludeApplications = @(
                )
            }
            users            = @{
                includeGroups = @(
                )
                excludeGroups = @(
                    $EntraCABreakGlass.group.id
                )
            }
            signInRiskLevels = @(
                'high'
                'medium'
                'low'
            )
        }
        grantControls = @{
            operator        = 'AND'
            builtInControls = @(
            )
        }
    }
)
