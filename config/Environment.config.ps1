# Optional, but highly recommended when dealing with multiple tenants and configurations.
# Otherwise received from $env:TenantId or script parameter -TenantId
#$TenantId = '00000000-0000-0000-0000-000000000000'

$CompanyName = 'Contoso'

# Prefix string: Could be a namespace, a tenant indicator, etc.
$DisplayNamePrefix = $null
$DisplayNameElementSeparator = '-'

# To prefix display names of groups, you may define some kind of namespace
$AADGroupDisplayNamePrefix = 'TNAMESHRT'
