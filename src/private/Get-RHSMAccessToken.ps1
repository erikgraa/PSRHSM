function Get-RHSMAccessToken {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [SecureString]$OfflineToken,

        [Parameter(Mandatory = $false)]
        [String]$TokenUri = 'https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token'
    )

    $body = @{
        grant_type    = 'refresh_token'
        client_id     = 'rhsm-api'
        refresh_token = $OfflineToken | Convert-SecureStringToPlaintext
    }

    try {
        $response = Invoke-RestMethod -Uri $TokenUri -Method Post -Body $body -ContentType 'application/x-www-form-urlencoded'
    }
    catch {
        Write-Error -Message ('Error encountered exchanging the offline token for an access token: {0}' -f $_) -ErrorAction Stop
    }

    [PSCustomObject]@{
        AccessToken = ConvertTo-SecureString -String $response.access_token -AsPlainText -Force
        ExpiresAt   = (Get-Date).AddSeconds([int]$response.expires_in)
    }
}
