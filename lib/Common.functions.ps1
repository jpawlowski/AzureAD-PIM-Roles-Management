<#
.SYNOPSIS

.DESCRIPTION

.LINK
    https://github.com/jpawlowski/AzureAD-PIM-Roles-Management

.NOTES
    Filename: Common.functions.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
#>
#Requires -Version 7.2
#Requires -Modules @{ ModuleName='Microsoft.Graph.Authentication'; ModuleVersion='2.0' }

function Connect-MyMgGraph {
    [CmdletBinding()]
    Param (
        [string[]]$Scopes,
        [string]$TenantId,
        [switch]$UseDeviceCode
    )

    if (
        ($null -eq $TenantId) -or
        ($TenantId -eq '')
    ) {
        if (
            ($null -ne $env:AZURE_TENANT_ID) -and
            ($env:AZURE_TENANT_ID -ne '')
        ) {
            $TenantId = $env:AZURE_TENANT_ID
        }
        else {
            Write-Error "Missing `$env:AZURE_TENANT_ID environment variable or -TenantId parameter"
        }
    }

    if ($WhatIfPreference) {
        Write-Debug "WhatIf: Removing Write scopes from Microsoft.Graph for Read-Only output"
        $MgScopes = $MgScopes | Where-Object -FilterScript { $_ -notlike '*Write*' }
    }

    Write-Debug "Requesting the following scopes for Microsoft Graph PowerShell: `n           $(($MgScopes | Sort-Object | Get-Unique) -join "`n           ")"

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
        Write-Verbose "Re-authentication required"
        $params = @{
            ErrorAction  = 'Stop'
            ContextScope = 'Process'
        }
        if ($Scopes) { $params.Scopes = $Scopes | Get-Unique }
        if ($TenantId) { $params.TenantId = $TenantId }
        if ($UseDeviceCode) { $params.UseDeviceCode = $UseDeviceCode }
        Write-Debug "Connecting to Microsoft Graph with parameters: $($params | Out-String)"
        Connect-MgGraph @params
    }
    else {
        Write-Debug "Using existing connection to Microsoft Graph for tenant $((Get-MgContext).TenantId)"
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

function Write-InformationColored {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Object]$MessageData,
        [ConsoleColor]$ForegroundColor = $Host.UI.RawUI.ForegroundColor, # Make sure we use the current colours by default
        [ConsoleColor]$BackgroundColor = $Host.UI.RawUI.BackgroundColor,
        [Switch]$NoNewline
    )

    $params = [System.Management.Automation.HostInformationMessage]@{
        Message         = $MessageData
        ForegroundColor = $ForegroundColor
        BackgroundColor = $BackgroundColor
        NoNewline       = $NoNewline.IsPresent
    }

    Write-Information @params
}

function Get-RandomCharacter($length, $characters) {
    if ($length -lt 1) { return '' }
    $random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.Length }
    $private:ofs = ''
    return [string]$characters[$random]
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
