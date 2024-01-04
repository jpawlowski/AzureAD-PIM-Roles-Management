<#PSScriptInfo
.VERSION 0.0.1
.GUID c9836025-b441-474a-8c61-f7c3d17ebb23
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
    Get all dedicated cloud administrator accounts for a user ID.

.DESCRIPTION
    Searches for any dedicated cloud administrator account that is tied to the given user ID.

    NOTE: This script uses the Microsoft Graph Beta API as it requires support for Restricted Management Administrative Units which is not available in the stable API.

.PARAMETER ReferralUserId
    User account identifier of the main user account. May be an Entra Identity Object ID or User Principal Name (UPN).

.PARAMETER Tier
    The Tier level where the Cloud Administrator account shall be searched in.

.PARAMETER JobReference
    This information may be added for back reference in other IT systems. It will simply be added to the Job data.

.PARAMETER OutputJson
    Output the result in JSON format.
    This is useful when output data needs to be processed in other IT systems after the job was completed.

.PARAMETER OutputText
    Output the found User Principal Names only.
#>

[CmdletBinding()]
Param (
    [Parameter(Position = 0, mandatory = $true)]
    [Array]$ReferralUserId,

    [Parameter(Position = 1, mandatory = $false)]
    [Array]$Tier,

    [Boolean]$OutJson,
    [Boolean]$OutText,
    [Object]$JobReference
)

if ($PSCommandPath) {
    Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | ForEach-Object { $_.PSObject.Properties | ForEach-Object { $_.Name + ': ' + $_.Value } }) -join ', ') ---"
}
