# Optional, otherwise received from $env:TenantId or script parameter -TenantId
$TenantId = ''

$AADCAAuthContexts = @(
    # Tier 0 Authorization Contexts
    @{
        default  = @{
            id          = "c1"
            name        = "Tier0-Admin-AuthContext"
            description = "Tier0 administration using Privileged Identity Management"
        }
        scopable = @{
            id          = "c4"
            name        = "Tier0-Scoped-Admin-AuthContext"
            description = "Tier 0 administration for scope-enabled roles that could also be used in Tier 1 when scope was assigned"
        }
    },

    # Tier 1 Authorization Contexts
    @{
        default  = @{
            id          = "c2"
            name        = "Tier1-Admin-AuthContext"
            description = "Tier1 administration using Privileged Identity Management"
        }
        scopable = @{
            id          = "c5"
            name        = "Tier1-Scoped-Admin-AuthContext"
            description = "Tier 1 administration for scope-enabled roles that could also be used in Tier 2 when scope was assigned"
        }
    },

    # Tier 2 Authorization Contexts
    @{
        default = @{
            id          = "c3"
            name        = "Tier2-Admin-AuthContext"
            description = "Tier2 administration using Privileged Identity Management"
        }
    }
)

$AADRoleClassifications = @(

    #:-------------------------------------------------------------------------
    # Tier 0 Azure AD Roles
    #
    @(
        @{
            displayName = "Attribute Definition Administrator"
            TemplateId  = "8424c6f0-a189-499e-bbd0-26c1753c96d4"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Authentication Extensibility Administrator"
            TemplateId  = "25a516ed-2fa0-40ea-a2d0-12923a21473a"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Authentication Policy Administrator"
            TemplateId  = "0526716b-113d-4c15-b2c8-68e3c22b9f80"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Azure Information Protection Administrator"
            TemplateId  = "7495fdc4-34c4-4d15-a289-98788ce399fd"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Cloud App Security Administrator"
            TemplateId  = "892c5842-a9a6-463a-8041-72aa08ca3cf6"
            IsBuiltIn   = $true
        }
        @{
            displayName                              = "Cloud Device Administrator"
            TemplateId                               = "7698a772-787b-4ac8-901f-60d6b08affd2"
            IsBuiltIn                                = $true
            IsScopable                               = $true
            AuthenticationContext_EndUser_Assignment = @{
                claimValue = $AADCAAuthContexts[0].scopable.Id
            }
        }
        @{
            displayName = "Compliance Administrator"
            TemplateId  = "17315797-102d-40b4-93e0-432062caca18"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Conditional Access Administrator"
            TemplateId  = "b1be1c3e-b65d-4f19-8427-f6fa0d97feb9"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Domain Name Administrator"
            TemplateId  = "8329153b-31d0-4727-b945-745eb3bc5f31"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Exchange Administrator"
            TemplateId  = "29232cdf-9323-42fd-ade2-1d097af3e4de"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Global Administrator"
            TemplateId  = "62e90394-69f5-4237-9190-012177145e10"
            IsBuiltIn   = $true
        }
        @{
            displayName                              = "Groups Administrator"
            TemplateId                               = "fdd7a751-b60b-444a-984c-02652fe8fa1c"
            IsBuiltIn                                = $true
            IsScopable                               = $true
            AuthenticationContext_EndUser_Assignment = @{
                claimValue = $AADCAAuthContexts[0].scopable.Id
            }
        }
        @{
            displayName = "Hybrid Identity Administrator"
            TemplateId  = "8ac3fc64-6eca-42ea-9e69-59f4c7b60eb2"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Intune Administrator"
            TemplateId  = "3a2c62db-5318-420d-8d74-23affee5d9d5"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Privileged Authentication Administrator"
            TemplateId  = "7be44c8a-adaf-4e2a-84d6-ab2649e08a13"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Privileged Role Administrator"
            TemplateId  = "e8611ab8-c189-46e8-94e1-60213ab1f814"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Security Administrator"
            TemplateId  = "194ae4cb-b126-40b2-bd5b-6091b380977d"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Tenant Creator"
            TemplateId  = "112ca1a2-15ad-4102-995e-45b0bc479a6a"
            IsBuiltIn   = $true
        }
        @{
            displayName                              = "User Administrator"
            TemplateId                               = "fe930be7-5e62-47db-91af-98c3a49a38b1"
            IsBuiltIn                                = $true
            IsScopable                               = $true
            AuthenticationContext_EndUser_Assignment = @{
                claimValue = $AADCAAuthContexts[0].scopable.Id
            }
        }
        @{
            displayName = "Windows 365 Administrator"
            TemplateId  = "11451d60-acb2-45eb-a7d6-43d0f0125c13"
            IsBuiltIn   = $true
        }
    ),

    #:-------------------------------------------------------------------------
    # Tier 1 Azure AD Roles
    #
    @(
        @{
            displayName = "Application Administrator"
            TemplateId  = "9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Attack Simulation Administrator"
            TemplateId  = "c430b396-e693-46cc-96f3-db01bf8bb62a"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Attribute Assignment Administrator"
            TemplateId  = "58a13ea3-c632-46ae-9ee0-9c0d43cd7f3d"
            IsBuiltIn   = $true
        }
        @{
            displayName                              = "Authentication Administrator"
            TemplateId                               = "c4e39bd9-1100-46d3-8c65-fb160da0071f"
            IsBuiltIn                                = $true
            IsScopable                               = $true
            Expiration_EndUser_Assignment            = @{
                maximumDuration = "PT1H"
            }
            AuthenticationContext_EndUser_Assignment = @{
                claimValue = $AADCAAuthContexts[1].scopable.Id
            }
        }
        @{
            displayName                   = "Azure AD Joined Device Local Administrator"
            TemplateId                    = "9f06204d-73c1-4d4c-880a-6edb90606fd8"
            IsBuiltIn                     = $true
            Expiration_EndUser_Assignment = @{
                maximumDuration = "PT1H"
            }
            Enablement_EndUser_Assignment = @{
                enabledRules = @(
                    "Justification"
                    "Ticketing"
                )
            }
        }
        @{
            displayName                   = "Azure DevOps Administrator"
            TemplateId                    = "e3973bdf-4987-49ae-837a-ba8e231c7286"
            IsBuiltIn                     = $true
            Expiration_EndUser_Assignment = @{
                maximumDuration = "PT4H"
            }
            Enablement_EndUser_Assignment = @{
                enabledRules = @(
                    "Justification"
                )
            }
        }
        @{
            displayName = "B2C IEF Keyset Administrator"
            TemplateId  = "aaf43236-0c0d-4d5f-883a-6955382ac081"
            IsBuiltIn   = $true
        }
        @{
            displayName = "B2C IEF Policy Administrator"
            TemplateId  = "3edaf663-341e-4475-9f94-5c398ef6c070"
            IsBuiltIn   = $true
        }
        @{
            displayName                   = "Billing Administrator"
            TemplateId                    = "b0f54661-2d74-4c50-afa3-1ec803f12efe"
            IsBuiltIn                     = $true
            Enablement_EndUser_Assignment = @{
                enabledRules = @(
                    "Justification"
                )
            }
        }
        @{
            displayName = "Cloud Application Administrator"
            TemplateId  = "158c047a-c907-4556-b7ef-446551a6b5f7"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Compliance Data Administrator"
            TemplateId  = "e6d1a23a-da11-4be4-9570-befc86d067a7"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Customer LockBox Access Approver"
            TemplateId  = "5c4f9dcd-47dc-4cf7-8c9a-9e4207cbfc91"
            IsBuiltIn   = $true
        }
        @{
            displayName                   = "Dynamics 365 Administrator"
            TemplateId                    = "44367163-eba1-44c3-98af-f5787879f96a"
            IsBuiltIn                     = $true
            Expiration_EndUser_Assignment = @{
                maximumDuration = "PT4H"
            }
            Enablement_EndUser_Assignment = @{
                enabledRules = @(
                    "Justification"
                )
            }
        }
        @{
            displayName = "Exchange Recipient Administrator"
            TemplateId  = "31392ffb-586c-42d1-9346-e59415a2cc4e"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Extended Directory User Administrator"
            TemplateId  = "dd13091a-6207-4fc0-82ba-3641e056ab95"
            IsBuiltIn   = $true
            Expiration_EndUser_Assignment = @{
                maximumDuration = "PT4H"
            }
        }
        @{
            displayName                   = "External ID User Flow Administrator"
            TemplateId                    = "6e591065-9bad-43ed-90f3-e9424366d2f0"
            IsBuiltIn                     = $true
            Expiration_EndUser_Assignment = @{
                maximumDuration = "PT4H"
            }
            Enablement_EndUser_Assignment = @{
                enabledRules = @(
                    "Justification"
                )
            }
        }
        @{
            displayName                   = "External ID User Flow Attribute Administrator"
            TemplateId                    = "0f971eea-41eb-4569-a71e-57bb8a3eff1e"
            IsBuiltIn                     = $true
            Expiration_EndUser_Assignment = @{
                maximumDuration = "PT4H"
            }
            Enablement_EndUser_Assignment = @{
                enabledRules = @(
                    "Justification"
                )
            }
        }
        @{
            displayName                   = "External Identity Provider Administrator"
            TemplateId                    = "be2f45a1-457d-42af-a067-6ec1fa63bc45"
            IsBuiltIn                     = $true
            Expiration_EndUser_Assignment = @{
                maximumDuration = "PT4H"
            }
            Enablement_EndUser_Assignment = @{
                enabledRules = @(
                    "Justification"
                )
            }
        }
        @{
            displayName                              = "Helpdesk Administrator"
            TemplateId                               = "729827e3-9c14-49f7-bb1b-9608f156bbb8"
            IsBuiltIn                                = $true
            IsScopable                               = $true
            Expiration_EndUser_Assignment            = @{
                maximumDuration = "PT1H"
            }
            Enablement_EndUser_Assignment            = @{
                enabledRules = @(
                    "Ticketing"
                )
            }
            AuthenticationContext_EndUser_Assignment = @{
                claimValue = $AADCAAuthContexts[1].scopable.Id
            }
        }
        @{
            displayName = "Identity Governance Administrator"
            TemplateId  = "45d8d3c5-c802-45c6-b32a-1d70b5e1e86e"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Insights Administrator"
            TemplateId  = "eb1f4a8d-243a-41f0-9fbd-c7cdf6c5ef7c"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Insights Analyst"
            TemplateId  = "25df335f-86eb-4119-b717-0ff02de207e9"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Kaizala Administrator"
            TemplateId  = "74ef975b-6605-40af-a5d2-b9539d836353"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Knowledge Administrator"
            TemplateId  = "b5a8dcf3-09d5-43a9-a639-8e29ef291470"
            IsBuiltIn   = $true
        }
        @{
            displayName                              = "License Administrator"
            TemplateId                               = "4d6ac14f-3453-41d0-bef9-a3e0c569773a"
            IsBuiltIn                                = $true
            IsScopable                               = $true
            Expiration_EndUser_Assignment            = @{
                maximumDuration = "PT1H"
            }
            AuthenticationContext_EndUser_Assignment = @{
                claimValue = $AADCAAuthContexts[1].scopable.Id
            }
        }
        @{
            displayName = "Lifecycle Workflows Administrator"
            TemplateId  = "59d46f88-662b-457b-bceb-5c3809e5908f"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Microsoft Hardware Warranty Administrator"
            TemplateId  = "1501b917-7653-4ff9-a4b5-203eaf33784f"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Network Administrator"
            TemplateId  = "d37c8bed-0711-4417-ba38-b4abe66ce4c2"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Office Apps Administrator"
            TemplateId  = "2b745bdf-0803-4d80-aa65-822c4493daac"
            IsBuiltIn   = $true
        }
        @{
            displayName                              = "Password Administrator"
            TemplateId                               = "966707d0-3269-4727-9be2-8c3a10f19b9d"
            IsBuiltIn                                = $true
            IsScopable                               = $true
            Expiration_EndUser_Assignment            = @{
                maximumDuration = "PT1H"
            }
            Enablement_EndUser_Assignment            = @{
                enabledRules = @(
                    "Ticketing"
                )
            }
            AuthenticationContext_EndUser_Assignment = @{
                claimValue = $AADCAAuthContexts[1].scopable.Id
            }
        }
        @{
            displayName = "Permissions Management Administrator"
            TemplateId  = "af78dc32-cf4d-46f9-ba4e-4428526346b5"
            IsBuiltIn   = $true
        }
        @{
            displayName                   = "Power BI Administrator"
            TemplateId                    = "a9ea8996-122f-4c74-9520-8edcd192826c"
            IsBuiltIn                     = $true
            Expiration_EndUser_Assignment = @{
                maximumDuration = "PT4H"
            }
            Enablement_EndUser_Assignment = @{
                enabledRules = @(
                    "Justification"
                )
            }
        }
        @{
            displayName                   = "Power Platform Administrator"
            TemplateId                    = "11648597-926c-4cf3-9c36-bcebb0ba8dcc"
            IsBuiltIn                     = $true
            Expiration_EndUser_Assignment = @{
                maximumDuration = "PT4H"
            }
            Enablement_EndUser_Assignment = @{
                enabledRules = @(
                    "Justification"
                )
            }
        }
        @{
            displayName                              = "Printer Administrator"
            TemplateId                               = "644ef478-e28f-4e28-b9dc-3fdde9aa0b1f"
            IsBuiltIn                                = $true
            IsScopable                               = $true
            AuthenticationContext_EndUser_Assignment = @{
                claimValue = $AADCAAuthContexts[1].scopable.Id
            }
        }
        @{
            displayName = "Printer Technician"
            TemplateId  = "e8cef6f1-e4bd-4ea8-bc07-4b8d950f4477"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Search Administrator"
            TemplateId  = "0964bb5e-9bdb-4d7b-ac29-58e794862a40"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Security Operator"
            TemplateId  = "5f2222b1-57c3-48ba-8ad5-d4759f1fde6f"
            IsBuiltIn   = $true
        }
        @{
            displayName                   = "SharePoint Administrator"
            TemplateId                    = "f28a1f50-f6e7-4571-818b-6a12f2af6b6c"
            IsBuiltIn                     = $true
            IsScopable                    = $true
            Expiration_EndUser_Assignment = @{
                maximumDuration = "PT4H"
            }
            Enablement_EndUser_Assignment = @{
                enabledRules = @(
                    "Justification"
                )
            }
        }
        @{
            displayName = "Skype for Business Administrator"
            TemplateId  = "75941009-915a-4869-abe7-691bff18279e"
            IsBuiltIn   = $true
        }
        @{
            displayName                              = "Teams Administrator"
            TemplateId                               = "69091246-20e8-4a56-aa4d-066075b2a7a8"
            IsBuiltIn                                = $true
            IsScopable                               = $true
            Expiration_EndUser_Assignment            = @{
                maximumDuration = "PT4H"
            }
            AuthenticationContext_EndUser_Assignment = @{
                claimValue = $AADCAAuthContexts[1].scopable.Id
            }
        }
        @{
            displayName = "Teams Communications Administrator"
            TemplateId  = "baf37b3a-610e-45da-9e62-d9d1e5e8914b"
            IsBuiltIn   = $true
        }
        @{
            displayName                              = "Teams Devices Administrator"
            TemplateId                               = "3d762c5a-1b6c-493f-843e-55a3b42923d4"
            IsBuiltIn                                = $true
            IsScopable                               = $true
            AuthenticationContext_EndUser_Assignment = @{
                claimValue = $AADCAAuthContexts[1].scopable.Id
            }
        }
        @{
            displayName = "Viva Goals Administrator"
            TemplateId  = "92b086b3-e367-4ef2-b869-1de128fb986e"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Viva Pulse Administrator"
            TemplateId  = "87761b17-1ed2-4af3-9acd-92a150038160"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Windows Update Deployment Administrator"
            TemplateId  = "32696413-001a-46ae-978c-ce0f6b3620d2"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Yammer Administrator"
            TemplateId  = "810a2642-a034-447f-a5e8-41beaa378541"
            IsBuiltIn   = $true
        }
    ),

    #:-------------------------------------------------------------------------
    # Tier 2 Azure AD Roles
    #
    @(
        @{
            displayName = "Application Developer"
            TemplateId  = "cf1c38e5-3621-4004-a7cb-879624dced7c"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Attack Payload Author"
            TemplateId  = "9c6df0f2-1e7c-4dc3-b195-66dfbd24aa8f"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Attribute Assignment Reader"
            TemplateId  = "ffd52fa5-98dc-465c-991d-fc073eb59f8f"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Attribute Definition Reader"
            TemplateId  = "1d336d2c-4ae8-42ef-9711-b3604ce3fc2c"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Desktop Analytics Administrator"
            TemplateId  = "38a96431-2bdf-4b4c-8b6e-5d3d8abac1a4"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Edge Administrator"
            TemplateId  = "3f1acade-1e04-4fbc-9b69-f0302cd84aef"
            IsBuiltIn   = $true
        }
        @{
            displayName                   = "Global Reader"
            TemplateId                    = "f2ef992c-3afb-46b9-b7cf-a126ee74c451"
            IsBuiltIn                     = $true
            Enablement_EndUser_Assignment = @{
                enabledRules = @(
                    "Justification"
                )
            }
        }
        @{
            displayName                              = "Guest Inviter"
            TemplateId                               = "95e79109-95c0-4d8e-aee3-d01accf2d47b"
            IsBuiltIn                                = $true
            Enablement_EndUser_Assignment            = @{
                enabledRules = @(
                    "MultiFactorAuthentication"
                )
            }
            AuthenticationContext_EndUser_Assignment = @{
                isEnabled = $false
            }
        }
        @{
            displayName = "Insights Business Leader"
            TemplateId  = "31e939ad-9672-4796-9c2e-873181342d2d"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Knowledge Manager"
            TemplateId  = "744ec460-397e-42ad-a462-8b3f9747a02c"
            IsBuiltIn   = $true
        }
        @{
            displayName                              = "Message Center Privacy Reader"
            TemplateId                               = "ac16e43d-7b2d-40e0-ac05-243ff356ab5b"
            IsBuiltIn                                = $true
            Enablement_EndUser_Assignment            = @{
                enabledRules = @(
                )
            }
            AuthenticationContext_EndUser_Assignment = @{
                isEnabled = $false
            }
        }
        @{
            displayName                              = "Message Center Reader"
            TemplateId                               = "790c1fb9-7f7d-4f88-86a1-ef1f95c05c1b"
            IsBuiltIn                                = $true
            Enablement_EndUser_Assignment            = @{
                enabledRules = @(
                )
            }
            AuthenticationContext_EndUser_Assignment = @{
                isEnabled = $false
            }
        }
        @{
            displayName = "Microsoft Hardware Warranty Specialist"
            TemplateId  = "281fe777-fb20-4fbb-b7a3-ccebce5b0d96"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Organizational Messages Writer"
            TemplateId  = "507f53e4-4e52-4077-abd3-d2e1558b6ea2"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Reports Reader"
            TemplateId  = "4a5d8f65-41da-4de4-8968-e035b65339cf"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Search Editor"
            TemplateId  = "8835291a-918c-4fd7-a9ce-faa49f0cf7d9"
            IsBuiltIn   = $true
        }
        @{
            displayName                   = "Security Reader"
            TemplateId                    = "5d6b6bb7-de71-4623-b4af-96380a352509"
            IsBuiltIn                     = $true
            Enablement_EndUser_Assignment = @{
                enabledRules = @(
                    "Justification"
                )
            }
        }
        @{
            displayName = "Service Support Administrator"
            TemplateId  = "f023fd81-a637-4b56-95fd-791ac0226033"
            IsBuiltIn   = $true
            Enablement_EndUser_Assignment            = @{
                enabledRules = @(
                )
            }
            AuthenticationContext_EndUser_Assignment = @{
                isEnabled = $false
            }
        }
        @{
            displayName = "Teams Communications Support Engineer"
            TemplateId  = "f70938a0-fc10-4177-9e90-2178f8765737"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Teams Communications Support Specialist"
            TemplateId  = "fcf91098-03e3-41a9-b5ba-6f0ec8188a12"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Usage Summary Reports Reader"
            TemplateId  = "75934031-6c7e-415a-99d7-48dbd49e875e"
            IsBuiltIn   = $true
        }
        @{
            displayName = "User Experience Success Manager"
            TemplateId  = "27460883-1df1-4691-b032-3b79643e5e63"
            IsBuiltIn   = $true
        }
        @{
            displayName = "Virtual Visits Administrator"
            TemplateId  = "e300d9e7-4a2b-4295-9eff-f1c78b36cc98"
            IsBuiltIn   = $true
        }
    )
)

$AADRoleManagementRulesDefaults = @(

    #:-------------------------------------------------------------------------
    # Default values for management rules of Tier 0 Azure AD Roles
    #
    @(
        # Activation: Duration / Expiration
        @{
            "@odata.type"        = "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule"
            id                   = "Expiration_EndUser_Assignment"
            isExpirationRequired = $true
            maximumDuration      = "PT4H"
            target               = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "EndUser"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Activation: Enablement rules
        #             Excluding MultiFactorAuthentication in favor of using AuthenticationContext_EndUser_Assignment
        @{
            "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyEnablementRule"
            id            = "Enablement_EndUser_Assignment"
            enabledRules  = @(
                "Justification"
            )
            target        = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "EndUser"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Activation: AAD Conditional Access Authentication Context
        #             Replaces MultiFactorAuthentication in Enablement_EndUser_Assignment rule
        @{
            "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyAuthenticationContextRule"
            id            = "AuthenticationContext_EndUser_Assignment"
            isEnabled     = $true
            claimValue    = $AADCAAuthContexts[0].default.Id
            target        = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "EndUser"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Activation: Approval
        @{
            "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyApprovalRule"
            id            = "Approval_EndUser_Assignment"
            target        = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "EndUser"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
            setting       = @{
                "@odata.type"                    = "microsoft.graph.approvalSettings"
                isApprovalRequired               = $false
                isApprovalRequiredForExtension   = $false
                isRequestorJustificationRequired = $true
                approvalMode                     = "NoApproval"
                approvalStages                   = @(
                    @{
                        "@odata.type"                   = "microsoft.graph.unifiedApprovalStage"
                        approvalStageTimeOutInDays      = 7
                        isApproverJustificationRequired = $true
                        escalationTimeInMinutes         = 180
                        primaryApprovers                = @()
                        isEscalationEnabled             = $false
                        escalationApprovers             = @()
                    }
                )
            }
        }

        # Assignment: Eligibility
        @{
            "@odata.type"        = "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule"
            id                   = "Expiration_Admin_Eligibility"
            isExpirationRequired = $true
            maximumDuration      = "P90D"
            target               = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "Admin"
                operations          = @(
                    "All"
                )
                level               = "Eligibility"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Assignment: Permanent
        @{
            "@odata.type"        = "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule"
            id                   = "Expiration_Admin_Assignment"
            isExpirationRequired = $true # To exceptionally use permanent assignments, isExpirationRequired=$false can be set on selected roles and for a limited time only
            maximumDuration      = "P1D" # Basically eliminate new permanent assignments as much as possible
            target               = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "Admin"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Assignment: Rules for eligible assignments
        #             Note: Currently no rules are available / NOT IN USE.
        @{
            "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyEnablementRule"
            id            = "Enablement_Admin_Eligibility"
            enabledRules  = @(
            )
            target        = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "Admin"
                operations          = @(
                    "All"
                )
                level               = "Eligibility"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Assignment: Rules for permanent assignments
        #             Note: Authentication Context is currently not (yet?) supported here.
        @{
            "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyEnablementRule"
            id            = "Enablement_Admin_Assignment"
            enabledRules  = @(
                "Justification"
                "MultiFactorAuthentication"
            )
            target        = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "Admin"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as eligible: Admin
        @{
            "@odata.type"              = "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule"
            id                         = "Notification_Admin_Admin_Eligibility"
            isDefaultRecipientsEnabled = $true
            notificationLevel          = "Critical"
            recipientType              = "Admin"
            notificationType           = "Email"
            notificationRecipients     = @()
            target                     = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "Admin"
                operations          = @(
                    "All"
                )
                level               = "Eligibility"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as eligible: Assignee / Requestor
        @{
            "@odata.type"              = "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule"
            id                         = "Notification_Requestor_Admin_Eligibility"
            isDefaultRecipientsEnabled = $true
            notificationLevel          = "All"
            recipientType              = "Requestor"
            notificationType           = "Email"
            notificationRecipients     = @()
            target                     = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "Admin"
                operations          = @(
                    "All"
                )
                level               = "Eligibility"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as eligible: Approver
        @{
            "@odata.type"              = "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule"
            id                         = "Notification_Approver_Admin_Eligibility"
            isDefaultRecipientsEnabled = $true
            notificationLevel          = "All"
            recipientType              = "Approver"
            notificationType           = "Email"
            notificationRecipients     = @()
            target                     = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "Admin"
                operations          = @(
                    "All"
                )
                level               = "Eligibility"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as active: Admin
        @{
            "@odata.type"              = "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule"
            id                         = "Notification_Admin_Admin_Assignment"
            isDefaultRecipientsEnabled = $true
            notificationLevel          = "Critical"
            recipientType              = "Admin"
            notificationType           = "Email"
            notificationRecipients     = @()
            target                     = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "Admin"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as active: Assignee / Requestor
        @{
            "@odata.type"              = "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule"
            id                         = "Notification_Requestor_Admin_Assignment"
            isDefaultRecipientsEnabled = $true
            notificationLevel          = "All"
            recipientType              = "Requestor"
            notificationType           = "Email"
            notificationRecipients     = @()
            target                     = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "Admin"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as active: Approver
        @{
            "@odata.type"              = "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule"
            id                         = "Notification_Approver_Admin_Assignment"
            isDefaultRecipientsEnabled = $true
            notificationLevel          = "All"
            recipientType              = "Approver"
            notificationType           = "Email"
            notificationRecipients     = @()
            target                     = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "Admin"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when eligible members activate: Admin
        @{
            "@odata.type"              = "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule"
            id                         = "Notification_Admin_EndUser_Assignment"
            isDefaultRecipientsEnabled = $true
            notificationLevel          = "Critical"
            recipientType              = "Admin"
            notificationType           = "Email"
            notificationRecipients     = @()
            target                     = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "EndUser"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when eligible members activate: Requestor
        @{
            "@odata.type"              = "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule"
            id                         = "Notification_Requestor_EndUser_Assignment"
            isDefaultRecipientsEnabled = $true
            notificationLevel          = "Critical"
            recipientType              = "Requestor"
            notificationType           = "Email"
            notificationRecipients     = @()
            target                     = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "EndUser"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when eligible members activate: Approver
        @{
            "@odata.type"              = "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule"
            id                         = "Notification_Approver_EndUser_Assignment"
            isDefaultRecipientsEnabled = $true
            notificationLevel          = "All"
            recipientType              = "Approver"
            notificationType           = "Email"
            notificationRecipients     = @()
            target                     = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "EndUser"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }
    ),

    #:-------------------------------------------------------------------------
    # Default values for management rules of Tier 1 Azure AD Roles
    #
    @(
        # Activation: Duration / Expiration
        @{
            "@odata.type"        = "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule"
            id                   = "Expiration_EndUser_Assignment"
            isExpirationRequired = $true
            maximumDuration      = "PT10H"
            target               = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "EndUser"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Activation: Enablement rules
        #             Excluding MultiFactorAuthentication in favor of using AuthenticationContext_EndUser_Assignment
        @{
            "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyEnablementRule"
            id            = "Enablement_EndUser_Assignment"
            enabledRules  = @(
            )
            target        = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "EndUser"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Activation: AAD Conditional Access Authentication Context
        #             Replaces MultiFactorAuthentication in Enablement_EndUser_Assignment rule
        @{
            "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyAuthenticationContextRule"
            id            = "AuthenticationContext_EndUser_Assignment"
            isEnabled     = $true
            claimValue    = $AADCAAuthContexts[0].default.Id
            target        = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "EndUser"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Activation: Approval
        @{
            "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyApprovalRule"
            id            = "Approval_EndUser_Assignment"
            target        = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "EndUser"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
            setting       = @{
                "@odata.type"                    = "microsoft.graph.approvalSettings"
                isApprovalRequired               = $false
                isApprovalRequiredForExtension   = $false
                isRequestorJustificationRequired = $true
                approvalMode                     = "NoApproval"
                approvalStages                   = @(
                    @{
                        "@odata.type"                   = "microsoft.graph.unifiedApprovalStage"
                        approvalStageTimeOutInDays      = 7
                        isApproverJustificationRequired = $true
                        escalationTimeInMinutes         = 180
                        primaryApprovers                = @()
                        isEscalationEnabled             = $false
                        escalationApprovers             = @()
                    }
                )
            }
        }

        # Assignment: Eligibility
        @{
            "@odata.type"        = "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule"
            id                   = "Expiration_Admin_Eligibility"
            isExpirationRequired = $true
            maximumDuration      = "P180D"
            target               = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "Admin"
                operations          = @(
                    "All"
                )
                level               = "Eligibility"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Assignment: Permanent
        @{
            "@odata.type"        = "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule"
            id                   = "Expiration_Admin_Assignment"
            isExpirationRequired = $true # To exceptionally use permanent assignments, isExpirationRequired=$false can be set on selected roles and for a limited time only
            maximumDuration      = "P1D" # Basically eliminate new permanent assignments as much as possible
            target               = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "Admin"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Assignment: Rules for eligible assignments
        #             Note: Currently no rules are available / NOT IN USE.
        @{
            "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyEnablementRule"
            id            = "Enablement_Admin_Eligibility"
            enabledRules  = @(
            )
            target        = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "Admin"
                operations          = @(
                    "All"
                )
                level               = "Eligibility"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Assignment: Rules for permanent assignments
        #             Note: Authentication Context is currently not (yet?) supported here.
        @{
            "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyEnablementRule"
            id            = "Enablement_Admin_Assignment"
            enabledRules  = @(
                "Justification"
                "MultiFactorAuthentication"
            )
            target        = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "Admin"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as eligible: Admin
        @{
            "@odata.type"              = "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule"
            id                         = "Notification_Admin_Admin_Eligibility"
            isDefaultRecipientsEnabled = $true
            notificationLevel          = "Critical"
            recipientType              = "Admin"
            notificationType           = "Email"
            notificationRecipients     = @()
            target                     = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "Admin"
                operations          = @(
                    "All"
                )
                level               = "Eligibility"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as eligible: Assignee / Requestor
        @{
            "@odata.type"              = "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule"
            id                         = "Notification_Requestor_Admin_Eligibility"
            isDefaultRecipientsEnabled = $true
            notificationLevel          = "All"
            recipientType              = "Requestor"
            notificationType           = "Email"
            notificationRecipients     = @()
            target                     = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "Admin"
                operations          = @(
                    "All"
                )
                level               = "Eligibility"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as eligible: Approver
        @{
            "@odata.type"              = "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule"
            id                         = "Notification_Approver_Admin_Eligibility"
            isDefaultRecipientsEnabled = $true
            notificationLevel          = "All"
            recipientType              = "Approver"
            notificationType           = "Email"
            notificationRecipients     = @()
            target                     = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "Admin"
                operations          = @(
                    "All"
                )
                level               = "Eligibility"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as active: Admin
        @{
            "@odata.type"              = "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule"
            id                         = "Notification_Admin_Admin_Assignment"
            isDefaultRecipientsEnabled = $true
            notificationLevel          = "Critical"
            recipientType              = "Admin"
            notificationType           = "Email"
            notificationRecipients     = @()
            target                     = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "Admin"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as active: Assignee / Requestor
        @{
            "@odata.type"              = "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule"
            id                         = "Notification_Requestor_Admin_Assignment"
            isDefaultRecipientsEnabled = $true
            notificationLevel          = "All"
            recipientType              = "Requestor"
            notificationType           = "Email"
            notificationRecipients     = @()
            target                     = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "Admin"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as active: Approver
        @{
            "@odata.type"              = "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule"
            id                         = "Notification_Approver_Admin_Assignment"
            isDefaultRecipientsEnabled = $true
            notificationLevel          = "All"
            recipientType              = "Approver"
            notificationType           = "Email"
            notificationRecipients     = @()
            target                     = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "Admin"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when eligible members activate: Admin
        @{
            "@odata.type"              = "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule"
            id                         = "Notification_Admin_EndUser_Assignment"
            isDefaultRecipientsEnabled = $true
            notificationLevel          = "Critical"
            recipientType              = "Admin"
            notificationType           = "Email"
            notificationRecipients     = @()
            target                     = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "EndUser"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when eligible members activate: Requestor
        @{
            "@odata.type"              = "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule"
            id                         = "Notification_Requestor_EndUser_Assignment"
            isDefaultRecipientsEnabled = $true
            notificationLevel          = "Critical"
            recipientType              = "Requestor"
            notificationType           = "Email"
            notificationRecipients     = @()
            target                     = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "EndUser"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when eligible members activate: Approver
        @{
            "@odata.type"              = "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule"
            id                         = "Notification_Approver_EndUser_Assignment"
            isDefaultRecipientsEnabled = $true
            notificationLevel          = "All"
            recipientType              = "Approver"
            notificationType           = "Email"
            notificationRecipients     = @()
            target                     = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "EndUser"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }
    ),

    # Default values for management rules of Tier 2 Azure AD Roles
    @(
        # Activation: Duration / Expiration
        @{
            "@odata.type"        = "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule"
            id                   = "Expiration_EndUser_Assignment"
            isExpirationRequired = $true
            maximumDuration      = "PT10H"
            target               = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "EndUser"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Activation: Enablement rules
        #             Excluding MultiFactorAuthentication in favor of using AuthenticationContext_EndUser_Assignment
        @{
            "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyEnablementRule"
            id            = "Enablement_EndUser_Assignment"
            enabledRules  = @(
                "Justification"
            )
            target        = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "EndUser"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Activation: AAD Conditional Access Authentication Context
        #             Replaces MultiFactorAuthentication in Enablement_EndUser_Assignment rule
        @{
            "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyAuthenticationContextRule"
            id            = "AuthenticationContext_EndUser_Assignment"
            isEnabled     = $true
            claimValue    = $AADCAAuthContexts[0].default.Id
            target        = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "EndUser"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Activation: Approval
        @{
            "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyApprovalRule"
            id            = "Approval_EndUser_Assignment"
            target        = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "EndUser"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
            setting       = @{
                "@odata.type"                    = "microsoft.graph.approvalSettings"
                isApprovalRequired               = $false
                isApprovalRequiredForExtension   = $false
                isRequestorJustificationRequired = $true
                approvalMode                     = "NoApproval"
                approvalStages                   = @(
                    @{
                        "@odata.type"                   = "microsoft.graph.unifiedApprovalStage"
                        approvalStageTimeOutInDays      = 7
                        isApproverJustificationRequired = $true
                        escalationTimeInMinutes         = 180
                        primaryApprovers                = @()
                        isEscalationEnabled             = $false
                        escalationApprovers             = @()
                    }
                )
            }
        }

        # Assignment: Eligibility
        @{
            "@odata.type"        = "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule"
            id                   = "Expiration_Admin_Eligibility"
            isExpirationRequired = $true
            maximumDuration      = "P365D"
            target               = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "Admin"
                operations          = @(
                    "All"
                )
                level               = "Eligibility"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Assignment: Permanent
        @{
            "@odata.type"        = "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule"
            id                   = "Expiration_Admin_Assignment"
            isExpirationRequired = $true # To exceptionally use permanent assignments, isExpirationRequired=$false can be set on selected roles and for a limited time only
            maximumDuration      = "P1D" # Basically eliminate new permanent assignments as much as possible
            target               = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "Admin"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Assignment: Rules for eligible assignments
        #             Note: Currently no rules are available / NOT IN USE.
        @{
            "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyEnablementRule"
            id            = "Enablement_Admin_Eligibility"
            enabledRules  = @(
            )
            target        = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "Admin"
                operations          = @(
                    "All"
                )
                level               = "Eligibility"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Assignment: Rules for permanent assignments
        #             Note: Authentication Context is currently not (yet?) supported here.
        @{
            "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyEnablementRule"
            id            = "Enablement_Admin_Assignment"
            enabledRules  = @(
                "Justification"
                "MultiFactorAuthentication"
            )
            target        = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "Admin"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as eligible: Admin
        @{
            "@odata.type"              = "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule"
            id                         = "Notification_Admin_Admin_Eligibility"
            isDefaultRecipientsEnabled = $true
            notificationLevel          = "Critical"
            recipientType              = "Admin"
            notificationType           = "Email"
            notificationRecipients     = @()
            target                     = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "Admin"
                operations          = @(
                    "All"
                )
                level               = "Eligibility"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as eligible: Assignee / Requestor
        @{
            "@odata.type"              = "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule"
            id                         = "Notification_Requestor_Admin_Eligibility"
            isDefaultRecipientsEnabled = $true
            notificationLevel          = "All"
            recipientType              = "Requestor"
            notificationType           = "Email"
            notificationRecipients     = @()
            target                     = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "Admin"
                operations          = @(
                    "All"
                )
                level               = "Eligibility"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as eligible: Approver
        @{
            "@odata.type"              = "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule"
            id                         = "Notification_Approver_Admin_Eligibility"
            isDefaultRecipientsEnabled = $true
            notificationLevel          = "All"
            recipientType              = "Approver"
            notificationType           = "Email"
            notificationRecipients     = @()
            target                     = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "Admin"
                operations          = @(
                    "All"
                )
                level               = "Eligibility"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as active: Admin
        @{
            "@odata.type"              = "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule"
            id                         = "Notification_Admin_Admin_Assignment"
            isDefaultRecipientsEnabled = $true
            notificationLevel          = "Critical"
            recipientType              = "Admin"
            notificationType           = "Email"
            notificationRecipients     = @()
            target                     = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "Admin"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as active: Assignee / Requestor
        @{
            "@odata.type"              = "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule"
            id                         = "Notification_Requestor_Admin_Assignment"
            isDefaultRecipientsEnabled = $true
            notificationLevel          = "All"
            recipientType              = "Requestor"
            notificationType           = "Email"
            notificationRecipients     = @()
            target                     = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "Admin"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as active: Approver
        @{
            "@odata.type"              = "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule"
            id                         = "Notification_Approver_Admin_Assignment"
            isDefaultRecipientsEnabled = $true
            notificationLevel          = "All"
            recipientType              = "Approver"
            notificationType           = "Email"
            notificationRecipients     = @()
            target                     = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "Admin"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when eligible members activate: Admin
        @{
            "@odata.type"              = "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule"
            id                         = "Notification_Admin_EndUser_Assignment"
            isDefaultRecipientsEnabled = $true
            notificationLevel          = "Critical"
            recipientType              = "Admin"
            notificationType           = "Email"
            notificationRecipients     = @()
            target                     = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "EndUser"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when eligible members activate: Requestor
        @{
            "@odata.type"              = "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule"
            id                         = "Notification_Requestor_EndUser_Assignment"
            isDefaultRecipientsEnabled = $true
            notificationLevel          = "Critical"
            recipientType              = "Requestor"
            notificationType           = "Email"
            notificationRecipients     = @()
            target                     = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "EndUser"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when eligible members activate: Approver
        @{
            "@odata.type"              = "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule"
            id                         = "Notification_Approver_EndUser_Assignment"
            isDefaultRecipientsEnabled = $true
            notificationLevel          = "All"
            recipientType              = "Approver"
            notificationType           = "Email"
            notificationRecipients     = @()
            target                     = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "EndUser"
                operations          = @(
                    "All"
                )
                level               = "Assignment"
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }
    )
)
