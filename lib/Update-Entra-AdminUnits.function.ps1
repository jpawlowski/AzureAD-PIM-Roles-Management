<#
.SYNOPSIS

.DESCRIPTION

.LINK
    https://github.com/jpawlowski/AzureAD-PIM-Roles-Management

.NOTES
    Filename: Update-Entra-AdminUnits.function.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
#>
#Requires -Version 7.2
#Requires -Modules @{ ModuleName='Microsoft.Graph.Beta.Identity.DirectoryManagement'; ModuleVersion='2.0' }

$MgScopes += 'AdministrativeUnit.Read.All'
$MgScopes += 'AdministrativeUnit.ReadWrite.All'
$MgScopes += 'Directory.Write.Restricted'

function Update-Entra-AdminUnits {
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'High'
    )]
    [OutputType([Int])]
    Param (
        [array]$Config,
        [switch]$CommonAdminUnits,
        [switch]$TierAdminUnits,
        [string[]]$Id,
        [string[]]$Name,
        [switch]$Tier0,
        [switch]$Tier1,
        [switch]$Tier2,
        [switch]$Force
    )

    $ConfigLevels = @();

    if ($TierAdminUnits -or $Tier0 -or $Tier1 -or $Tier2) {
        if ($Tier0) {
            $ConfigLevels += 0
        }
        if ($Tier1) {
            $ConfigLevels += 1
        }
        if ($Tier2) {
            $ConfigLevels += 2
        }
        if ($ConfigLevels.Count -eq 0) {
            $ConfigLevels = @(0, 1, 2)
        }
    }

    if ($CommonAdminUnits -or !$TierAdminUnits) {
        $ConfigLevels += 3
    }

    $i = 0
    foreach ($ConfigLevel in $ConfigLevels) {
        if (
            ($null -eq $Config[$ConfigLevel]) -or
            ($Config[$ConfigLevel].Count -eq 0)
        ) {
            $i++
            continue
        }

        if ($ConfigLevel -le $EntraMaxAdminTier) {
            $Subject = "Tier $ConfigLevel"
        }
        else {
            $Subject = "Common"
        }

        # Validate unique config items
        [array]$list = @()
        foreach ($ConfigItem in $Config[$ConfigLevel]) {
            if (
                (-Not $ConfigItem.displayName) -or
                (-Not $ConfigItem.description)
            ) {
                Write-Warning "[$Subject] SKIPPED: Ignored incomplete object from file $(Join-Path (Split-Path (Split-Path $ConfigItem.FileOrigin -Parent) -Leaf) ($ConfigItem.FileOrigin.Name))"
                continue
            }

            $otherObjs = $Config[$ConfigLevel] | Where-Object -FilterScript { (($null -ne $_.id) -and ($_.id -eq $ConfigItem.id)) -or (($null -ne $_.displayName) -and ($_.displayName -eq $ConfigItem.displayName)) }
            if (($otherObjs | Measure-Object).Count -gt 1) {
                Write-Warning "[$Subject] SKIPPED: '$($ConfigItem.displayName)' ($($ConfigItem.id)) is defined for this configuration level already [File: $(Join-Path (Split-Path (Split-Path $ConfigItem.FileOrigin -Parent) -Leaf) ($ConfigItem.FileOrigin.Name))]"
                continue
            }

            $PreviousConfigLevel = $ConfigLevel - 1;
            $duplicate = $false
            do {
                $otherObjs = $Config[$PreviousConfigLevel] | Where-Object -FilterScript { (($null -ne $_.id) -and ($_.id -eq $ConfigItem.id)) -or (($null -ne $_.displayName) -and ($_.displayName -eq $ConfigItem.displayName)) }
                if (($otherObjs | Measure-Object).Count -gt 0) {
                    Write-Warning "[$Subject] SKIPPED: '$($ConfigItem.displayName)' ($($ConfigItem.id)) is a duplicate from higher configuration level $PreviousConfigLevel [Files: $(Join-Path (Split-Path (Split-Path $ConfigItem.FileOrigin -Parent) -Leaf) ($ConfigItem.FileOrigin.Name))]"
                    $duplicate = $true
                }
                $PreviousConfigLevel--
            } while (
                $PreviousConfigLevel -ge 0
            )
            if ($duplicate) {
                continue
            }

            $NextConfigLevel = $ConfigLevel + 1;
            $duplicate = $false
            do {
                $otherObjs = $Config[$NextConfigLevel] | Where-Object -FilterScript { (($null -ne $_.id) -and ($_.id -eq $ConfigItem.id)) -or (($null -ne $_.displayName) -and ($_.displayName -eq $ConfigItem.displayName)) }
                if (($otherObjs | Measure-Object).Count -gt 0) {
                    Write-Warning "[$Subject] SKIPPED: '$($ConfigItem.displayName)' ($($ConfigItem.id)) has a duplicate at lower configuration level $NextConfigLevel [Files: $(Join-Path (Split-Path (Split-Path $ConfigItem.FileOrigin -Parent) -Leaf) ($ConfigItem.FileOrigin.Name))]"
                    $duplicate = $true
                }
                $NextConfigLevel++
            } while (
                $NextConfigLevel -le $Config.Count
            )
            if ($duplicate) {
                continue
            }

            # If only selected items shall be worked on
            if ($Id -or $Name) {
                Write-Debug "[$Subject] Administrative Unit: Whitelist processing enabled"

                $found = $false
                if (
                    $Id -and
                    $ConfigItem.Id -and
                    ($ConfigItem.id -notmatch '^00000000-') -and
                    ($ConfigItem.id -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$') -and
                    ($ConfigItem.Id -in $Id)
                ) {
                    Write-Debug "[$Subject] Administrative Unit whitelist: Found $($ConfigItem.Id)"
                    $found = $true
                }
                elseif (
                    $Name -and
                    $ConfigItem.displayName -and
                    ($ConfigItem.displayName -in $Name)
                ) {
                    Write-Debug "[$Subject] Administrative Unit whitelist: Found $($ConfigItem.displayName)"
                    $found = $true
                }
                if (-Not $found) {
                    continue
                }
            }

            $list += $ConfigItem
        }

        if ($list.Count -eq 0) {
            $i++
            continue
        }

        $list = $list | Sort-Object -Property displayName

        $PercentComplete = $i / $ConfigLevels.Count * 100
        $params = @{
            Activity         = 'Working on                       '
            Status           = " $([math]::floor($PercentComplete))% Complete: $Subject"
            PercentComplete  = $PercentComplete
            CurrentOperation = 'EntraAdminUnitsConfigLevel'
        }
        Write-Progress @params

        if ($Force -or $WhatIfPreference -or $PSCmdlet.ShouldContinue(
                "Do you confirm to process a total of $($list.Count) [$Subject] Administrative Unit(s) ?",
                "!!! WARNING: Processing [$Subject] Microsoft Entra Administrative Units !!!"
            )) {

            $j = 0
            foreach ($ConfigItem in $list) {
                $j++

                $PercentComplete = $j / $list.Count * 100
                $params = @{
                    Id               = 1
                    ParentId         = 0
                    Activity         = 'Administrative Unit       '
                    Status           = " $([math]::floor($PercentComplete))% Complete: $($ConfigItem.displayName)"
                    PercentComplete  = $PercentComplete
                    CurrentOperation = 'EntraAdminUnitCreateOrUpdate'
                }

                $updateOnly = $false
                $obj = $null
                if (
                    ($null -ne $ConfigItem.id) -and
                    ($ConfigItem.id -notmatch '^00000000-') -and
                    ($ConfigItem.id -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$')
                ) {
                    $obj = Get-MgBetaAdministrativeUnit `
                        -AdministrativeUnitId $ConfigItem.id `
                        -ErrorAction SilentlyContinue
                    if ($obj) {
                        $updateOnly = $true
                    }
                    else {
                        Write-Warning "[$Subject] SKIPPED $($ConfigItem.id) Administrative Unit: No existing object found"
                        continue
                    }
                }
                else {
                    $obj = Get-MgBetaAdministrativeUnit -All `
                        -Filter "displayName eq '$($ConfigItem.displayName)'" `
                        -ErrorAction SilentlyContinue
                    if ($obj.Count -gt 1) {
                        Write-Error "[$Subject] Administrative Unit $($ConfigItem.displayName): Display Name is not a unique identifier; found $($obj.Count) objects instead of 1"
                        continue
                    }
                    elseif ($obj) {
                        Write-InformationColored -ForegroundColor Blue "HINT: [$Subject] Administrative Unit $($ConfigItem.displayName): Add the unique object ID '$($obj.Id)' to the configuration file for more robust resilience instead of using the display name for updates."
                        $ConfigItem.id = $obj.Id
                        $updateOnly = $true
                    }
                }

                $BodyParameter = $ConfigItem.PSObject.copy()
                $BodyParameter.Remove('FileOrigin')

                if ($updateOnly) {
                    $params.Activity = 'Update Administrative Unit'
                    $params.Status = " $([math]::floor($PercentComplete))% Complete: $($ConfigItem.displayName)"
                    Write-Progress @params

                    try {
                        $diff = Compare-Object -ReferenceObject $BodyParameter -DifferenceObject $obj -Property @($BodyParameter.Keys) -CaseSensitive
                        if ($diff) {
                            if ($PSCmdlet.ShouldProcess(
                                    "[$Subject] Administrative Unit: Update $($ConfigItem.id) ($($ConfigItem.displayName))",
                                    "Do you confirm to update this Administrative Unit?",
                                    "Update Administrative Unit $($ConfigItem.id) ($($ConfigItem.displayName))"
                                )) {
                                Write-Verbose "[$Subject] Updating Administrative Unit $($ConfigItem.id) ($($ConfigItem.displayName))"
                                Write-Debug "BodyParameter: $($BodyParameter | Out-String)"
                                $null = Update-MgBetaAdministrativeUnit `
                                    -AdministrativeUnitId $ConfigItem.Id `
                                    -BodyParameter $BodyParameter `
                                    -ErrorAction Stop `
                                    -Confirm:$false
                            }
                        }
                        else {
                            Write-Debug "[$Subject] Administrative Unit $($ConfigItem.id) ($($ConfigItem.displayName)) is up-to-date"
                        }
                    }
                    catch {
                        throw $_
                    }
                }
                else {
                    $params.Activity = 'Create Administrative Unit'
                    $params.Status = " $([math]::floor($PercentComplete))% Complete: $($ConfigItem.displayName)"
                    Write-Progress @params

                    try {
                        if ($PSCmdlet.ShouldProcess(
                                "[$Subject] Administrative Unit: Create '$($ConfigItem.displayName)'",
                                "Do you confirm to create this new Administrative Unit?",
                                "Create new Administrative Unit '$($ConfigItem.displayName)'"
                            )) {
                            Write-Verbose "[$Subject] Creating Administrative Unit '$($ConfigItem.displayName)'"

                            Write-Debug "BodyParameter: $($BodyParameter | Out-String)"
                            $obj = New-MgBetaAdministrativeUnit `
                                -BodyParameter $BodyParameter `
                                -ErrorAction Stop `
                                -Confirm:$false

                            Write-InformationColored -ForegroundColor Blue "[$Subject] Administrative Unit $($ConfigItem.displayName): Add the unique object ID '$($obj.Id)' to the configuration file for more robust resilience instead of using the display name for updates."
                            $ConfigItem.id = $obj.Id
                        }
                    }
                    catch {
                        throw $_
                    }
                }

                Start-Sleep -Milliseconds 25
            }
        }

        Start-Sleep -Milliseconds 25
        $i++
    }
}
