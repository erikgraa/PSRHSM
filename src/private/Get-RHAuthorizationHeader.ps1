function Get-RHAuthorizationHeader {
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param ()

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

    @{ 'Authorization' = 'Bearer {0}' -f ($script:RHSession.AccessToken | Convert-SecureStringToPlaintext) }
}
