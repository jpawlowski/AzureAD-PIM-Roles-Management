function ConnectMgGraph {
    if (
        ($null -eq $TenantId) -or
        ($TenantId -eq '')
    ) {
        if (
            ($null -ne $env:TenantId) -and
            ($env:TenantId -ne '')
        ) {
            $TenantId = $env:TenantId
        }
        else {
            Write-Error "Missing `$env:TenantId environment variable or -TenantId parameter"
        }
    }

    # Connect to Microsoft Graph API
    #
    $MgScopes = @()
    if ($UpdateRoles) {
        $MgScopes += "RoleManagement.Read.Directory"
        $MgScopes += "RoleManagement.ReadWrite.Directory"
    }
    if ($UpdateAuthContext) {
        $MgScopes += "AuthenticationContext.Read.All"
        $MgScopes += "AuthenticationContext.ReadWrite.All"
    }
    if ($CreateNamedLocations -or $CreateAuthStrength -or $CreateCAPolicies) {
        $MgScopes += 'Policy.Read.All'
        $MgScopes += 'Policy.ReadWrite.ConditionalAccess'
        $MgScopes += 'Application.Read.All'
    }
    if ($CreateCAPolicies) {
        $MgScopes += 'User.Read.All'
        $MgScopes += 'Group.Read.All'
        $MgScopes += 'Group.ReadWrite.All'
        $MgScopes += "RoleManagement.Read.Directory"
    }

    $reauth = $false
    foreach ($MgScope in $MgScopes) {
        if ($MgScope -notin @((Get-MgContext).Scopes)) {
            $reauth = $true
        }
    }

    if (
        $reauth -or
        ((Get-MgContext).TenantId -ne $TenantId)
    ) {
        Write-Output "Connecting to tenant $TenantId ..."
        Connect-MgGraph `
            -ContextScope Process `
            -TenantId $TenantId `
            -Scopes $MgScopes
    }
}
