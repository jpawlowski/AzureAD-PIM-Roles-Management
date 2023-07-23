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

$MgScopes += 'Policy.Read.All'
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

    $ConfigLevels = @();
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

    try {
        $current = Get-MgPolicyAuthenticationStrengthPolicy -Filter "PolicyType eq 'custom'" -ErrorAction Stop
    }
    catch {
        Throw $_
    }

    $i = 0
    foreach ($ConfigLevel in $ConfigLevels) {
        if (
            ($null -eq $Config[$ConfigLevel]) -or
            ($Config[$ConfigLevel].Count -eq 0)
        ) {
            continue
        }

        $PercentComplete = $i / $ConfigLevels.Count * 100
        $params = @{
            Activity         = 'Working on Tier                 '
            Status           = " $([math]::floor($PercentComplete))% Complete: Tier $ConfigLevel"
            PercentComplete  = $PercentComplete
            CurrentOperation = 'EntraCAAuthStrengthConfigLevel'
        }
        Write-Progress @params

        if ($PSCmdlet.ShouldProcess(
                "Update a total of $($ConfigLevels[$ConfigLevel].Count) Authentication Stength policies in [Tier $ConfigLevel]",
                "Do you confirm to create new or update a total of $($ConfigLevels[$ConfigLevel].Count) Authentication Strength policies for Tier ${tier}?",
                "!!! WARNING: Create and/or update [Tier $ConfigLevel] Microsoft Entra Conditional Access Authentication Strengths !!!"
            )) {
            $j = 0
            foreach ($key in $ConfigLevels[$ConfigLevel].Keys) {
                $j++

                $PercentComplete = $j / $ConfigLevels[$ConfigLevel].Count * 100
                $params = @{
                    Id               = 1
                    ParentId         = 0
                    Activity         = 'Authentication Strength       '
                    Status           = " $([math]::floor($PercentComplete))% Complete: $($role.displayName)"
                    PercentComplete  = $PercentComplete
                    CurrentOperation = 'EntraCAAuthStrengthCreateOrUpdate'
                }

                foreach ($authStrength in $ConfigLevels[$ConfigLevel][$key]) {

                    $updateOnly = $false
                    if ($authStrength.id) {
                        if ($current | Where-Object -FilterScript { $_.Id -eq $authStrength.id }) {
                            $updateOnly = $true
                        }
                        else {
                            Write-Warning "[Tier $ConfigLevel] SKIPPED $($authStrength.id) Authentication Strength: No existing policy found"
                            continue
                        }
                    }
                    else {
                        $obj = $current | Where-Object -FilterScript { $_.DisplayName -eq $authStrength.displayName }
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
                            Write-Verbose "[Tier $ConfigLevel] Updating authentication strength policy $($authStrength.id) ($($authStrength.displayName))"
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
                            Write-Verbose "[Tier $ConfigLevel] Creating authentication strength policy '$($authStrength.displayName)'"
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
