<#
    .SYNOPSIS
    Connects to the Red Hat Subscription Management (RHSM) API.

    .DESCRIPTION
    Exchanges a Red Hat offline token for a short-lived bearer access token and stores the session in module scope.
    The access token is refreshed automatically when it is about to expire.

    .PARAMETER OfflineToken
    Specifies the Red Hat offline token as a SecureString. Generate one at https://access.redhat.com/management/api.

    .PARAMETER BaseUri
    Specifies the v1 API base URI. Defaults to https://api.access.redhat.com/management/v1.

    .PARAMETER BaseUriV2
    Specifies the v2 API base URI, used for activation keys. Defaults to https://api.access.redhat.com/api/rhsm/v2.

    .EXAMPLE
    $token = Read-Host -AsSecureString -Prompt 'Red Hat offline token'
    Connect-RHSM -OfflineToken $token

    .OUTPUTS
    [PSCustomObject].

    .LINK
    https://access.redhat.com/management/api/rhsm
#>

function Connect-RHSM {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [SecureString]$OfflineToken,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [String]$BaseUri = 'https://api.access.redhat.com/management/v1',

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [String]$BaseUriV2 = 'https://api.access.redhat.com/api/rhsm/v2'
    )

    process {
        $token = Get-RHSMAccessToken -OfflineToken $OfflineToken

        $script:RHSMSession = [PSCustomObject]@{
            BaseUri      = $BaseUri
            BaseUriV2    = $BaseUriV2
            OfflineToken = $OfflineToken
            AccessToken  = $token.AccessToken
            ExpiresAt    = $token.ExpiresAt
        }

        [PSCustomObject]@{
            BaseUri   = $BaseUri
            ExpiresAt = $token.ExpiresAt
        }
    }
}
