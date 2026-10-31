function Invoke-RHSMApiRequest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]$Path,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Get', 'Post')]
        [String]$Method = 'Get',

        [Parameter(Mandatory = $false)]
        [Hashtable]$Query,

        [Parameter(Mandatory = $false)]
        [Hashtable]$Body,

        [Parameter(Mandatory = $false)]
        [ValidatePattern('^v\d+$')]
        [String]$ApiVersion = 'v1'
    )

    $headers = Get-RHSMAuthorizationHeader
    $headers['Accept'] = 'application/json'

    # The session base URI ends in the default API version; swap it when another version is requested
    $baseUri = $script:RHSMSession.BaseUri.TrimEnd('/') -replace '/v\d+$', ('/{0}' -f $ApiVersion)
    $uri = '{0}/{1}' -f $baseUri, $Path.TrimStart('/')

    if ($Query -and $Query.Count -gt 0) {
        $pairs = foreach ($key in $Query.Keys) {
            '{0}={1}' -f [Uri]::EscapeDataString($key), [Uri]::EscapeDataString([String]$Query[$key])
        }

        $uri = '{0}?{1}' -f $uri, ($pairs -join '&')
    }

    $parameters = @{
        Uri     = $uri
        Method  = $Method
        Headers = $headers
    }

    if ($Body) {
        $parameters['Body'] = $Body | ConvertTo-Json -Depth 5
        $parameters['ContentType'] = 'application/json'
    }

    Write-Verbose -Message ('{0} {1}' -f $Method.ToUpper(), $uri)

    try {
        Invoke-RestMethod @parameters
    }
    catch {
        Write-Error -Message ('Error encountered calling the Red Hat Subscription Management API: {0}' -f $_) -ErrorAction Stop
    }
}
