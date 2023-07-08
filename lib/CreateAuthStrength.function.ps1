function CreateAuthStrength {
    if (!$CreateAuthStrength) { return }

    $AuthStrengthTiers = @();
    if ($Tier0) {
        $AuthStrengthTiers += 0
    }
    if ($Tier1) {
        $AuthStrengthTiers += 1
    }
    if ($Tier2) {
        $AuthStrengthTiers += 2
    }
    if ($AuthStrengthTiers.Count -eq 0) {
        $AuthStrengthTiers = @(0, 1, 2)
    }

    $authStrengthPolicies = Get-MgPolicyAuthenticationStrengthPolicy -Filter "PolicyType eq 'custom'"

    foreach ($tier in $AuthStrengthTiers) {
        $result = 1
        if ($Force) {
            $result = 0
        } else {
            $title = "!!! WARNING: Create and/or update Tier $tier Azure AD Conditional Access Authentication Strengths !!!"
            $message = "Do you confirm to create new or update a total of $($AADCAAuthStrengths[$tier].Count) Authentication Strength policies for Tier ${tier}?"
            $result = $host.ui.PromptForChoice($title, $message, $choices, 1)
        }
        switch ($result) {
            0 {
                !$Force ? (Write-Output " Yes: Continue with creation or update.") : $null
                foreach ($key in $AADCAAuthStrengths[$tier].Keys) {
                    foreach ($authStrength in $AADCAAuthStrengths[$tier][$key]) {
                        $updateOnly = $false
                        if ($authStrength.id) {
                            if ($authStrengthPolicies | Where-Object -FilterScript { $_.Id -eq $authStrength.id }) {
                                $updateOnly = $true
                            }
                            else {
                                Write-Output ''
                                Write-Warning "[Tier $tier] SKIPPED $($authStrength.id) Authentication Strength: No existing policy found"
                                continue
                            }
                        }
                        else {
                            $obj = $authStrengthPolicies | Where-Object -FilterScript { $_.DisplayName -eq $authStrength.displayName }
                            if ($obj) {
                                $authStrength.id = $obj.Id
                                $updateOnly = $true
                            }
                        }

                        if ($updateOnly) {
                            try {
                                Write-Output "`n[Tier $tier] Updating authentication strength policy $($authStrength.id) ($($authStrength.displayName))"
                                $null = Update-MgPolicyAuthenticationStrengthPolicy `
                                    -AuthenticationStrengthPolicyId $authStrength.id `
                                    -DisplayName $authStrength.displayName `
                                    -Description $authStrength.description

                                Write-Output "            Updating allowed combinations: $($authStrength.allowedCombinations -join '; ')"
                                $null = Update-MgPolicyAuthenticationStrengthPolicyAllowedCombination `
                                    -AuthenticationStrengthPolicyId $authStrength.id `
                                    -AllowedCombinations $authStrength.allowedCombinations

                                if ($authStrength.CombinationConfigurations) {
                                    $combConfs = Get-MgPolicyAuthenticationStrengthPolicyCombinationConfiguration `
                                        -AuthenticationStrengthPolicyId $authStrength.id

                                    foreach ($key in $authStrength.CombinationConfigurations.Keys) {
                                        $obj = $combConfs | Where-Object -FilterScript { $_.AppliesToCombinations -contains $key }
                                        if ($obj) {
                                            Write-Output "            Updating combination configuration for '$key'"
                                            if ($authStrength.CombinationConfigurations.$key.allowedAAGUIDs) {
                                                Write-Output ("               " + ($authStrength.CombinationConfigurations.$key.allowedAAGUIDs -join "`n               "))
                                            }
                                            $null = Update-MgPolicyAuthenticationStrengthPolicyCombinationConfiguration `
                                                -AuthenticationCombinationConfigurationId $obj.id `
                                                -AuthenticationStrengthPolicyId $authStrength.id `
                                                -AppliesToCombinations $key `
                                                -AdditionalProperties $authStrength.CombinationConfigurations.$key
                                        }
                                        else {
                                            Write-Output "            Creating combination configuration for '$key'"
                                            $null = New-MgPolicyAuthenticationStrengthPolicyCombinationConfiguration `
                                                -AuthenticationStrengthPolicyId $authStrength.id `
                                                -AppliesToCombinations $key `
                                                -AdditionalProperties $authStrength.CombinationConfigurations.$key
                                        }
                                    }
                                }
                            }
                            catch {
                                throw $_
                            }
                        }
                        else {
                            try {
                                Write-Output "`n[Tier $tier] Creating authentication strength policy '$($authStrength.displayName)'"
                                $obj = New-MgPolicyAuthenticationStrengthPolicy `
                                    -DisplayName $authStrength.displayName `
                                    -Description $authStrength.description `
                                    -AllowedCombinations $authStrength.allowedCombinations
                                $authStrength.id = $obj.Id

                                if ($authStrength.CombinationConfigurations) {
                                    foreach ($key in $authStrength.CombinationConfigurations.Keys) {
                                        Write-Output "            Creating combination configuration for '$key'"
                                        $null = New-MgPolicyAuthenticationStrengthPolicyCombinationConfiguration `
                                            -AuthenticationStrengthPolicyId $authStrength.id `
                                            -AppliesToCombinations $key `
                                            -AdditionalProperties $authStrength.CombinationConfigurations.$key
                                    }
                                }
                            }
                            catch {
                                throw $_
                            }
                        }
                        Start-Sleep -Seconds 0.5
                    }
                }
            }
            1 {
                !$Force ? (Write-Output " No: Skipping Tier $tier Authentication Strengths creation / updates.") : $null
            }
            * {
                !$Force ? (Write-Output " Cancel: Aborting command.") : $null
                exit
            }
        }
    }
}
