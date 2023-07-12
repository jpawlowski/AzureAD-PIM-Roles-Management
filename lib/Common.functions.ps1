#Requires -Version 7.2
#Requires -Modules @{ ModuleName='Microsoft.Graph.Authentication'; ModuleVersion='2.0' }
function Connect-MyMgGraph {
    Param (
        [string[]]$Scopes
    )

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
    foreach ($Scope in $Scopes) {
        if ($Scope -notin @((Get-MgContext).Scopes)) {
            $reauth = $true
        }
    }

    if (
        $reauth -or
        ((Get-MgContext).TenantId -ne $TenantId)
    ) {
        $params = @{
            ContextScope = 'Process'
            TenantId = $TenantId
        }
        if ($Scopes) { $params.Scopes = $Scopes }
        if ($UseDeviceCode) { $params.UseDeviceCode = $UseDeviceCode }
        Write-Information "Connecting to tenant $TenantId with scopes: $Scopes"
        Connect-MgGraph @params
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

function Get-RandomCharacter($length, $characters) {
    if ($length -lt 1) { return '' }
    $random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.length }
    $private:ofs = ''
    return [String]$characters[$random]
}

function Get-ScrambleString([string]$inputString) {
    $characterArray = $inputString.ToCharArray()
    $scrambledStringArray = $characterArray | Get-Random -Count $characterArray.Length
    $outputString = -join $scrambledStringArray
    return $outputString
}

function Get-RandomPassword($lowerChars, $upperChars, $numbers, $symbols) {
    if ($null -eq $lowerChars) { $lowerChars = 8 }
    if ($null -eq $upperChars) { $upperChars = 8 }
    if ($null -eq $numbers) { $numbers = 8 }
    if ($null -eq $symbols) { $symbols = 8 }
    $password = Get-RandomCharacter -length $lowerChars -characters 'abcdefghiklmnoprstuvwxyz'
    $password += Get-RandomCharacter -length $upperChars -characters 'ABCDEFGHKLMNOPRSTUVWXYZ'
    $password += Get-RandomCharacter -length $numbers -characters '1234567890'
    $password += Get-RandomCharacter -length $symbols -characters "@#$%^&*-_!+=[]{}|\:',.?/`~`"();<>"
    return Get-ScrambleString $password
}
