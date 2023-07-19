#Requires -Version 7.2

# Optional, but highly recommended when dealing with multiple tenants and configurations.
# Otherwise received from $env:TenantId or script parameter -TenantId
#$TenantId = '00000000-0000-0000-0000-000000000000'

$CompanyName = 'Contoso'
$CompanyNameShort = 'CTSO'

# Prefix string: Could be a namespace, a tenant indicator, etc.
$DisplayNamePrefix = $null
$DisplayNameElementSeparator = '-'
