function Invoke-RHSMApiRequest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]$Path,

        [Parameter(Mandatory = $false)]
        [Hashtable]$Query
    )

    $headers = Get-RHSMAuthorizationHeader
    $headers['Accept'] = 'application/json'

    $uri = '{0}/{1}' -f $script:RHSMSession.BaseUri.TrimEnd('/'), $Path.TrimStart('/')

    if ($Query -and $Query.Count -gt 0) {
        $pairs = foreach ($key in $Query.Keys) {
            '{0}={1}' -f [Uri]::EscapeDataString($key), [Uri]::EscapeDataString([String]$Query[$key])
        }

        $uri = '{0}?{1}' -f $uri, ($pairs -join '&')
    }

    Write-Verbose -Message ('GET {0}' -f $uri)

    try {
        Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
    }
    catch {
        Write-Error -Message ('Error encountered calling the Red Hat Subscription Management API: {0}' -f $_) -ErrorAction Stop
    }
}
