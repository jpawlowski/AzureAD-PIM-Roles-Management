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

$MgScopes += 'AuthenticationContext.ReadWrite.All'

function Update-Entra-CA-AuthContext {
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

    $i = 0
    foreach ($Tier in $AuthContextTiers) {
        $PercentComplete = $i / $AuthContextTiers.Count * 100
        $params = @{
            Activity         = 'Working on Tier                  '
            Status           = " $([math]::floor($PercentComplete))% Complete: Tier $Tier"
            PercentComplete  = $PercentComplete
            CurrentOperation = 'EntraCAAuthContextTier'
        }
        Write-Progress @params

        if ($PSCmdlet.ShouldProcess(
                "Update a total of $($Config[$Tier].Count) Authentication Context(s) in [Tier $Tier]",
                "Do you confirm to update a total of $($Config[$Tier].Count) Authentication Context(s) for Tier ${tier}?",
                "!!! WARNING: Update [Tier $Tier] Microsoft Entra Conditional Access Authentication Contexts !!!"
            )) {

            foreach ($key in $Config[$Tier].Keys) {
                $j = 0

                foreach ($authContext in $Config[$Tier][$key]) {
                    $j++
                    $PercentComplete = $j / $Config[$Tier][$key].Count * 100
                    $params = @{
                        Id               = 1
                        ParentId         = 0
                        Activity         = 'Updating Authentication Context'
                        Status           = " $([math]::floor($PercentComplete))% Complete: $($authContext.displayName)"
                        PercentComplete  = $PercentComplete
                        CurrentOperation = 'EntraCAAuthContextClassReference'
                    }
                    Write-Progress @params

                    Write-Verbose "[Tier $Tier] Updating authentication context class reference $($authContext.id) ($($authContext.displayName))"
                    Update-MgIdentityConditionalAccessAuthenticationContextClassReference `
                        -AuthenticationContextClassReferenceId $authContext.id `
                        -DisplayName $authContext.displayName `
                        -Description $authContext.description `
                        -IsAvailable:$authContext.isAvailable `
                        -ErrorAction Stop `
                        -Confirm:$false

                    Start-Sleep -Milliseconds 25
                }

                Start-Sleep -Milliseconds 25
            }
        }

        Start-Sleep -Milliseconds 25
        $i++
    }
}
