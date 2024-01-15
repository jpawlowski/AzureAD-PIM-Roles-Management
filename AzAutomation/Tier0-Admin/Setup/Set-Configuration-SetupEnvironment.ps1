# Create admin unit for security groups:
#    $params = @{
#        OutputType = 'PSObject'
#        Method     = 'POST'
#        Uri        = "https://graph.microsoft.com/beta/administrativeUnits"
#        Body       = @{
#            displayName                   = 'CORP-T0-S-Cloud-Administration-Groups-RestrictedAdminUnit'
#            description                   = 'Groups for Privileged Cloud Administration in Tier 0, 1, and 2'
#            isMemberManagementRestricted  = $true
#            visibility                    = 'HiddenMembership'
#        }
#    }
#    $CloudAdmin_RestrictedAdminUnit = Invoke-MgGraphRequest @params

# Create admin unit for Tier0 admin accounts:
#    $params = @{
#        OutputType = 'PSObject'
#        Method     = 'POST'
#        Uri        = "https://graph.microsoft.com/beta/administrativeUnits"
#        Body       = @{
#            displayName                   = 'CORP-T0-D-Tier0-Admin-Users-RestrictedAdminUnit'
#            description                   = 'Privileged Users for Cloud Administration in Tier 0'
#            isMemberManagementRestricted  = $true
#            visibility                    = 'HiddenMembership'
#            membershipType                = 'Dynamic'
#            membershipRule                = @'
#                (user.userType -eq "Member") and
#                (user.onPremisesSecurityIdentifier -eq null) and
#                (user.userPrincipalName -notMatch "^.+#EXT#@.+\.onmicrosoft\.com$") and
#                (
#                    (user.userPrincipalName -match "A0C-.+@.+$") or
#                    (user.extensionAttribute15 -eq "A0C")
#                )
#    '@ -replace '(?m)^\s+'
#            membershipRuleProcessingState = 'On'
#        }
#    }
#    $CloudAdminTier0_AccountAdminUnit = Invoke-MgGraphRequest @params

# Create group for Tier0:
#    $params = @{
#        OutputType = 'PSObject'
#        Method     = 'POST'
#        Uri        = "https://graph.microsoft.com/v1.0/directory/administrativeUnits/$($CloudAdmin_RestrictedAdminUnit.Id)/members"
#        Body       = @{
#            '@odata.type'                 = '#Microsoft.Graph.Group'
#            displayName                   = 'CORP-T0-S-Privileged-Role-Tier0-Users'
#            description                   = 'Tier 0 Cloud Administrators'
#            securityEnabled               = $true
#            mailEnabled                   = $false
#            mailNickname                  = (New-Guid).Guid.Substring(0, 10)
#        }
#    }
#    $CloudAdminTier0_Group = Invoke-MgGraphRequest @params

# Create license group for dedicated Tier0 admin accounts:
#    $params = @{
#        OutputType = 'PSObject'
#        Method     = 'POST'
#        Uri        = "https://graph.microsoft.com/v1.0/directory/administrativeUnits/$($CloudAdmin_RestrictedAdminUnit.Id)/members"
#        Body       = @{
#            '@odata.type'                 = '#Microsoft.Graph.Group'
#            displayName                   = 'CORP-T0-D-Tier0-Admin-Users-Licensing'
#            description                   = 'Licensing for dedicated Tier 0 Cloud Administrator accounts'
#            securityEnabled               = $true
#            mailEnabled                   = $false
#            mailNickname                  = (New-Guid).Guid.Substring(0, 10)
#            groupTypes                    = @(
#                'DynamicMembership'
#            )
#            membershipRule                = @'
#                (user.userType -eq "Member") and
#                (user.onPremisesSecurityIdentifier -eq null) and
#                (user.userPrincipalName -notMatch "^.+#EXT#@.+\.onmicrosoft\.com$") and
#                (
#                  (user.userPrincipalName -match "A0C-.+@.+$") or
#                  (user.extensionAttribute15 -eq "A0C")
#                )
#    '@ -replace '(?m)^\s+'
#            membershipRuleProcessingState = 'On'
#        }
#    }
#    $CloudAdminTier0_LicenseGroup = Invoke-MgGraphRequest @params
#    $TenantSubscriptions = Get-MgBetaSubscribedSku -All -ErrorAction Stop
#    $licenseParams = @{
#        groupId = $CloudAdminTier0_LicenseGroup.Id
#        addLicenses = @(
#            @{
#                SkuId = ($TenantSubscriptions | Where-Object { $_.SkuPartNumber -eq 'EXCHANGEDESKLESS' }).SkuId
#                DisabledPlans = ($TenantSubscriptions | Where-Object { $_.SkuPartNumber -eq 'EXCHANGEDESKLESS' }).ServicePlans | Where-Object { ($_.AppliesTo -eq 'User') -and ($_.ServicePlanName -NotMatch 'EXCHANGE') } | Select-Object -ExpandProperty ServicePlanId
#            }
#        )
#        removeLicenses = @()
#    }
#    Set-MgGroupLicense @licenseParams

$env:AV_CloudAdmin_RestrictedAdminUnitId = '85d94a66-71a1-4d36-aa6b-bae93b741a1d'
$env:AV_CloudAdminTier0_GroupId = '02077e68-d40d-4ffc-b6ea-e84b12740ad6' # Must be member of AV_CloudAdmin_RestrictedAdminUnitId
$env:AV_CloudAdminTier1_GroupId = 'f43a0305-9c01-4c4a-be41-0057679d58e5' # Must be member of AV_CloudAdmin_RestrictedAdminUnitId
$env:AV_CloudAdminTier2_GroupId = 'abc148e4-810a-445b-9aab-eadf2fb96ea3' # Must be member of AV_CloudAdmin_RestrictedAdminUnitId

$env:AV_CloudAdminTier0_AccountRestrictedAdminUnitId = 'a4a254d2-2aa6-4f52-912d-b89a98b9a2bb' # Dedicated Tier 0 admin accounts go to this admin unit
$env:AV_CloudAdminTier0_LicenseGroupId = '4d155eee-64c4-4712-9d56-1cc07940144c' # Dedicated Tier 0 admin accounts receive their license from this group; Must be member of AV_CloudAdmin_RestrictedAdminUnitId
$env:AV_CloudAdminTier0_UserPhotoUrl = 'https://wkho-webresources.azureedge.net/user-photo/Tier0-Admin.png' # Dedicated User Photo for Tier 0 admin account

$env:AV_CloudAdminTier1_AccountAdminUnitId = '4eac6950-303e-46a4-bc62-dcff1192659b' # Dedicated Tier 1 admin accounts go to this admin unit
$env:AV_CloudAdminTier1_LicenseGroupId = '4c7bb801-1f49-4dd2-add8-5f42a9c72e36' # Dedicated Tier 1 admin accounts receive their license from this group; Must be member of AV_CloudAdmin_RestrictedAdminUnitId
$env:AV_CloudAdminTier1_UserPhotoUrl = 'https://wkho-webresources.azureedge.net/user-photo/Tier1-Admin.png' # Dedicated User Photo for Tier 1 admin account

$env:AV_CloudAdminTier2_AccountAdminUnitId = 'a6ca71dd-bc72-4979-bc2b-5687385346aa' # Dedicated Tier 2 admin accounts go to this admin unit
$env:AV_CloudAdminTier2_LicenseGroupId = 'cf8bbc81-e4a5-48fe-90b6-4cd706f0bbd5' # Dedicated Tier 2 admin accounts receive their license from this group; Must be member of AV_CloudAdmin_RestrictedAdminUnitId
