<#
.SYNOPSIS

.DESCRIPTION

.LINK
    https://github.com/jpawlowski/AzureAD-PIM-Roles-Management

.NOTES
    Filename: Update-Entra-RoleRules.function.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
#>
#Requires -Version 7.2
#Requires -Modules @{ ModuleName='Microsoft.Graph.Identity.Governance'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Identity.SignIns'; ModuleVersion='2.0' }

$MgScopes += 'RoleManagement.Read.All'
$MgScopes += 'RoleManagement.ReadWrite.Directory'

function Update-Entra-RoleRules {
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'High'
    )]
    Param (
        [array]$Config,
        [array]$DefaultConfig,
        [string[]]$Id,
        [string[]]$Name,
        [switch]$Tier0,
        [switch]$Tier1,
        [switch]$Tier2
    )

    $PolicyTiers = @();
    if ($Tier0) {
        $PolicyTiers += 0
    }
    if ($Tier1) {
        $PolicyTiers += 1
    }
    if ($Tier2) {
        $PolicyTiers += 2
    }
    if ($PolicyTiers.Count -eq 0) {
        $PolicyTiers = @(0, 1, 2)
    }

    $k = 0
    foreach ($tier in $PolicyTiers) {
        $i = 0
        [array]$roleList = @()
        foreach ($role in $Config[$tier]) {
            if (
                ($null -eq $role.IsBuiltIn) -or
                ($role.IsBuiltIn -and -not $role.templateId) -or
                ((-Not $role.IsBuiltIn) -and (-not $role.id) -and (-not $role.templateId)) -or
                (-Not $role.displayName)
            ) {
                Write-Warning "[Tier $tier] Incomplete role definition ignored from configuration at array position $i"
                continue
            }

            if (($Config[$tier] | Where-Object -FilterScript { ($_.templateId -eq $role.templateId) -or ($_.displayName -eq $role.displayName) } | Measure-Object).Count -gt 1) {
                Write-Warning "[Tier $tier] SKIPPED: '$($role.displayName)' ($($role.templateId)) is defined for this Tier already"
                continue
            }

            $previousTier = $tier - 1;
            $duplicate = $false
            do {
                if (($Config[$previousTier] | Where-Object -FilterScript { ($_.templateId -eq $role.templateId) -or ($_.displayName -eq $role.displayName) } | Measure-Object).Count -gt 0) {
                    Write-Warning "[Tier $tier] SKIPPED: '$($role.displayName)' ($($role.templateId)) is a duplicate from higher Tier ${previousTier}"
                    $duplicate = $true
                }
                $previousTier--
            } while (
                $previousTier -ge 0
            )
            if ($duplicate) {
                continue
            }

            $nextTier = $tier + 1;
            $duplicate = $false
            do {
                if (($Config[$nextTier] | Where-Object -FilterScript { ($_.templateId -eq $role.templateId) -or ($_.displayName -eq $role.displayName) } | Measure-Object).Count -gt 0) {
                    Write-Warning "[Tier $tier] SKIPPED: '$($role.displayName)' ($($role.templateId)) is a duplicate from lower Tier ${nextTier}"
                    $duplicate = $true
                }
                $nextTier++
            } while (
                $nextTier -le 2
            )
            if ($duplicate) {
                continue
            }

            if ($Id -or $Name) {
                $found = $false
                if (
                    $Id -and
                    $role.TemplateId -and
                    ($role.TemplateId -in $Id)
                ) {
                    $found = $true
                }
                elseif (
                    $Name -and
                    $role.displayName -and
                    ($role.displayName -in $Name)
                ) {
                    $found = $true
                }
                if (-Not $found) {
                    continue
                }
            }

            $roleList += $role
            $i++
        }

        if ($roleList.Count -eq 0) {
            $k++
            continue
        }

        $roleList = $roleList | Sort-Object -Property displayName
        $totalCountChars = ($roleList.Count | Measure-Object -Character).Characters

        $PercentComplete = $k / $PolicyTiers.Count * 100
        $params = @{
            Activity         = 'Working on Tier  '
            Status           = " $([math]::floor($PercentComplete))% Complete: Tier $tier"
            PercentComplete  = $PercentComplete
            CurrentOperation = 'EntraRoleRulesTier'
        }
        Write-Progress @params

        if ($PSCmdlet.ShouldProcess(
                "Update [Tier $tier] Privileged Identity Management policies for a total of $($roleList.Count) Microsoft Entra role(s)",
                (
                    "Do you confirm to update the management policies for the following $($roleList.Count) Microsoft Entra role(s) in Tier ${tier}?`n" + `
                    $($roleList | ForEach-Object { [PSCustomObject]$_ } | Format-Table -AutoSize -Property displayName, isBuiltIn, templateId, id | Out-String)
                ),
                "!!! WARNING: Update [Tier $tier] Privileged Identity Management policies !!!"
            )) {
            $i = 0
            foreach ($role in $roleList) {
                $PercentComplete = $i / $roleList.Count * 100
                $params = @{
                    Id               = 1
                    ParentId         = 0
                    Activity         = 'Role           '
                    Status           = " $([math]::floor($PercentComplete))% Complete: $($role.displayName)"
                    PercentComplete  = $PercentComplete
                    CurrentOperation = 'EntraRoleUpdate'
                }
                Write-Progress @params

                if (-Not $role.IsBuiltIn) {
                    if (-Not $role.templateId) {
                        $role.templateId = $role.id
                    }
                    if (-Not $role.id) {
                        $role.id = $role.templateId
                    }
                }
                if ($role.id) {
                    $filter = "Id eq '$($role.id)' and IsBuiltIn eq " + (($role.isBuiltIn).ToString()).ToLower()
                }
                elseif ($role.templateId) {
                    $filter = "TemplateId eq '$($role.templateId)' and IsBuiltIn eq " + (($role.isBuiltIn).ToString()).ToLower()
                }
                else {
                    $filter = "DisplayName eq '$($role.displayName)' and IsBuiltIn eq " + (($role.isBuiltIn).ToString()).ToLower()
                }
                $roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -Filter $filter -ErrorAction Stop
                if (-Not $roleDefinition) {
                    Write-Warning (
                        "[Tier $tier] " +
                            ('{0:d' + $totalCountChars + '}') -f $i +
                        "/$($roleList.Count): " +
                        "SKIPPED " +
                            ($role.IsBuiltIn ? "Built-in" : "Custom") +
                        " role " +
                        $roleDefinition.displayName +
                            ($role.TemplateId ? " ($($role.TemplateId))" : '') +
                        ": No role definition found"
                    )
                    $i++
                    continue
                }

                $filter = "scopeId eq '/' and scopeType eq 'DirectoryRole' and RoleDefinitionId eq '$($roleDefinition.Id)'"
                $policyAssignment = Get-MgPolicyRoleManagementPolicyAssignment -Filter $filter -ErrorAction Stop
                if (-Not $policyAssignment) {
                    Write-Warning (
                        "`n[Tier $tier] " +
                            ('{0:d' + $totalCountChars + '}') -f $i +
                        "/$($roleList.Count): " +
                        "SKIPPED " +
                            ($role.IsBuiltIn ? "Built-in" : "Custom") +
                        " role " +
                        $roleDefinition.displayName +
                            ($role.TemplateId ? " ($($role.TemplateId))" : '') +
                        ": No policy assignment found"
                    )
                    $i++
                    continue
                }

                Write-Verbose (
                    "[Tier $tier] " +
                        ('{0:d' + $totalCountChars + '}') -f $i +
                    "/$($roleList.Count): " +
                    "Updated management policy rules for " +
                        ($role.IsBuiltIn ? "built-in" : "custom") +
                    " role " +
                    $roleDefinition.TemplateId +
                    " ($($roleDefinition.displayName)):"
                )

                $j = 0
                foreach ($rolePolicyRuleTemplate in $DefaultConfig[$tier]) {
                    $j++
                    $rolePolicyRule = $rolePolicyRuleTemplate.PsObject.Copy()

                    if ($role.ContainsKey($rolePolicyRule.Id)) {
                        Write-Verbose "                [Individual role setting]          $($rolePolicyRule.Id)"
                        foreach ($key in $item.$($rolePolicyRule.Id).Keys) {
                            $rolePolicyRule.$key = $item.$($rolePolicyRule.Id).$key
                        }
                    }
                    else {
                        Write-Verbose "                [Inherited from Tier $tier Defaults]   $($rolePolicyRule.Id)"
                    }

                    $PercentComplete = $j / $DefaultConfig[$tier].Count * 100
                    $params = @{
                        Id               = 2
                        ParentId         = 1
                        Activity         = 'Update policy'
                        Status           = " $([math]::floor($PercentComplete))% Complete: $($rolePolicyRule.Id)"
                        PercentComplete  = $PercentComplete
                        CurrentOperation = 'EntraRolePolicyRuleUpdate'
                    }
                    Write-Progress @params

                    try {
                        Update-MgPolicyRoleManagementPolicyRule `
                            -UnifiedRoleManagementPolicyId $policyAssignment.PolicyId `
                            -UnifiedRoleManagementPolicyRuleId $rolePolicyRule.Id `
                            -BodyParameter $rolePolicyRule `
                            -ErrorAction Stop `
                            -Confirm:$false
                    }
                    catch {
                        throw $_
                    }

                    Start-Sleep -Milliseconds 25
                }

                Start-Sleep -Milliseconds 25
                $i++
            }
        }

        Start-Sleep -Milliseconds 25
        $k++
    }
}
