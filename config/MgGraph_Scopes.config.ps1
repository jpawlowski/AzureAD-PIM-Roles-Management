$MgScopes = @()

if ($UpdateRoles) {
    $MgScopes += 'RoleManagement.ReadWrite.Directory'
}
if ($UpdateAuthContext) {
    $MgScopes += "AuthenticationContext.ReadWrite.All"
}
if ($CreateNamedLocations -or $CreateAuthStrength -or $CreateAdminCAPolicies -or $CreateGeneralCAPolicies) {
    $MgScopes += 'Policy.Read.All'
    $MgScopes += 'Policy.ReadWrite.ConditionalAccess'
    $MgScopes += 'Application.Read.All'
}
if ($CreateAdminCAPolicies -or $CreateGeneralCAPolicies -or $ValidateBreakGlass) {
    $MgScopes += 'User.Read.All'
    $MgScopes += 'Group.Read.All'
    $MgScopes += 'AdministrativeUnit.Read.All'
    $MgScopes += 'RoleManagement.Read.Directory'
    $MgScopes += 'UserAuthenticationMethod.Read.All'
}
if ($CreateAdminUnits) {
    $MgScopes += 'AdministrativeUnit.Read.All'
    $MgScopes += 'AdministrativeUnit.ReadWrite.All'
}
if ($CreateBreakGlass) {
    $MgScopes += 'User.ReadWrite.All'
    $MgScopes += 'Group.ReadWrite.All'
    $MgScopes += 'AdministrativeUnit.ReadWrite.All'
    $MgScopes += 'Directory.Write.Restricted'
    $MgScopes += 'RoleManagement.ReadWrite.Directory'
}
