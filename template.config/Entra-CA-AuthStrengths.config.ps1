#Requires -Version 7.2

$EntraCAAuthStrengthDisplayNamePrefix = $null
$EntraCAAuthStrengthDisplayNameSuffix = 'AuthStr'

$EntraCAAuthStrengths = @(
    #:-------------------------------------------------------------------------
    # Tier 0 Authentication Strengths
    #
    # Note: For security reasons, no built-in Authentication Strengths are supported.
    # Dedicated custom Authentication Strength policies are required to be created for full Tier separation.
    #
    @{
        account                = @{
            # id = ''   # This is tenant specific and may be added after initial creation to use GUID instead of name
            displayName               = @($EntraCAAuthStrengthDisplayNamePrefix, 'Tier0-Admin-Account', $EntraCAAuthStrengthDisplayNameSuffix) | Join-String -Separator $DisplayNameElementSeparator
            description               = 'Authentication methods for users with no Tier0 Microsoft Entra ID Roles activated. DO NOT CHANGE MANUALLY!'

            # List: https://learn.microsoft.com/en-us/graph/api/authenticationstrengthroot-list-authenticationmethodmodes?tabs=http#response-1
            allowedCombinations       = @(
                'windowsHelloForBusiness'
                'fido2'
                # 'deviceBasedPush'             # Optionally required if your Tier0 users do not use FIDO2 security keys
                'temporaryAccessPassOneTime'    # Required for passwordless onboarding of new Tier0 admin accounts, but only available without any active roles
                'temporaryAccessPassMultiUse'   # Required for passwordless onboarding of new Tier0 admin accounts, but only available without any active roles
            )

            combinationConfigurations = @{
                fido2 = @{
                    '@odata.type'  = '#microsoft.graph.fido2CombinationConfiguration'
                    allowedAAGUIDs = @(
                        # From https://support.yubico.com/hc/en-us/articles/360016648959-YubiKey-Hardware-FIDO2-AAGUIDs
                        'cb69481e-8ff7-4039-93ec-0a2729a154a8' # YubiKey 5 Series (Firmware 5.1)
                        'ee882879-721c-4913-9775-3dfcce97072a' # YubiKey 5 Series (Firmware 5.2, 5.4)
                        'fa2b99dc-9e39-4257-8f92-4a30d23c4118' # YubiKey 5 Series with NFC (Firmware 5.1)
                        '2fc0579f-8113-47ea-b116-bb5a8db9202a' # YubiKey 5 Series with NFC (Firmware 5.2, 5.4)
                        '73bb0cd4-e502-49b8-9c6f-b59445bf720b' # YubiKey 5 FIPS Series (Firmware 5.4)
                        'c1f9a0bc-1dd2-404a-b27f-8e29047a43fd' # YubiKey 5 FIPS Series with NFC (Firmware 5.4)
                        'c5ef55ff-ad9a-4b9f-b580-adebafe026d0' # YubiKey 5Ci (Firmware 5.2, 5.4)
                        '85203421-48f9-4355-9bc8-8a53846e5083' # YubiKey 5Ci FIPS (Firmware 5.4)
                        'd8522d9f-575b-4866-88a9-ba99fa02f35b' # YubiKey Bio Series (Firmware 5.5)
                        'f8a011f3-8c0a-4d15-8006-17111f9edc7d' # Security Key by Yubico (Firmware 5.1)
                        'b92c3f9a-c014-4056-887f-140a2501163b' # Security Key by Yubico (Firmware 5.2)
                        '6d44ba9b-f6ec-2e49-b930-0c8fe920cb73' # Security Key by Yubico with NFC (Firmware 5.1)
                        '149a2021-8ef6-4133-96b8-81f8d5b7f1f5' # Security Key by Yubico with NFC (Firmware 5.2, 5.4)
                        'a4e9fc6d-4cbe-4758-b8ba-37598bb5bbaa' # Security Key by Yubico with NFC - Black (Firmware 5.4)
                        '0bb43545-fd2c-4185-87dd-feb0b2916ace' # Security Key by Yubico with NFC - Enterprise Edition (Firmware 5.4)

                        # From https://github.com/passkeydeveloper/passkey-authenticator-aaguids/blob/main/aaguid.json
                        # 'dd4ec289-e01d-41c9-bb89-70fa845d4bf2' # Apple iCloud Keychain (Managed)
                        # 'd548826e-79b4-db40-a3d8-11116f7e8349' # Bitwarden
                        # 'adce0002-35bc-c60a-648b-0b25f1f05503' # Chrome on Mac
                        # 'b5397666-4885-aa6b-cebf-e52262a439a2' # Chromium Browser
                        # '531126d6-e717-415c-9320-3d9aa6981239' # Dashlane
                        # '771b48fd-d3d4-4f74-9232-fc157ab0507a' # Edge on Mac
                        # 'f3809540-7f14-49c1-a8b3-8f813b225541' # Enpass
                        # 'ea9b8d66-4d01-1d21-3ce4-b6b48cb575d4' # Google Password Manager
                        # '39a5647e-1853-446c-a1f6-a79bae9f5bc7' # IDmelon
                        # '0ea242b4-43c4-4a1b-8b17-dd6d0b6baec6' # Keeper
                        # 'b84e4048-15dc-4dd0-8640-f4f60813c8af' # NordPass
                        # '53414d53-554e-4700-0000-000000000000' # Samsung Pass
                        # '08987058-cadc-4b81-b6e1-30de50dcbe96' # Windows Hello Hardware Authenticator
                        # '6028b017-b1d4-4c02-b4b3-afcdafc96bb2' # Windows Hello Software Authenticator
                        # '9ddd1817-af5a-4672-a2b9-3e3dd95000a9' # Windows Hello VBS Hardware Authenticator
                        # 'bada5566-a7aa-401f-bd96-45619a55120d' # 1Password
                    )
                }
            }
        }
        activeRole             = @{
            # id = ''   # This is tenant specific and may be added after initial creation to use GUID instead of name
            displayName               = @($EntraCAAuthStrengthDisplayNamePrefix, 'Tier0-Admin-Role', $EntraCAAuthStrengthDisplayNameSuffix) | Join-String -Separator $DisplayNameElementSeparator
            description               = 'Authentication methods for users with active Tier0 Azure AD Roles. DO NOT CHANGE MANUALLY!'

            # List: https://learn.microsoft.com/en-us/graph/api/authenticationstrengthroot-list-authenticationmethodmodes?tabs=http#response-1
            allowedCombinations       = @(
                'windowsHelloForBusiness'
                'fido2'
                # 'deviceBasedPush'             # Optionally required if your Tier0 users do not use FIDO2 security keys
            )

            combinationConfigurations = @{
                fido2 = @{
                    '@odata.type'  = '#microsoft.graph.fido2CombinationConfiguration'
                    allowedAAGUIDs = @(
                        # From https://support.yubico.com/hc/en-us/articles/360016648959-YubiKey-Hardware-FIDO2-AAGUIDs
                        'cb69481e-8ff7-4039-93ec-0a2729a154a8' # YubiKey 5 Series (Firmware 5.1)
                        'ee882879-721c-4913-9775-3dfcce97072a' # YubiKey 5 Series (Firmware 5.2, 5.4)
                        'fa2b99dc-9e39-4257-8f92-4a30d23c4118' # YubiKey 5 Series with NFC (Firmware 5.1)
                        '2fc0579f-8113-47ea-b116-bb5a8db9202a' # YubiKey 5 Series with NFC (Firmware 5.2, 5.4)
                        '73bb0cd4-e502-49b8-9c6f-b59445bf720b' # YubiKey 5 FIPS Series (Firmware 5.4)
                        'c1f9a0bc-1dd2-404a-b27f-8e29047a43fd' # YubiKey 5 FIPS Series with NFC (Firmware 5.4)
                        'c5ef55ff-ad9a-4b9f-b580-adebafe026d0' # YubiKey 5Ci (Firmware 5.2, 5.4)
                        '85203421-48f9-4355-9bc8-8a53846e5083' # YubiKey 5Ci FIPS (Firmware 5.4)
                        'd8522d9f-575b-4866-88a9-ba99fa02f35b' # YubiKey Bio Series (Firmware 5.5)
                        'f8a011f3-8c0a-4d15-8006-17111f9edc7d' # Security Key by Yubico (Firmware 5.1)
                        'b92c3f9a-c014-4056-887f-140a2501163b' # Security Key by Yubico (Firmware 5.2)
                        '6d44ba9b-f6ec-2e49-b930-0c8fe920cb73' # Security Key by Yubico with NFC (Firmware 5.1)
                        '149a2021-8ef6-4133-96b8-81f8d5b7f1f5' # Security Key by Yubico with NFC (Firmware 5.2, 5.4)
                        'a4e9fc6d-4cbe-4758-b8ba-37598bb5bbaa' # Security Key by Yubico with NFC - Black (Firmware 5.4)
                        '0bb43545-fd2c-4185-87dd-feb0b2916ace' # Security Key by Yubico with NFC - Enterprise Edition (Firmware 5.4)

                        # From https://github.com/passkeydeveloper/passkey-authenticator-aaguids/blob/main/aaguid.json
                        # 'dd4ec289-e01d-41c9-bb89-70fa845d4bf2' # Apple iCloud Keychain (Managed)
                        # 'd548826e-79b4-db40-a3d8-11116f7e8349' # Bitwarden
                        # 'adce0002-35bc-c60a-648b-0b25f1f05503' # Chrome on Mac
                        # 'b5397666-4885-aa6b-cebf-e52262a439a2' # Chromium Browser
                        # '531126d6-e717-415c-9320-3d9aa6981239' # Dashlane
                        # '771b48fd-d3d4-4f74-9232-fc157ab0507a' # Edge on Mac
                        # 'f3809540-7f14-49c1-a8b3-8f813b225541' # Enpass
                        # 'ea9b8d66-4d01-1d21-3ce4-b6b48cb575d4' # Google Password Manager
                        # '39a5647e-1853-446c-a1f6-a79bae9f5bc7' # IDmelon
                        # '0ea242b4-43c4-4a1b-8b17-dd6d0b6baec6' # Keeper
                        # 'b84e4048-15dc-4dd0-8640-f4f60813c8af' # NordPass
                        # '53414d53-554e-4700-0000-000000000000' # Samsung Pass
                        # '08987058-cadc-4b81-b6e1-30de50dcbe96' # Windows Hello Hardware Authenticator
                        # '6028b017-b1d4-4c02-b4b3-afcdafc96bb2' # Windows Hello Software Authenticator
                        # '9ddd1817-af5a-4672-a2b9-3e3dd95000a9' # Windows Hello VBS Hardware Authenticator
                        # 'bada5566-a7aa-401f-bd96-45619a55120d' # 1Password
                    )
                }
            }
        }
        roleEnablement         = @{
            # id = ''   # This is tenant specific and may be added after initial creation to use GUID instead of name
            displayName               = @($EntraCAAuthStrengthDisplayNamePrefix, 'Tier0-Admin-PIM', $EntraCAAuthStrengthDisplayNameSuffix) | Join-String -Separator $DisplayNameElementSeparator
            description               = "Authentication methods during Azure AD Role enablement for $($EntraCAAuthContexts[0].default.displayName). DO NOT CHANGE MANUALLY!"

            # List: https://learn.microsoft.com/en-us/graph/api/authenticationstrengthroot-list-authenticationmethodmodes?tabs=http#response-1
            allowedCombinations       = @(
                'windowsHelloForBusiness'
                'fido2'
                # 'deviceBasedPush'             # Optionally required if your Tier0 users do not use FIDO2 security keys
            )

            combinationConfigurations = @{
                fido2 = @{
                    '@odata.type'  = '#microsoft.graph.fido2CombinationConfiguration'
                    allowedAAGUIDs = @(
                        # From https://support.yubico.com/hc/en-us/articles/360016648959-YubiKey-Hardware-FIDO2-AAGUIDs
                        'cb69481e-8ff7-4039-93ec-0a2729a154a8' # YubiKey 5 Series (Firmware 5.1)
                        'ee882879-721c-4913-9775-3dfcce97072a' # YubiKey 5 Series (Firmware 5.2, 5.4)
                        'fa2b99dc-9e39-4257-8f92-4a30d23c4118' # YubiKey 5 Series with NFC (Firmware 5.1)
                        '2fc0579f-8113-47ea-b116-bb5a8db9202a' # YubiKey 5 Series with NFC (Firmware 5.2, 5.4)
                        '73bb0cd4-e502-49b8-9c6f-b59445bf720b' # YubiKey 5 FIPS Series (Firmware 5.4)
                        'c1f9a0bc-1dd2-404a-b27f-8e29047a43fd' # YubiKey 5 FIPS Series with NFC (Firmware 5.4)
                        'c5ef55ff-ad9a-4b9f-b580-adebafe026d0' # YubiKey 5Ci (Firmware 5.2, 5.4)
                        '85203421-48f9-4355-9bc8-8a53846e5083' # YubiKey 5Ci FIPS (Firmware 5.4)
                        'd8522d9f-575b-4866-88a9-ba99fa02f35b' # YubiKey Bio Series (Firmware 5.5)
                        'f8a011f3-8c0a-4d15-8006-17111f9edc7d' # Security Key by Yubico (Firmware 5.1)
                        'b92c3f9a-c014-4056-887f-140a2501163b' # Security Key by Yubico (Firmware 5.2)
                        '6d44ba9b-f6ec-2e49-b930-0c8fe920cb73' # Security Key by Yubico with NFC (Firmware 5.1)
                        '149a2021-8ef6-4133-96b8-81f8d5b7f1f5' # Security Key by Yubico with NFC (Firmware 5.2, 5.4)
                        'a4e9fc6d-4cbe-4758-b8ba-37598bb5bbaa' # Security Key by Yubico with NFC - Black (Firmware 5.4)
                        '0bb43545-fd2c-4185-87dd-feb0b2916ace' # Security Key by Yubico with NFC - Enterprise Edition (Firmware 5.4)

                        # From https://github.com/passkeydeveloper/passkey-authenticator-aaguids/blob/main/aaguid.json
                        # 'dd4ec289-e01d-41c9-bb89-70fa845d4bf2' # Apple iCloud Keychain (Managed)
                        # 'd548826e-79b4-db40-a3d8-11116f7e8349' # Bitwarden
                        # 'adce0002-35bc-c60a-648b-0b25f1f05503' # Chrome on Mac
                        # 'b5397666-4885-aa6b-cebf-e52262a439a2' # Chromium Browser
                        # '531126d6-e717-415c-9320-3d9aa6981239' # Dashlane
                        # '771b48fd-d3d4-4f74-9232-fc157ab0507a' # Edge on Mac
                        # 'f3809540-7f14-49c1-a8b3-8f813b225541' # Enpass
                        # 'ea9b8d66-4d01-1d21-3ce4-b6b48cb575d4' # Google Password Manager
                        # '39a5647e-1853-446c-a1f6-a79bae9f5bc7' # IDmelon
                        # '0ea242b4-43c4-4a1b-8b17-dd6d0b6baec6' # Keeper
                        # 'b84e4048-15dc-4dd0-8640-f4f60813c8af' # NordPass
                        # '53414d53-554e-4700-0000-000000000000' # Samsung Pass
                        # '08987058-cadc-4b81-b6e1-30de50dcbe96' # Windows Hello Hardware Authenticator
                        # '6028b017-b1d4-4c02-b4b3-afcdafc96bb2' # Windows Hello Software Authenticator
                        # '9ddd1817-af5a-4672-a2b9-3e3dd95000a9' # Windows Hello VBS Hardware Authenticator
                        # 'bada5566-a7aa-401f-bd96-45619a55120d' # 1Password
                    )
                }
            }
        }
        scopableRoleEnablement = @{
            # id = ''   # This is tenant specific and may be added after initial creation to use GUID instead of name
            displayName               = @($EntraCAAuthStrengthDisplayNamePrefix, 'Tier0-Scoped-Admin-PIM', $EntraCAAuthStrengthDisplayNameSuffix) | Join-String -Separator $DisplayNameElementSeparator
            description               = "Authentication methods during Azure AD Role enablement for $($EntraCAAuthContexts[0].scopable.displayName). DO NOT CHANGE MANUALLY!"

            # List: https://learn.microsoft.com/en-us/graph/api/authenticationstrengthroot-list-authenticationmethodmodes?tabs=http#response-1
            allowedCombinations       = @(
                'windowsHelloForBusiness'
                'fido2'
                'deviceBasedPush'
            )

            combinationConfigurations = @{
                fido2 = @{
                    '@odata.type'  = '#microsoft.graph.fido2CombinationConfiguration'
                    allowedAAGUIDs = @(
                        # From https://support.yubico.com/hc/en-us/articles/360016648959-YubiKey-Hardware-FIDO2-AAGUIDs
                        'cb69481e-8ff7-4039-93ec-0a2729a154a8' # YubiKey 5 Series (Firmware 5.1)
                        'ee882879-721c-4913-9775-3dfcce97072a' # YubiKey 5 Series (Firmware 5.2, 5.4)
                        'fa2b99dc-9e39-4257-8f92-4a30d23c4118' # YubiKey 5 Series with NFC (Firmware 5.1)
                        '2fc0579f-8113-47ea-b116-bb5a8db9202a' # YubiKey 5 Series with NFC (Firmware 5.2, 5.4)
                        '73bb0cd4-e502-49b8-9c6f-b59445bf720b' # YubiKey 5 FIPS Series (Firmware 5.4)
                        'c1f9a0bc-1dd2-404a-b27f-8e29047a43fd' # YubiKey 5 FIPS Series with NFC (Firmware 5.4)
                        'c5ef55ff-ad9a-4b9f-b580-adebafe026d0' # YubiKey 5Ci (Firmware 5.2, 5.4)
                        '85203421-48f9-4355-9bc8-8a53846e5083' # YubiKey 5Ci FIPS (Firmware 5.4)
                        'd8522d9f-575b-4866-88a9-ba99fa02f35b' # YubiKey Bio Series (Firmware 5.5)
                        'f8a011f3-8c0a-4d15-8006-17111f9edc7d' # Security Key by Yubico (Firmware 5.1)
                        'b92c3f9a-c014-4056-887f-140a2501163b' # Security Key by Yubico (Firmware 5.2)
                        '6d44ba9b-f6ec-2e49-b930-0c8fe920cb73' # Security Key by Yubico with NFC (Firmware 5.1)
                        '149a2021-8ef6-4133-96b8-81f8d5b7f1f5' # Security Key by Yubico with NFC (Firmware 5.2, 5.4)
                        'a4e9fc6d-4cbe-4758-b8ba-37598bb5bbaa' # Security Key by Yubico with NFC - Black (Firmware 5.4)
                        '0bb43545-fd2c-4185-87dd-feb0b2916ace' # Security Key by Yubico with NFC - Enterprise Edition (Firmware 5.4)

                        # From https://github.com/passkeydeveloper/passkey-authenticator-aaguids/blob/main/aaguid.json
                        # 'dd4ec289-e01d-41c9-bb89-70fa845d4bf2' # Apple iCloud Keychain (Managed)
                        # 'd548826e-79b4-db40-a3d8-11116f7e8349' # Bitwarden
                        # 'adce0002-35bc-c60a-648b-0b25f1f05503' # Chrome on Mac
                        # 'b5397666-4885-aa6b-cebf-e52262a439a2' # Chromium Browser
                        # '531126d6-e717-415c-9320-3d9aa6981239' # Dashlane
                        # '771b48fd-d3d4-4f74-9232-fc157ab0507a' # Edge on Mac
                        # 'f3809540-7f14-49c1-a8b3-8f813b225541' # Enpass
                        # 'ea9b8d66-4d01-1d21-3ce4-b6b48cb575d4' # Google Password Manager
                        # '39a5647e-1853-446c-a1f6-a79bae9f5bc7' # IDmelon
                        # '0ea242b4-43c4-4a1b-8b17-dd6d0b6baec6' # Keeper
                        # 'b84e4048-15dc-4dd0-8640-f4f60813c8af' # NordPass
                        # '53414d53-554e-4700-0000-000000000000' # Samsung Pass
                        # '08987058-cadc-4b81-b6e1-30de50dcbe96' # Windows Hello Hardware Authenticator
                        # '6028b017-b1d4-4c02-b4b3-afcdafc96bb2' # Windows Hello Software Authenticator
                        # '9ddd1817-af5a-4672-a2b9-3e3dd95000a9' # Windows Hello VBS Hardware Authenticator
                        # 'bada5566-a7aa-401f-bd96-45619a55120d' # 1Password
                    )
                }
            }
        }
    }

    #:-------------------------------------------------------------------------
    # Tier 1 Authentication Strengths
    #
    # Note: For security reasons, no built-in Authentication Strengths are supported.
    # Dedicated custom Authentication Strength policies are required to be created for full Tier separation.
    #
    @{
        # Only required if you are using dedicated accounts for Tier1 admins (highly recommended!)
        account                = @{
            # id = ''   # This is tenant specific and may be added after initial creation to use GUID instead of name
            displayName               = @($EntraCAAuthStrengthDisplayNamePrefix, 'Tier1-Admin-Account', $EntraCAAuthStrengthDisplayNameSuffix) | Join-String -Separator $DisplayNameElementSeparator
            description               = 'Authentication methods for users with no Tier1 Microsoft Entra ID Roles activated. DO NOT CHANGE MANUALLY!'

            # List: https://learn.microsoft.com/en-us/graph/api/authenticationstrengthroot-list-authenticationmethodmodes?tabs=http#response-1
            allowedCombinations       = @(
                'windowsHelloForBusiness'
                'fido2'
                'deviceBasedPush'
                'microsoftAuthenticatorPush'    # Usually a good idea for dedicated Tier1 accounts to allow using password + push as a fallback method to allow people re-configure their passwordless methods before enabling a role
                'temporaryAccessPassOneTime'    # Required for passwordless onboarding of new Tier1 admin accounts, but only available without any active roles
                'temporaryAccessPassMultiUse'   # Required for passwordless onboarding of new Tier1 admin accounts, but only available without any active roles
            )

            combinationConfigurations = @{
                fido2 = @{
                    '@odata.type'  = '#microsoft.graph.fido2CombinationConfiguration'
                    allowedAAGUIDs = @(
                        # From https://support.yubico.com/hc/en-us/articles/360016648959-YubiKey-Hardware-FIDO2-AAGUIDs
                        'cb69481e-8ff7-4039-93ec-0a2729a154a8' # YubiKey 5 Series (Firmware 5.1)
                        'ee882879-721c-4913-9775-3dfcce97072a' # YubiKey 5 Series (Firmware 5.2, 5.4)
                        'fa2b99dc-9e39-4257-8f92-4a30d23c4118' # YubiKey 5 Series with NFC (Firmware 5.1)
                        '2fc0579f-8113-47ea-b116-bb5a8db9202a' # YubiKey 5 Series with NFC (Firmware 5.2, 5.4)
                        '73bb0cd4-e502-49b8-9c6f-b59445bf720b' # YubiKey 5 FIPS Series (Firmware 5.4)
                        'c1f9a0bc-1dd2-404a-b27f-8e29047a43fd' # YubiKey 5 FIPS Series with NFC (Firmware 5.4)
                        'c5ef55ff-ad9a-4b9f-b580-adebafe026d0' # YubiKey 5Ci (Firmware 5.2, 5.4)
                        '85203421-48f9-4355-9bc8-8a53846e5083' # YubiKey 5Ci FIPS (Firmware 5.4)
                        'd8522d9f-575b-4866-88a9-ba99fa02f35b' # YubiKey Bio Series (Firmware 5.5)
                        'f8a011f3-8c0a-4d15-8006-17111f9edc7d' # Security Key by Yubico (Firmware 5.1)
                        'b92c3f9a-c014-4056-887f-140a2501163b' # Security Key by Yubico (Firmware 5.2)
                        '6d44ba9b-f6ec-2e49-b930-0c8fe920cb73' # Security Key by Yubico with NFC (Firmware 5.1)
                        '149a2021-8ef6-4133-96b8-81f8d5b7f1f5' # Security Key by Yubico with NFC (Firmware 5.2, 5.4)
                        'a4e9fc6d-4cbe-4758-b8ba-37598bb5bbaa' # Security Key by Yubico with NFC - Black (Firmware 5.4)
                        '0bb43545-fd2c-4185-87dd-feb0b2916ace' # Security Key by Yubico with NFC - Enterprise Edition (Firmware 5.4)

                        # From https://github.com/passkeydeveloper/passkey-authenticator-aaguids/blob/main/aaguid.json
                        'dd4ec289-e01d-41c9-bb89-70fa845d4bf2' # Apple iCloud Keychain (Managed)
                        'd548826e-79b4-db40-a3d8-11116f7e8349' # Bitwarden
                        'adce0002-35bc-c60a-648b-0b25f1f05503' # Chrome on Mac
                        'b5397666-4885-aa6b-cebf-e52262a439a2' # Chromium Browser
                        '531126d6-e717-415c-9320-3d9aa6981239' # Dashlane
                        '771b48fd-d3d4-4f74-9232-fc157ab0507a' # Edge on Mac
                        'f3809540-7f14-49c1-a8b3-8f813b225541' # Enpass
                        'ea9b8d66-4d01-1d21-3ce4-b6b48cb575d4' # Google Password Manager
                        '39a5647e-1853-446c-a1f6-a79bae9f5bc7' # IDmelon
                        '0ea242b4-43c4-4a1b-8b17-dd6d0b6baec6' # Keeper
                        'b84e4048-15dc-4dd0-8640-f4f60813c8af' # NordPass
                        '53414d53-554e-4700-0000-000000000000' # Samsung Pass
                        '08987058-cadc-4b81-b6e1-30de50dcbe96' # Windows Hello Hardware Authenticator
                        # '6028b017-b1d4-4c02-b4b3-afcdafc96bb2' # Windows Hello Software Authenticator
                        '9ddd1817-af5a-4672-a2b9-3e3dd95000a9' # Windows Hello VBS Hardware Authenticator
                        'bada5566-a7aa-401f-bd96-45619a55120d' # 1Password
                    )
                }
            }
        }

        # Only required if you are using dedicated accounts for Tier1 admins (highly recommended!)
        activeRole             = @{
            # id = ''   # This is tenant specific and may be added after initial creation to use GUID instead of name
            displayName               = @($EntraCAAuthStrengthDisplayNamePrefix, 'Tier1-Admin-Role', $EntraCAAuthStrengthDisplayNameSuffix) | Join-String -Separator $DisplayNameElementSeparator
            description               = 'Authentication methods for users with active Tier1 Azure AD Roles. DO NOT CHANGE MANUALLY!'

            # List: https://learn.microsoft.com/en-us/graph/api/authenticationstrengthroot-list-authenticationmethodmodes?tabs=http#response-1
            allowedCombinations       = @(
                'windowsHelloForBusiness'
                'fido2'
                'deviceBasedPush'
            )

            combinationConfigurations = @{
                fido2 = @{
                    '@odata.type'  = '#microsoft.graph.fido2CombinationConfiguration'
                    allowedAAGUIDs = @(
                        # From https://support.yubico.com/hc/en-us/articles/360016648959-YubiKey-Hardware-FIDO2-AAGUIDs
                        'cb69481e-8ff7-4039-93ec-0a2729a154a8' # YubiKey 5 Series (Firmware 5.1)
                        'ee882879-721c-4913-9775-3dfcce97072a' # YubiKey 5 Series (Firmware 5.2, 5.4)
                        'fa2b99dc-9e39-4257-8f92-4a30d23c4118' # YubiKey 5 Series with NFC (Firmware 5.1)
                        '2fc0579f-8113-47ea-b116-bb5a8db9202a' # YubiKey 5 Series with NFC (Firmware 5.2, 5.4)
                        '73bb0cd4-e502-49b8-9c6f-b59445bf720b' # YubiKey 5 FIPS Series (Firmware 5.4)
                        'c1f9a0bc-1dd2-404a-b27f-8e29047a43fd' # YubiKey 5 FIPS Series with NFC (Firmware 5.4)
                        'c5ef55ff-ad9a-4b9f-b580-adebafe026d0' # YubiKey 5Ci (Firmware 5.2, 5.4)
                        '85203421-48f9-4355-9bc8-8a53846e5083' # YubiKey 5Ci FIPS (Firmware 5.4)
                        'd8522d9f-575b-4866-88a9-ba99fa02f35b' # YubiKey Bio Series (Firmware 5.5)
                        'f8a011f3-8c0a-4d15-8006-17111f9edc7d' # Security Key by Yubico (Firmware 5.1)
                        'b92c3f9a-c014-4056-887f-140a2501163b' # Security Key by Yubico (Firmware 5.2)
                        '6d44ba9b-f6ec-2e49-b930-0c8fe920cb73' # Security Key by Yubico with NFC (Firmware 5.1)
                        '149a2021-8ef6-4133-96b8-81f8d5b7f1f5' # Security Key by Yubico with NFC (Firmware 5.2, 5.4)
                        'a4e9fc6d-4cbe-4758-b8ba-37598bb5bbaa' # Security Key by Yubico with NFC - Black (Firmware 5.4)
                        '0bb43545-fd2c-4185-87dd-feb0b2916ace' # Security Key by Yubico with NFC - Enterprise Edition (Firmware 5.4)

                        # From https://github.com/passkeydeveloper/passkey-authenticator-aaguids/blob/main/aaguid.json
                        'dd4ec289-e01d-41c9-bb89-70fa845d4bf2' # Apple iCloud Keychain (Managed)
                        'd548826e-79b4-db40-a3d8-11116f7e8349' # Bitwarden
                        'adce0002-35bc-c60a-648b-0b25f1f05503' # Chrome on Mac
                        'b5397666-4885-aa6b-cebf-e52262a439a2' # Chromium Browser
                        '531126d6-e717-415c-9320-3d9aa6981239' # Dashlane
                        '771b48fd-d3d4-4f74-9232-fc157ab0507a' # Edge on Mac
                        'f3809540-7f14-49c1-a8b3-8f813b225541' # Enpass
                        'ea9b8d66-4d01-1d21-3ce4-b6b48cb575d4' # Google Password Manager
                        '39a5647e-1853-446c-a1f6-a79bae9f5bc7' # IDmelon
                        '0ea242b4-43c4-4a1b-8b17-dd6d0b6baec6' # Keeper
                        'b84e4048-15dc-4dd0-8640-f4f60813c8af' # NordPass
                        '53414d53-554e-4700-0000-000000000000' # Samsung Pass
                        '08987058-cadc-4b81-b6e1-30de50dcbe96' # Windows Hello Hardware Authenticator
                        # '6028b017-b1d4-4c02-b4b3-afcdafc96bb2' # Windows Hello Software Authenticator
                        '9ddd1817-af5a-4672-a2b9-3e3dd95000a9' # Windows Hello VBS Hardware Authenticator
                        'bada5566-a7aa-401f-bd96-45619a55120d' # 1Password
                    )
                }
            }
        }

        roleEnablement         = @{
            # id = ''   # This is tenant specific and may be added after initial creation to use GUID instead of name
            displayName               = @($EntraCAAuthStrengthDisplayNamePrefix, 'Tier1-Admin-PIM', $EntraCAAuthStrengthDisplayNameSuffix) | Join-String -Separator $DisplayNameElementSeparator
            description               = "Authentication methods during Azure AD Role enablement for $($EntraCAAuthContexts[1].default.displayName). DO NOT CHANGE MANUALLY!"

            # List: https://learn.microsoft.com/en-us/graph/api/authenticationstrengthroot-list-authenticationmethodmodes?tabs=http#response-1
            allowedCombinations       = @(
                'windowsHelloForBusiness'
                'fido2'
                'deviceBasedPush'
                'password,microsoftAuthenticatorPush'
            )

            combinationConfigurations = @{
                fido2 = @{
                    '@odata.type'  = '#microsoft.graph.fido2CombinationConfiguration'
                    allowedAAGUIDs = @(
                        # From https://support.yubico.com/hc/en-us/articles/360016648959-YubiKey-Hardware-FIDO2-AAGUIDs
                        'cb69481e-8ff7-4039-93ec-0a2729a154a8' # YubiKey 5 Series (Firmware 5.1)
                        'ee882879-721c-4913-9775-3dfcce97072a' # YubiKey 5 Series (Firmware 5.2, 5.4)
                        'fa2b99dc-9e39-4257-8f92-4a30d23c4118' # YubiKey 5 Series with NFC (Firmware 5.1)
                        '2fc0579f-8113-47ea-b116-bb5a8db9202a' # YubiKey 5 Series with NFC (Firmware 5.2, 5.4)
                        '73bb0cd4-e502-49b8-9c6f-b59445bf720b' # YubiKey 5 FIPS Series (Firmware 5.4)
                        'c1f9a0bc-1dd2-404a-b27f-8e29047a43fd' # YubiKey 5 FIPS Series with NFC (Firmware 5.4)
                        'c5ef55ff-ad9a-4b9f-b580-adebafe026d0' # YubiKey 5Ci (Firmware 5.2, 5.4)
                        '85203421-48f9-4355-9bc8-8a53846e5083' # YubiKey 5Ci FIPS (Firmware 5.4)
                        'd8522d9f-575b-4866-88a9-ba99fa02f35b' # YubiKey Bio Series (Firmware 5.5)
                        'f8a011f3-8c0a-4d15-8006-17111f9edc7d' # Security Key by Yubico (Firmware 5.1)
                        'b92c3f9a-c014-4056-887f-140a2501163b' # Security Key by Yubico (Firmware 5.2)
                        '6d44ba9b-f6ec-2e49-b930-0c8fe920cb73' # Security Key by Yubico with NFC (Firmware 5.1)
                        '149a2021-8ef6-4133-96b8-81f8d5b7f1f5' # Security Key by Yubico with NFC (Firmware 5.2, 5.4)
                        'a4e9fc6d-4cbe-4758-b8ba-37598bb5bbaa' # Security Key by Yubico with NFC - Black (Firmware 5.4)
                        '0bb43545-fd2c-4185-87dd-feb0b2916ace' # Security Key by Yubico with NFC - Enterprise Edition (Firmware 5.4)

                        # From https://github.com/passkeydeveloper/passkey-authenticator-aaguids/blob/main/aaguid.json
                        'dd4ec289-e01d-41c9-bb89-70fa845d4bf2' # Apple iCloud Keychain (Managed)
                        'd548826e-79b4-db40-a3d8-11116f7e8349' # Bitwarden
                        'adce0002-35bc-c60a-648b-0b25f1f05503' # Chrome on Mac
                        'b5397666-4885-aa6b-cebf-e52262a439a2' # Chromium Browser
                        '531126d6-e717-415c-9320-3d9aa6981239' # Dashlane
                        '771b48fd-d3d4-4f74-9232-fc157ab0507a' # Edge on Mac
                        'f3809540-7f14-49c1-a8b3-8f813b225541' # Enpass
                        'ea9b8d66-4d01-1d21-3ce4-b6b48cb575d4' # Google Password Manager
                        '39a5647e-1853-446c-a1f6-a79bae9f5bc7' # IDmelon
                        '0ea242b4-43c4-4a1b-8b17-dd6d0b6baec6' # Keeper
                        'b84e4048-15dc-4dd0-8640-f4f60813c8af' # NordPass
                        '53414d53-554e-4700-0000-000000000000' # Samsung Pass
                        '08987058-cadc-4b81-b6e1-30de50dcbe96' # Windows Hello Hardware Authenticator
                        # '6028b017-b1d4-4c02-b4b3-afcdafc96bb2' # Windows Hello Software Authenticator
                        '9ddd1817-af5a-4672-a2b9-3e3dd95000a9' # Windows Hello VBS Hardware Authenticator
                        'bada5566-a7aa-401f-bd96-45619a55120d' # 1Password
                    )
                }
            }
        }
        scopableRoleEnablement = @{
            # id = ''   # This is tenant specific and may be added after initial creation to use GUID instead of name
            displayName               = @($EntraCAAuthStrengthDisplayNamePrefix, 'Tier1-Scoped-Admin-PIM', $EntraCAAuthStrengthDisplayNameSuffix) | Join-String -Separator $DisplayNameElementSeparator
            description               = "Authentication methods during Azure AD Role enablement for $($EntraCAAuthContexts[1].scopable.displayName). DO NOT CHANGE MANUALLY!"

            # List: https://learn.microsoft.com/en-us/graph/api/authenticationstrengthroot-list-authenticationmethodmodes?tabs=http#response-1
            allowedCombinations       = @(
                'windowsHelloForBusiness'
                'fido2'
                'deviceBasedPush'
            )

            combinationConfigurations = @{
                fido2 = @{
                    '@odata.type'  = '#microsoft.graph.fido2CombinationConfiguration'
                    allowedAAGUIDs = @(
                        # From https://support.yubico.com/hc/en-us/articles/360016648959-YubiKey-Hardware-FIDO2-AAGUIDs
                        'cb69481e-8ff7-4039-93ec-0a2729a154a8' # YubiKey 5 Series (Firmware 5.1)
                        'ee882879-721c-4913-9775-3dfcce97072a' # YubiKey 5 Series (Firmware 5.2, 5.4)
                        'fa2b99dc-9e39-4257-8f92-4a30d23c4118' # YubiKey 5 Series with NFC (Firmware 5.1)
                        '2fc0579f-8113-47ea-b116-bb5a8db9202a' # YubiKey 5 Series with NFC (Firmware 5.2, 5.4)
                        '73bb0cd4-e502-49b8-9c6f-b59445bf720b' # YubiKey 5 FIPS Series (Firmware 5.4)
                        'c1f9a0bc-1dd2-404a-b27f-8e29047a43fd' # YubiKey 5 FIPS Series with NFC (Firmware 5.4)
                        'c5ef55ff-ad9a-4b9f-b580-adebafe026d0' # YubiKey 5Ci (Firmware 5.2, 5.4)
                        '85203421-48f9-4355-9bc8-8a53846e5083' # YubiKey 5Ci FIPS (Firmware 5.4)
                        'd8522d9f-575b-4866-88a9-ba99fa02f35b' # YubiKey Bio Series (Firmware 5.5)
                        'f8a011f3-8c0a-4d15-8006-17111f9edc7d' # Security Key by Yubico (Firmware 5.1)
                        'b92c3f9a-c014-4056-887f-140a2501163b' # Security Key by Yubico (Firmware 5.2)
                        '6d44ba9b-f6ec-2e49-b930-0c8fe920cb73' # Security Key by Yubico with NFC (Firmware 5.1)
                        '149a2021-8ef6-4133-96b8-81f8d5b7f1f5' # Security Key by Yubico with NFC (Firmware 5.2, 5.4)
                        'a4e9fc6d-4cbe-4758-b8ba-37598bb5bbaa' # Security Key by Yubico with NFC - Black (Firmware 5.4)
                        '0bb43545-fd2c-4185-87dd-feb0b2916ace' # Security Key by Yubico with NFC - Enterprise Edition (Firmware 5.4)

                        # From https://github.com/passkeydeveloper/passkey-authenticator-aaguids/blob/main/aaguid.json
                        'dd4ec289-e01d-41c9-bb89-70fa845d4bf2' # Apple iCloud Keychain (Managed)
                        'd548826e-79b4-db40-a3d8-11116f7e8349' # Bitwarden
                        'adce0002-35bc-c60a-648b-0b25f1f05503' # Chrome on Mac
                        'b5397666-4885-aa6b-cebf-e52262a439a2' # Chromium Browser
                        '531126d6-e717-415c-9320-3d9aa6981239' # Dashlane
                        '771b48fd-d3d4-4f74-9232-fc157ab0507a' # Edge on Mac
                        'f3809540-7f14-49c1-a8b3-8f813b225541' # Enpass
                        'ea9b8d66-4d01-1d21-3ce4-b6b48cb575d4' # Google Password Manager
                        '39a5647e-1853-446c-a1f6-a79bae9f5bc7' # IDmelon
                        '0ea242b4-43c4-4a1b-8b17-dd6d0b6baec6' # Keeper
                        'b84e4048-15dc-4dd0-8640-f4f60813c8af' # NordPass
                        '53414d53-554e-4700-0000-000000000000' # Samsung Pass
                        '08987058-cadc-4b81-b6e1-30de50dcbe96' # Windows Hello Hardware Authenticator
                        # '6028b017-b1d4-4c02-b4b3-afcdafc96bb2' # Windows Hello Software Authenticator
                        '9ddd1817-af5a-4672-a2b9-3e3dd95000a9' # Windows Hello VBS Hardware Authenticator
                        'bada5566-a7aa-401f-bd96-45619a55120d' # 1Password
                    )
                }
            }
        }
    }

    #:-------------------------------------------------------------------------
    # Tier 2 Authentication Strengths
    #
    # Note: For security reasons, no built-in Authentication Strengths are supported.
    # Dedicated custom Authentication Strength policies are required to be created for full Tier separation.
    #
    @{
        roleEnablement = @{
            # id = ''   # This is tenant specific and may be added after initial creation to use GUID instead of name
            displayName         = @($EntraCAAuthStrengthDisplayNamePrefix, 'Tier2-Admin-PIM', $EntraCAAuthStrengthDisplayNameSuffix) | Join-String -Separator $DisplayNameElementSeparator
            description         = "Authentication methods during Azure AD Role enablement for $($EntraCAAuthContexts[2].default.displayName). DO NOT CHANGE MANUALLY!"

            # List: https://learn.microsoft.com/en-us/graph/api/authenticationstrengthroot-list-authenticationmethodmodes?tabs=http#response-1
            allowedCombinations = @(
                'windowsHelloForBusiness'
                'fido2'
                'deviceBasedPush'
            )
        }
    }

    #:-------------------------------------------------------------------------
    # Common Authentication Strengths for regular user accounts
    #
    @(
    )
)
