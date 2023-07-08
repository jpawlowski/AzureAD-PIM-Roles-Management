$MgScopes = @()

if ($UpdateRoles) {
    $MgScopes += 'RoleManagement.Read.Directory'
    $MgScopes += 'RoleManagement.ReadWrite.Directory'
}
if ($UpdateAuthContext) {
    $MgScopes += "AuthenticationContext.Read.All"
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
    $MgScopes += 'Group.ReadWrite.All'
    $MgScopes += 'RoleManagement.Read.Directory'
    $MgScopes += 'UserAuthenticationMethod.Read.All'
}
if ($CreateBreakGlass) {
    $MgScopes += 'User.Read.All'
    $MgScopes += 'User.ReadWrite.All'
    $MgScopes += 'Group.Read.All'
    $MgScopes += 'Group.ReadWrite.All'
    $MgScopes += 'RoleManagement.ReadWrite.Directory'
    $MgScopes += 'UserAuthenticationMethod.Read.All'
}
