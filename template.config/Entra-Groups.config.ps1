#Requires -Version 7.2

$EntraGroupsDisplayNamePrefix = $CompanyNameShort
$EntraGroupsTier0DisplayNamePrefix = @($EntraGroupsDisplayNamePrefix, 'T0') | Join-String -Separator $DisplayNameElementSeparator
$EntraGroupsTier1DisplayNamePrefix = @($EntraGroupsDisplayNamePrefix, 'T1') | Join-String -Separator $DisplayNameElementSeparator
$EntraGroupsTier2DisplayNamePrefix = @($EntraGroupsDisplayNamePrefix, 'T2') | Join-String -Separator $DisplayNameElementSeparator

$EntraGroupsConfigSubfolder = 'Entra-Groups.config'

$Tier0AdminAccountRegex = '^A0C_.+@' + [regex]::Escape($TenantName) + '$'
$Tier1AdminAccountRegex = '^A1C_.+@' + [regex]::Escape($TenantName) + '$'
