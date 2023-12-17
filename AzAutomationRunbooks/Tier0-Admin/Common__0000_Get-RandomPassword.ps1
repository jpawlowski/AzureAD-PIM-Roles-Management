<#
.SYNOPSIS
    Get a random password

.NOTES
    Original name: Common__0000_Get-RandomPassword.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
    Version: 1.0.0
#>

#Requires -Version 5.1

[CmdletBinding()]
Param(
    [Int32]$lowerChars,
    [Int32]$upperChars,
    [Int32]$numbers,
    [Int32]$symbols
)

if (-Not $MyInvocation.PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name) ---"

#region [COMMON] FUNCTIONS -----------------------------------------------------
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
#endregion ---------------------------------------------------------------------

if ($null -eq $lowerChars) { $lowerChars = 8 }
if ($null -eq $upperChars) { $upperChars = 8 }
if ($null -eq $numbers) { $numbers = 8 }
if ($null -eq $symbols) { $symbols = 8 }
$Password = Get-RandomCharacter -length $lowerChars -characters 'abcdefghiklmnoprstuvwxyz'
$Password += Get-RandomCharacter -length $upperChars -characters 'ABCDEFGHKLMNOPRSTUVWXYZ'
$Password += Get-RandomCharacter -length $numbers -characters '1234567890'
$Password += Get-RandomCharacter -length $symbols -characters "@#$%^&*-_!+=[]{}|\:',.?/`~`"();<>"
$Password = Get-ScrambleString $Password

Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
return $Password
