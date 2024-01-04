<#PSScriptInfo
.VERSION 1.0.0
.GUID 42b14e9d-de1d-4a82-ae38-9d8c33dd56fe
.AUTHOR Julian Pawlowski
.COMPANYNAME Workoho GmbH
.COPYRIGHT (c) 2024 Workoho GmbH. All rights reserved.
.TAGS
.LICENSEURI
.PROJECTURI
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>

<#
.SYNOPSIS
    Returns an array of Constants that are shared between all Cloud Administrator scripts.

.DESCRIPTION
    These constants are transformed using Common_0000__Convert-PSEnvToPSLocalVariable.ps1.
    Values come from local environment variables and are validated against the Regex or Type property,
    otherwise a default value is used.
    Script variables that are already set (e.g. via script parameters) may take higher priority using
    the respectScriptParameter property.

    In Azure Automation sandbox, environment variables are synchronzed with Azure Automation Variables
    before. See Common_0002__Import-AzAutomationVariableToPSEnv.ps1 for more details.

    That way, flexible configuration can be provided with easy control as part of the Azure Automation Account.
    Also, script runtime parameters can be reduced to the absolute minimum to improve security.
#>

[OutputType([array])]
param()

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | ForEach-Object { $_.PSObject.Properties | ForEach-Object { $_.Name + ': ' + $_.Value } }) -join ', ') ---"

$Constants = [array] @(
    #region General Constants
    @{
        sourceName    = "AV_CloudAdmin_RestrictedAdminUnitId"
        mapToVariable = 'CloudAdminRestrictedAdminUnitId'
        defaultValue  = $null
        Regex         = '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$'
    }
    @{
        sourceName    = "AV_CloudAdmin_AccountTypeExtensionAttribute"
        mapToVariable = 'AccountTypeExtensionAttribute'
        defaultValue  = 15
        Regex         = '^([1-9]|1[012345])$'
    }
    @{
        sourceName    = "AV_CloudAdmin_AccountTypeEmployeeType"
        mapToVariable = 'AccountTypeEmployeeType'
        defaultValue  = $true
        type          = 'Boolean'
    }
    @{
        sourceName    = "AV_CloudAdmin_ReferenceExtensionAttribute"
        mapToVariable = 'ReferenceExtensionAttribute'
        defaultValue  = 14
        Regex         = '^([1-9]|1[012345])$'
    }
    @{
        sourceName    = "AV_CloudAdmin_ReferenceManager"
        mapToVariable = 'ReferenceManager'
        defaultValue  = $false
        type          = 'Boolean'
    }
    @{
        sourceName    = "AV_CloudAdmin_Webhook"
        mapToVariable = 'Webhook'
        defaultValue  = $null
        Regex         = '^https:\/\/.+$'
    }
    #endregion

    #region Tier 0 Constants
    @{
        sourceName    = "AV_CloudAdminTier0_LicenseSkuPartNumber"
        mapToVariable = 'LicenseSkuPartNumber_Tier0'
        defaultValue  = 'EXCHANGEDESKLESS'
        Regex         = '^[A-Z][A-Z_ ]+[A-Z]$'
    }
    @{
        sourceName    = "AV_CloudAdminTier0_GroupId"
        mapToVariable = 'GroupId_Tier0'
        defaultValue  = $null
        Regex         = '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$'
    }
    @{
        sourceName    = "AV_CloudAdminTier0_GroupDescription"
        mapToVariable = 'GroupDescription_Tier0'
        defaultValue  = 'Tier 0 Cloud Administrators'
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName             = "AV_CloudAdminTier0_UserPhotoUrl"
        respectScriptParameter = 'UserPhotoUrl'
        mapToVariable          = 'PhotoUrl_Tier0'
        defaultValue           = $null
        Regex                  = '^https:\/\/.+(?:\.png|\.jpg|\.jpeg|\?.+)$'
    }
    @{
        sourceName    = "AV_CloudAdminTier0_DedicatedAccount"
        mapToVariable = 'DedicatedAccount_Tier0'
        defaultValue  = $true
        Type          = 'boolean'
    }
    @{
        sourceName    = "AV_CloudAdminTier0_AccountTypeEmployeeTypePrefix"
        mapToVariable = 'AccountTypeEmployeeTypePrefix_Tier0'
        defaultValue  = 'Tier 0 Cloud Administrator'
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName    = "AV_CloudAdminTier0_AccountTypeEmployeeTypePrefixSeparator"
        mapToVariable = 'AccountTypeEmployeeTypePrefixSeparator_Tier0'
        defaultValue  = ' ('
        Regex         = '^.{1,2}$'
    }
    @{
        sourceName    = "AV_CloudAdminTier0_AccountTypeEmployeeTypeSuffix"
        mapToVariable = 'AccountTypeEmployeeTypeSuffix_Tier0'
        defaultValue  = ')'
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName    = "AV_CloudAdminTier0_AccountTypeEmployeeTypeSuffixSeparator"
        mapToVariable = 'AccountTypeEmployeeTypeSuffixSeparator_Tier0'
        defaultValue  = ''
        Regex         = '^.{1,2}$'
    }
    @{
        sourceName    = "AV_CloudAdminTier0_AccountTypeExtensionAttributePrefix"
        mapToVariable = 'AccountTypeExtensionAttributePrefix_Tier0'
        defaultValue  = 'A0C'
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName    = "AV_CloudAdminTier0_AccountTypeExtensionAttributePrefixSeparator"
        mapToVariable = 'AccountTypeExtensionAttributePrefixSeparator_Tier0'
        defaultValue  = '__'
        Regex         = '^.{1,2}$'
    }
    @{
        sourceName    = "AV_CloudAdminTier0_AccountTypeExtensionAttributeSuffix"
        mapToVariable = 'AccountTypeExtensionAttributeSuffix_Tier0'
        defaultValue  = $null
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName    = "AV_CloudAdminTier0_AccountTypeExtensionAttributeSuffixSeparator"
        mapToVariable = 'AccountTypeExtensionAttributeSuffixSeparator_Tier0'
        defaultValue  = '__'
        Regex         = '^.{1,2}$'
    }
    @{
        sourceName    = "AV_CloudAdminTier0_UserDisplayNamePrefix"
        mapToVariable = 'UserDisplayNamePrefix_Tier0'
        defaultValue  = 'A0C'
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName    = "AV_CloudAdminTier0_UserDisplayNamePrefixSeparator"
        mapToVariable = 'UserDisplayNamePrefixSeparator_Tier0'
        defaultValue  = '-'
        Regex         = '^.{1,2}$'
    }
    @{
        sourceName    = "AV_CloudAdminTier0_UserDisplayNameSuffix"
        mapToVariable = 'UserDisplayNameSuffix_Tier0'
        defaultValue  = $null
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName    = "AV_CloudAdminTier0_UserDisplayNameSuffixSeparator"
        mapToVariable = 'UserDisplayNameSuffixSeparator_Tier0'
        defaultValue  = ' '
        Regex         = '^.{1,2}$'
    }
    @{
        sourceName    = "AV_CloudAdminTier0_GivenNamePrefix"
        mapToVariable = 'GivenNamePrefix_Tier0'
        defaultValue  = 'A0C'
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName    = "AV_CloudAdminTier0_GivenNamePrefixSeparator"
        mapToVariable = 'GivenNamePrefixSeparator_Tier0'
        defaultValue  = '-'
        Regex         = '^.{1,2}$'
    }
    @{
        sourceName    = "AV_CloudAdminTier0_GivenNameSuffix"
        mapToVariable = 'GivenNameSuffix_Tier0'
        defaultValue  = $null
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName    = "AV_CloudAdminTier0_GivenNameSuffixSeparator"
        mapToVariable = 'GivenNameSuffixSeparator_Tier0'
        defaultValue  = '-'
        Regex         = '^.{1,2}$'
    }
    @{
        sourceName    = "AV_CloudAdminTier0_UserPrincipalNamePrefix"
        mapToVariable = 'UserPrincipalNamePrefix_Tier0'
        defaultValue  = 'A0C'
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName    = "AV_CloudAdminTier0_UserPrincipalNamePrefixSeparator"
        mapToVariable = 'UserPrincipalNamePrefixSeparator_Tier0'
        defaultValue  = '-'
        Regex         = '^.{1,2}$'
    }
    @{
        sourceName    = "AV_CloudAdminTier0_UserPrincipalNameSuffix"
        mapToVariable = 'UserPrincipalNameSuffix_Tier0'
        defaultValue  = $null
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName    = "AV_CloudAdminTier0_UserPrincipalNameSuffixSeparator"
        mapToVariable = 'UserPrincipalNameSuffixSeparator_Tier0'
        defaultValue  = '-'
        Regex         = '^.{1,2}$'
    }
    #endregion

    #region Tier 1 Constants
    @{
        sourceName    = "AV_CloudAdminTier1_LicenseSkuPartNumber"
        mapToVariable = 'LicenseSkuPartNumber_Tier1'
        defaultValue  = 'EXCHANGEDESKLESS'
        Regex         = '^[A-Z][A-Z_ ]+[A-Z]$'
    }
    @{
        sourceName    = "AV_CloudAdminTier1_GroupId"
        mapToVariable = 'GroupId_Tier1'
        defaultValue  = $null
        Regex         = '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$'
    }
    @{
        sourceName    = "AV_CloudAdminTier1_GroupDescription"
        mapToVariable = 'GroupDescription_Tier1'
        defaultValue  = 'Tier 1 Cloud Administrators'
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName             = "AV_CloudAdminTier1_UserPhotoUrl"
        respectScriptParameter = 'UserPhotoUrl'
        mapToVariable          = 'PhotoUrl_Tier1'
        defaultValue           = $null
        Regex                  = '^https:\/\/.+(?:\.png|\.jpg|\.jpeg|\?.+)$'
    }
    @{
        sourceName    = "AV_CloudAdminTier1_DedicatedAccount"
        mapToVariable = 'DedicatedAccount_Tier1'
        defaultValue  = $false
        Type          = 'boolean'
    }
    @{
        sourceName    = "AV_CloudAdminTier1_AccountTypeEmployeeTypePrefix"
        mapToVariable = 'AccountTypeEmployeeTypePrefix_Tier1'
        defaultValue  = 'Tier 1 Cloud Administrator'
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName    = "AV_CloudAdminTier1_AccountTypeEmployeeTypePrefixSeparator"
        mapToVariable = 'AccountTypeEmployeeTypePrefixSeparator_Tier1'
        defaultValue  = ' ('
        Regex         = '^.{1,2}$'
    }
    @{
        sourceName    = "AV_CloudAdminTier1_AccountTypeEmployeeTypeSuffix"
        mapToVariable = 'AccountTypeEmployeeTypeSuffix_Tier1'
        defaultValue  = ')'
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName    = "AV_CloudAdminTier1_AccountTypeEmployeeTypeSuffixSeparator"
        mapToVariable = 'AccountTypeEmployeeTypeSuffixSeparator_Tier1'
        defaultValue  = ''
        Regex         = '^.{1,2}$'
    }
    @{
        sourceName    = "AV_CloudAdminTier1_AccountTypeExtensionAttributePrefix"
        mapToVariable = 'AccountTypeExtensionAttributePrefix_Tier1'
        defaultValue  = 'A0C'
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName    = "AV_CloudAdminTier1_AccountTypeExtensionAttributePrefixSeparator"
        mapToVariable = 'AccountTypeExtensionAttributePrefixSeparator_Tier1'
        defaultValue  = '__'
        Regex         = '^.{1,2}$'
    }
    @{
        sourceName    = "AV_CloudAdminTier1_AccountTypeExtensionAttributeSuffix"
        mapToVariable = 'AccountTypeExtensionAttributeSuffix_Tier1'
        defaultValue  = $null
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName    = "AV_CloudAdminTier1_AccountTypeExtensionAttributeSuffixSeparator"
        mapToVariable = 'AccountTypeExtensionAttributeSuffixSeparator_Tier1'
        defaultValue  = '__'
        Regex         = '^.{1,2}$'
    }
    @{
        sourceName    = "AV_CloudAdminTier1_UserDisplayNamePrefix"
        mapToVariable = 'UserDisplayNamePrefix_Tier1'
        defaultValue  = 'A1C'
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName    = "AV_CloudAdminTier1_UserDisplayNamePrefixSeparator"
        mapToVariable = 'UserDisplayNamePrefixSeparator_Tier1'
        defaultValue  = '-'
        Regex         = '^.{1,2}$'
    }
    @{
        sourceName    = "AV_CloudAdminTier1_UserDisplayNameSuffix"
        mapToVariable = 'UserDisplayNameSuffix_Tier1'
        defaultValue  = $null
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName    = "AV_CloudAdminTier1_UserDisplayNameSuffixSeparator"
        mapToVariable = 'UserDisplayNameSuffixSeparator_Tier1'
        defaultValue  = ' '
        Regex         = '^.{1,2}$'
    }
    @{
        sourceName    = "AV_CloudAdminTier1_GivenNamePrefix"
        mapToVariable = 'GivenNamePrefix_Tier1'
        defaultValue  = 'A1C'
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName    = "AV_CloudAdminTier1_GivenNamePrefixSeparator"
        mapToVariable = 'GivenNamePrefixSeparator_Tier1'
        defaultValue  = '-'
        Regex         = '^.{1,2}$'
    }
    @{
        sourceName    = "AV_CloudAdminTier1_GivenNameSuffix"
        mapToVariable = 'GivenNameSuffix_Tier1'
        defaultValue  = $null
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName    = "AV_CloudAdminTier1_GivenNameSuffixSeparator"
        mapToVariable = 'GivenNameSuffixSeparator_Tier1'
        defaultValue  = '-'
        Regex         = '^.{1,2}$'
    }
    @{
        sourceName    = "AV_CloudAdminTier1_UserPrincipalNamePrefix"
        mapToVariable = 'UserPrincipalNamePrefix_Tier1'
        defaultValue  = 'A1C'
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName    = "AV_CloudAdminTier1_UserPrincipalNamePrefixSeparator"
        mapToVariable = 'UserPrincipalNamePrefixSeparator_Tier1'
        defaultValue  = '-'
        Regex         = '^.{1,2}$'
    }
    @{
        sourceName    = "AV_CloudAdminTier1_UserPrincipalNameSuffix"
        mapToVariable = 'UserPrincipalNameSuffix_Tier1'
        defaultValue  = $null
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName    = "AV_CloudAdminTier1_UserPrincipalNameSuffixSeparator"
        mapToVariable = 'UserPrincipalNameSuffixSeparator_Tier1'
        defaultValue  = '-'
        Regex         = '^.{1,2}$'
    }
    #endregion

    #region Tier 2 Constants
    @{
        sourceName    = "AV_CloudAdminTier2_LicenseSkuPartNumber"
        mapToVariable = 'LicenseSkuPartNumber_Tier2'
        defaultValue  = ''
        Regex         = '^[A-Z][A-Z_ ]+[A-Z]$'
    }
    @{
        sourceName    = "AV_CloudAdminTier2_GroupId"
        mapToVariable = 'GroupId_Tier2'
        defaultValue  = $null
        Regex         = '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$'
    }
    @{
        sourceName    = "AV_CloudAdminTier2_GroupDescription"
        mapToVariable = 'GroupDescription_Tier2'
        defaultValue  = 'Tier 2 Cloud Administrators'
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName             = "AV_CloudAdminTier2_UserPhotoUrl"
        respectScriptParameter = 'UserPhotoUrl'
        mapToVariable          = 'PhotoUrl_Tier2'
        defaultValue           = $null
        Regex                  = '^https:\/\/.+(?:\.png|\.jpg|\.jpeg|\?.+)$'
    }
    @{
        sourceName    = "AV_CloudAdminTier2_DedicatedAccount"
        mapToVariable = 'DedicatedAccount_Tier2'
        defaultValue  = $false
        Type          = 'boolean'
    }
    @{
        sourceName    = "AV_CloudAdminTier2_AccountTypeEmployeeTypePrefix"
        mapToVariable = 'AccountTypeEmployeeTypePrefix_Tier2'
        defaultValue  = 'Tier 2 Cloud Administrator'
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName    = "AV_CloudAdminTier2_AccountTypeEmployeeTypePrefixSeparator"
        mapToVariable = 'AccountTypeEmployeeTypePrefixSeparator_Tier2'
        defaultValue  = ' ('
        Regex         = '^.{1,2}$'
    }
    @{
        sourceName    = "AV_CloudAdminTier2_AccountTypeEmployeeTypeSuffix"
        mapToVariable = 'AccountTypeEmployeeTypeSuffix_Tier2'
        defaultValue  = ')'
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName    = "AV_CloudAdminTier2_AccountTypeEmployeeTypeSuffixSeparator"
        mapToVariable = 'AccountTypeEmployeeTypeSuffixSeparator_Tier2'
        defaultValue  = ''
        Regex         = '^.{1,2}$'
    }
    @{
        sourceName    = "AV_CloudAdminTier2_AccountTypeExtensionAttributePrefix"
        mapToVariable = 'AccountTypeExtensionAttributePrefix_Tier2'
        defaultValue  = 'A0C'
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName    = "AV_CloudAdminTier2_AccountTypeExtensionAttributePrefixSeparator"
        mapToVariable = 'AccountTypeExtensionAttributePrefixSeparator_Tier2'
        defaultValue  = '__'
        Regex         = '^.{1,2}$'
    }
    @{
        sourceName    = "AV_CloudAdminTier2_AccountTypeExtensionAttributeSuffix"
        mapToVariable = 'AccountTypeExtensionAttributeSuffix_Tier2'
        defaultValue  = $null
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName    = "AV_CloudAdminTier2_AccountTypeExtensionAttributeSuffixSeparator"
        mapToVariable = 'AccountTypeExtensionAttributeSuffixSeparator_Tier2'
        defaultValue  = '__'
        Regex         = '^.{1,2}$'
    }
    @{
        sourceName    = "AV_CloudAdminTier2_UserDisplayNamePrefix"
        mapToVariable = 'UserDisplayNamePrefix_Tier2'
        defaultValue  = 'A2C'
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName    = "AV_CloudAdminTier2_UserDisplayNamePrefixSeparator"
        mapToVariable = 'UserDisplayNamePrefixSeparator_Tier2'
        defaultValue  = '-'
        Regex         = '^.{1,2}$'
    }
    @{
        sourceName    = "AV_CloudAdminTier2_UserDisplayNameSuffix"
        mapToVariable = 'UserDisplayNameSuffix_Tier2'
        defaultValue  = $null
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName    = "AV_CloudAdminTier2_UserDisplayNameSuffixSeparator"
        mapToVariable = 'UserDisplayNameSuffixSeparator_Tier2'
        defaultValue  = ' '
        Regex         = '^.{1,2}$'
    }
    @{
        sourceName    = "AV_CloudAdminTier2_GivenNamePrefix"
        mapToVariable = 'GivenNamePrefix_Tier2'
        defaultValue  = 'A2C'
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName    = "AV_CloudAdminTier2_GivenNamePrefixSeparator"
        mapToVariable = 'GivenNamePrefixSeparator_Tier2'
        defaultValue  = '-'
        Regex         = '^.{1,2}$'
    }
    @{
        sourceName    = "AV_CloudAdminTier2_GivenNameSuffix"
        mapToVariable = 'GivenNameSuffix_Tier2'
        defaultValue  = $null
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName    = "AV_CloudAdminTier2_GivenNameSuffixSeparator"
        mapToVariable = 'GivenNameSuffixSeparator_Tier2'
        defaultValue  = '-'
        Regex         = '^.{1,2}$'
    }
    @{
        sourceName    = "AV_CloudAdminTier2_UserPrincipalNamePrefix"
        mapToVariable = 'UserPrincipalNamePrefix_Tier2'
        defaultValue  = 'A2C'
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName    = "AV_CloudAdminTier2_UserPrincipalNamePrefixSeparator"
        mapToVariable = 'UserPrincipalNamePrefixSeparator_Tier2'
        defaultValue  = '-'
        Regex         = '^.{1,2}$'
    }
    @{
        sourceName    = "AV_CloudAdminTier2_UserPrincipalNameSuffix"
        mapToVariable = 'UserPrincipalNameSuffix_Tier2'
        defaultValue  = $null
        Regex         = '^[^\s].*[^\s]$|^.$'
    }
    @{
        sourceName    = "AV_CloudAdminTier2_UserPrincipalNameSuffixSeparator"
        mapToVariable = 'UserPrincipalNameSuffixSeparator_Tier2'
        defaultValue  = '-'
        Regex         = '^.{1,2}$'
    }
    #endregion
)

Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
return $Constants
