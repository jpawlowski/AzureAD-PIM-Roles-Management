<#PSScriptInfo
.VERSION 1.0.0
.GUID 710022f9-8ea6-49a9-8a1a-0714ff253fe0
.AUTHOR Julian Pawlowski
.COMPANYNAME Workoho GmbH
.COPYRIGHT (c) 2024 Workoho GmbH. All rights reserved.
.TAGS
.LICENSEURI
.PROJECTURI
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>

<#
.SYNOPSIS
    Get a random password

.DESCRIPTION
    Common runbook that can be used by other runbooks. It can not be started as an Azure Automation job directly.
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory)]
    [Int32]$length,

    [Int32]$minLower = 0,
    [Int32]$minUpper = 0,
    [Int32]$minNumber = 0,
    [Int32]$minSpecial = 0
)

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | ForEach-Object { $_.PSObject.Properties | ForEach-Object { $_.Name + ': ' + $_.Value } }) -join ', ') ---"
$StartupVariables = (Get-Variable | ForEach-Object { $_.Name })

#region [COMMON] FUNCTIONS -----------------------------------------------------
function Get-RandomCharacter([Int32]$length, [string]$characters) {
    if ($length -lt 1) { return '' }
    if (Get-Command Get-SecureRandom -ErrorAction SilentlyContinue) {
        $random = 1..$length | ForEach-Object { Get-SecureRandom -Maximum $characters.Length }
    }
    else {
        $random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.Length }
    }
    $private:ofs = ''
    return [string]$characters[$random]
}
function Get-ScrambleString([string]$inputString) {
    $characterArray = $inputString.ToCharArray()
    if (Get-Command Get-SecureRandom -ErrorAction SilentlyContinue) {
        return -join ($characterArray | Get-SecureRandom -Count $characterArray.Length)
    }
    else {
        return -join ($characterArray | Get-Random -Count $characterArray.Length)
    }
}
#endregion ---------------------------------------------------------------------

# Define character sets
$lowerChars = 'abcdefghijklmnopqrstuvwxyz'
$upperChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
$numberChars = '0123456789'
$specialChars = "~`!@#$%^&*()_-+={[}]|\:;`"'<,>.?/"

# Calculate the number of characters needed for each set
$totalChars = $minLower + $minUpper + $minNumber + $minSpecial
$remainingChars = $length - $totalChars
$lowerCharsNeeded = [Math]::Max($minLower - $remainingChars, 0)
$upperCharsNeeded = [Math]::Max($minUpper - $remainingChars, 0)
$numberCharsNeeded = [Math]::Max($minNumber - $remainingChars, 0)
$specialCharsNeeded = [Math]::Max($minSpecial - $remainingChars, 0)

# Generate the password
$return = [System.Text.StringBuilder]''
if ($lowerCharsNeeded -gt 0) {
    $return.Append((Get-RandomCharacter -length $lowerCharsNeeded -characters $lowerChars))
}
if ($upperCharsNeeded -gt 0) {
    $return.Append((Get-RandomCharacter -length $upperCharsNeeded -characters $upperChars))
}
if ($numberCharsNeeded -gt 0) {
    $return.Append((Get-RandomCharacter -length $numberCharsNeeded -characters $numberChars))
}
if ($specialCharsNeeded -gt 0) {
    $return.Append((Get-RandomCharacter -length $specialCharsNeeded -characters $specialChars))
}
$remainingChars = $length - $return.Length
if ($remainingChars -gt 0) {
    $return.Append((Get-RandomCharacter -length $remainingChars -characters ($lowerChars + $upperChars + $numberChars + $specialChars)))
}
$return = Get-ScrambleString $return.ToString()

Get-Variable | Where-Object { $StartupVariables -notcontains @($_.Name, 'return') } | ForEach-Object { Remove-Variable -Scope 0 -Name $_.Name -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -Verbose:$false -Debug:$false }
Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
return $return
