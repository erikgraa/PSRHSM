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

The offline token is exchanged at `sso.redhat.com` (`grant_type=refresh_token`, `client_id=rhsm-api`) for a bearer access token, which is refreshed automatically.

## Notes

The RHSM OpenAPI docs require a Red Hat login, so the image list endpoint (`GET /images/rhel/{version}/{architecture}`) and response shapes are untested against a live account. `GET /images/{checksum}/download` is expected to return `body.href`. Please report discrepancies.

## Tests

```powershell
Invoke-Pester .\tests
```
