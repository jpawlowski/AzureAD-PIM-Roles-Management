function UpdateAuthContext {
    if (!$UpdateAuthContext) { return }

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
        $title = "!!! WARNING: Update Tier $tier Azure AD Conditional Access Authentication Contexts !!!"
        $message = "Do you confirm to update a total of $($AADCAAuthContexts[$tier].Count) Authentication Context(s) for Tier ${tier}?"
        $result = $host.ui.PromptForChoice($title, $message, $options, 1)
        switch ($result) {
            0 {
                Write-Output " Yes: Continue with update."
                foreach ($key in $AADCAAuthContexts[$tier].Keys) {
                    foreach ($authContext in $AADCAAuthContexts[$tier][$key]) {
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
                Write-Output " No: Skipping Tier $tier Authentication Context updates."
            }
            * {
                Write-Output " Cancel: Aborting command."
                exit
            }
        }
    }
}