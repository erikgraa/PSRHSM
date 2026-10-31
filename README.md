# PSRedHat

PowerShell module for the Red Hat Subscription Management (RHSM) API. Current scope: authentication and RHEL image download. Subscriptions, systems and activation keys may follow.

## Install

```powershell
Import-Module .\src\PSRedHat.psd1
```

## Usage

Generate an offline token at <https://access.redhat.com/management/api>, then:

```powershell
$token = Read-Host -AsSecureString -Prompt 'Red Hat offline token'
Connect-RHSubscription -OfflineToken $token

# List images
Get-RHImage -Version 9.4 -Architecture x86_64 -Filter '*dvd*'

# Download (with progress and SHA-256 verification)
Get-RHImage -Version 9.4 -Filter '*dvd*' | Save-RHImage -Path C:\ISO

Disconnect-RHSubscription
```

### Downloading after `Get-RHImage`

`Save-RHImage` accepts `DownloadHref`, `FileName` and `Checksum` from the pipeline:

```powershell
# Download everything matching the filter
Get-RHImage -Version 9.4 -Filter '*dvd*' | Save-RHImage -Path C:\ISO

# Pick one image
Get-RHImage -Version 9.4 -Filter '*boot*' | Select-Object -First 1 | Save-RHImage -Path C:\ISO

# Several versions/architectures at once, then download them all
$images = Get-RHImage -Version 9.4, 9.5 -Architecture x86_64, aarch64 -Filter '*dvd*'
Save-RHImage -InputObject $images -Path C:\ISO

# Or specify the link directly
Save-RHImage -DownloadHref <href> -FileName rhel-9.4-x86_64-dvd.iso -Checksum <sha256> -Path C:\ISO
```

`-Path` defaults to the current directory, `-Force` overwrites an existing file, and `-WhatIf` previews. The SHA-256 is verified after download; a mismatching file is deleted.

The offline token is exchanged at `sso.redhat.com` (`grant_type=refresh_token`, `client_id=rhsm-api`) for a bearer access token, which is refreshed automatically.

## Notes

The RHSM OpenAPI docs require a Red Hat login, so the image list endpoint (`GET /images/rhel/{version}/{architecture}`) and response shapes are untested against a live account. `GET /images/{checksum}/download` is expected to return `body.href`. Please report discrepancies.

## Tests

```powershell
Invoke-Pester .\tests
```
