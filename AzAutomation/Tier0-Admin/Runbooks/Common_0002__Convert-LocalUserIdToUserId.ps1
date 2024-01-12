<#PSScriptInfo
.VERSION 1.0.0
.GUID 56ccfd86-ec40-4815-815a-00656a08952d
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
    Convert local User Principal Name like user@contoso.com or user_contoso.com#EXT@tenant.onmicrosoft.com to a user name like user@contoso.com.

.DESCRIPTION
    Common runbook that can be used by other runbooks. It can not be started as an Azure Automation job directly.
#>

[CmdletBinding()]
Param(
    [Parameter(mandatory = $true)]
    [Array]$UserId
)

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | & { process{$_.PSObject.Properties | & { process{$_.Name + ': ' + $_.Value} }} }) -join ', ') ---"
$StartupVariables = (Get-Variable | & { process { $_.Name } })      # Remember existing variables so we can cleanup ours at the end of the script

$return = [System.Collections.ArrayList]::new($UserId.Count)

$UserId | & {
    process {
        if ($_.GetType().Name -ne 'String') {
            Write-Error "Input array UserId contains item of type $($_.GetType().Name)"
            return
        }
        if ([string]::IsNullOrEmpty($_)) {
            Write-Error 'Input array UserId contains IsNullOrEmpty string'
            return
        }
        switch -Regex ($_) {
            '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$' {
                $null = $script:return.Add($_)
                break
            }
            "^(.+)_([^_]+\..+)#EXT#@(.+)$" {
                $UPN = [System.Text.StringBuilder]::new()
                $null = $UPN.Append(($Matches[1]).ToLower())
                $null = $UPN.Append('@')
                $null = $UPN.Append(($Matches[2]).ToLower())
                $null = $script:return.Add( $UPN.ToString() )
                break
            }
            '^(.+)@(.+)$' {
                $null = $script:return.Add($_)
                break
            }
            default {
                Write-Warning "Could not convert $_ to user name."
                $null = $script:return.Add($_)
                break
            }
        }
    }
}

Get-Variable | Where-Object { $StartupVariables -notcontains @($_.Name, 'return') } | & { process { Remove-Variable -Scope 0 -Name $_.Name -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -Verbose:$false -Debug:$false } }        # Delete variables created in this script to free up memory for tiny Azure Automation sandbox
Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
return $return.ToArray()
