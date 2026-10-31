function Save-RHFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]$Uri,

        [Parameter(Mandatory = $true)]
        [String]$Destination
    )

    Add-Type -AssemblyName System.Net.Http

    $client = New-Object System.Net.Http.HttpClient
    $client.Timeout = [TimeSpan]::FromHours(12)
    $stream = $null
    $output = $null

    try {
        $response = $client.GetAsync($Uri, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        $response.EnsureSuccessStatusCode() | Out-Null

        $total = $response.Content.Headers.ContentLength
        $stream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $output = [System.IO.File]::Create($Destination)

        $buffer = New-Object byte[] 1MB
        $received = 0L
        $lastUpdate = [DateTime]::MinValue

        while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $output.Write($buffer, 0, $read)
            $received += $read

            if (([DateTime]::UtcNow - $lastUpdate).TotalMilliseconds -ge 500) {
                $lastUpdate = [DateTime]::UtcNow

                if ($total) {
                    Write-Progress -Activity 'Downloading image' -Status ('{0:N0} / {1:N0} MB' -f ($received / 1MB), ($total / 1MB)) -PercentComplete ([int](100 * $received / $total))
                }
                else {
                    Write-Progress -Activity 'Downloading image' -Status ('{0:N0} MB' -f ($received / 1MB))
                }
            }
        }

        Write-Progress -Activity 'Downloading image' -Completed
    }
    finally {
        if ($output) { $output.Dispose() }
        if ($stream) { $stream.Dispose() }
        $client.Dispose()
    }
}
