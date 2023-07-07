function CreateCAPolicies {
    if (!$CreateAdminCAPolicies -and !$CreateGeneralCAPolicies) { return }
    if (!$validBreakGlass) {
        Write-Error 'Conditional Access Policies can not be updated without Break Glass Account validation. Use -SkipBreakGlassValidation to enforce update.'
        return
    }

}
