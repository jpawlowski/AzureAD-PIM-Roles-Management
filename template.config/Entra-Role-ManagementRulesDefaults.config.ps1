#Requires -Version 7.2

$EntraRoleManagementRulesDefaults = @(

    #:-------------------------------------------------------------------------
    # Default values for management rules of Tier 0 Roles in Microsoft Entra
    #
    @(
        # Activation: Duration / Expiration
        @{
            '@odata.type'        = '#microsoft.graph.unifiedRoleManagementPolicyExpirationRule'
            id                   = 'Expiration_EndUser_Assignment'
            isExpirationRequired = $true
            maximumDuration      = 'PT4H'
            target               = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'EndUser'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Activation: Enablement rules
        #             Excluding MultiFactorAuthentication in favor of using AuthenticationContext_EndUser_Assignment
        @{
            '@odata.type' = '#microsoft.graph.unifiedRoleManagementPolicyEnablementRule'
            id            = 'Enablement_EndUser_Assignment'
            enabledRules  = @(
                'Justification'
            )
            target        = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'EndUser'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Activation: AAD Conditional Access Authentication Context
        #             Replaces MultiFactorAuthentication in Enablement_EndUser_Assignment rule
        @{
            '@odata.type' = '#microsoft.graph.unifiedRoleManagementPolicyAuthenticationContextRule'
            id            = 'AuthenticationContext_EndUser_Assignment'
            isEnabled     = $true
            claimValue    = $EntraCAAuthContexts[0].default.Id
            target        = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'EndUser'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Activation: Approval
        @{
            '@odata.type' = '#microsoft.graph.unifiedRoleManagementPolicyApprovalRule'
            id            = 'Approval_EndUser_Assignment'
            setting       = @{
                '@odata.type'                    = 'microsoft.graph.approvalSettings'
                isApprovalRequired               = $false
                isApprovalRequiredForExtension   = $false
                isRequestorJustificationRequired = $true
                approvalMode                     = 'NoApproval'
                approvalStages                   = @(
                    @{
                        '@odata.type'                   = 'microsoft.graph.unifiedApprovalStage'
                        approvalStageTimeOutInDays      = 7
                        isApproverJustificationRequired = $true
                        escalationTimeInMinutes         = 180
                        primaryApprovers                = @()
                        isEscalationEnabled             = $false
                        escalationApprovers             = @()
                    }
                )
            }
            target        = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'EndUser'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Assignment: Eligibility
        @{
            '@odata.type'        = '#microsoft.graph.unifiedRoleManagementPolicyExpirationRule'
            id                   = 'Expiration_Admin_Eligibility'
            isExpirationRequired = $true
            maximumDuration      = 'P90D'
            target               = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'Admin'
                operations          = @(
                    'All'
                )
                level               = 'Eligibility'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Assignment: Permanent
        @{
            '@odata.type'        = '#microsoft.graph.unifiedRoleManagementPolicyExpirationRule'
            id                   = 'Expiration_Admin_Assignment'
            isExpirationRequired = $true # To exceptionally use permanent assignments, isExpirationRequired=$false can be set on selected roles and for a limited time only
            maximumDuration      = 'P1D' # Basically eliminate new permanent assignments as much as possible
            target               = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'Admin'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Assignment: Rules for eligible assignments
        #             Note: Currently no rules are available / NOT IN USE.
        @{
            '@odata.type' = '#microsoft.graph.unifiedRoleManagementPolicyEnablementRule'
            id            = 'Enablement_Admin_Eligibility'
            enabledRules  = @(
            )
            target        = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'Admin'
                operations          = @(
                    'All'
                )
                level               = 'Eligibility'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Assignment: Rules for permanent assignments
        #             Note: Authentication Context is currently not (yet?) supported here.
        @{
            '@odata.type' = '#microsoft.graph.unifiedRoleManagementPolicyEnablementRule'
            id            = 'Enablement_Admin_Assignment'
            enabledRules  = @(
                'Justification'
                'MultiFactorAuthentication'
            )
            target        = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'Admin'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as eligible: Admin
        @{
            '@odata.type'              = '#microsoft.graph.unifiedRoleManagementPolicyNotificationRule'
            id                         = 'Notification_Admin_Admin_Eligibility'
            isDefaultRecipientsEnabled = $true
            notificationLevel          = 'Critical'
            recipientType              = 'Admin'
            notificationType           = 'Email'
            notificationRecipients     = @()
            target                     = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'Admin'
                operations          = @(
                    'All'
                )
                level               = 'Eligibility'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as eligible: Assignee / Requestor
        @{
            '@odata.type'              = '#microsoft.graph.unifiedRoleManagementPolicyNotificationRule'
            id                         = 'Notification_Requestor_Admin_Eligibility'
            isDefaultRecipientsEnabled = $true
            notificationLevel          = 'All'
            recipientType              = 'Requestor'
            notificationType           = 'Email'
            notificationRecipients     = @()
            target                     = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'Admin'
                operations          = @(
                    'All'
                )
                level               = 'Eligibility'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as eligible: Approver
        @{
            '@odata.type'              = '#microsoft.graph.unifiedRoleManagementPolicyNotificationRule'
            id                         = 'Notification_Approver_Admin_Eligibility'
            isDefaultRecipientsEnabled = $true
            notificationLevel          = 'All'
            recipientType              = 'Approver'
            notificationType           = 'Email'
            notificationRecipients     = @()
            target                     = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'Admin'
                operations          = @(
                    'All'
                )
                level               = 'Eligibility'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as active: Admin
        @{
            '@odata.type'              = '#microsoft.graph.unifiedRoleManagementPolicyNotificationRule'
            id                         = 'Notification_Admin_Admin_Assignment'
            isDefaultRecipientsEnabled = $true
            notificationLevel          = 'Critical'
            recipientType              = 'Admin'
            notificationType           = 'Email'
            notificationRecipients     = @()
            target                     = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'Admin'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as active: Assignee / Requestor
        @{
            '@odata.type'              = '#microsoft.graph.unifiedRoleManagementPolicyNotificationRule'
            id                         = 'Notification_Requestor_Admin_Assignment'
            isDefaultRecipientsEnabled = $true
            notificationLevel          = 'All'
            recipientType              = 'Requestor'
            notificationType           = 'Email'
            notificationRecipients     = @()
            target                     = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'Admin'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as active: Approver
        @{
            '@odata.type'              = '#microsoft.graph.unifiedRoleManagementPolicyNotificationRule'
            id                         = 'Notification_Approver_Admin_Assignment'
            isDefaultRecipientsEnabled = $true
            notificationLevel          = 'All'
            recipientType              = 'Approver'
            notificationType           = 'Email'
            notificationRecipients     = @()
            target                     = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'Admin'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when eligible members activate: Admin
        @{
            '@odata.type'              = '#microsoft.graph.unifiedRoleManagementPolicyNotificationRule'
            id                         = 'Notification_Admin_EndUser_Assignment'
            isDefaultRecipientsEnabled = $true
            notificationLevel          = 'Critical'
            recipientType              = 'Admin'
            notificationType           = 'Email'
            notificationRecipients     = @()
            target                     = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'EndUser'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when eligible members activate: Requestor
        @{
            '@odata.type'              = '#microsoft.graph.unifiedRoleManagementPolicyNotificationRule'
            id                         = 'Notification_Requestor_EndUser_Assignment'
            isDefaultRecipientsEnabled = $true
            notificationLevel          = 'Critical'
            recipientType              = 'Requestor'
            notificationType           = 'Email'
            notificationRecipients     = @()
            target                     = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'EndUser'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when eligible members activate: Approver
        @{
            '@odata.type'              = '#microsoft.graph.unifiedRoleManagementPolicyNotificationRule'
            id                         = 'Notification_Approver_EndUser_Assignment'
            isDefaultRecipientsEnabled = $true
            notificationLevel          = 'All'
            recipientType              = 'Approver'
            notificationType           = 'Email'
            notificationRecipients     = @()
            target                     = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'EndUser'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }
    ),

    #:-------------------------------------------------------------------------
    # Default values for management rules of Tier 1 Roles in Microsoft Entra
    #
    @(
        # Activation: Duration / Expiration
        @{
            '@odata.type'        = '#microsoft.graph.unifiedRoleManagementPolicyExpirationRule'
            id                   = 'Expiration_EndUser_Assignment'
            isExpirationRequired = $true
            maximumDuration      = 'PT10H'
            target               = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'EndUser'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Activation: Enablement rules
        #             Excluding MultiFactorAuthentication in favor of using AuthenticationContext_EndUser_Assignment
        @{
            '@odata.type' = '#microsoft.graph.unifiedRoleManagementPolicyEnablementRule'
            id            = 'Enablement_EndUser_Assignment'
            enabledRules  = @(
            )
            target        = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'EndUser'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Activation: AAD Conditional Access Authentication Context
        #             Replaces MultiFactorAuthentication in Enablement_EndUser_Assignment rule
        @{
            '@odata.type' = '#microsoft.graph.unifiedRoleManagementPolicyAuthenticationContextRule'
            id            = 'AuthenticationContext_EndUser_Assignment'
            isEnabled     = $true
            claimValue    = $EntraCAAuthContexts[1].default.Id
            target        = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'EndUser'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Activation: Approval
        @{
            '@odata.type' = '#microsoft.graph.unifiedRoleManagementPolicyApprovalRule'
            id            = 'Approval_EndUser_Assignment'
            setting       = @{
                '@odata.type'                    = 'microsoft.graph.approvalSettings'
                isApprovalRequired               = $false
                isApprovalRequiredForExtension   = $false
                isRequestorJustificationRequired = $true
                approvalMode                     = 'NoApproval'
                approvalStages                   = @(
                    @{
                        '@odata.type'                   = 'microsoft.graph.unifiedApprovalStage'
                        approvalStageTimeOutInDays      = 7
                        isApproverJustificationRequired = $true
                        escalationTimeInMinutes         = 180
                        primaryApprovers                = @()
                        isEscalationEnabled             = $false
                        escalationApprovers             = @()
                    }
                )
            }
            target        = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'EndUser'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Assignment: Eligibility
        @{
            '@odata.type'        = '#microsoft.graph.unifiedRoleManagementPolicyExpirationRule'
            id                   = 'Expiration_Admin_Eligibility'
            isExpirationRequired = $true
            maximumDuration      = 'P180D'
            target               = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'Admin'
                operations          = @(
                    'All'
                )
                level               = 'Eligibility'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Assignment: Permanent
        @{
            '@odata.type'        = '#microsoft.graph.unifiedRoleManagementPolicyExpirationRule'
            id                   = 'Expiration_Admin_Assignment'
            isExpirationRequired = $true # To exceptionally use permanent assignments, isExpirationRequired=$false can be set on selected roles and for a limited time only
            maximumDuration      = 'P1D' # Basically eliminate new permanent assignments as much as possible
            target               = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'Admin'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Assignment: Rules for eligible assignments
        #             Note: Currently no rules are available / NOT IN USE.
        @{
            '@odata.type' = '#microsoft.graph.unifiedRoleManagementPolicyEnablementRule'
            id            = 'Enablement_Admin_Eligibility'
            enabledRules  = @(
            )
            target        = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'Admin'
                operations          = @(
                    'All'
                )
                level               = 'Eligibility'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Assignment: Rules for permanent assignments
        #             Note: Authentication Context is currently not (yet?) supported here.
        @{
            '@odata.type' = '#microsoft.graph.unifiedRoleManagementPolicyEnablementRule'
            id            = 'Enablement_Admin_Assignment'
            enabledRules  = @(
                'Justification'
                'MultiFactorAuthentication'
            )
            target        = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'Admin'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as eligible: Admin
        @{
            '@odata.type'              = '#microsoft.graph.unifiedRoleManagementPolicyNotificationRule'
            id                         = 'Notification_Admin_Admin_Eligibility'
            isDefaultRecipientsEnabled = $true
            notificationLevel          = 'Critical'
            recipientType              = 'Admin'
            notificationType           = 'Email'
            notificationRecipients     = @()
            target                     = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'Admin'
                operations          = @(
                    'All'
                )
                level               = 'Eligibility'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as eligible: Assignee / Requestor
        @{
            '@odata.type'              = '#microsoft.graph.unifiedRoleManagementPolicyNotificationRule'
            id                         = 'Notification_Requestor_Admin_Eligibility'
            isDefaultRecipientsEnabled = $true
            notificationLevel          = 'All'
            recipientType              = 'Requestor'
            notificationType           = 'Email'
            notificationRecipients     = @()
            target                     = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'Admin'
                operations          = @(
                    'All'
                )
                level               = 'Eligibility'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as eligible: Approver
        @{
            '@odata.type'              = '#microsoft.graph.unifiedRoleManagementPolicyNotificationRule'
            id                         = 'Notification_Approver_Admin_Eligibility'
            isDefaultRecipientsEnabled = $true
            notificationLevel          = 'All'
            recipientType              = 'Approver'
            notificationType           = 'Email'
            notificationRecipients     = @()
            target                     = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'Admin'
                operations          = @(
                    'All'
                )
                level               = 'Eligibility'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as active: Admin
        @{
            '@odata.type'              = '#microsoft.graph.unifiedRoleManagementPolicyNotificationRule'
            id                         = 'Notification_Admin_Admin_Assignment'
            isDefaultRecipientsEnabled = $true
            notificationLevel          = 'Critical'
            recipientType              = 'Admin'
            notificationType           = 'Email'
            notificationRecipients     = @()
            target                     = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'Admin'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as active: Assignee / Requestor
        @{
            '@odata.type'              = '#microsoft.graph.unifiedRoleManagementPolicyNotificationRule'
            id                         = 'Notification_Requestor_Admin_Assignment'
            isDefaultRecipientsEnabled = $true
            notificationLevel          = 'All'
            recipientType              = 'Requestor'
            notificationType           = 'Email'
            notificationRecipients     = @()
            target                     = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'Admin'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as active: Approver
        @{
            '@odata.type'              = '#microsoft.graph.unifiedRoleManagementPolicyNotificationRule'
            id                         = 'Notification_Approver_Admin_Assignment'
            isDefaultRecipientsEnabled = $true
            notificationLevel          = 'All'
            recipientType              = 'Approver'
            notificationType           = 'Email'
            notificationRecipients     = @()
            target                     = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'Admin'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when eligible members activate: Admin
        @{
            '@odata.type'              = '#microsoft.graph.unifiedRoleManagementPolicyNotificationRule'
            id                         = 'Notification_Admin_EndUser_Assignment'
            isDefaultRecipientsEnabled = $true
            notificationLevel          = 'Critical'
            recipientType              = 'Admin'
            notificationType           = 'Email'
            notificationRecipients     = @()
            target                     = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'EndUser'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when eligible members activate: Requestor
        @{
            '@odata.type'              = '#microsoft.graph.unifiedRoleManagementPolicyNotificationRule'
            id                         = 'Notification_Requestor_EndUser_Assignment'
            isDefaultRecipientsEnabled = $true
            notificationLevel          = 'Critical'
            recipientType              = 'Requestor'
            notificationType           = 'Email'
            notificationRecipients     = @()
            target                     = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'EndUser'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when eligible members activate: Approver
        @{
            '@odata.type'              = '#microsoft.graph.unifiedRoleManagementPolicyNotificationRule'
            id                         = 'Notification_Approver_EndUser_Assignment'
            isDefaultRecipientsEnabled = $true
            notificationLevel          = 'All'
            recipientType              = 'Approver'
            notificationType           = 'Email'
            notificationRecipients     = @()
            target                     = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'EndUser'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }
    ),

    # Default values for management rules of Tier 2 Roles in Microsoft Entra
    @(
        # Activation: Duration / Expiration
        @{
            '@odata.type'        = '#microsoft.graph.unifiedRoleManagementPolicyExpirationRule'
            id                   = 'Expiration_EndUser_Assignment'
            isExpirationRequired = $true
            maximumDuration      = 'PT10H'
            target               = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'EndUser'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Activation: Enablement rules
        #             Excluding MultiFactorAuthentication in favor of using AuthenticationContext_EndUser_Assignment
        @{
            '@odata.type' = '#microsoft.graph.unifiedRoleManagementPolicyEnablementRule'
            id            = 'Enablement_EndUser_Assignment'
            enabledRules  = @(
                'Justification'
            )
            target        = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'EndUser'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Activation: AAD Conditional Access Authentication Context
        #             Replaces MultiFactorAuthentication in Enablement_EndUser_Assignment rule
        @{
            '@odata.type' = '#microsoft.graph.unifiedRoleManagementPolicyAuthenticationContextRule'
            id            = 'AuthenticationContext_EndUser_Assignment'
            isEnabled     = $true
            claimValue    = $EntraCAAuthContexts[2].default.Id
            target        = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'EndUser'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Activation: Approval
        @{
            '@odata.type' = '#microsoft.graph.unifiedRoleManagementPolicyApprovalRule'
            id            = 'Approval_EndUser_Assignment'
            setting       = @{
                '@odata.type'                    = 'microsoft.graph.approvalSettings'
                isApprovalRequired               = $false
                isApprovalRequiredForExtension   = $false
                isRequestorJustificationRequired = $true
                approvalMode                     = 'NoApproval'
                approvalStages                   = @(
                    @{
                        '@odata.type'                   = 'microsoft.graph.unifiedApprovalStage'
                        approvalStageTimeOutInDays      = 7
                        isApproverJustificationRequired = $true
                        escalationTimeInMinutes         = 180
                        primaryApprovers                = @()
                        isEscalationEnabled             = $false
                        escalationApprovers             = @()
                    }
                )
            }
            target        = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'EndUser'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Assignment: Eligibility
        @{
            '@odata.type'        = '#microsoft.graph.unifiedRoleManagementPolicyExpirationRule'
            id                   = 'Expiration_Admin_Eligibility'
            isExpirationRequired = $true
            maximumDuration      = 'P365D'
            target               = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'Admin'
                operations          = @(
                    'All'
                )
                level               = 'Eligibility'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Assignment: Permanent
        @{
            '@odata.type'        = '#microsoft.graph.unifiedRoleManagementPolicyExpirationRule'
            id                   = 'Expiration_Admin_Assignment'
            isExpirationRequired = $true # To exceptionally use permanent assignments, isExpirationRequired=$false can be set on selected roles and for a limited time only
            maximumDuration      = 'P1D' # Basically eliminate new permanent assignments as much as possible
            target               = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'Admin'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Assignment: Rules for eligible assignments
        #             Note: Currently no rules are available / NOT IN USE.
        @{
            '@odata.type' = '#microsoft.graph.unifiedRoleManagementPolicyEnablementRule'
            id            = 'Enablement_Admin_Eligibility'
            enabledRules  = @(
            )
            target        = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'Admin'
                operations          = @(
                    'All'
                )
                level               = 'Eligibility'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Assignment: Rules for permanent assignments
        #             Note: Authentication Context is currently not (yet?) supported here.
        @{
            '@odata.type' = '#microsoft.graph.unifiedRoleManagementPolicyEnablementRule'
            id            = 'Enablement_Admin_Assignment'
            enabledRules  = @(
                'Justification'
                'MultiFactorAuthentication'
            )
            target        = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'Admin'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as eligible: Admin
        @{
            '@odata.type'              = '#microsoft.graph.unifiedRoleManagementPolicyNotificationRule'
            id                         = 'Notification_Admin_Admin_Eligibility'
            isDefaultRecipientsEnabled = $true
            notificationLevel          = 'Critical'
            recipientType              = 'Admin'
            notificationType           = 'Email'
            notificationRecipients     = @()
            target                     = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'Admin'
                operations          = @(
                    'All'
                )
                level               = 'Eligibility'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as eligible: Assignee / Requestor
        @{
            '@odata.type'              = '#microsoft.graph.unifiedRoleManagementPolicyNotificationRule'
            id                         = 'Notification_Requestor_Admin_Eligibility'
            isDefaultRecipientsEnabled = $true
            notificationLevel          = 'All'
            recipientType              = 'Requestor'
            notificationType           = 'Email'
            notificationRecipients     = @()
            target                     = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'Admin'
                operations          = @(
                    'All'
                )
                level               = 'Eligibility'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as eligible: Approver
        @{
            '@odata.type'              = '#microsoft.graph.unifiedRoleManagementPolicyNotificationRule'
            id                         = 'Notification_Approver_Admin_Eligibility'
            isDefaultRecipientsEnabled = $true
            notificationLevel          = 'All'
            recipientType              = 'Approver'
            notificationType           = 'Email'
            notificationRecipients     = @()
            target                     = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'Admin'
                operations          = @(
                    'All'
                )
                level               = 'Eligibility'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as active: Admin
        @{
            '@odata.type'              = '#microsoft.graph.unifiedRoleManagementPolicyNotificationRule'
            id                         = 'Notification_Admin_Admin_Assignment'
            isDefaultRecipientsEnabled = $true
            notificationLevel          = 'Critical'
            recipientType              = 'Admin'
            notificationType           = 'Email'
            notificationRecipients     = @()
            target                     = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'Admin'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as active: Assignee / Requestor
        @{
            '@odata.type'              = '#microsoft.graph.unifiedRoleManagementPolicyNotificationRule'
            id                         = 'Notification_Requestor_Admin_Assignment'
            isDefaultRecipientsEnabled = $true
            notificationLevel          = 'All'
            recipientType              = 'Requestor'
            notificationType           = 'Email'
            notificationRecipients     = @()
            target                     = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'Admin'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when members are assigned as active: Approver
        @{
            '@odata.type'              = '#microsoft.graph.unifiedRoleManagementPolicyNotificationRule'
            id                         = 'Notification_Approver_Admin_Assignment'
            isDefaultRecipientsEnabled = $true
            notificationLevel          = 'All'
            recipientType              = 'Approver'
            notificationType           = 'Email'
            notificationRecipients     = @()
            target                     = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'Admin'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when eligible members activate: Admin
        @{
            '@odata.type'              = '#microsoft.graph.unifiedRoleManagementPolicyNotificationRule'
            id                         = 'Notification_Admin_EndUser_Assignment'
            isDefaultRecipientsEnabled = $true
            notificationLevel          = 'Critical'
            recipientType              = 'Admin'
            notificationType           = 'Email'
            notificationRecipients     = @()
            target                     = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'EndUser'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when eligible members activate: Requestor
        @{
            '@odata.type'              = '#microsoft.graph.unifiedRoleManagementPolicyNotificationRule'
            id                         = 'Notification_Requestor_EndUser_Assignment'
            isDefaultRecipientsEnabled = $true
            notificationLevel          = 'Critical'
            recipientType              = 'Requestor'
            notificationType           = 'Email'
            notificationRecipients     = @()
            target                     = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'EndUser'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }

        # Notification when eligible members activate: Approver
        @{
            '@odata.type'              = '#microsoft.graph.unifiedRoleManagementPolicyNotificationRule'
            id                         = 'Notification_Approver_EndUser_Assignment'
            isDefaultRecipientsEnabled = $true
            notificationLevel          = 'All'
            recipientType              = 'Approver'
            notificationType           = 'Email'
            notificationRecipients     = @()
            target                     = @{
                '@odata.type'       = 'microsoft.graph.unifiedRoleManagementPolicyRuleTarget'
                caller              = 'EndUser'
                operations          = @(
                    'All'
                )
                level               = 'Assignment'
                inheritableSettings = @(
                )
                enforcedSettings    = @(
                )
            }
        }
    )
)
