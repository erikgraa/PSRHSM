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
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $output.Write($buffer, 0, $read)
            $received += $read

            if (([DateTime]::UtcNow - $lastUpdate).TotalMilliseconds -ge 250) {
                $lastUpdate = [DateTime]::UtcNow

                if ($total) {
                    $rate = $received / [Math]::Max($stopwatch.Elapsed.TotalSeconds, 0.001)
                    $eta = [int](([Math]::Max($total - $received, 0)) / [Math]::Max($rate, 1))
                    Write-Progress -Id 1 -Activity ('Downloading {0}' -f (Split-Path -Path $Destination -Leaf)) -Status ('{0:N0} / {1:N0} MB at {2:N1} MB/s' -f ($received / 1MB), ($total / 1MB), ($rate / 1MB)) -PercentComplete ([int](100 * $received / $total)) -SecondsRemaining $eta
                }
                else {
                    Write-Progress -Id 1 -Activity ('Downloading {0}' -f (Split-Path -Path $Destination -Leaf)) -Status ('{0:N0} MB' -f ($received / 1MB))
                }
            }
        }

        Write-Progress -Id 1 -Activity 'Downloading' -Completed
    }
    finally {
        if ($output) { $output.Dispose() }
        if ($stream) { $stream.Dispose() }
        $client.Dispose()
    }
}
