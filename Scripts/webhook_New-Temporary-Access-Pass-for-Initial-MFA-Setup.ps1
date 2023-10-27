Param(
    [Parameter(Position = 0, Mandatory=$false)]
    [System.Object]$WebhookData
)

if ($WebhookData) {
    if ($WebhookData.RequestBody) {
        $obj = (ConvertFrom-Json -InputObject $WebhookData.RequestBody)
    } else {
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
