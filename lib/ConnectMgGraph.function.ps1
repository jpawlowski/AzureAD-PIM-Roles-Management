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
    if ($Roles) {
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
