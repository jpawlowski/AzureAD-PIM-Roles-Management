<#
.SYNOPSIS

.DESCRIPTION

.LINK
    https://github.com/jpawlowski/AzureAD-PIM-Roles-Management

.NOTES
    Filename: Update-Entra-Groups.function.ps1
    Author: Julian Pawlowski <metres_topaz.0v@icloud.com>
#>
#Requires -Version 7.2
#Requires -Modules @{ ModuleName='Microsoft.Graph.Groups'; ModuleVersion='2.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Beta.Identity.DirectoryManagement'; ModuleVersion='2.0' }

$MgScopes += 'Group.Read.All'
$MgScopes += 'Group.ReadWrite.All'
$MgScopes += 'Directory.Write.Restricted'
$MgScopes += 'AdministrativeUnit.Read.All'
$MgScopes += 'AdministrativeUnit.ReadWrite.All'

function Update-Entra-Groups {
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'High'
    )]
    [OutputType([Int])]
    Param (
        [array]$Config,
        [switch]$CommonGroups,
        [switch]$TierGroups,
        [string[]]$Id,
        [string[]]$Name,
        [switch]$Tier0,
        [switch]$Tier1,
        [switch]$Tier2,
        [switch]$Force
    )

    $ConfigLevels = @();

    if ($TierGroups -or $Tier0 -or $Tier1 -or $Tier2) {
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

    if ($CommonGroups -or !$TierGroups) {
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
                Write-Debug "[$Subject] Group: Whitelist processing enabled"

                $found = $false
                if (
                    $Id -and
                    $ConfigItem.Id -and
                    ($ConfigItem.id -notmatch '^00000000-') -and
                    ($ConfigItem.id -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$') -and
                    ($ConfigItem.Id -in $Id)
                ) {
                    Write-Debug "[$Subject] Group whitelist: Found $($ConfigItem.Id)"
                    $found = $true
                }
                elseif (
                    $Name -and
                    $ConfigItem.displayName -and
                    ($ConfigItem.displayName -in $Name)
                ) {
                    Write-Debug "[$Subject] Group whitelist: Found $($ConfigItem.displayName)"
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
            CurrentOperation = 'EntraGroupsConfigLevel'
        }
        Write-Progress @params

        if ($Force -or $WhatIfPreference -or $PSCmdlet.ShouldContinue(
                "Do you confirm to process a total of $($list.Count) [$Subject] Group(s) ?",
                "!!! WARNING: Processing [$Subject] Microsoft Entra Groups !!!"
            )) {

            $j = 0
            foreach ($ConfigItem in $list) {
                $j++

                $PercentComplete = $j / $list.Count * 100
                $params = @{
                    Id               = 1
                    ParentId         = 0
                    Activity         = 'Group       '
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
                    $obj = Get-MgGroup `
                        -GroupId $ConfigItem.id `
                        -ErrorAction SilentlyContinue
                    if ($obj) {
                        $updateOnly = $true
                    }
                    else {
                        Write-Warning "[$Subject] SKIPPED $($ConfigItem.id) Group: No existing object found"
                        continue
                    }
                }
                else {
                    $obj = Get-MgGroup -All `
                        -Filter "displayName eq '$($ConfigItem.displayName)'" `
                        -ErrorAction SilentlyContinue
                    if ($obj.Count -gt 1) {
                        Write-Error "[$Subject] Group $($ConfigItem.displayName): Display Name is not a unique identifier; found $($obj.Count) objects instead of 1"
                        continue
                    }
                    elseif ($obj) {
                        Write-InformationColored -ForegroundColor Blue "HINT: [$Subject] Group $($ConfigItem.displayName): Add the unique object ID '$($obj.Id)' to the configuration file for more robust resilience instead of using the display name for updates."
                        $ConfigItem.id = $obj.Id
                        $updateOnly = $true
                    }
                }

                $BodyParameter = $ConfigItem.PSObject.copy()
                $BodyParameter.Remove('FileOrigin')
                $BodyParameter.Remove('administrativeUnit')

                if ($updateOnly) {
                    $params.Activity = 'Update Group'
                    $params.Status = " $([math]::floor($PercentComplete))% Complete: $($ConfigItem.displayName)"
                    Write-Progress @params

                    try {
                        $diff = Compare-Object -ReferenceObject $BodyParameter -DifferenceObject $obj -Property @($BodyParameter.Keys) -CaseSensitive
                        if ($diff) {
                            if ($PSCmdlet.ShouldProcess(
                                    "[$Subject] Group: Update $($ConfigItem.id) ($($ConfigItem.displayName))",
                                    "Do you confirm to update this Group?",
                                    "Update Group $($ConfigItem.id) ($($ConfigItem.displayName))"
                                )) {
                                Write-Verbose "[$Subject] Updating Group $($ConfigItem.id) ($($ConfigItem.displayName))"
                                Write-Debug "BodyParameter: $($BodyParameter | Out-String)"
                                $null = Update-MgGroup `
                                    -GroupId $ConfigItem.Id `
                                    -BodyParameter $BodyParameter `
                                    -ErrorAction Stop `
                                    -Confirm:$false
                            }
                        }
                        else {
                            Write-Debug "[$Subject] Group $($ConfigItem.id) ($($ConfigItem.displayName)) is up-to-date"
                        }
                    }
                    catch {
                        throw $_
                    }
                }
                else {
                    $params.Activity = 'Create Group'
                    $params.Status = " $([math]::floor($PercentComplete))% Complete: $($ConfigItem.displayName)"
                    Write-Progress @params

                    try {
                        if ($PSCmdlet.ShouldProcess(
                                "[$Subject] Group: Create '$($ConfigItem.displayName)'",
                                "Do you confirm to create this new Group?",
                                "Create new Group '$($ConfigItem.displayName)'"
                            )) {
                            Write-Verbose "[$Subject] Creating Group '$($ConfigItem.displayName)'"
                            if ($null -eq $BodyParameter.mailNickname) {
                                $ConfigItem.mailNickname = (New-Guid).Guid.Substring(0, 10)
                                $BodyParameter.mailNickname = $ConfigItem.mailNickname
                            }

                            Write-Debug "BodyParameter: $($BodyParameter | Out-String)"
                            $obj = New-MgGroup `
                                -BodyParameter $BodyParameter `
                                -ErrorAction Stop `
                                -Confirm:$false

                            Write-InformationColored -ForegroundColor Blue "[$Subject] Group $($ConfigItem.displayName): Add the unique object ID '$($obj.Id)' to the configuration file for more robust resilience instead of using the display name for updates."
                            $ConfigItem.id = $obj.Id

                            if ($ConfigItem.administrativeUnit) {
                                $BodyParameter = @{
                                    "@odata.id" = "https://graph.microsoft.com/beta/groups/$($ConfigItem.id)"
                                }

                                foreach ($adminUnit in $ConfigItem.administrativeUnit) {
                                    $obj = $null
                                    if (
                                        ($null -ne $adminUnit.id) -and
                                        ($adminUnit.id -notmatch '^00000000-') -and
                                        ($adminUnit.id -match '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$')
                                    ) {
                                        $obj = Get-MgBetaAdministrativeUnit `
                                            -AdministrativeUnitId $adminUnit.id `
                                            -ErrorAction SilentlyContinue
                                        if ($null -eq $obj) {
                                            Write-Warning "[$Subject] Group $($ConfigItem.displayName): SKIPPED $($adminUnit.id) Administrative Unit: No existing object found"
                                            continue
                                        }
                                    }
                                    else {
                                        $obj = Get-MgBetaAdministrativeUnit -All `
                                            -Filter "displayName eq '$($adminUnit.displayName)'" `
                                            -ErrorAction SilentlyContinue
                                        if ($obj.Count -gt 1) {
                                            Write-Error "[$Subject] Group $($ConfigItem.displayName): Administrative Unit $($adminUnit.displayName): Display Name is not a unique identifier; found $($obj.Count) objects instead of 1"
                                            continue
                                        }
                                        elseif ($obj) {
                                            Write-InformationColored -ForegroundColor Blue "HINT: [$Subject] Group $($ConfigItem.displayName): Administrative Unit $($adminUnit.displayName): Add the unique object ID '$($obj.Id)' to the configuration file for more robust resilience instead of using the display name for updates."
                                            $adminUnit.id = $obj.Id
                                            $updateOnly = $true
                                        }
                                    }

                                    $null = New-MgBetaDirectoryAdministrativeUnitMemberByRef `
                                        -AdministrativeUnitId $adminUnit.Id `
                                        -BodyParameter $BodyParameter `
                                        -ErrorAction Stop `
                                        -Confirm:$false
                                }
                            }
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
