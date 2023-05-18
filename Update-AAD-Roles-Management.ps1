[CmdletBinding()]
Param (
    [
        Parameter(
            Position=0,
            Mandatory = $false,
            HelpMessage ="Azure AD tenant ID.",
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )
    ]
    [Alias("Tenant")]
    [string]$TenantId,
    [switch]$Tier0,
    [switch]$Tier1,
    [switch]$Tier2
    # [switch]$CreateAuthContext
)

$config = Join-Path $PSScriptRoot 'AAD-Roles-Management.config.ps1'
try {
    . $config
}
catch {
    Write-Error "Missing configuration file $config"
    exit
}

if (
    ($null -eq $TenantId) -or
    ($TenantId -eq '')
) {
    if (
        ($null -ne $env:TenantId) -and
        ($env:TenantId -ne '')
    ) {
        $TenantId = $env:TenantId
    } else {
        Write-Error "Missing `$env:TenantId environment variable or -TenantId parameter"
        exit
    }
}

if (
    ($false -eq $Tier0) -and
    ($false -eq $Tier1) -and
    ($false -eq $Tier2)
) {
    Write-Error "At least one Tier is required for update: -Tier0, -Tier1, or -Tier2"
    exit
}

if (
    ((Get-MgContext).TenantId -ne $TenantId) -or
    (-Not (((Get-MgContext).Scopes) -eq "RoleManagement.ReadWrite.Directory"))
) {
    try {
        Write-Host -NoNewline "Connecting to tenant $TenantId ..."
        $null = Connect-MgGraph -TenantId $TenantId -Scopes "RoleManagement.ReadWrite.Directory"
    }
    catch {
        Write-Host " failed"
        Write-Output $_
        exit
    }
    Write-Host " ok"
}

Write-Host ""

$ProcessingTiers = @();
if ($Tier0) {
    $ProcessingTiers += 0
}
if ($Tier1) {
    $ProcessingTiers += 1
}
if ($Tier2) {
    $ProcessingTiers += 2
}

foreach ($tier in $ProcessingTiers) {
    $i = 0
    foreach ($item in $AADRoleClassifications[$tier]) {
        if (
            ($null -eq $item.IsBuiltIn) -or
            (
                -Not $item.TemplateId -and
                -Not $item.displayName
            )
        ) {
            Write-Warning "[Tier${tier}] Incomplete role definition ignored at position $i"
            continue
        }

        try {
            if ($item.TemplateId) {
                $filter = "TemplateId eq '$($item.TemplateId)' and IsBuiltIn eq " + (($item.IsBuiltIn).ToString()).ToLower()
            } else {
                $filter = "displayName eq '$($item.displayName)' and IsBuiltIn eq " + (($item.IsBuiltIn).ToString()).ToLower()
            }
            $roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -Filter $filter

            $filter = "scopeId eq '/' and scopeType eq 'DirectoryRole' and RoleDefinitionId eq '$($roleDefinition.Id)'"
            $policyAssignment = Get-MgPolicyRoleManagementPolicyAssignment -Filter $filter

            Write-Host "[Tier${tier}] Updating management policy rules for role $($roleDefinition.TemplateId) ($($roleDefinition.displayName))"
            foreach ($itemPolicyRuleTemplate in $AADRoleManagementRulesDefaults[$tier]) {
                $itemPolicyRule = $itemPolicyRuleTemplate.PsObject.Copy()

                if ($item.ContainsKey($itemPolicyRule.Id)) {
                    Write-Host "          [Deviated] $($itemPolicyRule.Id)"
                    foreach ($key in $item.$($itemPolicyRule.Id).Keys) {
                        $itemPolicyRule.$key = $item.$($itemPolicyRule.Id).$key
                    }
                } else {
                    Write-Host "          [Default] $($itemPolicyRule.Id)"
                }

                Update-MgPolicyRoleManagementPolicyRule `
                    -UnifiedRoleManagementPolicyId $policyAssignment.PolicyId `
                    -UnifiedRoleManagementPolicyRuleId $itemPolicyRule.Id `
                    -BodyParameter $itemPolicyRule

                Start-Sleep -Seconds 1
            }
        }
        catch {
            Write-Output $_
        }

        Start-Sleep -Seconds 1
        $i++
    }
}
