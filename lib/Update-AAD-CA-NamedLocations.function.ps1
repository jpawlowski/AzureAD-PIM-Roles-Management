function Update-AAD-CA-NamedLocations {
    if (!$CreateNamedLocations) { return }

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

    $namedLocations = Get-MgIdentityConditionalAccessNamedLocation

    foreach ($tier in $NamedLocationsTiers) {
        $result = 1
        if ($tier -eq 0 -and $Force) {
            Write-Output ''
            Write-Warning "[Tier $tier] Azure AD Conditional Access Named Locations can NOT be forcably updated in unattended mode: -Force parameter is ignored"
        }
        if ($tier -ne 0 -and $Force) {
            $result = 0
        }
        else {
            $title = "!!! WARNING: Create and/or update [Tier $tier] Azure AD Conditional Access Named Locations !!!"
            $message = "Do you confirm to create new or update a total of $($AADCANamedLocations[$tier].Count) Named Locations for Tier ${tier}?"
            $result = $host.ui.PromptForChoice($title, $message, $choices, 1)
        }
        switch ($result) {
            0 {
                !$Force ? (Write-Output " Yes: Continue with creation or update.") : $null
                foreach ($namedLocation in $AADCANamedLocations[$tier]) {
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
                            Write-Output ''
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
                            Write-Output "`n[Tier $tier] Updating named location $($namedLocation.id) ($($namedLocation.displayName))"
                            $params = $namedLocation.PSObject.copy()
                            $params.id = $null
                            $null = Update-MgIdentityConditionalAccessNamedLocation `
                                -NamedLocationId $namedLocation.id `
                                -BodyParameter $params
                        }
                        catch {
                            throw $_
                        }
                    }
                    else {
                        try {
                            Write-Output "`n[Tier $tier] Creating named location '$($namedLocation.displayName)'"
                            $obj = New-MgIdentityConditionalAccessNamedLocation `
                                -BodyParameter $namedLocation
                            $namedLocation.id = $obj.Id
                        }
                        catch {
                            throw $_
                        }
                    }
                    Start-Sleep -Seconds 0.5
                }
            }
            1 {
                !$Force ? (Write-Output " No: Skipping Tier $tier Named Location creation / updates.") : $null
            }
            * {
                !$Force ? (Write-Output " Cancel: Aborting command.") : $null
                exit
            }
        }
    }
}