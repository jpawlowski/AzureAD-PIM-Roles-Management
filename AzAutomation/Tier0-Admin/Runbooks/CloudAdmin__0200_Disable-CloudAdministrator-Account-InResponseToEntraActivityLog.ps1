<#PSScriptInfo
.VERSION 0.0.1
.GUID 394d727b-7b9f-4392-9d86-c6467f3c3909
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
    ...

.DESCRIPTION
    ...
#>

Param(
    [Parameter (Mandatory = $false)]
    [Object]$WebhookData
)

#region [COMMON] SCRIPT CONFIGURATION PARAMETERS -------------------------------
#
# IMPORTANT: You should actually NOT change these parameters here. Instead, use the environment variables described above.
# These parameters here exist quite far up in this file so that you get a quick idea of some
# interesting aspects of the dependencies, e.g. when performing a code audit for security reasons.

$ImportPsModules = @(
    # @{ Name = 'Az.Compute'; MinimumVersion = '4.27'; MaximumVersion = '4.65535' }
)
#endregion ---------------------------------------------------------------------

#region [COMMON] ENVIRONMENT ---------------------------------------------------
$ErrorActionPreference = "stop"
.\Common__0000_Import-Modules.ps1 -Modules $ImportPsModules 1> $null
.\Common__0003_Import-AzAutomationVariableToPSEnv.ps1 1> $null
.\Common__0000_Convert-PSEnvToPSLocalVariable.ps1 -Variable (.\CloudAdmin__0000_Common_0000_Get-ConfigurationConstants.ps1) 1> $null
#endregion ---------------------------------------------------------------------

if ($WebhookData) {
    # Get the data object from WebhookData
    $WebhookBody = (ConvertFrom-Json -InputObject $WebhookData.RequestBody)

    # Get the info needed to identify the VM (depends on the payload schema)
    $schemaId = $WebhookBody.schemaId
    Write-Verbose "schemaId: $schemaId" -Verbose

    if ($schemaId -eq "azureMonitorCommonAlertSchema") {
        # This is the common Metric Alert schema (released March 2019)
        $Essentials = [object]($WebhookBody.data).essentials
        # Get the first target only as this script doesn't handle multiple
        $alertTargetIdArray = (($Essentials.alertTargetIds)[0]).Split('/')
        $SubId = ($alertTargetIdArray)[2]
        $ResourceGroupName = ($alertTargetIdArray)[4]
        $ResourceType = ($alertTargetIdArray)[6] + '/' + ($alertTargetIdArray)[7]
        $ResourceName = ($alertTargetIdArray)[-1]
        $status = $Essentials.monitorCondition
    }
    elseif ($schemaId -eq "AzureMonitorMetricAlert") {
        # This is the near-real-time Metric Alert schema
        $AlertContext = [object]($WebhookBody.data).context
        $SubId = $AlertContext.subscriptionId
        $ResourceGroupName = $AlertContext.resourceGroupName
        $ResourceType = $AlertContext.resourceType
        $ResourceName = $AlertContext.resourceName
        $status = ($WebhookBody.data).status
    }
    elseif ($schemaId -eq "Microsoft.Insights/activityLogs") {
        # This is the Activity Log Alert schema
        $AlertContext = [object](($WebhookBody.data).context).activityLog
        $SubId = $AlertContext.subscriptionId
        $ResourceGroupName = $AlertContext.resourceGroupName
        $ResourceType = $AlertContext.resourceType
        $ResourceName = (($AlertContext.resourceId).Split('/'))[-1]
        $status = ($WebhookBody.data).status
    }
    elseif ($null -eq $schemaId) {
        # This is the original Metric Alert schema
        $AlertContext = [object]$WebhookBody.context
        $SubId = $AlertContext.subscriptionId
        $ResourceGroupName = $AlertContext.resourceGroupName
        $ResourceType = $AlertContext.resourceType
        $ResourceName = $AlertContext.resourceName
        $status = $WebhookBody.status
    }
    else {
        # Schema not supported
        Write-Error "The alert data schema - $schemaId - is not supported."
    }

    Write-Verbose "Status: $status" -Verbose

    if (($status -eq "Activated") -or ($status -eq "Fired")) {
        Write-Verbose "resourceType: $ResourceType" -Verbose
        Write-Verbose "resourceName: $ResourceName" -Verbose
        Write-Verbose "resourceGroupName: $ResourceGroupName" -Verbose
        Write-Verbose "subscriptionId: $SubId" -Verbose

        # Determine code path depending on the resourceType
        if ($ResourceType -eq "Microsoft.Compute/virtualMachines") {
            # This is an Resource Manager VM
            Write-Verbose "This is an Resource Manager VM." -Verbose

            # Ensures you do not inherit an AzContext in your runbook
            Disable-AzContextAutosave -Scope Process

            # Connect to Azure with system-assigned managed identity
            $AzureContext = (Connect-AzAccount -Identity).context

            # set and store context
            $AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext

            # Stop the Resource Manager VM
            Write-Verbose "Stopping the VM - $ResourceName - in resource group - $ResourceGroupName -" -Verbose
            Stop-AzVM -Name $ResourceName -ResourceGroupName $ResourceGroupName -DefaultProfile $AzureContext -Force
            # [OutputType(PSAzureOperationResponse")]
        }
        else {
            # ResourceType not supported
            Write-Error "$ResourceType is not a supported resource type for this runbook."
        }
    }
    else {
        # The alert status was not 'Activated' or 'Fired' so no action taken
        Write-Verbose ("No action taken. Alert status: " + $status) -Verbose
    }
}
else {
    # Error
    Write-Error "This runbook is meant to be started from an Azure alert webhook only."
}
