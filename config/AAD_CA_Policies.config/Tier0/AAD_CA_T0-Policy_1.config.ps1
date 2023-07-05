@(
    @{
        displayName   = @($AADCAPolicyDisplayNameSuffix, 'CA Name1') | Join-String -Separator '-'
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
