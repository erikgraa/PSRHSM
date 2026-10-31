<#
    .SYNOPSIS
    Lists Red Hat Enterprise Linux images available for download.

    .DESCRIPTION
    Queries the RHSM images API for RHEL images by version and architecture, handling pagination.

    .PARAMETER Version
    Specifies one or more RHEL versions, e.g. 9.4.

    .PARAMETER Architecture
    Specifies one or more architectures. Defaults to x86_64.

    .PARAMETER Filter
    Optional wildcard filter applied to the image file name, e.g. '*dvd*'.

    .NOTES
    The response shape (filename, checksum, downloadHref) follows the RHSM OpenAPI specification, which requires a Red Hat login to view; verify against your account.

    .EXAMPLE
    Connect-RHSubscription -OfflineToken $token
    Get-RHImage -Version 9.4 -Filter '*dvd*'

    .OUTPUTS
    [PSCustomObject].

    .LINK
    https://access.redhat.com/management/api/rhsm#/images
#>

function Get-RHImage {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String[]]$Version,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [String[]]$Architecture = 'x86_64',

        [Parameter(Mandatory = $false)]
        [String]$Filter = '*'
    )

    process {
        foreach ($_version in $Version) {
            foreach ($_architecture in $Architecture) {
                $path = 'images/rhel/{0}/{1}' -f [Uri]::EscapeDataString($_version), [Uri]::EscapeDataString($_architecture)
                $limit = 100
                $offset = 0

                do {
                    $response = Invoke-RHApiRequest -Path $path -Query @{ limit = $limit; offset = $offset }
                    $items = @($response.body)

                    foreach ($item in $items) {
                        if ($item.filename -like $Filter) {
                            [PSCustomObject]@{
                                PSTypeName   = 'PSRedHat.Image'
                                FileName     = $item.filename
                                Checksum     = $item.checksum
                                DownloadHref = $item.downloadHref
                                Version      = $_version
                                Architecture = $_architecture
                            }
                        }
                    }

                    $offset += $limit
                } while ($items.Count -ge $limit)
            }
        }
    }
}
