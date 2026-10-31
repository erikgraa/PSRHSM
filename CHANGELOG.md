# Changelog

All notable changes to this project are documented here. Versions follow `0.YYMM.N`.

## [Unreleased]

### Added
- `Get-RHSMActivationKey` and `New-RHSMActivationKey` for the v2 activation keys API (`https://api.access.redhat.com/api/rhsm/v2`).
- `Connect-RHSM -BaseUriV2` to override the v2 base URI.

## [0.2610.2] - 2026-10-31

First release on the PowerShell Gallery.

### Added
- `Connect-RHSM` / `Disconnect-RHSM`: offline token to bearer token exchange with automatic refresh.
- `Get-RHSMImage` / `Save-RHSMImage`: list RHEL images (multiple versions and architectures) and download them with SHA-256 verification.
- `Get-RHSMSystem`, `Get-RHSMSubscription` and `Get-RHSMOrganization`.
- Pester tests, GitHub Actions CI and a tag-triggered PowerShell Gallery publish workflow.
