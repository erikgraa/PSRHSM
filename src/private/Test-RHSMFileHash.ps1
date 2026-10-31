function Test-RHSMFileHash {
    [CmdletBinding()]
    [OutputType([Boolean])]
    param (
        [Parameter(Mandatory = $true)]
        [String]$Path,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$Checksum
    )

    $actual = (Get-FileHash -Path $Path -Algorithm SHA256).Hash

    $actual -eq $Checksum.Trim()
}
