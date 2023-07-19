#Requires -Version 7.2

$EntraCAPolicyDisplayNamePrefix = $CompanyNameShort
$EntraCAPolicyTier0DisplayNamePrefix = @($EntraCAPolicyDisplayNamePrefix, '0') | Join-String -Separator $DisplayNameElementSeparator
$EntraCAPolicyTier1DisplayNamePrefix = @($EntraCAPolicyDisplayNamePrefix, '1') | Join-String -Separator $DisplayNameElementSeparator
$EntraCAPolicyTier2DisplayNamePrefix = @($EntraCAPolicyDisplayNamePrefix, '2') | Join-String -Separator $DisplayNameElementSeparator

$EntraCAPoliciesSubfolder = 'Entra-CA-Policies.config'
