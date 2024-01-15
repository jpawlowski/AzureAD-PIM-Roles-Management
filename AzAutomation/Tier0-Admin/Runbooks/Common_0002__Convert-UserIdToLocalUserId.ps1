<#PSScriptInfo
.VERSION 1.0.0
.GUID 06f32253-347f-45dc-a6f8-f61eb7fcfb0f
.AUTHOR Julian Pawlowski
.COMPANYNAME Workoho GmbH
.COPYRIGHT (c) 2024 Workoho GmbH. All rights reserved.
.TAGS
.LICENSEURI
.PROJECTURI
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS Common_0001__Connect-MgGraph.ps1,Common_0000__Import-Module.ps1
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>

<#
.SYNOPSIS
    Convert any user name like user@example.com or user_example.com#EXT@othertenant.onmicrosoft.com to a local User Principal Name that COULD exist in the tenant.

.DESCRIPTION
    Common runbook that can be used by other runbooks. It can not be started as an Azure Automation job directly.
#>

[CmdletBinding()]
Param(
    [Parameter(mandatory = $true)]
    [Array]$UserId,
    [Object]$VerifiedDomains
)

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | & { process{$_.PSObject.Properties | & { process{$_.Name + ': ' + $_.Value} }} }) -join ', ') ---"
$StartupVariables = (Get-Variable | & { process { $_.Name } })      # Remember existing variables so we can cleanup ours at the end of the script

$return = [System.Collections.ArrayList]::new($UserId.Count)

$tenantVerifiedDomains = if ($VerifiedDomains) { $VerifiedDomains } else {
    #region [COMMON] OPEN CONNECTIONS: Microsoft Graph -----------------------------
    .\Common_0001__Connect-MgGraph.ps1 -Scopes @(
        'Organization.Read.All'
    ) 1> $null
    #endregion ---------------------------------------------------------------------

    try {
        (Get-MgBetaOrganization -OrganizationId (Get-MgContext).TenantId -ErrorAction Stop -Verbose:$false).VerifiedDomains
    }
    catch {
        $_
    }
}
$tenantDomain = ($tenantVerifiedDomains | Where-Object { $_.IsInitial -eq $true }).Name

$UserId | & {
    process {
        if ($_.GetType().Name -ne 'String') {
            Write-Error "[COMMON]: - Input array UserId contains item of type $($_.GetType().Name)"
            return
        }
        if ([string]::IsNullOrEmpty( $_.Trim() )) {
            Write-Error '[COMMON]: - Input array UserId contains IsNullOrEmpty string'
            return
        }
        switch -Regex ( $_.Trim() ) {
            '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$' {
                $null = $script:return.Add($_)
                break
            }
            "^(.+)_([^_]+\..+)#EXT#@(.+)$" {
                if ($Matches[2] -in $tenantVerifiedDomains.Name) {
                    $UPN = [System.Text.StringBuilder]::new()
                    $null = $UPN.Append(($Matches[1]).ToLower())
                    $null = $UPN.Append('@')
                    $null = $UPN.Append(($Matches[2]).ToLower())
                    $null = $script:return.Add( $UPN.ToString() )
                    Write-Verbose "[COMMON]: - $_ > $($UPN.ToString()) (Uses a verified domain of this tenant, but was provided in external format)"
                }
                elseif ($Matches[3] -in $tenantVerifiedDomains.Name) {
                    Write-Verbose "[COMMON]: - $_ > $_ (Already in external format)"
                    $null = $script:return.Add($_)
                }
                else {
                    $UPN = [System.Text.StringBuilder]::new()
                    $null = $UPN.Append(($Matches[1]).ToLower())
                    $null = $UPN.Append('_')
                    $null = $UPN.Append(($Matches[2]).ToLower())
                    $null = $UPN.Append('#EXT#@')
                    $null = $UPN.Append($script:tenantDomain)
                    $null = $script:return.Add( $UPN.ToString() )
                    Write-Verbose "[COMMON]: - $_ > $($UPN.ToString()) (Uses an external domain in external format)"
                }
                break
            }
            '^([^\s]+)@([^\s]+\.[^\s]+)$' {
                if ($Matches[2] -in $tenantVerifiedDomains.Name) {
                    Write-Verbose "[COMMON]: - $_ > $_ (Uses a verified domain of this tenant)"
                    $null = $script:return.Add($_)
                }
                else {
                    $UPN = [System.Text.StringBuilder]::new()
                    $null = $UPN.Append(($Matches[1]).ToLower())
                    $null = $UPN.Append('_')
                    $null = $UPN.Append(($Matches[2]).ToLower())
                    $null = $UPN.Append('#EXT#@')
                    $null = $UPN.Append($script:tenantDomain)
                    $null = $script:return.Add( $UPN.ToString() )
                    Write-Verbose "[COMMON]: - $_ > $($UPN.ToString()) (Uses an external domain)"
                }
                break
            }
            default {
                Write-Warning "[COMMON]: - Could not convert $_ to local User Principal Name."
                $null = $script:return.Add($_)
                break
            }
        }
    }
}

Get-Variable | Where-Object { $StartupVariables -notcontains @($_.Name, 'return') } | & { process { Remove-Variable -Scope 0 -Name $_.Name -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -Verbose:$false -Debug:$false } }        # Delete variables created in this script to free up memory for tiny Azure Automation sandbox
Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
return $return.ToArray()
