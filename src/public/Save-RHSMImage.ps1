<#
    .SYNOPSIS
    Downloads a Red Hat image and verifies its SHA-256 checksum.

    .DESCRIPTION
    Downloads the image from its download link (as returned by Get-RHSMImage) with Invoke-WebRequest -OutFile, authenticating with the current access token, and verifies the SHA-256 checksum.

    .PARAMETER InputObject
    Specifies one or more image objects from Get-RHSMImage, by pipeline or parameter.

    .PARAMETER DownloadHref
    Specifies the download link, as returned by Get-RHSMImage.

    .PARAMETER FileName
    Specifies the file name to save as. Defaults to the file name from Get-RHSMImage, or the last segment of the download link.

    .PARAMETER Checksum
    Specifies the expected SHA-256 checksum. If omitted, no verification is done.

    .PARAMETER Path
    Specifies the destination directory. Defaults to the current directory.

    .PARAMETER Force
    Overwrites an existing file.

    .EXAMPLE
    Get-RHSMImage -Version 9.4 -Filter '*dvd*' | Save-RHSMImage -Path C:\ISO

    .EXAMPLE
    $images = Get-RHSMImage -Version 9.4, 9.5 -Filter '*dvd*'
    Save-RHSMImage -InputObject $images -Path C:\ISO

    .OUTPUTS
    [System.IO.FileInfo].

    .LINK
    https://access.redhat.com/management/api/rhsm#/images/downloadImage
#>

function Save-RHSMImage {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([System.IO.FileInfo])]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Image', ValueFromPipeline = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [PSObject[]]$InputObject,

        [Parameter(Mandatory = $true, ParameterSetName = 'Href', ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$DownloadHref,

        [Parameter(Mandatory = $false, ParameterSetName = 'Href', ValueFromPipelineByPropertyName = $true)]
        [String]$FileName,

        [Parameter(Mandatory = $false, ParameterSetName = 'Href', ValueFromPipelineByPropertyName = $true)]
        [String]$Checksum,

        [Parameter(Mandatory = $false)]
        [String]$Path = (Get-Location).Path,

        [Parameter(Mandatory = $false)]
        [Switch]$Force
    )

    process {
        $images = if ($PSCmdlet.ParameterSetName -eq 'Image') {
            $InputObject
        }
        else {
            [PSCustomObject]@{ DownloadHref = $DownloadHref; FileName = $FileName; Checksum = $Checksum }
        }

        foreach ($image in $images) {
            if (-not $image.DownloadHref) {
                Write-Error -Message 'Input object has no DownloadHref; pass objects from Get-RHSMImage.'
                continue
            }

            $name = if ($image.FileName) { $image.FileName } else { [IO.Path]::GetFileName(([Uri]$image.DownloadHref).AbsolutePath) }
            $destination = Join-Path -Path $Path -ChildPath $name

            if ((Test-Path -Path $destination) -and -not $Force) {
                Write-Error -Message ("'{0}' already exists. Use -Force to overwrite." -f $destination)
                continue
            }

            if (-not $PSCmdlet.ShouldProcess($destination, 'Download image')) {
                continue
            }

            try {
                Write-Verbose -Message ('Downloading {0} to {1}' -f $image.DownloadHref, $destination)
                Invoke-WebRequest -Uri $image.DownloadHref -Headers (Get-RHSMAuthorizationHeader) -OutFile $destination -UseBasicParsing
            }
            catch {
                if (Test-Path -Path $destination) { Remove-Item -Path $destination -Force }
                Write-Error -Message ('Error encountered downloading the image: {0}' -f $_)
                continue
            }

            if ($image.Checksum -and -not (Test-RHSMFileHash -Path $destination -Checksum $image.Checksum)) {
                Remove-Item -Path $destination -Force
                Write-Error -Message ("SHA-256 checksum mismatch for '{0}'; the downloaded file was removed." -f $name)
                continue
            }

            Get-Item -Path $destination
        }
    }
}
