<#
    .SYNOPSIS
    Lists subscriptions on the Red Hat account.

    .DESCRIPTION
    Queries GET /subscriptions on the RHSM API, handling pagination.

    .PARAMETER Name
    Optional wildcard filter applied to the subscription name, e.g. '*Developer*'.

    .NOTES
    The response shape (body array, subscriptionName) follows the RHSM OpenAPI specification, which requires a Red Hat login to view; verify against your account.

    .EXAMPLE
    Connect-RHSM -OfflineToken $token
    Get-RHSMSubscription -Name '*Developer*'

    .OUTPUTS
    [PSCustomObject].

    .LINK
    https://access.redhat.com/management/api/rhsm#/subscriptions
#>

function Get-RHSMSubscription {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $false)]
        [String]$Name = '*'
    )

    process {
        $limit = 100
        $offset = 0

        do {
            $response = Invoke-RHSMApiRequest -Path 'subscriptions' -Query @{ limit = $limit; offset = $offset }
            $items = @($response.body)

            foreach ($item in $items) {
                if ($Name -eq '*' -or $item.subscriptionName -like $Name) {
                    $item.PSObject.TypeNames.Insert(0, 'PSRHSM.Subscription')
                    $item
                }
            }

            $offset += $limit
        } while ($items.Count -ge $limit)
    }
}
