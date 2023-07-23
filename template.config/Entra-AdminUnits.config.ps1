#Requires -Version 7.2

$EntraAdminUnitsDisplayNamePrefix = $CompanyNameShort
$EntraAdminUnitsDisplayNameSuffix = 'AdminUnit'
$EntraAdminUnitsRestrictedDisplayNameSuffix = "Restricted$EntraAdminUnitsDisplayNameSuffix"
$EntraAdminUnitsTier0DisplayNamePrefix = @($EntraAdminUnitsDisplayNamePrefix, 'T0') | Join-String -Separator $DisplayNameElementSeparator
$EntraAdminUnitsTier1DisplayNamePrefix = @($EntraAdminUnitsDisplayNamePrefix, 'T1') | Join-String -Separator $DisplayNameElementSeparator
$EntraAdminUnitsTier2DisplayNamePrefix = @($EntraAdminUnitsDisplayNamePrefix, 'T2') | Join-String -Separator $DisplayNameElementSeparator

$EntraAdminUnitsConfigSubfolder = 'Entra-AdminUnits.config'
