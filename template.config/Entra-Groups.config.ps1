#Requires -Version 7.2

$EntraGroupsDisplayNamePrefix = $CompanyNameShort
$EntraGroupsTier0DisplayNamePrefix = @($EntraGroupsDisplayNamePrefix, 'T0') | Join-String -Separator $DisplayNameElementSeparator
$EntraGroupsTier1DisplayNamePrefix = @($EntraGroupsDisplayNamePrefix, 'T1') | Join-String -Separator $DisplayNameElementSeparator
$EntraGroupsTier2DisplayNamePrefix = @($EntraGroupsDisplayNamePrefix, 'T2') | Join-String -Separator $DisplayNameElementSeparator

$EntraGroupsSubfolder = 'Entra-Groups.config'
