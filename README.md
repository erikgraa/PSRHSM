<p align="center"><img src="assets/icon.png" alt="PSRHSM icon" width="160"></p>

# 🐧 PSRHSM

PowerShell module for the **Red Hat Subscription Management (RHSM) API**: authenticate, find and download RHEL images, and inspect your systems, subscriptions and organization.

> ⚠️ Unofficial, community-driven module. Not affiliated with, sponsored by or endorsed by Red Hat, Inc. or IBM. "Red Hat" and "RHEL" are trademarks of Red Hat, Inc.

> 🧪 The RHSM OpenAPI docs require a Red Hat login, so response shapes were written from the documented API. Please report discrepancies.

## ✨ Features

- 🔐 Offline token → bearer token, refreshed automatically
- 💿 List and download RHEL images, with SHA-256 verification
- 🖥️ List registered systems
- 🧾 List subscriptions
- 🏢 Get organization details
- 📦 Works on Windows PowerShell 5.1 and PowerShell 7+

## 📋 Requirements

- A Red Hat account (the free Developer subscription works for RHEL downloads)
- An **offline token**, generated at <https://access.redhat.com/management/api>. Treat it like a password; it expires after 30 days of inactivity.

## 🚀 Getting started

```powershell
Import-Module .\src\PSRHSM.psd1

$token = Read-Host -AsSecureString -Prompt 'Red Hat offline token'
Connect-RHSM -OfflineToken $token
```

The token is exchanged at `sso.redhat.com` (`grant_type=refresh_token`, `client_id=rhsm-api`) for a short-lived access token that is kept in module scope and refreshed automatically.

## 🧰 Cmdlets

| Cmdlet | Endpoint | Description |
|---|---|---|
| `Connect-RHSM` | SSO token | 🔐 Sign in with an offline token |
| `Disconnect-RHSM` | n/a | 👋 Clear the stored session |
| `Get-RHSMImage` | `GET /images/rhel/{version}/{arch}` | 💿 List RHEL images |
| `Save-RHSMImage` | image `downloadHref` | ⬇️ Download images and verify SHA-256 |
| `Get-RHSMSystem` | `GET /systems` | 🖥️ List registered systems |
| `Get-RHSMSubscription` | `GET /subscriptions` | 🧾 List subscriptions |
| `Get-RHSMOrganization` | `GET /organization` | 🏢 Get the organization |

Use `Get-Help <cmdlet> -Full` for details.

## 💿 Images

```powershell
# List images (several versions/architectures at once)
Get-RHSMImage -Version 9.4, 9.5 -Architecture x86_64, aarch64 -Filter '*dvd*'

# Download everything matching the filter
Get-RHSMImage -Version 9.4 -Filter '*dvd*' | Save-RHSMImage -Path C:\ISO

# Or pass images explicitly
$images = Get-RHSMImage -Version 9.4 -Filter '*boot*'
Save-RHSMImage -InputObject $images -Path C:\ISO

# Or specify the link directly
Save-RHSMImage -DownloadHref <href> -FileName rhel-9.4-x86_64-dvd.iso -Checksum <sha256> -Path C:\ISO
```

Image variants are told apart by file name: `dvd` (full installer), `boot` (network installer), `qcow2` (KVM guest image) and so on. `-Filter` is a wildcard on the file name.

`Save-RHSMImage` supports `-Force` (overwrite) and `-WhatIf` (preview). The SHA-256 is checked after download, and a mismatching file is deleted.

## 🖥️ Systems, 🧾 subscriptions and 🏢 organization

```powershell
Get-RHSMSystem -Name 'web*'
Get-RHSMSubscription -Name '*Developer*'
Get-RHSMOrganization
```

## 🧪 Tests

```powershell
Invoke-Pester .\tests
```

## 🤝 Contributing

Issues and pull requests are welcome. Run the Pester tests before submitting.

## 📄 License

MIT, see [LICENSE](LICENSE). The icon is original artwork.
