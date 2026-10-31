<#
    .SYNOPSIS
    Lists systems registered with Red Hat Subscription Management.

    .DESCRIPTION
    Queries GET /systems on the RHSM API, handling pagination.

    .PARAMETER Name
    Optional wildcard filter applied to the system name, e.g. 'web*'.

    .NOTES
    The response shape follows the RHSM OpenAPI specification, which requires a Red Hat login to view; verify against your account.

    .EXAMPLE
    Connect-RHSM -OfflineToken $token
    Get-RHSMSystem -Name 'web*'

    .OUTPUTS
    [PSCustomObject].

    .LINK
    https://access.redhat.com/management/api/rhsm#/systems
#>

function Get-RHSMSystem {
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
            $response = Invoke-RHSMApiRequest -Path 'systems' -Query @{ limit = $limit; offset = $offset }
            $items = @($response.body)

            foreach ($item in $items) {
                if ($item.name -like $Name) {
                    $item.PSObject.TypeNames.Insert(0, 'PSRHSM.System')
                    $item
                }
            }

            $offset += $limit
        } while ($items.Count -ge $limit)
    }
}
