#Requires -Version 7.2

$AADRoleClassifications = @(

    #:-------------------------------------------------------------------------
    # Tier 0 Azure AD Roles
    #
    # You may move roles to another Tier, based on your own requirements.
    # Custom Azure AD roles that were created before may also be added here as desired.
    #
    # Settings are inherited from $AADRoleManagementRulesDefaults.
    # Define selected rules here to explicitly replace/overwrite default settings.
    #
    # Note: Roles 'Global Administrator' and 'Privileged Role Administrator'
    #       explicitly need to be added to Tier 0. Remove the respective comments
    #       below when you are ready.
    #
    @(
        @{
            displayName = 'Attribute Definition Administrator'
            templateId  = '8424c6f0-a189-499e-bbd0-26c1753c96d4'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Authentication Extensibility Administrator'
            templateId  = '25a516ed-2fa0-40ea-a2d0-12923a21473a'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Authentication Policy Administrator'
            templateId  = '0526716b-113d-4c15-b2c8-68e3c22b9f80'
            isBuiltIn   = $true
        }
        @{
            displayName                              = 'Cloud Device Administrator'
            templateId                               = '7698a772-787b-4ac8-901f-60d6b08affd2'
            isBuiltIn                                = $true
            isScopable                               = $true
            AuthenticationContext_EndUser_Assignment = @{
                claimValue = $AADCAAuthContexts[0].scopable.Id
            }
        }
        @{
            displayName = 'Conditional Access Administrator'
            templateId  = 'b1be1c3e-b65d-4f19-8427-f6fa0d97feb9'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Domain Name Administrator'
            templateId  = '8329153b-31d0-4727-b945-745eb3bc5f31'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Exchange Administrator'
            templateId  = '29232cdf-9323-42fd-ade2-1d097af3e4de'
            isBuiltIn   = $true
        }
        # Remove the comment when you are ready
        # to update your Global Administrator role by this script
        #
        # @{
        #     displayName = 'Global Administrator'
        #     templateId  = '62e90394-69f5-4237-9190-012177145e10'
        #     isBuiltIn   = $true
        # }
        @{
            displayName                              = 'Groups Administrator'
            templateId                               = 'fdd7a751-b60b-444a-984c-02652fe8fa1c'
            isBuiltIn                                = $true
            isScopable                               = $true
            AuthenticationContext_EndUser_Assignment = @{
                claimValue = $AADCAAuthContexts[0].scopable.Id
            }
        }
        @{
            displayName = 'Hybrid Identity Administrator'
            templateId  = '8ac3fc64-6eca-42ea-9e69-59f4c7b60eb2'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Intune Administrator'
            templateId  = '3a2c62db-5318-420d-8d74-23affee5d9d5'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Privileged Authentication Administrator'
            templateId  = '7be44c8a-adaf-4e2a-84d6-ab2649e08a13'
            isBuiltIn   = $true
        }
        # Remove the comment when you are ready
        # to update your Privileged Role Administrator role by this script
        #
        # @{
        #     displayName = 'Privileged Role Administrator'
        #     templateId  = 'e8611ab8-c189-46e8-94e1-60213ab1f814'
        #     isBuiltIn   = $true
        # }
        @{
            displayName = 'Security Administrator'
            templateId  = '194ae4cb-b126-40b2-bd5b-6091b380977d'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Tenant Creator'
            templateId  = '112ca1a2-15ad-4102-995e-45b0bc479a6a'
            isBuiltIn   = $true
        }
        @{
            displayName                              = 'User Administrator'
            templateId                               = 'fe930be7-5e62-47db-91af-98c3a49a38b1'
            isBuiltIn                                = $true
            isScopable                               = $true
            AuthenticationContext_EndUser_Assignment = @{
                claimValue = $AADCAAuthContexts[0].scopable.Id
            }
        }
        @{
            displayName = 'Windows 365 Administrator'
            templateId  = '11451d60-acb2-45eb-a7d6-43d0f0125c13'
            isBuiltIn   = $true
        }
    ),

    #:-------------------------------------------------------------------------
    # Tier 1 Azure AD Roles
    #
    # You may move roles to another Tier, based on your own requirements.
    # Custom Azure AD roles that were created before may also be added here as desired.
    #
    # Settings are inherited from $AADRoleManagementRulesDefaults.
    # Define selected rules here to explicitly replace/overwrite default settings.
    #
    @(
        @{
            displayName = 'Application Administrator'
            templateId  = '9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Attack Simulation Administrator'
            templateId  = 'c430b396-e693-46cc-96f3-db01bf8bb62a'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Attribute Assignment Administrator'
            templateId  = '58a13ea3-c632-46ae-9ee0-9c0d43cd7f3d'
            isBuiltIn   = $true
        }
        @{
            displayName                              = 'Authentication Administrator'
            templateId                               = 'c4e39bd9-1100-46d3-8c65-fb160da0071f'
            isBuiltIn                                = $true
            isScopable                               = $true
            Expiration_EndUser_Assignment            = @{
                maximumDuration = 'PT1H'
            }
            AuthenticationContext_EndUser_Assignment = @{
                claimValue = $AADCAAuthContexts[1].scopable.Id
            }
        }
        @{
            displayName                   = 'Azure AD Joined Device Local Administrator'
            templateId                    = '9f06204d-73c1-4d4c-880a-6edb90606fd8'
            isBuiltIn                     = $true
            Expiration_EndUser_Assignment = @{
                maximumDuration = 'PT1H'
            }
            Enablement_EndUser_Assignment = @{
                enabledRules = @(
                    'Justification'
                    'Ticketing'
                )
            }
        }
        @{
            displayName                   = 'Azure DevOps Administrator'
            templateId                    = 'e3973bdf-4987-49ae-837a-ba8e231c7286'
            isBuiltIn                     = $true
            Expiration_EndUser_Assignment = @{
                maximumDuration = 'PT4H'
            }
            Enablement_EndUser_Assignment = @{
                enabledRules = @(
                    'Justification'
                )
            }
        }
        @{
            displayName                   = 'Azure Information Protection Administrator'
            templateId                    = '7495fdc4-34c4-4d15-a289-98788ce399fd'
            isBuiltIn                     = $true
            Expiration_EndUser_Assignment = @{
                maximumDuration = 'PT4H'
            }
            Enablement_EndUser_Assignment = @{
                enabledRules = @(
                    'Justification'
                )
            }
        }
        @{
            displayName = 'B2C IEF Keyset Administrator'
            templateId  = 'aaf43236-0c0d-4d5f-883a-6955382ac081'
            isBuiltIn   = $true
        }
        @{
            displayName = 'B2C IEF Policy Administrator'
            templateId  = '3edaf663-341e-4475-9f94-5c398ef6c070'
            isBuiltIn   = $true
        }
        @{
            displayName                   = 'Billing Administrator'
            templateId                    = 'b0f54661-2d74-4c50-afa3-1ec803f12efe'
            isBuiltIn                     = $true
            Enablement_EndUser_Assignment = @{
                enabledRules = @(
                    'Justification'
                )
            }
        }
        @{
            displayName                   = 'Cloud App Security Administrator'    # aka Defender for Cloud Apps Administrator
            templateId                    = '892c5842-a9a6-463a-8041-72aa08ca3cf6'
            isBuiltIn                     = $true
            Expiration_EndUser_Assignment = @{
                maximumDuration = 'PT4H'
            }
            Enablement_EndUser_Assignment = @{
                enabledRules = @(
                    'Justification'
                )
            }
        }
        @{
            displayName = 'Cloud Application Administrator'
            templateId  = '158c047a-c907-4556-b7ef-446551a6b5f7'
            isBuiltIn   = $true
        }
        @{
            displayName                   = 'Compliance Administrator'
            templateId                    = '17315797-102d-40b4-93e0-432062caca18'
            isBuiltIn                     = $true
            Expiration_EndUser_Assignment = @{
                maximumDuration = 'PT4H'
            }
            Enablement_EndUser_Assignment = @{
                enabledRules = @(
                    'Justification'
                )
            }
        }
        @{
            displayName = 'Compliance Data Administrator'
            templateId  = 'e6d1a23a-da11-4be4-9570-befc86d067a7'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Edge Administrator'
            templateId  = '3f1acade-1e04-4fbc-9b69-f0302cd84aef'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Desktop Analytics Administrator'
            templateId  = '38a96431-2bdf-4b4c-8b6e-5d3d8abac1a4'
            isBuiltIn   = $true
        }
        @{
            displayName                   = 'Dynamics 365 Administrator'
            templateId                    = '44367163-eba1-44c3-98af-f5787879f96a'
            isBuiltIn                     = $true
            Expiration_EndUser_Assignment = @{
                maximumDuration = 'PT4H'
            }
            Enablement_EndUser_Assignment = @{
                enabledRules = @(
                    'Justification'
                )
            }
        }
        @{
            displayName = 'Exchange Recipient Administrator'
            templateId  = '31392ffb-586c-42d1-9346-e59415a2cc4e'
            isBuiltIn   = $true
        }
        @{
            displayName                   = 'Extended Directory User Administrator'
            templateId                    = 'dd13091a-6207-4fc0-82ba-3641e056ab95'
            isBuiltIn                     = $true
            Expiration_EndUser_Assignment = @{
                maximumDuration = 'PT4H'
            }
        }
        @{
            displayName                   = 'External ID User Flow Administrator'
            templateId                    = '6e591065-9bad-43ed-90f3-e9424366d2f0'
            isBuiltIn                     = $true
            Expiration_EndUser_Assignment = @{
                maximumDuration = 'PT4H'
            }
            Enablement_EndUser_Assignment = @{
                enabledRules = @(
                    'Justification'
                )
            }
        }
        @{
            displayName                   = 'External ID User Flow Attribute Administrator'
            templateId                    = '0f971eea-41eb-4569-a71e-57bb8a3eff1e'
            isBuiltIn                     = $true
            Expiration_EndUser_Assignment = @{
                maximumDuration = 'PT4H'
            }
            Enablement_EndUser_Assignment = @{
                enabledRules = @(
                    'Justification'
                )
            }
        }
        @{
            displayName                   = 'External Identity Provider Administrator'
            templateId                    = 'be2f45a1-457d-42af-a067-6ec1fa63bc45'
            isBuiltIn                     = $true
            Expiration_EndUser_Assignment = @{
                maximumDuration = 'PT4H'
            }
            Enablement_EndUser_Assignment = @{
                enabledRules = @(
                    'Justification'
                )
            }
        }
        @{
            displayName                              = 'Helpdesk Administrator'
            templateId                               = '729827e3-9c14-49f7-bb1b-9608f156bbb8'
            isBuiltIn                                = $true
            isScopable                               = $true
            Expiration_EndUser_Assignment            = @{
                maximumDuration = 'PT1H'
            }
            Enablement_EndUser_Assignment            = @{
                enabledRules = @(
                    'Ticketing'
                )
            }
            AuthenticationContext_EndUser_Assignment = @{
                claimValue = $AADCAAuthContexts[1].scopable.Id
            }
        }
        @{
            displayName = 'Identity Governance Administrator'
            templateId  = '45d8d3c5-c802-45c6-b32a-1d70b5e1e86e'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Insights Administrator'
            templateId  = 'eb1f4a8d-243a-41f0-9fbd-c7cdf6c5ef7c'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Kaizala Administrator'
            templateId  = '74ef975b-6605-40af-a5d2-b9539d836353'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Knowledge Administrator'
            templateId  = 'b5a8dcf3-09d5-43a9-a639-8e29ef291470'
            isBuiltIn   = $true
        }
        @{
            displayName                              = 'License Administrator'
            templateId                               = '4d6ac14f-3453-41d0-bef9-a3e0c569773a'
            isBuiltIn                                = $true
            isScopable                               = $true
            Expiration_EndUser_Assignment            = @{
                maximumDuration = 'PT1H'
            }
            AuthenticationContext_EndUser_Assignment = @{
                claimValue = $AADCAAuthContexts[1].scopable.Id
            }
        }
        @{
            displayName = 'Lifecycle Workflows Administrator'
            templateId  = '59d46f88-662b-457b-bceb-5c3809e5908f'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Microsoft Hardware Warranty Administrator'
            templateId  = '1501b917-7653-4ff9-a4b5-203eaf33784f'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Network Administrator'
            templateId  = 'd37c8bed-0711-4417-ba38-b4abe66ce4c2'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Office Apps Administrator'
            templateId  = '2b745bdf-0803-4d80-aa65-822c4493daac'
            isBuiltIn   = $true
        }
        @{
            displayName                              = 'Password Administrator'
            templateId                               = '966707d0-3269-4727-9be2-8c3a10f19b9d'
            isBuiltIn                                = $true
            isScopable                               = $true
            Expiration_EndUser_Assignment            = @{
                maximumDuration = 'PT1H'
            }
            Enablement_EndUser_Assignment            = @{
                enabledRules = @(
                    'Ticketing'
                )
            }
            AuthenticationContext_EndUser_Assignment = @{
                claimValue = $AADCAAuthContexts[1].scopable.Id
            }
        }
        @{
            displayName = 'Permissions Management Administrator'
            templateId  = 'af78dc32-cf4d-46f9-ba4e-4428526346b5'
            isBuiltIn   = $true
        }
        @{
            displayName                   = 'Power BI Administrator'
            templateId                    = 'a9ea8996-122f-4c74-9520-8edcd192826c'
            isBuiltIn                     = $true
            Expiration_EndUser_Assignment = @{
                maximumDuration = 'PT4H'
            }
            Enablement_EndUser_Assignment = @{
                enabledRules = @(
                    'Justification'
                )
            }
        }
        @{
            displayName                   = 'Power Platform Administrator'
            templateId                    = '11648597-926c-4cf3-9c36-bcebb0ba8dcc'
            isBuiltIn                     = $true
            Expiration_EndUser_Assignment = @{
                maximumDuration = 'PT4H'
            }
            Enablement_EndUser_Assignment = @{
                enabledRules = @(
                    'Justification'
                )
            }
        }
        @{
            displayName                              = 'Printer Administrator'
            templateId                               = '644ef478-e28f-4e28-b9dc-3fdde9aa0b1f'
            isBuiltIn                                = $true
            isScopable                               = $true
            AuthenticationContext_EndUser_Assignment = @{
                claimValue = $AADCAAuthContexts[1].scopable.Id
            }
        }
        @{
            displayName = 'Search Administrator'
            templateId  = '0964bb5e-9bdb-4d7b-ac29-58e794862a40'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Security Operator'
            templateId  = '5f2222b1-57c3-48ba-8ad5-d4759f1fde6f'
            isBuiltIn   = $true
        }
        @{
            displayName                   = 'SharePoint Administrator'
            templateId                    = 'f28a1f50-f6e7-4571-818b-6a12f2af6b6c'
            isBuiltIn                     = $true
            isScopable                    = $true
            Expiration_EndUser_Assignment = @{
                maximumDuration = 'PT4H'
            }
            Enablement_EndUser_Assignment = @{
                enabledRules = @(
                    'Justification'
                )
            }
        }
        @{
            displayName = 'Skype for Business Administrator'
            templateId  = '75941009-915a-4869-abe7-691bff18279e'
            isBuiltIn   = $true
        }
        @{
            displayName                              = 'Teams Administrator'
            templateId                               = '69091246-20e8-4a56-aa4d-066075b2a7a8'
            isBuiltIn                                = $true
            isScopable                               = $true
            Expiration_EndUser_Assignment            = @{
                maximumDuration = 'PT4H'
            }
            AuthenticationContext_EndUser_Assignment = @{
                claimValue = $AADCAAuthContexts[1].scopable.Id
            }
        }
        @{
            displayName = 'Teams Communications Administrator'
            templateId  = 'baf37b3a-610e-45da-9e62-d9d1e5e8914b'
            isBuiltIn   = $true
        }
        @{
            displayName                              = 'Teams Devices Administrator'
            templateId                               = '3d762c5a-1b6c-493f-843e-55a3b42923d4'
            isBuiltIn                                = $true
            isScopable                               = $true
            AuthenticationContext_EndUser_Assignment = @{
                claimValue = $AADCAAuthContexts[1].scopable.Id
            }
        }
        @{
            displayName = 'Viva Goals Administrator'
            templateId  = '92b086b3-e367-4ef2-b869-1de128fb986e'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Viva Pulse Administrator'
            templateId  = '87761b17-1ed2-4af3-9acd-92a150038160'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Windows Update Deployment Administrator'
            templateId  = '32696413-001a-46ae-978c-ce0f6b3620d2'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Yammer Administrator'
            templateId  = '810a2642-a034-447f-a5e8-41beaa378541'
            isBuiltIn   = $true
        }
        # @{
        #     displayName = "$CompanyName Example Custom Tier1 Administrator"
        #     Id          = '00000000-0000-0000-0000-000000000000'
        #     isBuiltIn   = $false
        # }
    ),

    #:-------------------------------------------------------------------------
    # Tier 2 Azure AD Roles
    #
    # You may move roles to another Tier, based on your own requirements.
    # Custom Azure AD roles that were created before may also be added here as desired.
    #
    # Settings are inherited from $AADRoleManagementRulesDefaults.
    # Define selected rules here to explicitly replace/overwrite default settings.
    #
    @(
        @{
            displayName = 'Application Developer'
            templateId  = 'cf1c38e5-3621-4004-a7cb-879624dced7c'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Attack Payload Author'
            templateId  = '9c6df0f2-1e7c-4dc3-b195-66dfbd24aa8f'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Attribute Assignment Reader'
            templateId  = 'ffd52fa5-98dc-465c-991d-fc073eb59f8f'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Attribute Definition Reader'
            templateId  = '1d336d2c-4ae8-42ef-9711-b3604ce3fc2c'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Customer LockBox Access Approver'
            templateId  = '5c4f9dcd-47dc-4cf7-8c9a-9e4207cbfc91'
            isBuiltIn   = $true
        }
        @{
            displayName                   = 'Global Reader'
            templateId                    = 'f2ef992c-3afb-46b9-b7cf-a126ee74c451'
            isBuiltIn                     = $true
            Enablement_EndUser_Assignment = @{
                enabledRules = @(
                    'Justification'
                )
            }
        }
        @{
            displayName                              = 'Guest Inviter'
            templateId                               = '95e79109-95c0-4d8e-aee3-d01accf2d47b'
            isBuiltIn                                = $true
            Enablement_EndUser_Assignment            = @{
                enabledRules = @(
                    'MultiFactorAuthentication'
                )
            }
            AuthenticationContext_EndUser_Assignment = @{
                isEnabled = $false
            }
        }
        @{
            displayName = 'Insights Analyst'
            templateId  = '25df335f-86eb-4119-b717-0ff02de207e9'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Insights Business Leader'
            templateId  = '31e939ad-9672-4796-9c2e-873181342d2d'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Knowledge Manager'
            templateId  = '744ec460-397e-42ad-a462-8b3f9747a02c'
            isBuiltIn   = $true
        }
        @{
            displayName                              = 'Message Center Privacy Reader'
            templateId                               = 'ac16e43d-7b2d-40e0-ac05-243ff356ab5b'
            isBuiltIn                                = $true
            Enablement_EndUser_Assignment            = @{
                enabledRules = @(
                )
            }
            AuthenticationContext_EndUser_Assignment = @{
                isEnabled = $false
            }
        }
        @{
            displayName                              = 'Message Center Reader'
            templateId                               = '790c1fb9-7f7d-4f88-86a1-ef1f95c05c1b'
            isBuiltIn                                = $true
            Enablement_EndUser_Assignment            = @{
                enabledRules = @(
                )
            }
            AuthenticationContext_EndUser_Assignment = @{
                isEnabled = $false
            }
        }
        @{
            displayName = 'Microsoft Hardware Warranty Specialist'
            templateId  = '281fe777-fb20-4fbb-b7a3-ccebce5b0d96'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Organizational Messages Writer'
            templateId  = '507f53e4-4e52-4077-abd3-d2e1558b6ea2'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Printer Technician'
            templateId  = 'e8cef6f1-e4bd-4ea8-bc07-4b8d950f4477'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Reports Reader'
            templateId  = '4a5d8f65-41da-4de4-8968-e035b65339cf'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Search Editor'
            templateId  = '8835291a-918c-4fd7-a9ce-faa49f0cf7d9'
            isBuiltIn   = $true
        }
        @{
            displayName                   = 'Security Reader'
            templateId                    = '5d6b6bb7-de71-4623-b4af-96380a352509'
            isBuiltIn                     = $true
            Enablement_EndUser_Assignment = @{
                enabledRules = @(
                    'Justification'
                )
            }
        }
        @{
            displayName                              = 'Service Support Administrator'
            templateId                               = 'f023fd81-a637-4b56-95fd-791ac0226033'
            isBuiltIn                                = $true
            Enablement_EndUser_Assignment            = @{
                enabledRules = @(
                )
            }
            AuthenticationContext_EndUser_Assignment = @{
                isEnabled = $false
            }
        }
        @{
            displayName = 'Teams Communications Support Engineer'
            templateId  = 'f70938a0-fc10-4177-9e90-2178f8765737'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Teams Communications Support Specialist'
            templateId  = 'fcf91098-03e3-41a9-b5ba-6f0ec8188a12'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Usage Summary Reports Reader'
            templateId  = '75934031-6c7e-415a-99d7-48dbd49e875e'
            isBuiltIn   = $true
        }
        @{
            displayName = 'User Experience Success Manager'
            templateId  = '27460883-1df1-4691-b032-3b79643e5e63'
            isBuiltIn   = $true
        }
        @{
            displayName = 'Virtual Visits Administrator'
            templateId  = 'e300d9e7-4a2b-4295-9eff-f1c78b36cc98'
            isBuiltIn   = $true
        }
        # @{
        #     displayName = "$CompanyName Example Custom Tier2 Administrator"
        #     Id          = '00000000-0000-0000-0000-000000000000'
        #     isBuiltIn   = $false
        # }
    )
)
