<#
    .SYNOPSIS
    Downloads a Red Hat image and verifies its SHA-256 checksum.

    .DESCRIPTION
    Resolves the download URL via GET /images/{checksum}/download, downloads the file with progress, and verifies the SHA-256 checksum.

    .PARAMETER Checksum
    Specifies the SHA-256 checksum of the image, as returned by Get-RHImage.

    .PARAMETER FileName
    Specifies the file name to save as. Defaults to the name reported by the API.

    .PARAMETER Path
    Specifies the destination directory. Defaults to the current directory.

    .PARAMETER Force
    Overwrites an existing file.

    .EXAMPLE
    Get-RHImage -Version 9.4 -Filter '*dvd*' | Save-RHImage -Path C:\ISO

    .OUTPUTS
    [System.IO.FileInfo].

    .LINK
    https://access.redhat.com/management/api/rhsm#/images/downloadImage
#>

function Save-RHImage {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([System.IO.FileInfo])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$Checksum,

        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [String]$FileName,

        [Parameter(Mandatory = $false)]
        [String]$Path = (Get-Location).Path,

        [Parameter(Mandatory = $false)]
        [Switch]$Force
    )

    process {
        $download = Invoke-RHApiRequest -Path ('images/{0}/download' -f [Uri]::EscapeDataString($Checksum))
        Write-Verbose -Message ('Download response: {0}' -f ($download | ConvertTo-Json -Depth 5 -Compress))

        $href = $null
        $apiFileName = $null

        foreach ($candidate in @($download.body, $download)) {
            if (-not $candidate) { continue }

            foreach ($property in 'href', 'url', 'downloadHref', 'downloadUrl') {
                if (-not $href -and $candidate.$property -is [String]) { $href = $candidate.$property }
            }

            if (-not $apiFileName -and $candidate.filename) { $apiFileName = $candidate.filename }
        }

        if (-not $href) {
            Write-Error -Message ('The API did not return a download URL for checksum {0}. Response: {1}' -f $Checksum, ($download | ConvertTo-Json -Depth 5 -Compress)) -ErrorAction Stop
        }

        if (-not $FileName) {
            $FileName = if ($apiFileName) { $apiFileName } else { [IO.Path]::GetFileName(([Uri]$href).AbsolutePath) }
        }

        $destination = Join-Path -Path $Path -ChildPath $FileName

        if ((Test-Path -Path $destination) -and -not $Force) {
            Write-Error -Message ("'{0}' already exists. Use -Force to overwrite." -f $destination) -ErrorAction Stop
        }

        if (-not $PSCmdlet.ShouldProcess($destination, 'Download image')) {
            return
        }

        try {
            Write-Verbose -Message ('Downloading to {0}' -f $destination)
            Save-RHFile -Uri $href -Destination $destination
        }
        catch {
            if (Test-Path -Path $destination) { Remove-Item -Path $destination -Force }
            Write-Error -Message ('Error encountered downloading the image: {0}' -f $_) -ErrorAction Stop
        }

        if (-not (Test-RHFileHash -Path $destination -Checksum $Checksum)) {
            Remove-Item -Path $destination -Force
            Write-Error -Message 'SHA-256 checksum mismatch; the downloaded file was removed.' -ErrorAction Stop
        }

        Get-Item -Path $destination
    }
}
