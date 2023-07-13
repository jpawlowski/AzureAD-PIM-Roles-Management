<#
.SYNOPSIS

.DESCRIPTION

.LINK
    https://github.com/jpawlowski/AzureAD-PIM-Roles-Management

.NOTES
    Filename: Update-Entra-CA-AuthContext.function.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
#>
#Requires -Version 7.2
#Requires -Modules @{ ModuleName='Microsoft.Graph.Identity.SignIns'; ModuleVersion='2.0' }

$MgScopes += 'Policy.Read.All'
$MgScopes += 'AuthenticationContext.ReadWrite.All'

function Update-Entra-CA-AuthContext {
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'Medium'
    )]
    Param (
        [string[]]$Config,
        [switch]$Tier0,
        [switch]$Tier1,
        [switch]$Tier2
    )

    $AuthContextTiers = @();
    if ($Tier0) {
        $AuthContextTiers += 0
    }
    if ($Tier1) {
        $AuthContextTiers += 1
    }
    if ($Tier2) {
        $AuthContextTiers += 2
    }
    if ($AuthContextTiers.Count -eq 0) {
        $AuthContextTiers = @(0, 1, 2)
    }

    foreach ($tier in $AuthContextTiers) {
        $result = 1
        if ($tier -eq 0 -and $Force) {
            Write-Output ''
            Write-Warning "[Tier $tier] Microsoft Entra Conditional Access Authentication Contexts can NOT be forcably updated in unattended mode: -Force parameter is ignored"
        }
        if ($tier -ne 0 -and $Force) {
            $result = 0
        }
        else {
            $title = "!!! WARNING: Update [Tier $tier] Microsoft Entra Conditional Access Authentication Contexts !!!"
            $message = "Do you confirm to update a total of $($EntraCAAuthContexts[$tier].Count) Authentication Context(s) for Tier ${tier}?"
            $result = $host.ui.PromptForChoice($title, $message, $choices, 1)
        }
        switch ($result) {
            0 {
                !$Force ? (Write-Output " Yes: Continue with update.") : $null
                foreach ($key in $EntraCAAuthContexts[$tier].Keys) {
                    foreach ($authContext in $EntraCAAuthContexts[$tier][$key]) {
                        try {
                            Write-Output "`n[Tier $tier] Updating authentication context class reference $($authContext.id) ($($authContext.displayName))"
                            $null = Update-MgIdentityConditionalAccessAuthenticationContextClassReference `
                                -AuthenticationContextClassReferenceId $authContext.id `
                                -DisplayName $authContext.displayName `
                                -Description $authContext.description `
                                -IsAvailable:$authContext.isAvailable
                        }
                        catch {
                            throw $_
                        }
                        Start-Sleep -Seconds 0.5
                    }
                }
            }
            1 {
                !$Force ? (Write-Output " No: Skipping Tier $tier Authentication Context updates.") : $null
            }
            * {
                !$Force ? (Write-Output " Cancel: Aborting command.") : $null
                exit
            }
        }
    }
}
