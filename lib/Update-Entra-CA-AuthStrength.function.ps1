<#
.SYNOPSIS

.DESCRIPTION

.LINK
    https://github.com/jpawlowski/AzureAD-PIM-Roles-Management

.NOTES
    Filename: Update-Entra-CA-AuthStrength.function.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
#>
#Requires -Version 7.2
#Requires -Modules @{ ModuleName='Microsoft.Graph.Identity.SignIns'; ModuleVersion='2.0' }

$MgScopes += 'Policy.ReadWrite.AuthenticationMethod'

function Update-Entra-CA-AuthStrength {
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'High'
    )]
    Param (
        [array]$Config,
        [switch]$Tier0,
        [switch]$Tier1,
        [switch]$Tier2
    )

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

    try {
        $authStrengthPolicies = Get-MgPolicyAuthenticationStrengthPolicy -Filter "PolicyType eq 'custom'" -ErrorAction Stop
    }
    catch {
        Throw $_
    }

    $i = 0
    foreach ($tier in $AuthStrengthTiers) {
        $PercentComplete = $i / $AuthStrengthTiers.Count * 100
        $params = @{
            Activity         = 'Working on Tier                 '
            Status           = " $([math]::floor($PercentComplete))% Complete: Tier $tier"
            PercentComplete  = $PercentComplete
            CurrentOperation = 'EntraCAAuthStrengthTier'
        }
        Write-Progress @params

        if ($PSCmdlet.ShouldProcess(
                "Update a total of $($EntraCAAuthStrengths[$tier].Count) Authentication Stength policies in [Tier $tier]",
                "Do you confirm to create new or update a total of $($EntraCAAuthStrengths[$tier].Count) Authentication Strength policies for Tier ${tier}?",
                "!!! WARNING: Create and/or update [Tier $tier] Microsoft Entra Conditional Access Authentication Strengths !!!"
            )) {
            $j = 0
            foreach ($key in $EntraCAAuthStrengths[$tier].Keys) {
                $j++

                $PercentComplete = $j / $EntraCAAuthStrengths[$tier].Count * 100
                $params = @{
                    Id               = 1
                    ParentId         = 0
                    Activity         = 'Authentication Strength       '
                    Status           = " $([math]::floor($PercentComplete))% Complete: $($role.displayName)"
                    PercentComplete  = $PercentComplete
                    CurrentOperation = 'EntraCAAuthStrengthCreateOrUpdate'
                }

                foreach ($authStrength in $EntraCAAuthStrengths[$tier][$key]) {

                    $updateOnly = $false
                    if ($authStrength.id) {
                        if ($authStrengthPolicies | Where-Object -FilterScript { $_.Id -eq $authStrength.id }) {
                            $updateOnly = $true
                        }
                        else {
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
                        $params.Activity = 'Update Authentication Strength'
                        $params.Status = " $([math]::floor($PercentComplete))% Complete: $($authStrength.displayName)"
                        Write-Progress @params

                        try {
                            Write-Verbose "[Tier $tier] Updating authentication strength policy $($authStrength.id) ($($authStrength.displayName))"
                            $null = Update-MgPolicyAuthenticationStrengthPolicy `
                                -AuthenticationStrengthPolicyId $authStrength.id `
                                -DisplayName $authStrength.displayName `
                                -Description $authStrength.description `
                                -ErrorAction Stop `
                                -Confirm:$false

                            $params.Status = " $([math]::floor($PercentComplete))% Complete: $($authStrength.displayName) - Allowed Combinations"
                            Write-Progress @params

                            Write-Verbose "            Updating allowed combinations: $($authStrength.allowedCombinations -join '; ')"
                            $null = Update-MgPolicyAuthenticationStrengthPolicyAllowedCombination `
                                -AuthenticationStrengthPolicyId $authStrength.id `
                                -AllowedCombinations $authStrength.allowedCombinations `
                                -ErrorAction Stop `
                                -Confirm:$false

                            if ($authStrength.CombinationConfigurations) {
                                $combConfs = Get-MgPolicyAuthenticationStrengthPolicyCombinationConfiguration `
                                    -AuthenticationStrengthPolicyId $authStrength.id `
                                    -ErrorAction Stop

                                foreach ($key in $authStrength.CombinationConfigurations.Keys) {
                                    $params.Status = " $([math]::floor($PercentComplete))% Complete: $($authStrength.displayName) - $key Combination Configuration"
                                    Write-Progress @params

                                    $obj = $combConfs | Where-Object -FilterScript { $_.AppliesToCombinations -contains $key }
                                    if ($obj) {
                                        Write-Verbose "            Updating combination configuration for '$key'"
                                        if ($authStrength.CombinationConfigurations.$key.allowedAAGUIDs) {
                                            Write-Verbose ("               " + ($authStrength.CombinationConfigurations.$key.allowedAAGUIDs -join "`n               "))
                                        }
                                        $null = Update-MgPolicyAuthenticationStrengthPolicyCombinationConfiguration `
                                            -AuthenticationCombinationConfigurationId $obj.id `
                                            -AuthenticationStrengthPolicyId $authStrength.id `
                                            -AppliesToCombinations $key `
                                            -AdditionalProperties $authStrength.CombinationConfigurations.$key `
                                            -ErrorAction Stop `
                                            -Confirm:$false
                                    }
                                    else {
                                        Write-Verbose "            Creating combination configuration for '$key'"
                                        $null = New-MgPolicyAuthenticationStrengthPolicyCombinationConfiguration `
                                            -AuthenticationStrengthPolicyId $authStrength.id `
                                            -AppliesToCombinations $key `
                                            -AdditionalProperties $authStrength.CombinationConfigurations.$key `
                                            -ErrorAction Stop `
                                            -Confirm:$false
                                    }
                                }
                            }
                        }
                        catch {
                            throw $_
                        }
                    }
                    else {
                        $params.Activity = 'Create Authentication Strength'
                        $params.Status = " $([math]::floor($PercentComplete))% Complete: $($authStrength.displayName)"
                        Write-Progress @params

                        try {
                            Write-Verbose "[Tier $tier] Creating authentication strength policy '$($authStrength.displayName)'"
                            $obj = New-MgPolicyAuthenticationStrengthPolicy `
                                -DisplayName $authStrength.displayName `
                                -Description $authStrength.description `
                                -AllowedCombinations $authStrength.allowedCombinations `
                                -ErrorAction Stop `
                                -Confirm:$false
                            $authStrength.id = $obj.Id

                            if ($authStrength.CombinationConfigurations) {
                                foreach ($key in $authStrength.CombinationConfigurations.Keys) {
                                    $params.Status = " $([math]::floor($PercentComplete))% Complete: $($authStrength.displayName) - $key Combination Configuration"
                                    Write-Progress @params

                                    Write-Verbose "            Creating combination configuration for '$key'"
                                    $null = New-MgPolicyAuthenticationStrengthPolicyCombinationConfiguration `
                                        -AuthenticationStrengthPolicyId $authStrength.id `
                                        -AppliesToCombinations $key `
                                        -AdditionalProperties $authStrength.CombinationConfigurations.$key `
                                        -ErrorAction Stop `
                                        -Confirm:$false
                                }
                            }
                        }
                        catch {
                            throw $_
                        }
                    }

                    Start-Sleep -Milliseconds 25
                }

                Start-Sleep -Milliseconds 25
            }
        }

        Start-Sleep -Milliseconds 25
        $i++
    }
}
