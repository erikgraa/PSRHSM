<#
    .SYNOPSIS
    Downloads a Red Hat image and verifies its SHA-256 checksum.

    .DESCRIPTION
    Downloads the image from its download link (as returned by Get-RHImage) with Invoke-WebRequest -OutFile, authenticating with the current access token, and verifies the SHA-256 checksum.

    .PARAMETER DownloadHref
    Specifies the download link, as returned by Get-RHImage.

    .PARAMETER FileName
    Specifies the file name to save as. Defaults to the file name from Get-RHImage, or the last segment of the download link.

    .PARAMETER Checksum
    Specifies the expected SHA-256 checksum. If omitted, no verification is done.

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
        [String]$DownloadHref,

        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [String]$FileName,

        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [String]$Checksum,

        [Parameter(Mandatory = $false)]
        [String]$Path = (Get-Location).Path,

        [Parameter(Mandatory = $false)]
        [Switch]$Force
    )

    process {
        $name = if ($FileName) { $FileName } else { [IO.Path]::GetFileName(([Uri]$DownloadHref).AbsolutePath) }
        $destination = Join-Path -Path $Path -ChildPath $name

        if ((Test-Path -Path $destination) -and -not $Force) {
            Write-Error -Message ("'{0}' already exists. Use -Force to overwrite." -f $destination)
            return
        }

        if (-not $PSCmdlet.ShouldProcess($destination, 'Download image')) {
            return
        }

        try {
            Write-Verbose -Message ('Downloading {0} to {1}' -f $DownloadHref, $destination)
            Invoke-WebRequest -Uri $DownloadHref -Headers (Get-RHAuthorizationHeader) -OutFile $destination -UseBasicParsing
        }
        catch {
            if (Test-Path -Path $destination) { Remove-Item -Path $destination -Force }
            Write-Error -Message ('Error encountered downloading the image: {0}' -f $_)
            return
        }

        if ($Checksum -and -not (Test-RHFileHash -Path $destination -Checksum $Checksum)) {
            Remove-Item -Path $destination -Force
            Write-Error -Message 'SHA-256 checksum mismatch; the downloaded file was removed.'
            return
        }

        Get-Item -Path $destination
    }
}
