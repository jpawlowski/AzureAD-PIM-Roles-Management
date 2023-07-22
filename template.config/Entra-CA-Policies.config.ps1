#Requires -Version 7.2

$EntraCAPolicyDisplayNamePrefix = $CompanyNameShort
$EntraCAPolicyTier0DisplayNamePrefix = @($EntraCAPolicyDisplayNamePrefix, 'T0') | Join-String -Separator $DisplayNameElementSeparator
$EntraCAPolicyTier1DisplayNamePrefix = @($EntraCAPolicyDisplayNamePrefix, 'T1') | Join-String -Separator $DisplayNameElementSeparator
$EntraCAPolicyTier2DisplayNamePrefix = @($EntraCAPolicyDisplayNamePrefix, 'T2') | Join-String -Separator $DisplayNameElementSeparator

$EntraCAPoliciesConfigSubfolder = 'Entra-CA-Policies.config'
