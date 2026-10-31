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
        [ValidateSet('v1', 'v2')]
        [String]$ApiVersion = 'v1'
    )

    $headers = Get-RHSMAuthorizationHeader
    $headers['Accept'] = 'application/json'

    # v1 lives under /management/v1, v2 under /api/rhsm/v2
    $baseUri = if ($ApiVersion -eq 'v2') { $script:RHSMSession.BaseUriV2 } else { $script:RHSMSession.BaseUri }
    $uri = '{0}/{1}' -f $baseUri.TrimEnd('/'), $Path.TrimStart('/')

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
