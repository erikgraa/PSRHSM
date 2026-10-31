<#
    .SYNOPSIS
    Lists activation keys.

    .DESCRIPTION
    Queries GET /api/rhsm/v2/activation_keys on the RHSM API.

    .PARAMETER Name
    Optional wildcard filter applied to the activation key name, e.g. 'prod-*'.

    .NOTES
    The response shape follows the RHSM OpenAPI specification, which requires a Red Hat login to view; if the response has a 'body' property it is used, otherwise the response itself.

    .EXAMPLE
    Connect-RHSM -OfflineToken $token
    Get-RHSMActivationKey -Name 'prod-*'

    .OUTPUTS
    [PSCustomObject].

    .LINK
    https://access.redhat.com/management/api/rhsm#/activation_keys
#>

function Get-RHSMActivationKey {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $false)]
        [String]$Name = '*'
    )

    process {
        $response = Invoke-RHSMApiRequest -Path 'activation_keys' -ApiVersion 'v2'
        $items = if ($response -isnot [Array] -and $response.PSObject.Properties['body']) { $response.body } else { $response }

        foreach ($item in @($items)) {
            if ($null -ne $item -and ($Name -eq '*' -or $item.name -like $Name)) {
                $item.PSObject.TypeNames.Insert(0, 'PSRHSM.ActivationKey')
                $item
            }
        }
    }
}
