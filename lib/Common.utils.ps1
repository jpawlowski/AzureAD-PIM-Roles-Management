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
        Write-Information "Connecting to tenant $TenantId with scopes: $($MgScopes)"
        Connect-MgGraph `
            -ContextScope Process `
            -TenantId $TenantId `
            -Scopes $MgScopes
    }
}

function Test-NonInteractive {
    foreach ( $arg in [Environment]::GetCommandLineArgs() ) {
        if ( $arg -like "-noni*" ) {
            return $true
        }
    }
    return $false
}

if (Test-NonInteractive -and $null -eq $Force) {
    $Force = $true
}
