function Get-RHSMAuthorizationHeader {
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param ()

    if (-not $script:RHSMSession) {
        Write-Error -Message 'Not connected. Run Connect-RHSM first.' -ErrorAction Stop
    }

    # Refresh the access token shortly before it expires
    if ((Get-Date) -ge $script:RHSMSession.ExpiresAt.AddSeconds(-30)) {
        Write-Verbose -Message 'Access token expired or about to expire, refreshing.'

        $token = Get-RHSMAccessToken -OfflineToken $script:RHSMSession.OfflineToken
        $script:RHSMSession.AccessToken = $token.AccessToken
        $script:RHSMSession.ExpiresAt = $token.ExpiresAt
    }

    @{ 'Authorization' = 'Bearer {0}' -f ($script:RHSMSession.AccessToken | Convert-SecureStringToPlaintext) }
}
