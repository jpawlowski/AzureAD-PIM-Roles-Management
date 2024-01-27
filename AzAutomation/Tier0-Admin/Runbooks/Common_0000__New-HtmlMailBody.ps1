<#PSScriptInfo
.VERSION 1.0.0
.GUID d838c262-351f-4196-9e23-4aa973248547
.AUTHOR Julian Pawlowski
.COMPANYNAME Workoho GmbH
.COPYRIGHT (c) 2024 Workoho GmbH. All rights reserved.
.TAGS
.LICENSEURI https://github.com/Workoho/Azure-Automation-Common-Runbooks-Framework/LICENSE
.PROJECTURI https://github.com/Workoho/Azure-Automation-Common-Runbooks-Framework
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>

<#
.SYNOPSIS
   Generate HTML email body from template

.DESCRIPTION
    Common runbook that can be used by other runbooks. It can not be started as an Azure Automation job directly.
#>

[CmdletBinding()]
param(
    [string]$Language = 'en',
    [string]$Title,
    [string]$Headline,
    [array]$Message,
    [string]$MessagePreview,
    $Icon,
    $Logo
)

if (-Not $PSCommandPath) { Throw 'This runbook is used by other runbooks and must not be run directly.' }
Write-Verbose "---START of $((Get-Item $PSCommandPath).Name), $((Test-ScriptFileInfo $PSCommandPath | Select-Object -Property Version, Guid | & { process{$_.PSObject.Properties | & { process{$_.Name + ': ' + $_.Value} }} }) -join ', ') ---"
$StartupVariables = (Get-Variable | & { process { $_.Name } })      # Remember existing variables so we can cleanup ours at the end of the script

$Icons = @{
    information = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAYAAADimHc4AAAACXBIWXMAAAsTAAALEwEAmpwYAAACe0lEQVR4nO3bT2sTQRjH8b2Z3tRjK76V3CQzkXrqVa2+B5GK5Gh3Hhbxhfjn5HVxpiyoqMdWvFnvptS7MhoQIdI0GX0yO98PDOQSsvP89pndnSVVBQAAAABrqumuXa7D6I4E80K8PXLBfotj9vm5eLP7KIwvaR9n7zTdzobz9oHz9kSC/X7GmNbe7MXvaB93L9QH25vO2zcLFP7P4c2H/XD9qvbxZ22/HV1x3nw5d/F/j+OmG29pzyNLTbezIcG8W6H4s06wbyftcKA9n+y4YB6uXPzZcMHe155Pdnc7brEL7qJjyt3ROUiwdxMW/1cXvLK3/90p0zMS7/MTByDePNOeVzact5/SB2CPtOeVDRfsafIlKNhT7XmVHYC3J9rzyoYL9mP6AMyh9ryy4eLGWvoAnmrPKxvizW76a4C5qT2vrB7EJNhpwuJ/fdzeuKg9r6zU3uwlXH7uac8nO5N2OIgbaasHYF6zGbekphtvxS3l5Zce+zm+T0h7ahSmPtjejGfxEsV/zwuZRCbtcBC3lBe5MMcLblzzn7wcXUj1+5iJW8pxVzM+J8QHq/jE/HN4cxg32ySMb3G3AwAAgL9IvdMpZwyCIID1QgcoIwBlBKCMAJQRgDICUEYAyghAGQEoIwBlBKCMAJQRgDICyIzwPoAAiiZ0AAEUTegAAiia0AEEUDShAwigaEIHEEDRhA4ggKIJHUAARRM6gACKJnQAAfTK/34pL/ynjADWivYZLqX/q1K7wEIA+kUWOkC/0MISpF/seaPqO+0CCwHoF1noAP1CC0uQfrHnjarvtAssBKBfZKED9AstLEH6xZ43qr7TLrCUHgAAAACAStsPKb5OWY/kXb4AAAAASUVORK5CYII='
    success     = 'data:image/png;base64,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'
    warning     = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAYAAADimHc4AAAACXBIWXMAAAsTAAALEwEAmpwYAAAD8klEQVR4nO2cS0hVQRjHbwvP+EI0H2lWpl1TMQsSbZuJS1dugrKUHhKRLVwYSWSBBkpKEiiYllGWGgo96KHhGcwW0aJIDIqE2tRGC2lRkH1xr6HWddK8Z86cx/8H3+aexZ0z/zPwu/PNPR4PAAAAAAAAAAAAAAAAAACABSFdSyed3SKdTf2uPhpmXtXjcgU0zLz+SeeM/ijfZwjBhAC4Nhgw+XMhaE+IPKtMGIY7Ia6VCCd/rrQS1eN0JDTm0YizN0sGoGsTNOwJVT1ex0G6Vr300z8XQrXq8ToKGo1IIM6+LD8ANk08PEn1uB0D6Vr7sid/fhW0qx63I6CRkG3E2Y//D4DN0EhIrurxO1s7+ZKrAFoqXzsZtFSpdnJoqXrt5NBStdrJoaXqtZNDS9VqJ4eWqtdODi21gHYyaKlS7eTQUvXayaGl0rSzZvdWKt25Y9Gq3ZsDLZWtnWdKc4QB1JdlQ0tla+e58mxhAI2HsqClsrXz/OEsYQAXjmRAS2VrZ8vRDGEArZXp0FLZ2tl2fLMwgI4qL7RUtnZ2VnmFAVytToOWyt7tvHYiTRjAzZrUFQbgsiZ+MLudPac2CgPor00J5seZO5r4we52DpxNEQZwp25DEAG4pIkf7G7nvbr1wgAeNqxbeQBuaOIbsdv5qCFZGMBw09rgAnDy2VKjdjv15iRhAKMticEH4NSzpUbtdj69mCgM4FnrGgNWgAPPlhrZZH/eliAM4MWleIMCcJiWGtlkf9kRLwxg/EqsMQE4SUuNbrK/7ooVBvD2eoyBAThES41usr/rXi0M4H1PtHEBOEFLZTTZP/RGCwP42B9lbAB21lJZTfZPA1HCACZvRxofgF21VFaTfepupDCA6fvhElaADbXU8LOdfL6+PogQBvBtKExSADbTUilnO/lsfR8KEwYwo4fKCcBOWirtbCefrZ86o30FgZNfXpgvb/LtpKVSz3ZyxWV1LTXnbCdTXBbVUtPOdnLlq8CaWmrq2U6uPIRq12gn/WNLwtecGWxMpokbMSYHYDEtlamdtIiGNlVkBlhQc0Wm/5qJq6DdFdpJf1X3yVTh7wDfNRNXgTW01GztPFacKwygsni7eQFYQUtVaGd5YZ4wAN8112ipKu08vWeLMADfNddoqSrtfNUZR2W78gMmf39BPo1djnOHlqrQTlpQPu30/VHjQFEeHSzKo/rybBrvMrAfbHUtNVM7yS5llpaarZ1klzJLS/1vrFV9s9yipbM++QFw9ln5jXKLls4mEQB3egC+F2WrftK4ZatX3cuz3V46m6THbJP0ABaE0Of/UtU3zi0w8Zz1mjb5AAAAAAAAAAAAAAAAAADw2I1fEzo0LLaIZ8wAAAAASUVORK5CYII='
    error       = 'data:image/png;base64,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'
    action      = 'data:image/png;base64,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'
}

$Message = $Message | & {
    process {
        if ([string]::IsNullOrEmpty($_)) {
            "<p style=`"font-family: Helvetica, sans-serif; font-size: 16px; font-weight: normal; margin: 0; margin-bottom: 16px;`"><br></p>"
        }
        else {
            "<p style=`"font-family: Helvetica, sans-serif; font-size: 16px; font-weight: normal; margin: 0; margin-bottom: 16px;`">$_</p>"
        } -join "`n                                "
    }
}

if (($null -eq $Icon) -or ($Icon -is [string])) {
    $Icon = @{
        'padding-right'       = '56px'
        'background-repeat'   = 'no-repeat'
        'background-position' = 'right top'
        'background-size'     = '48px'
        'background-image'    = if ($Icon -match "^(?:url\(['`"])?((?:data|https?):.+)['`"]?$") {
            "url('$Match[1]')"
        }
        elseif ($null -ne $Icon -and $Icons.ContainsKey($Icon)) {
            "url('$($Icons.$Icon)')"
        }
        else {
            "url('$($Icons.information)')"
        }
    }
}
elseif ($Icon -isnot [hashtable]) {
    $Icon = @{}
}
if ($Icon.Count -gt 0) {
    $Icon = @(
        $Icon.GetEnumerator() | & {
            process {
                '{0}: {1}' -f $_.Key, $_.Value
            }
        }
    ) -join '; '
}

if (($null -eq $Logo) -or ($Logo -is [string])) {
    $Logo = @{
        style = @{
            'max-height' = '36px'
            border       = '0'
        }
        src   = if ($Logo -match "^(?:url\(['`"])?((?:data|https?):.+)['`"]?$") {
            $Match[1]
        }
        else {
            # 'data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiIHN0YW5kYWxvbmU9Im5vIj8+PCFET0NUWVBFIHN2ZyBQVUJMSUMgIi0vL1czQy8vRFREIFNWRyAxLjEvL0VOIiAiaHR0cDovL3d3dy53My5vcmcvR3JhcGhpY3MvU1ZHLzEuMS9EVEQvc3ZnMTEuZHRkIj48c3ZnIHdpZHRoPSIxMDAlIiBoZWlnaHQ9IjEwMCUiIHZpZXdCb3g9IjAgMCAyODQ3IDY4OSIgdmVyc2lvbj0iMS4xIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHhtbG5zOnhsaW5rPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5L3hsaW5rIiB4bWw6c3BhY2U9InByZXNlcnZlIiB4bWxuczpzZXJpZj0iaHR0cDovL3d3dy5zZXJpZi5jb20vIiBzdHlsZT0iZmlsbC1ydWxlOmV2ZW5vZGQ7Y2xpcC1ydWxlOmV2ZW5vZGQ7c3Ryb2tlLWxpbmVqb2luOnJvdW5kO3N0cm9rZS1taXRlcmxpbWl0OjI7Ij48ZyB0cmFuc2Zvcm09Im1hdHJpeCgxLjMyNzIsMCwwLDEuMzI3MiwtNTM5LjQ2NCwtMTM5Ny40NykiPjxnPjxnPjxnPjxnIHRyYW5zZm9ybT0ibWF0cml4KDAuMjE1MzgzLDAsMCwwLjIxNTM4MywxMjA3LjY0LDg3OS4zNDcpIj48cGF0aCBkPSJNMTk3OC43MywzMDMyLjM1TDExOTEuNDksMzAzMi4zNUwxMDIyLjcsMzE0OC4zOUwxMDIyLjcsMzIxNS4wMUwxODEwLjQzLDMyMTUuMDFMMTk3OC43MywzMDk4Ljk3TDE5NzguNzMsMzAzMi4zNVoiIHN0eWxlPSJmaWxsOnJnYig1Myw1Myw1Myk7Ii8+PC9nPjxnIHRyYW5zZm9ybT0ibWF0cml4KDAuMjE1MzgzLDAsMCwwLjIxNTM4MywxNTM2LjUxLDg3OS4zNDcpIj48cGF0aCBkPSJNNDQ1NC45NCwzMDMyLjM1TDExOTEuNDksMzAzMi4zNUwxMDIyLjcsMzE0OC4zOUwxMDIyLjcsMzIxNS4wMUw0Mjg2LjY1LDMyMTUuMDFMNDQ1NC45NCwzMDk4Ljk3TDQ0NTQuOTQsMzAzMi4zNVoiIHN0eWxlPSJmaWxsOnJnYig1Myw1Myw1Myk7Ii8+PC9nPjwvZz48Zz48ZyB0cmFuc2Zvcm09Im1hdHJpeCgyLjM2NjczLDAsMCwyLjM2NjczLC00NjAuNzM4LC00MzM5LjI4KSI+PHBhdGggZD0iTTU0Ny4yOTcsMjM0My4zM0M1MzMuNzQ1LDIzNDMuMzMgNTIyLjY4OSwyMzU0LjM4IDUyMi42ODksMjM2Ny45M0w1MjIuNjg5LDI0MjIuMTRDNTIyLjY4OSwyNDM1LjcgNTMzLjc0NSwyNDQ2Ljc1IDU0Ny4yOTcsMjQ0Ni43NUw2MDMuMTEyLDI0NDYuNzVDNjE2LjY2NCwyNDQ2Ljc1IDYyNy43MiwyNDM1LjcgNjI3LjcyLDI0MjIuMTRMNjI3LjcyLDIzNjcuOTNDNjI3LjcyLDIzNTQuMzggNjE2LjY2NCwyMzQzLjMzIDYwMy4xMTIsMjM0My4zM0w1NDcuMjk3LDIzNDMuMzNaTTU0Ny4yOTcsMjQyMy4zOUM1NDYuNTg0LDI0MjMuMzkgNTQ2LjA0OSwyNDIyLjg2IDU0Ni4wNDksMjQyMi4xNEw1NDYuMDQ5LDIzNjcuOTNDNTQ2LjA0OSwyMzY3LjIyIDU0Ni41ODQsMjM2Ni42OSA1NDcuMjk3LDIzNjYuNjlMNjAzLjExMiwyMzY2LjY5QzYwMy44MjUsMjM2Ni42OSA2MDQuMzYsMjM2Ny4yMiA2MDQuMzYsMjM2Ny45M0w2MDQuMzYsMjQyMi4xNEM2MDQuMzYsMjQyMi44NiA2MDMuODI1LDI0MjMuMzkgNjAzLjExMiwyNDIzLjM5TDU0Ny4yOTcsMjQyMy4zOVoiIHN0eWxlPSJmaWxsOnJnYig1Myw1Myw1Myk7ZmlsbC1ydWxlOm5vbnplcm87Ii8+PC9nPjxnIHRyYW5zZm9ybT0ibWF0cml4KDIuMzY2NzMsMCwwLDIuMzY2NzMsLTQ2MC43MzgsLTQzMzkuMjgpIj48cGF0aCBkPSJNNzUzLjI1OSwyMzY3LjkzQzc1My4yNTksMjM1NC41NiA3NDIuMjAzLDIzNDMuMzMgNzI4LjY1MSwyMzQzLjMzTDY0OC4yMjcsMjM0My4zM0w2NDguMjI3LDI0NDYuNzVMNjcxLjU4OCwyNDQ2Ljc1TDY3MS41ODgsMjQxMy40MUw2OTMuMTY1LDI0MTMuNDFMNzI5LjcyMSwyNDQ2Ljc1TDc1NS4wNDIsMjQ0Ni43NUw3NTUuMDQyLDI0NDAuNTFMNzI0LjU0OSwyNDEzLjQxTDcyOC42NTEsMjQxMy40MUM3NDIuMjAzLDI0MTMuNDEgNzUzLjI1OSwyNDAyLjE3IDc1My4yNTksMjM4OC44TDc1My4yNTksMjM2Ny45M1pNNjcyLjgzNiwyMzg5Ljg3QzY3Mi4xMjMsMjM4OS44NyA2NzEuNTg4LDIzODkuNTEgNjcxLjU4OCwyMzg4LjhMNjcxLjU4OCwyMzY3LjkzQzY3MS41ODgsMjM2Ny4yMiA2NzIuMTIzLDIzNjYuNjkgNjcyLjgzNiwyMzY2LjY5TDcyOC42NTEsMjM2Ni42OUM3MjkuMzY0LDIzNjYuNjkgNzI5Ljg5OSwyMzY3LjIyIDcyOS44OTksMjM2Ny45M0w3MjkuODk5LDIzODguOEM3MjkuODk5LDIzODkuNTEgNzI5LjM2NCwyMzg5Ljg3IDcyOC42NTEsMjM4OS44N0w2NzIuODM2LDIzODkuODdaIiBzdHlsZT0iZmlsbDpyZ2IoNTMsNTMsNTMpO2ZpbGwtcnVsZTpub256ZXJvOyIvPjwvZz48ZyB0cmFuc2Zvcm09Im1hdHJpeCgyLjM2NjczLDAsMCwyLjM2NjczLC04OTAuNjQyLC00MzM5LjI4KSI+PHBhdGggZD0iTTY3Ny4xNCwyMzE5LjE0TDY0My43NjksMjQwNC42N0w2MTQuODgxLDIzNDMuMzNMNTkyLjA1NiwyMzQzLjMzTDU3Mi44MTMsMjQwNC42N0w1NzIuODEzLDIyOTQuOTdMNTQ4LjA1OSwyMjk0Ljk3TDU0OC4wNTksMjQ0Ni43NUw1NzMuNjg5LDI0NDYuNzVMNjAzLjY0NywyMzc5LjE3TDYzNC44NTMsMjQ0Ni43NUw2NTMuMDQyLDI0NDYuNzVMNzAyLjEwNSwyMzE5LjE0TDY3Ny4xNCwyMzE5LjE0WiIgc3R5bGU9ImZpbGw6cmdiKDUzLDUzLDUzKTtmaWxsLXJ1bGU6bm9uemVybzsiLz48L2c+PC9nPjwvZz48Zz48Zz48ZyB0cmFuc2Zvcm09Im1hdHJpeCgyLjM2NjczLDAsMCwyLjM2NjczLC00NjAuNzM4LC00MzM5LjI4KSI+PHBhdGggZD0iTTg3Mi45MjMsMjM0My4zM0w4MzYuMDEsMjM4My4yN0w3OTguMDE4LDIzODMuMjdMNzk4LjAxOCwyMjk0Ljk3TDc3NC42NTgsMjI5NC45N0w3NzQuNjU4LDI0OTcuNTdMNzk4LjAxOCwyNDk3LjU3TDc5OC4wMTgsMjQwNi44MUw4MzYuMDEsMjQwNi44MUw5MTEuODEzLDI0OTcuNTdMOTM2Ljk1NiwyNDk3LjU3TDkzNi45NTYsMjQ5MS41MUw4NTYuNjk2LDIzOTUuMDRMODk4LjA2NiwyMzQ5LjM5TDg5OC4wNjYsMjM0My4zM0w4NzIuOTIzLDIzNDMuMzNaIiBzdHlsZT0iZmlsbDpyZ2IoMCwxNzksMjA2KTtmaWxsLXJ1bGU6bm9uemVybzsiLz48L2c+PGcgdHJhbnNmb3JtPSJtYXRyaXgoMi4zNjY3MywwLDAsMi4zNjY3MywtNDQyLjcyOCwtNDMzOS4yOCkiPjxwYXRoIGQ9Ik05MzAuNTY1LDIzNDMuMzNDOTE3LjAxMywyMzQzLjMzIDkwNS45NTcsMjM1NC4zOCA5MDUuOTU3LDIzNjcuOTNMOTA1Ljk1NywyNDIyLjE0QzkwNS45NTcsMjQzNS43IDkxNy4wMTMsMjQ0Ni43NSA5MzAuNTY1LDI0NDYuNzVMOTg2LjM4LDI0NDYuNzVDOTk5LjkzMywyNDQ2Ljc1IDEwMTAuOTksMjQzNS43IDEwMTAuOTksMjQyMi4xNEwxMDEwLjk5LDIzNjcuOTNDMTAxMC45OSwyMzU0LjM4IDk5OS45MzMsMjM0My4zMyA5ODYuMzgsMjM0My4zM0w5MzAuNTY1LDIzNDMuMzNaTTkzMC41NjUsMjQyMy4zOUM5MjkuODUyLDI0MjMuMzkgOTI5LjMxNywyNDIyLjg2IDkyOS4zMTcsMjQyMi4xNEw5MjkuMzE3LDIzNjcuOTNDOTI5LjMxNywyMzY3LjIyIDkyOS44NTIsMjM2Ni42OSA5MzAuNTY1LDIzNjYuNjlMOTg2LjM4LDIzNjYuNjlDOTg3LjA5MywyMzY2LjY5IDk4Ny42MjgsMjM2Ny4yMiA5ODcuNjI4LDIzNjcuOTNMOTg3LjYyOCwyNDIyLjE0Qzk4Ny42MjgsMjQyMi44NiA5ODcuMDkzLDI0MjMuMzkgOTg2LjM4LDI0MjMuMzlMOTMwLjU2NSwyNDIzLjM5WiIgc3R5bGU9ImZpbGw6cmdiKDAsMTc5LDIwNik7ZmlsbC1ydWxlOm5vbnplcm87Ii8+PC9nPjxnIHRyYW5zZm9ybT0ibWF0cml4KDIuMzY2NzMsMCwwLDIuMzY2NzMsLTQ0Mi43MjgsLTQzMzkuMjgpIj48cGF0aCBkPSJNMTExNi4wMiwyMzQzLjMzTDExMTYuMDIsMjM4My4yN0wxMDU0Ljg2LDIzODMuMjdMMTA1NC44NiwyMzQzLjMzTDEwMzEuNSwyMzQzLjMzTDEwMzEuNSwyNDQ2Ljc1TDEwNTQuODYsMjQ0Ni43NUwxMDU0Ljg2LDI0MDYuODFMMTExNi4wMiwyNDA2LjgxTDExMTYuMDIsMjQ0Ni43NUwxMTM5LjU2LDI0NDYuNzVMMTEzOS41NiwyMzQzLjMzTDExMTYuMDIsMjM0My4zM1oiIHN0eWxlPSJmaWxsOnJnYigwLDE3OSwyMDYpO2ZpbGwtcnVsZTpub256ZXJvOyIvPjwvZz48ZyB0cmFuc2Zvcm09Im1hdHJpeCgyLjM2NjczLDAsMCwyLjM2NjczLC00NDIuNzI4LC00MzM5LjI4KSI+PHBhdGggZD0iTTExODQuNjcsMjM0My4zM0MxMTcxLjEyLDIzNDMuMzMgMTE2MC4wNywyMzU0LjM4IDExNjAuMDcsMjM2Ny45M0wxMTYwLjA3LDI0MjIuMTRDMTE2MC4wNywyNDM1LjcgMTE3MS4xMiwyNDQ2Ljc1IDExODQuNjcsMjQ0Ni43NUwxMjQwLjQ5LDI0NDYuNzVDMTI1NC4wNCwyNDQ2Ljc1IDEyNjUuMSwyNDM1LjcgMTI2NS4xLDI0MjIuMTRMMTI2NS4xLDIzNjcuOTNDMTI2NS4xLDIzNTQuMzggMTI1NC4wNCwyMzQzLjMzIDEyNDAuNDksMjM0My4zM0wxMTg0LjY3LDIzNDMuMzNaTTExODQuNjcsMjQyMy4zOUMxMTgzLjk2LDI0MjMuMzkgMTE4My40MywyNDIyLjg2IDExODMuNDMsMjQyMi4xNEwxMTgzLjQzLDIzNjcuOTNDMTE4My40MywyMzY3LjIyIDExODMuOTYsMjM2Ni42OSAxMTg0LjY3LDIzNjYuNjlMMTI0MC40OSwyMzY2LjY5QzEyNDEuMiwyMzY2LjY5IDEyNDEuNzQsMjM2Ny4yMiAxMjQxLjc0LDIzNjcuOTNMMTI0MS43NCwyNDIyLjE0QzEyNDEuNzQsMjQyMi44NiAxMjQxLjIsMjQyMy4zOSAxMjQwLjQ5LDI0MjMuMzlMMTE4NC42NywyNDIzLjM5WiIgc3R5bGU9ImZpbGw6cmdiKDAsMTc5LDIwNik7ZmlsbC1ydWxlOm5vbnplcm87Ii8+PC9nPjwvZz48ZyB0cmFuc2Zvcm09Im1hdHJpeCgwLjIxNTM4MywwLDAsMC4yMTUzODMsMTA0Ni41MywzOTkuODMpIj48cGF0aCBkPSJNMTY4Mi41MiwzMDMyLjM1TDExOTEuNDksMzAzMi4zNUwxMDIyLjcsMzE0OC4zOUwxMDIyLjcsMzIxNS4wMUwxNTE0LjIyLDMyMTUuMDFMMTY4Mi41MiwzMDk4Ljk3TDE2ODIuNTIsMzAzMi4zNVoiIHN0eWxlPSJmaWxsOnJnYigwLDE3OSwyMDYpOyIvPjwvZz48L2c+PC9nPjwvZz48L3N2Zz4='
            'data:image/png;base64,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'
        }
    }
}
if ($Logo -isnot [hashtable]) {
    $Logo = @{}
}
if ($Logo.Count -gt 0) {
    $Logo = '<img {0}/>' -f (
        @(
            $Logo.GetEnumerator() | & {
                process {
                    '{0}="{1}"' -f $_.Key, $(
                        if ($_.Value -is [hashtable]) {
                            @(
                                $_.Value.GetEnumerator() | & {
                                    process {
                                        '{0}: {1}' -f $_.Key, $_.Value
                                    }
                                }
                            ) -join '; '
                        }
                        else {
                            $_.Value
                        }
                    )
                }
            }
            if (-Not $Logo.style) {
                'style="max-height: 36px; border: 0"'
            }
        ) -join ' '
    )
}

@"
<!doctype html>
<html lang="$($Language.ToLower())">

<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    $(
        if (-Not [string]::IsNullOrEmpty($Title)) {
            "    <title>$($Title)</title>"
        }
    )
    <style media="all" type="text/css">
        @media all {
            .btn-primary table td:hover {
                background-color: #ec0867 !important;
            }

            .btn-primary a:hover {
                background-color: #ec0867 !important;
                border-color: #ec0867 !important;
            }
        }

        @media only screen and (max-width: 640px) {

            .main p,
            .main td,
            .main span {
                font-size: 16px !important;
            }

            .wrapper {
                padding: 8px !important;
            }

            .content {
                padding: 0 !important;
            }

            .container {
                padding: 0 !important;
                padding-top: 8px !important;
                width: 100% !important;
            }

            .main {
                border-left-width: 0 !important;
                border-radius: 0 !important;
                border-right-width: 0 !important;
            }

            .btn table {
                max-width: 100% !important;
                width: 100% !important;
            }

            .btn a {
                font-size: 16px !important;
                max-width: 100% !important;
                width: 100% !important;
            }
        }

        @media all {
            .ExternalClass {
                width: 100%;
            }

            .ExternalClass,
            .ExternalClass p,
            .ExternalClass span,
            .ExternalClass font,
            .ExternalClass td,
            .ExternalClass div {
                line-height: 100%;
            }

            .apple-link a {
                color: inherit !important;
                font-family: inherit !important;
                font-size: inherit !important;
                font-weight: inherit !important;
                line-height: inherit !important;
                text-decoration: none !important;
            }

            #MessageViewBody a {
                color: inherit;
                text-decoration: none;
                font-size: inherit;
                font-family: inherit;
                font-weight: inherit;
                line-height: inherit;
            }
        }
    </style>
</head>

<body
    style="font-family: Helvetica, sans-serif; -webkit-font-smoothing: antialiased; font-size: 16px; line-height: 1.3; -ms-text-size-adjust: 100%; -webkit-text-size-adjust: 100%; background-color: #ffffff; margin: 0; padding: 0;">
    <table role="presentation" border="0" cellpadding="0" cellspacing="0" class="body"
        style="border-collapse: separate; mso-table-lspace: 0pt; mso-table-rspace: 0pt; background-color: #ffffff; width: 100%;"
        width="100%" bgcolor="#ffffff">
        <tr>
            <td style="font-family: Helvetica, sans-serif; font-size: 16px; vertical-align: top;" valign="top">&nbsp;
            </td>
            <td class="container"
                style="font-family: Helvetica, sans-serif; font-size: 16px; vertical-align: top; max-width: 600px; padding: 0; padding-top: 24px; width: 600px; margin: 0 auto;"
                width="600" valign="top">
                <div class="content"
                    style="box-sizing: border-box; display: block; margin: 0 auto; max-width: 600px; padding: 0;">

                    <!-- START CENTERED WHITE CONTAINER -->
                    $(
                        if (-Not [string]::IsNullOrEmpty($Logo)) {
                            "<div style=`"text-align: center; margin: 0; margin-bottom: 16px;`">$($Logo)</div>"
                        }
                    )
                    $(
                        if (-Not [string]::IsNullOrEmpty($MessagePreview)) {
                            "                    <span class=`"preheader`" style=`"color: transparent; display: none; height: 0; max-height: 0; max-width: 0; opacity: 0; overflow: hidden; mso-hide: all; visibility: hidden; width: 0;`">$($MessagePreview)</span>"
                        }
                    )
                    <table role="presentation" border="0" cellpadding="0" cellspacing="0" class="main"
                        style="border-collapse: separate; mso-table-lspace: 0pt; mso-table-rspace: 0pt; background: #f4f5f6; border: 1px solid #a6a6a6; border-radius: 16px; width: 100%;"
                        width="100%">

                        <!-- START MAIN CONTENT AREA -->
                        <tr>
                            <td class="wrapper"
                                style="font-family: Helvetica, sans-serif; font-size: 16px; vertical-align: top; box-sizing: border-box; padding: 24px;"
                                valign="top">
                                $(
                                    if (-Not [string]::IsNullOrEmpty($Headline)) {
                                        "                    <h1 style=`"font-family: Helvetica, sans-serif; font-size: 28px; font-weight: bold; min-height: 48px; margin: 0; margin-bottom: 16px;$($Icon)`">$($Headline)</h1>"
                                    }
                                )
                                $(
                                    if (-Not [string]::IsNullOrEmpty($Message)) {$Message}
                                )
                                <!-- <table role="presentation" border="0" cellpadding="0" cellspacing="0"
                                    class="btn btn-primary"
                                    style="border-collapse: separate; mso-table-lspace: 0pt; mso-table-rspace: 0pt; box-sizing: border-box; width: 100%; min-width: 100%;"
                                    width="100%">
                                    <tbody>
                                        <tr>
                                            <td align="left"
                                                style="font-family: Helvetica, sans-serif; font-size: 16px; vertical-align: top; padding-bottom: 16px;"
                                                valign="top">
                                                <table role="presentation" border="0" cellpadding="0" cellspacing="0"
                                                    style="border-collapse: separate; mso-table-lspace: 0pt; mso-table-rspace: 0pt; width: auto;">
                                                    <tbody>
                                                        <tr>
                                                            <td style="font-family: Helvetica, sans-serif; font-size: 16px; vertical-align: top; border-radius: 4px; text-align: center; background-color: #0867ec;"
                                                                valign="top" align="center" bgcolor="#0867ec">
                                                                <a href="http://htmlemail.io" target="_blank"
                                                                   style="border: solid 2px #0867ec; border-radius: 4px; box-sizing: border-box; cursor: pointer; display: inline-block; font-size: 16px; font-weight: bold; margin: 0; padding: 12px 24px; text-decoration: none; text-transform: capitalize; background-color: #0867ec; border-color: #0867ec; color: #ffffff;">
                                                                   Call To Action
                                                                </a>
                                                            </td>
                                                        </tr>
                                                    </tbody>
                                                </table>
                                            </td>
                                        </tr>
                                    </tbody>
                                </table> -->
                            </td>
                        </tr>

                        <!-- END MAIN CONTENT AREA -->
                    </table>

                    <!-- START FOOTER -->
                    <div class="footer" style="clear: both; padding-top: 24px; padding-bottom: 24px; text-align: center; width: 100%;">
                        <table role="presentation" border="0" cellpadding="0" cellspacing="0"
                            style="border-collapse: separate; mso-table-lspace: 0pt; mso-table-rspace: 0pt; width: 100%;"
                            width="100%">
                            $(
                                # if (-Not [string]::IsNullOrEmpty($Logo)) {
                                #     "<tr><td class=`"content-block`" valign=`"top`" align=`"center`">$($Logo)</td></tr>"
                                # }
                            )
                            <tr>
                                <td class="content-block"
                                    style="font-family: Helvetica, sans-serif; vertical-align: top; color: #9a9ea6; font-size: 16px; text-align: center;"
                                    valign="top" align="center">
                                    <span class="apple-link"
                                        style="color: #9a9ea6; font-size: 16px; text-align: center;">Company Inc, 7-11
                                        Commercial Ct, Belfast BT1 2NB</span>
                                </td>
                            </tr>
                            <!-- <tr>
                                <td class="content-block powered-by"
                                    style="font-family: Helvetica, sans-serif; vertical-align: top; color: #9a9ea6; font-size: 16px; text-align: center;"
                                    valign="top" align="center">
                                    Powered by <a href="http://htmlemail.io"
                                        style="color: #9a9ea6; font-size: 16px; text-align: center; text-decoration: none;">HTMLemail.io</a>
                                </td> -->
                            </tr>
                        </table>
                    </div>

                    <!-- END FOOTER -->

                    <!-- END CENTERED WHITE CONTAINER -->
                </div>
            </td>
            <td style="font-family: Helvetica, sans-serif; font-size: 16px; vertical-align: top;" valign="top">&nbsp;
            </td>
        </tr>
    </table>
</body>

</html>
"@

Get-Variable | Where-Object { $StartupVariables -notcontains $_.Name } | & { process { Remove-Variable -Scope 0 -Name $_.Name -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -Verbose:$false -Debug:$false } }        # Delete variables created in this script to free up memory for tiny Azure Automation sandbox
Write-Verbose "-----END of $((Get-Item $PSCommandPath).Name) ---"
