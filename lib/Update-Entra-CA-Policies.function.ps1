<#
.SYNOPSIS

.DESCRIPTION

.LINK
    https://github.com/jpawlowski/AzureAD-PIM-Roles-Management

.NOTES
    Filename: Update-Entra-CA-Policies.function.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
#>
#Requires -Version 7.2
#Requires -Modules @{ ModuleName='Microsoft.Graph.Beta.Identity.DirectoryManagement'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Users'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Groups'; ModuleVersion='2.0' }

$MgScopes += 'Application.Read.All'
$MgScopes += 'Policy.Read.All'
$MgScopes += 'Policy.ReadWrite.ConditionalAccess'

function Update-Entra-CA-Policies {
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'High'
    )]
    Param (
        [array]$Config,
        [switch]$TierCAPolicies,
        [switch]$CommonCAPolicies,
        [string[]]$Id,
        [string[]]$Name,
        [switch]$Tier0,
        [switch]$Tier1,
        [switch]$Tier2,
        [switch]$Force
    )

    $ConfigLevels = @();

    if ($TierCAPolicies -or $Tier0 -or $Tier1 -or $Tier2) {
        if ($Tier0) {
            $ConfigLevels += 0
        }
        if ($Tier1) {
            $ConfigLevels += 1
        }
        if ($Tier2) {
            $ConfigLevels += 2
        }
        if ($ConfigLevels.Count -eq 0) {
            $ConfigLevels = @(0, 1, 2)
        }
    }

    if ($CommonCAPolicies -or !$TierCAPolicies) {
        $ConfigLevels += 3
    }

    # Confirm Break Glass Group once more
    if (
        ($null -ne $EntraTier0BreakGlass.group.id) -and
        ($EntraTier0BreakGlass.group.id -notmatch '^00000000-') -and
        ($EntraTier0BreakGlass.group.id -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$')
    ) {
        Write-Debug "Detected Break Glass Group object ID: $($EntraTier0BreakGlass.group.id)"
    }
    elseif ($EntraTier0BreakGlass.group.displayName) {
        $result = Get-MgGroup -All -Filter "displayName eq '$($EntraTier0BreakGlass.group.displayName)'"
        if (($result | Measure-Object).Count -gt 1) {
            Write-Error "Break Glass Group displayName is not unique!"
            throw
        }
        if ($result.Id) {
            if (!$WhatIfPreference) { Write-Warning "+++IMPORTANT+++   You are STRONGLY advised to complete your Break Glass Group definition by adding the unique object ID '$($result.Id)' to the configuration file before implementing Conditional Access Policies !   +++IMPORTANT+++" }
            $EntraTier0BreakGlass.group.id = $result.Id
        }
        else {
            Write-Error "FATAL: Could not find defined Break Glass Group '$($EntraTier0BreakGlass.group.displayName)' !"
            throw
        }
    }
    else {
        Write-Error "FATAL: Break Glass Group definition must be valid to process Conditional Access Policies !"
        throw
    }

    $caBreakGlassPolicies = @()
    foreach ($policy in $EntraTier0BreakGlass.caPolicies) {
        if (
            ($null -ne $policy.id) -and
            ($policy.id -notmatch '^00000000-') -and
            ($policy.id -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$')
        ) {
            Write-Debug "Detected Break Glass CA Policy object ID: $($policy.id)"
        }
        elseif ($policy.displayName) {
            $result = Get-MgIdentityConditionalAccessPolicy -All -Filter "displayName eq '$($policy.displayName)'"
            if (($result | Measure-Object).Count -gt 1) {
                Write-Error "Break Glass CA Policy displayName is not unique!"
                throw
            }
            if ($result.Id) {
                if (!$WhatIfPreference) { Write-Warning "+++IMPORTANT+++   You are STRONGLY advised to complete your Break Glass CA definition by adding the unique object ID '$($result.Id)' to the configuration file before implementing Conditional Access Policies !      +++IMPORTANT+++" }
                $policy.id = $result.Id
            }
            else {
                Write-Error "FATAL: Could not find defined Break Glass CA Policy '$($policy.displayName)' !"
                throw
            }
        }
        else {
            Write-Error "FATAL: Break Glass CA Policy definition must be valid to process Conditional Access Policies !"
            throw
        }
        $caBreakGlassPolicies += $policy.id
    }

    # Before anything else, make sure that Break Glass Group is in excludeGroups of ANY Conditional Access Policy
    $fallbackMissingCA = Get-MgIdentityConditionalAccessPolicy -All -Filter "not conditions/users/excludeGroups/any(x: x eq '$($EntraTier0BreakGlass.group.id)')$($caBreakGlassPolicies | ForEach-Object { " and Id ne '$_'" } | Join-String)"
    if ($fallbackMissingCA) {
        if ($Force) {
            Write-Warning "Conditional Access Consistency Check: $($fallbackMissingCA.Count) policies missing Break Glass Group in their exclusion list !"
        }
        elseif ($WhatIfPreference -or $PSCmdlet.ShouldContinue(
                "There are  $($fallbackMissingCA.Count)  Conditional Access Policies missing to exclude the Break Glass Group '$($EntraTier0BreakGlass.group.displayName)'.`nWould you like to start fixing this now?",
                "Conditional Access Consistency Check"
            )) {
            foreach ($policy in $fallbackMissingCA) {
                if ($PSCmdlet.ShouldProcess(
                        "[Conditional Access Consistency Check] Update exclusion list of policy $($policy.id) ($($policy.displayName)) with Break Glass Group '$($EntraTier0BreakGlass.group.displayName)'",
                        "Do you confirm to add Break Glass Group '$($EntraTier0BreakGlass.group.displayName)' to the exclusion list of this Conditional Access Policy?",
                        "FIX Conditional Access Policy $($policy.id) ($($policy.displayName))"
                    )) {
                    $BodyParameter = @{
                        conditions    = @{
                            users        = @{
                                excludeGroups = $fallbackMissingCA.Conditions.Users.ExcludeGroups ? $fallbackMissingCA.Conditions.Users.ExcludeGroups : @()
                            }
                        }
                    }
                    $BodyParameter.conditions.users.excludeGroups += $EntraTier0BreakGlass.group.id
                    Write-Verbose "Conditional Access Consistency Check: Updating Conditional Access Policy $($policy.id) ($($policy.displayName)) [state = $($policy.state)]"
                    Write-Debug "BodyParameter:`n$($BodyParameter | ConvertTo-Json -Depth 10)"
                    $null = Update-MgIdentityConditionalAccessPolicy `
                        -ConditionalAccessPolicyId $policy.Id `
                        -BodyParameter $BodyParameter `
                        -ErrorAction Stop `
                        -Confirm:$false
                }
            }
        }
    }

    $i = 0
    foreach ($ConfigLevel in $ConfigLevels) {
        if (
            ($null -eq $Config[$ConfigLevel]) -or
            ($Config[$ConfigLevel].Count -eq 0)
        ) {
            $i++
            continue
        }

        if ($ConfigLevel -le $EntraMaxAdminTier) {
            $Subject = "Tier $ConfigLevel"
        }
        else {
            $Subject = "Common"
        }

        # Validate unique config items
        [array]$list = @()
        foreach ($ConfigItem in $Config[$ConfigLevel]) {
            if (
                (-Not $ConfigItem.displayName) -or
                (-Not $ConfigItem.description) -or
                (-Not $ConfigItem.state) -or
                (-Not $ConfigItem.conditions) -or
                (-Not $ConfigItem.grantControls)
            ) {
                Write-Warning "[$Subject] SKIPPED Conditional Access Policy: Ignored incomplete object from file $(Join-Path (Split-Path (Split-Path $ConfigItem.FileOrigin -Parent) -Leaf) ($ConfigItem.FileOrigin.Name))"
                continue
            }

            $otherObjs = $Config[$ConfigLevel] | Where-Object -FilterScript { (($null -ne $_.id) -and ($_.id -eq $ConfigItem.id)) -or (($null -ne $_.displayName) -and ($_.displayName -eq $ConfigItem.displayName)) }
            if (($otherObjs | Measure-Object).Count -gt 1) {
                Write-Warning "[$Subject] SKIPPED Conditional Access Policy: '$($ConfigItem.displayName)' ($($ConfigItem.id)) is defined for this configuration level already [File: $(Join-Path (Split-Path (Split-Path $ConfigItem.FileOrigin -Parent) -Leaf) ($ConfigItem.FileOrigin.Name))]"
                continue
            }

            $PreviousConfigLevel = $ConfigLevel - 1;
            $duplicate = $false
            do {
                $otherObjs = $Config[$PreviousConfigLevel] | Where-Object -FilterScript { (($null -ne $_.id) -and ($_.id -eq $ConfigItem.id)) -or (($null -ne $_.displayName) -and ($_.displayName -eq $ConfigItem.displayName)) }
                if (($otherObjs | Measure-Object).Count -gt 0) {
                    Write-Warning "[$Subject] SKIPPED Conditional Access Policy: '$($ConfigItem.displayName)' ($($ConfigItem.id)) is a duplicate from higher configuration level $PreviousConfigLevel [File: $(Join-Path (Split-Path (Split-Path $ConfigItem.FileOrigin -Parent) -Leaf) ($ConfigItem.FileOrigin.Name))]"
                    $duplicate = $true
                }
                $PreviousConfigLevel--
            } while (
                $PreviousConfigLevel -ge 0
            )
            if ($duplicate) {
                continue
            }

            $NextConfigLevel = $ConfigLevel + 1;
            $duplicate = $false
            do {
                $otherObjs = $Config[$NextConfigLevel] | Where-Object -FilterScript { (($null -ne $_.id) -and ($_.id -eq $ConfigItem.id)) -or (($null -ne $_.displayName) -and ($_.displayName -eq $ConfigItem.displayName)) }
                if (($otherObjs | Measure-Object).Count -gt 0) {
                    Write-Warning "[$Subject] SKIPPED Conditional Access Policy: '$($ConfigItem.displayName)' ($($ConfigItem.id)) has a duplicate at lower configuration level $NextConfigLevel [File: $(Join-Path (Split-Path (Split-Path $ConfigItem.FileOrigin -Parent) -Leaf) ($ConfigItem.FileOrigin.Name))]"
                    $duplicate = $true
                }
                $NextConfigLevel++
            } while (
                $NextConfigLevel -le $Config.Count
            )
            if ($duplicate) {
                continue
            }

            # If only selected items shall be worked on
            if ($Id -or $Name) {
                Write-Debug "[$Subject] Conditional Access Policy: Whitelist processing enabled"

                $found = $false
                if (
                    $Id -and
                    $ConfigItem.Id -and
                    ($ConfigItem.id -notmatch '^00000000-') -and
                    ($ConfigItem.id -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$') -and
                    ($ConfigItem.Id -in $Id)
                ) {
                    Write-Debug "[$Subject] Conditional Access Policy whitelist: Found $($ConfigItem.Id)"
                    $found = $true
                }
                elseif (
                    $Name -and
                    $ConfigItem.displayName -and
                    ($ConfigItem.displayName -in $Name)
                ) {
                    Write-Debug "[$Subject] Conditional Access Policy whitelist: Found $($ConfigItem.displayName)"
                    $found = $true
                }
                if (-Not $found) {
                    continue
                }
            }

            if (
                ($ConfigItem.state -eq 'enabled') -and
                (
                    ($null -eq $ConfigItem.id) -or
                    ($ConfigItem.id -match '^00000000-') -or
                    ($ConfigItem.id -notmatch '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$')
                )
            ) {
                Write-Warning "[$Subject] SKIPPED Conditional Access Policy: '$($ConfigItem.displayName)' ($($ConfigItem.id)) Policies with state=enabled require to have a valid object ID set for safety reasons [File: $(Join-Path (Split-Path (Split-Path $ConfigItem.FileOrigin -Parent) -Leaf) ($ConfigItem.FileOrigin.Name))]"
                continue
            }

            $list += $ConfigItem
        }

        if ($list.Count -eq 0) {
            $i++
            continue
        }

        $list = $list | Sort-Object -Property displayName

        $PercentComplete = $i / $ConfigLevels.Count * 100
        $params = @{
            Activity         = 'Working on                       '
            Status           = " $([math]::floor($PercentComplete))% Complete: $Subject"
            PercentComplete  = $PercentComplete
            CurrentOperation = 'EntraCAPoliciesConfigLevel'
        }
        Write-Progress @params

        if ($Force -or $WhatIfPreference -or $PSCmdlet.ShouldContinue(
                "Would you like to check a total of  $($list.Count)  [$Subject] Conditional Access Policies now?`nYou will be prompted again for any actual change.",
                "[$Subject] Conditional Access Policies"
            )) {

            $j = 0
            foreach ($ConfigItem in $list) {
                $j++

                $PercentComplete = $j / $list.Count * 100
                $params = @{
                    Id               = 1
                    ParentId         = 0
                    Activity         = 'Conditional Access Policy       '
                    Status           = " $([math]::floor($PercentComplete))% Complete: $($ConfigItem.displayName)"
                    PercentComplete  = $PercentComplete
                    CurrentOperation = 'EntraCAPolicyCreateOrUpdate'
                }

                $updateOnly = $false
                $obj = $null
                if (
                    ($null -ne $ConfigItem.id) -and
                    ($ConfigItem.id -notmatch '^00000000-') -and
                    ($ConfigItem.id -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$')
                ) {
                    $obj = Get-MgIdentityConditionalAccessPolicy `
                        -ConditionalAccessPolicyId $ConfigItem.id `
                        -ErrorAction SilentlyContinue
                    if ($obj) {
                        $updateOnly = $true
                    }
                    else {
                        Write-Warning "[$Subject] SKIPPED $($ConfigItem.id) Conditional Access Policy: No existing object found"
                        continue
                    }
                }
                else {
                    $obj = Get-MgIdentityConditionalAccessPolicy -All `
                        -Filter "displayName eq '$($ConfigItem.displayName)'" `
                        -ErrorAction SilentlyContinue
                    if ($obj.Count -gt 1) {
                        Write-Error "[$Subject] Conditional Access Policy $($ConfigItem.displayName): Display Name is not a unique identifier; found $($obj.Count) objects instead of 1"
                        continue
                    }
                    elseif ($obj) {
                        Write-Warning "[$Subject] Conditional Access Policy $($ConfigItem.displayName): Add the unique object ID '$($obj.Id)' to the policy configuration file for more robust resilience instead of using the display name for updates."
                        $ConfigItem.id = $obj.Id
                        $updateOnly = $true
                    }
                }

                $BodyParameter = $ConfigItem.PSObject.copy()
                $BodyParameter.Remove('FileOrigin')
                $BodyParameter.Remove('Description')    # As long as description property for CA policies is read-only in Microsoft Graph backend, we can't send it :-(

                # Resolve excludeGroups
                $excludeGroups = [System.Collections.ArrayList]@()
                if ($null -ne $BodyParameter.conditions.users.excludeGroups) {
                    [System.Collections.ArrayList]$excludeGroups = $BodyParameter.conditions.users.excludeGroups
                }
                $excludeGroups += $EntraTier0BreakGlass.group.id    # Always add Break Glass group to excludeGroups
                $excludeGroups.Remove('breakglass_group')
                $BodyParameter.conditions.users.excludeGroups = $excludeGroups
                $ConfigItem.conditions.users.excludeGroups = $excludeGroups

                # Resolve User References
                #TODO

                # Resolve Authentication Strength Reference
                if (
                    ($null -ne $BodyParameter.grantControls.AuthenticationStrength) -and
                    ($BodyParameter.grantControls.AuthenticationStrength.Id.GetType().Name -ne 'String')
                ) {
                    if ($BodyParameter.grantControls.AuthenticationStrength.Id.Id) {
                        $BodyParameter.grantControls.AuthenticationStrength.Id = $BodyParameter.grantControls.AuthenticationStrength.Id.Id
                    }
                    elseif ($BodyParameter.grantControls.AuthenticationStrength.Id.displayName) {
                        $result = Get-MgPolicyAuthenticationStrengthPolicy -Filter "PolicyType eq 'custom' and displayName eq '$($BodyParameter.grantControls.AuthenticationStrength.Id.displayName)'"
                        if ($result.Id) {
                            Write-Warning "[$Subject] Conditional Access Policy $($ConfigItem.displayName): Add the unique object ID '$($result.Id)' to the Authentication Stength configuration file for more robust resilience instead of using the display name for updates."
                            $BodyParameter.grantControls.AuthenticationStrength.Id = $result.Id
                            $ConfigItem.grantControls.AuthenticationStrength.Id = $result.Id
                        }
                        else {
                            Write-Error "Could not find defined Authentication Strength"
                            continue
                        }
                    }
                }

                if ($updateOnly) {
                    $params.Activity = 'Update Conditional Access Policy'
                    $params.Status = " $([math]::floor($PercentComplete))% Complete: $($ConfigItem.displayName)"
                    Write-Progress @params

                    try {
                        $diff = Compare-Object -ReferenceObject $BodyParameter -DifferenceObject $obj -Property displayName,state -CaseSensitive
                        if ($diff) {
                            if ($PSCmdlet.ShouldProcess(
                                    "[$Subject] Conditional Access Policy: Update $($ConfigItem.id) ($($ConfigItem.displayName)) [state = $($ConfigItem.state)]",
                                    "Do you confirm to update this Conditional Access Policy?",
                                    "Update Conditional Access Policy $($ConfigItem.id) ($($ConfigItem.displayName))"
                                )) {
                                Write-Verbose "[$Subject] Updating Conditional Access Policy $($ConfigItem.id) ($($ConfigItem.displayName)) [state = $($ConfigItem.state)]"
                                Write-Debug "BodyParameter from file $($ConfigItem.FileOrigin):`n$($BodyParameter | ConvertTo-Json -Depth 10)"
                                $null = Update-MgIdentityConditionalAccessPolicy `
                                    -ConditionalAccessPolicyId $ConfigItem.Id `
                                    -BodyParameter $BodyParameter `
                                    -ErrorAction Stop `
                                    -Confirm:$false
                            }
                        }
                        else {
                            Write-Debug "[$Subject] Conditional Access Policy $($ConfigItem.id) ($($ConfigItem.displayName)) is up-to-date"
                        }
                    }
                    catch {
                        throw $_
                    }
                }
                else {
                    $params.Activity = 'Create Conditional Access Policy'
                    $params.Status = " $([math]::floor($PercentComplete))% Complete: $($ConfigItem.displayName)"
                    Write-Progress @params

                    try {
                        if ($PSCmdlet.ShouldProcess(
                                "[$Subject] Conditional Access Policy: Create '$($ConfigItem.displayName)' (state = $($ConfigItem.state))",
                                "Do you confirm to create this new Conditional Access Policy?",
                                "Create new Conditional Access Policy '$($ConfigItem.displayName)' (state = $($ConfigItem.state))"
                            )) {
                            Write-Verbose "[$Subject] Creating Conditional Access Policy '$($ConfigItem.displayName)'"

                            Write-Debug "BodyParameter from file $($ConfigItem.FileOrigin):`n$($BodyParameter | ConvertTo-Json -Depth 10)"
                            $obj = New-MgIdentityConditionalAccessPolicy `
                                -BodyParameter $BodyParameter `
                                -ErrorAction Stop `
                                -Confirm:$false

                            Write-Warning "[$Subject] Conditional Access Policy $($ConfigItem.displayName): Add the unique object ID '$($obj.Id)' to the policy configuration file for more robust resilience instead of using the display name for updates."
                            $ConfigItem.id = $obj.Id
                        }
                    }
                    catch {
                        throw $_
                    }
                }

                Start-Sleep -Milliseconds 250
            }
        }

        Start-Sleep -Milliseconds 25
        $i++
    }
}
