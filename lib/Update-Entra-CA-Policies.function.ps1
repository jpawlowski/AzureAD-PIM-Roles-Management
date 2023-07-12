#Requires -Version 7.2
function Update-Entra-CA-Policies {
    if (!$validBreakGlass) {
        Write-Error 'Conditional Access Policies can not be updated without Break Glass Account validation. Use -SkipBreakGlassValidation to enforce update.'
        return
    }

}
