function Invoke-RHApiRequest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]$Path,

        [Parameter(Mandatory = $false)]
        [Hashtable]$Query
    )

    if (-not $script:RHSession) {
        Write-Error -Message 'Not connected. Run Connect-RHSubscription first.' -ErrorAction Stop
    }

    # Refresh the access token shortly before it expires
    if ((Get-Date) -ge $script:RHSession.ExpiresAt.AddSeconds(-30)) {
        Write-Verbose -Message 'Access token expired or about to expire, refreshing.'

        $token = Get-RHAccessToken -OfflineToken $script:RHSession.OfflineToken
        $script:RHSession.AccessToken = $token.AccessToken
        $script:RHSession.ExpiresAt = $token.ExpiresAt
    }

    $uri = '{0}/{1}' -f $script:RHSession.BaseUri.TrimEnd('/'), $Path.TrimStart('/')

    if ($Query -and $Query.Count -gt 0) {
        $pairs = foreach ($key in $Query.Keys) {
            '{0}={1}' -f [Uri]::EscapeDataString($key), [Uri]::EscapeDataString([String]$Query[$key])
        }

        $uri = '{0}?{1}' -f $uri, ($pairs -join '&')
    }

    $headers = @{
        'Accept'        = 'application/json'
        'Authorization' = 'Bearer {0}' -f ($script:RHSession.AccessToken | Convert-SecureStringToPlaintext)
    }

    Write-Verbose -Message ('GET {0}' -f $uri)

    try {
        Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
    }
    catch {
        Write-Error -Message ('Error encountered calling the Red Hat Subscription Management API: {0}' -f $_) -ErrorAction Stop
    }
}
