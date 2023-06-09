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

$MgScopes += 'RoleManagement.ReadWrite.Directory'

function Update-Entra-RoleRules {
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'High'
    )]
    Param (
        [string[]]$Config,
        [string[]]$DefaultConfig,
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
                Write-Output ''
                Write-Warning "[Tier $tier] Incomplete role definition ignored from configuration at array position $i"
                continue
            }

            if (($Config[$tier] | Where-Object -FilterScript { ($_.templateId -eq $role.templateId) -or ($_.displayName -eq $role.displayName) } | Measure-Object).Count -gt 1) {
                Write-Output ''
                Write-Warning "[Tier $tier] SKIPPED: '$($role.displayName)' ($($role.templateId)) is defined for this Tier already"
                continue
            }

            $previousTier = $tier - 1;
            $duplicate = $false
            do {
                if (($Config[$previousTier] | Where-Object -FilterScript { ($_.templateId -eq $role.templateId) -or ($_.displayName -eq $role.displayName) } | Measure-Object).Count -gt 0) {
                    Write-Output ''
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
                    Write-Output ''
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

            if ($RoleTemplateIDsWhitelist -or $RoleNamesWhitelist) {
                $found = $false
                if (
                    $RoleTemplateIDsWhitelist -and
                    $role.TemplateId -and
                    ($role.TemplateId -in $RoleTemplateIDsWhitelist)
                ) {
                    $found = $true
                }
                elseif (
                    $RoleNamesWhitelist -and
                    $role.displayName -and
                    ($role.displayName -in $RoleNamesWhitelist)
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
            continue
        }

        $roleList = $roleList | Sort-Object -Property displayName
        $roleList | ForEach-Object { [PSCustomObject]$_ } | Format-Table -AutoSize -Property displayName, isBuiltIn, templateId, id
        $totalCount = $roleList.Count
        $totalCountChars = ($totalCount | Measure-Object -Character).Characters

        $result = 1
        if ($tier -eq 0 -and $Force) {
            Write-Output ''
            Write-Warning "[Tier $tier] Privileged ID Management policies can NOT be forcably updated in unattended mode: -Force parameter is ignored"
        }
        if ($tier -ne 0 -and $Force) {
            $result = 0
        }
        else {
            $title = "!!! WARNING: Update [Tier $tier] Privileged ID Management policies !!!"
            $message = "Do you confirm to update the management policies for a total of $totalCount Microsoft Entra role(s) in Tier ${tier} listed above?"
            $result = $host.ui.PromptForChoice($title, $message, $choices, 1)
        }
        switch ($result) {
            0 {
                !$Force ? (Write-Output " Yes: Continue with update.") : $null
                $i = 0
                foreach ($role in $roleList) {
                    $i++
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
                    $roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -Filter $filter
                    if (-Not $roleDefinition) {
                        Write-Output ''
                        Write-Warning (
                            "[Tier $tier] " +
                            ('{0:d' + $totalCountChars + '}') -f $i +
                            "/${totalCount}: " +
                            "SKIPPED " +
                            ($role.IsBuiltIn ? "Built-in" : "Custom") +
                            " role " +
                            $roleDefinition.displayName +
                            ($role.TemplateId ? " ($($role.TemplateId))" : '') +
                            ": No role definition found"
                        )
                        continue
                    }

                    $filter = "scopeId eq '/' and scopeType eq 'DirectoryRole' and RoleDefinitionId eq '$($roleDefinition.Id)'"
                    $policyAssignment = Get-MgPolicyRoleManagementPolicyAssignment -Filter $filter
                    if (-Not $policyAssignment) {
                        Write-Output ''
                        Write-Warning (
                            "`n[Tier $tier] " +
                            ('{0:d' + $totalCountChars + '}') -f $i +
                            "/${totalCount}: " +
                            "SKIPPED " +
                            ($role.IsBuiltIn ? "Built-in" : "Custom") +
                            " role " +
                            $roleDefinition.displayName +
                            ($role.TemplateId ? " ($($role.TemplateId))" : '') +
                            ": No policy assignment found"
                        )
                        continue
                    }

                    Write-Output (
                        "`n[Tier $tier] " +
                        ('{0:d' + $totalCountChars + '}') -f $i +
                        "/${totalCount}: " +
                        "Updating management policy rules for " +
                        ($role.IsBuiltIn ? "built-in" : "custom") +
                        " role " +
                        $roleDefinition.TemplateId +
                        " ($($roleDefinition.displayName)):"
                    )
                    foreach ($rolePolicyRuleTemplate in $DefaultConfig[$tier]) {
                        $rolePolicyRule = $rolePolicyRuleTemplate.PsObject.Copy()

                        if ($role.ContainsKey($rolePolicyRule.Id)) {
                            Write-Output "                [Individual role setting]          $($rolePolicyRule.Id)"
                            foreach ($key in $item.$($rolePolicyRule.Id).Keys) {
                                $rolePolicyRule.$key = $item.$($rolePolicyRule.Id).$key
                            }
                        }
                        else {
                            Write-Output "                [Inherited from Tier $tier Defaults]   $($rolePolicyRule.Id)"
                        }

                        try {
                            Update-MgPolicyRoleManagementPolicyRule `
                                -UnifiedRoleManagementPolicyId $policyAssignment.PolicyId `
                                -UnifiedRoleManagementPolicyRuleId $rolePolicyRule.Id `
                                -BodyParameter $rolePolicyRule
                        }
                        catch {
                            throw
                        }
                        Start-Sleep -Seconds 0.5
                    }
                }
            }
            1 {
                Write-Output " No: Skipping management policy rules update for Tier $tier Microsoft Entra Roles."
            }
            * {
                Write-Output " Cancel: Aborting command."
                exit
            }
        }
    }
}

$UpdateRoleRules = $false
$RoleTemplateIDsWhitelist = @();
$RoleNamesWhitelist = @();
if (
    ($Roles.Count -eq 1) -and
    ($Roles[0].GetType().Name -eq 'String') -and
    ($Roles[0] -eq 'All')
) {
    $UpdateRoleRules = $true
}
else {
    foreach ($role in $Roles) {
        if ($role.GetType().Name -eq 'String') {
            if ($role -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$') {
                $RoleTemplateIDsWhitelist += $role
            }
            else {
                $RoleNamesWhitelist += $role
            }
            $UpdateRoleRules = $true
        }
        elseif ($role.GetType().Name -eq 'Hashtable') {
            if ($role.TemplateId) {
                $RoleTemplateIDsWhitelist += $role.TemplateId
                $UpdateRoleRules = $true
            }
            elseif ($role.displayName) {
                $RoleNamesWhitelist += $role.displayName
                $UpdateRoleRules = $true
            }
        }
    }
}
