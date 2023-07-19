<#
.SYNOPSIS

.DESCRIPTION

.LINK
    https://github.com/jpawlowski/AzureAD-PIM-Roles-Management

.NOTES
    Filename: Update-Entra-CA-NamedLocations.function.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
#>
#Requires -Version 7.2
#Requires -Modules @{ ModuleName='Microsoft.Graph.Identity.SignIns'; ModuleVersion='2.0' }

$MgScopes += 'Policy.Read.All'
$MgScopes += 'Policy.ReadWrite.ConditionalAccess'

function Update-Entra-CA-NamedLocations {
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

    $NamedLocationsTiers = @();
    if ($Tier0) {
        $NamedLocationsTiers += 0
    }
    if ($Tier1) {
        $NamedLocationsTiers += 1
    }
    if ($Tier2) {
        $NamedLocationsTiers += 2
    }
    if ($NamedLocationsTiers.Count -eq 0) {
        $NamedLocationsTiers = @(0, 1, 2)
    }

    try {
        $namedLocations = Get-MgIdentityConditionalAccessNamedLocation -ErrorAction Stop
    }
    catch {
        throw $_
    }

    $i = 0
    foreach ($tier in $NamedLocationsTiers) {
        $PercentComplete = $i / $NamedLocationsTiers.Count * 100
        $params = @{
            Activity         = 'Working on Tier '
            Status           = " $([math]::floor($PercentComplete))% Complete: Tier $tier"
            PercentComplete  = $PercentComplete
            CurrentOperation = 'EntraCANamedLocationTier'
        }
        Write-Progress @params

        if ($PSCmdlet.ShouldProcess(
                "Update a total of $($EntraCANamedLocations[$tier].Count) Named Locations in [Tier $tier]",
                "Do you confirm to create new or update a total of $($EntraCANamedLocations[$tier].Count) Named Locations for Tier ${tier}?",
                "!!! WARNING: Create and/or update [Tier $tier] Microsoft Entra Conditional Access Named Locations !!!"
            )) {
            $j = 0
            foreach ($namedLocation in $EntraCANamedLocations[$tier]) {
                $j++

                $PercentComplete = $j / $EntraCANamedLocations[$tier].Count * 100
                $params = @{
                    Id               = 1
                    ParentId         = 0
                    Activity         = 'Named Location'
                    Status           = " $([math]::floor($PercentComplete))% Complete: $($role.displayName)"
                    PercentComplete  = $PercentComplete
                    CurrentOperation = 'EntraCANamedLocationCreateOrUpdate'
                }
                Write-Progress @params

                $updateOnly = $false
                if ($namedLocation.id) {
                    if (
                        $namedLocations |
                        Where-Object -FilterScript {
                            $_.AdditionalProperties.'@odata.type' -eq $namedLocation.'@odata.type' -and
                            $_.Id -eq $namedLocation.id
                        }
                    ) {
                        $updateOnly = $true
                    }
                    else {
                        Write-Warning "[Tier $tier] SKIPPED $($namedLocation.id) Named Location: No existing policy found"
                        continue
                    }
                }
                else {
                    $obj = $namedLocations |
                    Where-Object -FilterScript {
                        $_.AdditionalProperties.'@odata.type' -eq $namedLocation.'@odata.type' -and
                        $_.DisplayName -eq $namedLocation.displayName
                    }
                    if ($obj) {
                        $namedLocation.id = $obj.Id
                        $updateOnly = $true
                    }
                }

                if ($updateOnly) {
                    try {
                        Write-Verbose "[Tier $tier] Updating named location $($namedLocation.id) ($($namedLocation.displayName))"
                        $params = $namedLocation.PSObject.copy()
                        $params.id = $null
                        $null = Update-MgIdentityConditionalAccessNamedLocation `
                            -NamedLocationId $namedLocation.id `
                            -BodyParameter $params `
                            -ErrorAction Stop `
                            -Confirm:$false
                    }
                    catch {
                        throw $_
                    }
                }
                else {
                    try {
                        Write-Verbose "[Tier $tier] Creating named location '$($namedLocation.displayName)'"
                        $obj = New-MgIdentityConditionalAccessNamedLocation `
                            -BodyParameter $namedLocation `
                            -ErrorAction Stop `
                            -Confirm:$false
                        $namedLocation.id = $obj.Id
                    }
                    catch {
                        throw $_
                    }
                }

                Start-Sleep -Milliseconds 25
            }
        }

        Start-Sleep -Milliseconds 25
        $i++
    }
}
