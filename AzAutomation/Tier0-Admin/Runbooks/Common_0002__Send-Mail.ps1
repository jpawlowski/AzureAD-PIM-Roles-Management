<#PSScriptInfo
.VERSION 1.0.0
.GUID 2c248242-44a2-494e-9ff9-9e17fe363577
.AUTHOR Julian Pawlowski
.COMPANYNAME Workoho GmbH
.COPYRIGHT (c) 2024 Workoho GmbH. All rights reserved.
.TAGS
.LICENSEURI
.PROJECTURI
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS Common_0001__Connect-MgGraph.ps1
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>

<#
.SYNOPSIS
    Send email

.DESCRIPTION
    Common runbook that can be used by other runbooks. It can not be started as an Azure Automation job directly.
#>

[CmdletBinding()]
[OutputType([boolean])]
Param (
    [string]$From = $env:MG_PRINCIPAL_ID,

    [Parameter(mandatory = $true)]
    [array]$To,

    [array]$CC,

    [Parameter(mandatory = $true)]
    [string]$Subject,

    [Parameter(mandatory = $true)]
    [array]$Message,
    [boolean]$MessageIsRawHtmlContent,

    [string]$Headline,
    [string]$MessagePreview,
    [string]$Language = 'en',
    $Icon,
    $Logo
)

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | & { process{$_.PSObject.Properties | & { process{$_.Name + ': ' + $_.Value} }} }) -join ', ') ---"
$StartupVariables = (Get-Variable | & { process { $_.Name } })      # Remember existing variables so we can cleanup ours at the end of the script

$return = $null

Function Get-MessageRecipient ([array]$ListOfAddresses) {
    $ListOfAddresses | & {
        process {
            if ([string]::IsNullOrEmpty($_)) { return }
            @{
                EmailAddress = @{ Address = $_ }
            }
        }
    }
}

Function Get-FileAttachment ([array]$ListOfAttachments) {
    $ListOfAttachments | & {
        process {
            if ([string]::IsNullOrEmpty($_)) { return }
            Write-Verbose "[COMMON]: - Processing attachment $_"
            @{
                "@odata.type" = '#microsoft.graph.fileAttachment'
                name          = ($_ -split [IO.Path]::DirectorySeparatorChar)[-1]
                contentType   = 'text/plain'
                contentBytes  = [Convert]::ToBase64String([IO.File]::ReadAllBytes($_))
            }
        }
    }
}

.\Common_0001__Connect-MgGraph.ps1 -Scopes @( 'Mail.Send' )

try {
    $params = @{
        OutputType  = 'PSObject'
        Method      = 'POST'
        Uri         = "https://graph.microsoft.com/v1.0/users/$(if([string]::IsNullOrEmpty($From)) { (Get-MgContext).Account } else { $From })/microsoft.graph.sendMail"
        ErrorAction = 'Stop'
        Body        = @{
            Message         = @{
                Subject      = $Subject
                Body         = @{
                    ContentType = 'Html'
                    Content     = if ($MessageIsRawHtmlContent) {
                        $Message -join "`n"
                    }
                    else {
                        $params = @{
                            Language       = $Language
                            Title          = $Subject
                            Headline       = $(if ($Headline) { $Headline } else { $Subject })
                            Message        = $Message
                            MessagePreview = $MessagePreview
                            Icon           = $Icon
                            Logo           = $Logo
                            ErrorAction    = 'Stop'
                        }
                        .\Common_0000__New-HtmlMailBody.ps1 @params
                    }
                }
                ToRecipients = @(Get-MessageRecipient $To)
                CcRecipients = @(Get-MessageRecipient $CC)
            }
            saveToSentItems = $false
        } | ConvertTo-Json -Depth 10 -Compress
    }
    if ($null -eq $Verbose) { $params.Verbose = $false }
    Invoke-MgGraphRequest @params
}
catch {
    Write-Error $_
    $return = $false
}
if ($null -eq $return) { $return = $true }

Get-Variable | Where-Object { $StartupVariables -notcontains @($_.Name, 'return') } | & { process { Remove-Variable -Scope 0 -Name $_.Name -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -Verbose:$false -Debug:$false } }        # Delete variables created in this script to free up memory for tiny Azure Automation sandbox
Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
return $return
