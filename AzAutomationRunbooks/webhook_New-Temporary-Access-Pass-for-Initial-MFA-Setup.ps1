Param(
    [Parameter(Position = 0, Mandatory = $false)]
    [System.Object]$WebhookData
)

$WebhookName = 'cc5873e2-7350-4db1-b717-9eba71ec064d'

Write-Verbose 'start'
Write-Verbose ('object type: {0}' -f $WebhookData.gettype())
Write-Verbose $WebhookData
Write-Verbose "`n`n"
Write-Verbose $WebhookData.WebhookName
Write-Verbose $WebhookData.RequestBody
Write-Verbose $WebhookData.RequestHeader
Write-Verbose 'end'

if ($WebhookData) {
    if ($WebhookData.RequestBody) {
        # The name of the webhook that was generated for this runbook
        if (-Not $WebhookName -eq $WebhookData.WebhookName) {
            Throw 'Webhook name missmatch'
        }
        $obj = (ConvertFrom-Json -InputObject $WebhookData.RequestBody)
    }
    else {
        $obj = (ConvertFrom-Json -InputObject $WebhookData)
    }
    Write-Verbose $obj

    # Call child runbook using online execution
    # https://learn.microsoft.com/en-us/azure/automation/automation-child-runbooks#call-a-child-runbook-by-using-inline-execution
    .\New-Temporary-Access-Pass-for-Initial-MFA-Setup.ps1 `
        -UserId $obj.UserPrincipalName `
        -Confirm:$false `
        -OutJson
}
