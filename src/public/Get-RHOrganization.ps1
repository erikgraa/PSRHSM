<#
    .SYNOPSIS
    Gets the Red Hat organization for the connected account.

    .DESCRIPTION
    Queries GET /organization on the RHSM API.

    .NOTES
    The response shape follows the RHSM OpenAPI specification, which requires a Red Hat login to view; if the response has a 'body' property it is returned, otherwise the response itself.

    .EXAMPLE
    Connect-RHSubscription -OfflineToken $token
    Get-RHOrganization

    .OUTPUTS
    [PSCustomObject].

    .LINK
    https://access.redhat.com/management/api/rhsm#/organization
#>

function Get-RHOrganization {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param ()

    process {
        $response = Invoke-RHApiRequest -Path 'organization'
        $organization = if ($null -ne $response.body) { $response.body } else { $response }

        foreach ($item in @($organization)) {
            $item.PSObject.TypeNames.Insert(0, 'PSRedHat.Organization')
            $item
        }
    }
}
