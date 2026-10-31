BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\src\PSRHSM.psd1') -Force

    function New-TestSession {
        param ([datetime]$ExpiresAt = (Get-Date).AddHours(1))

        [PSCustomObject]@{
            BaseUri      = 'https://example.test/v1'
            OfflineToken = ConvertTo-SecureString 'offline' -AsPlainText -Force
            AccessToken  = ConvertTo-SecureString 'access' -AsPlainText -Force
            ExpiresAt    = $ExpiresAt
        }
    }
}

AfterAll {
    Remove-Module PSRHSM -ErrorAction SilentlyContinue
}

Describe 'Module' {
    It 'exports exactly the functions listed in the manifest' {
        $manifest = Import-PowerShellDataFile (Join-Path $PSScriptRoot '..\src\PSRHSM.psd1')
        $exported = (Get-Command -Module PSRHSM).Name

        @($exported | Sort-Object) | Should -Be @($manifest.FunctionsToExport | Sort-Object)
    }

    It 'does not export private helpers' {
        Get-Command -Module PSRHSM -Name 'Invoke-RHSMApiRequest', 'Get-RHSMAccessToken', 'Get-RHSMAuthorizationHeader', 'Test-RHSMFileHash' -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'has comment-based help for every exported command' {
        foreach ($command in Get-Command -Module PSRHSM) {
            (Get-Help $command.Name).Synopsis | Should -Not -BeNullOrEmpty -Because $command.Name
        }
    }
}

Describe 'Get-RHSMAccessToken' {
    It 'posts the refresh_token grant and returns a SecureString token with an expiry' {
        InModuleScope PSRHSM {
            Mock Invoke-RestMethod { [PSCustomObject]@{ access_token = 'abc'; expires_in = 300 } }

            $token = Get-RHSMAccessToken -OfflineToken (ConvertTo-SecureString 'offline' -AsPlainText -Force)

            $token.AccessToken | Should -BeOfType [SecureString]
            ($token.AccessToken | Convert-SecureStringToPlaintext) | Should -Be 'abc'
            $token.ExpiresAt | Should -BeGreaterThan (Get-Date).AddSeconds(250)

            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'Post' -and
                $Uri -eq 'https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token' -and
                $Body.grant_type -eq 'refresh_token' -and
                $Body.client_id -eq 'rhsm-api' -and
                $Body.refresh_token -eq 'offline'
            }
        }
    }

    It 'throws a descriptive error when the exchange fails' {
        InModuleScope PSRHSM {
            Mock Invoke-RestMethod { throw 'invalid_grant' }

            { Get-RHSMAccessToken -OfflineToken (ConvertTo-SecureString 'bad' -AsPlainText -Force) } | Should -Throw '*exchanging the offline token*'
        }
    }
}

Describe 'Connect-RHSM / Disconnect-RHSM' {
    BeforeEach {
        InModuleScope PSRHSM {
            $script:RHSMSession = $null
            Mock Get-RHSMAccessToken {
                [PSCustomObject]@{ AccessToken = (ConvertTo-SecureString 'access' -AsPlainText -Force); ExpiresAt = (Get-Date).AddHours(1) }
            }
        }
    }

    It 'stores a session and returns only non-secret details' {
        $result = Connect-RHSM -OfflineToken (ConvertTo-SecureString 'offline' -AsPlainText -Force)

        $result.BaseUri | Should -Be 'https://api.access.redhat.com/management/v1'
        $result.PSObject.Properties.Name | Should -Not -Contain 'OfflineToken'
        $result.PSObject.Properties.Name | Should -Not -Contain 'AccessToken'

        InModuleScope PSRHSM { $script:RHSMSession | Should -Not -BeNullOrEmpty }
    }

    It 'honours a custom base URI' {
        (Connect-RHSM -OfflineToken (ConvertTo-SecureString 'offline' -AsPlainText -Force) -BaseUri 'https://example.test/v1').BaseUri | Should -Be 'https://example.test/v1'
    }

    It 'stores the default v2 base URI used for activation keys' {
        Connect-RHSM -OfflineToken (ConvertTo-SecureString 'offline' -AsPlainText -Force) | Out-Null

        InModuleScope PSRHSM { $script:RHSMSession.BaseUriV2 | Should -Be 'https://console.redhat.com/api/rhsm/v2' }
    }

    It 'clears the session on disconnect' {
        Connect-RHSM -OfflineToken (ConvertTo-SecureString 'offline' -AsPlainText -Force) | Out-Null
        Disconnect-RHSM

        InModuleScope PSRHSM { $script:RHSMSession | Should -BeNullOrEmpty }
    }
}

Describe 'Get-RHSMAuthorizationHeader' {
    It 'throws when not connected' {
        InModuleScope PSRHSM {
            $script:RHSMSession = $null
            { Get-RHSMAuthorizationHeader } | Should -Throw '*Not connected*'
        }
    }

    It 'returns a bearer header without refreshing a valid token' {
        InModuleScope PSRHSM {
            $script:RHSMSession = [PSCustomObject]@{
                BaseUri      = 'https://example.test/v1'
                OfflineToken = ConvertTo-SecureString 'offline' -AsPlainText -Force
                AccessToken  = ConvertTo-SecureString 'access' -AsPlainText -Force
                ExpiresAt    = (Get-Date).AddHours(1)
            }
            Mock Get-RHSMAccessToken { }

            (Get-RHSMAuthorizationHeader).Authorization | Should -Be 'Bearer access'
            Should -Invoke Get-RHSMAccessToken -Times 0 -Exactly
        }
    }

    It 'refreshes a token that is about to expire' {
        InModuleScope PSRHSM {
            $script:RHSMSession = [PSCustomObject]@{
                BaseUri      = 'https://example.test/v1'
                OfflineToken = ConvertTo-SecureString 'offline' -AsPlainText -Force
                AccessToken  = ConvertTo-SecureString 'old' -AsPlainText -Force
                ExpiresAt    = (Get-Date).AddSeconds(10)
            }
            Mock Get-RHSMAccessToken {
                [PSCustomObject]@{ AccessToken = (ConvertTo-SecureString 'fresh' -AsPlainText -Force); ExpiresAt = (Get-Date).AddHours(1) }
            }

            (Get-RHSMAuthorizationHeader).Authorization | Should -Be 'Bearer fresh'
            Should -Invoke Get-RHSMAccessToken -Times 1 -Exactly
        }
    }
}

Describe 'Invoke-RHSMApiRequest' {
    BeforeEach {
        InModuleScope PSRHSM {
            $script:RHSMSession = [PSCustomObject]@{
                BaseUri      = 'https://example.test/v1/'
                OfflineToken = ConvertTo-SecureString 'offline' -AsPlainText -Force
                AccessToken  = ConvertTo-SecureString 'access' -AsPlainText -Force
                ExpiresAt    = (Get-Date).AddHours(1)
            }
        }
    }

    It 'sends Accept and Authorization headers and escapes query values' {
        InModuleScope PSRHSM {
            Mock Invoke-RestMethod { 'ok' }

            Invoke-RHSMApiRequest -Path 'systems' -Query @{ name = 'a b&c' } | Should -Be 'ok'

            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $Uri -eq 'https://example.test/v1/systems?name=a%20b%26c' -and
                $Headers.Authorization -eq 'Bearer access' -and
                $Headers.Accept -eq 'application/json'
            }
        }
    }

    It 'wraps API failures in a descriptive error' {
        InModuleScope PSRHSM {
            Mock Invoke-RestMethod { throw '403 Forbidden' }

            { Invoke-RHSMApiRequest -Path 'systems' } | Should -Throw '*Red Hat Subscription Management API*'
        }
    }
}

Describe 'Get-RHSMImage (mocked API)' {
    It 'follows pagination until a short page is returned' {
        InModuleScope PSRHSM {
            $script:page = 0
            Mock Invoke-RHSMApiRequest {
                $script:page++
                $count = if ($script:page -eq 1) { 100 } else { 3 }
                [PSCustomObject]@{ body = 1..$count | ForEach-Object { [PSCustomObject]@{ filename = "f$($script:page)-$_.iso"; checksum = 'AA'; downloadHref = 'https://h/x' } } }
            }

            @(Get-RHSMImage -Version 9.4).Count | Should -Be 103

            Should -Invoke Invoke-RHSMApiRequest -Times 1 -Exactly -ParameterFilter { $Path -eq 'images/rhel/9.4/x86_64' -and $Query.offset -eq 0 }
            Should -Invoke Invoke-RHSMApiRequest -Times 1 -Exactly -ParameterFilter { $Query.offset -eq 100 }
        }
    }

    It 'returns typed objects with the properties Save-RHSMImage binds' {
        InModuleScope PSRHSM {
            Mock Invoke-RHSMApiRequest {
                [PSCustomObject]@{ body = @([PSCustomObject]@{ filename = 'a.iso'; checksum = 'AA'; downloadHref = 'https://h/a' }) }
            }

            $image = Get-RHSMImage -Version 9.4 -Architecture aarch64

            $image.PSObject.TypeNames[0] | Should -Be 'PSRHSM.Image'
            $image.FileName | Should -Be 'a.iso'
            $image.Checksum | Should -Be 'AA'
            $image.DownloadHref | Should -Be 'https://h/a'
            $image.Version | Should -Be '9.4'
            $image.Architecture | Should -Be 'aarch64'
        }
    }

    It 'emits nothing when no file matches the filter' {
        InModuleScope PSRHSM {
            Mock Invoke-RHSMApiRequest {
                [PSCustomObject]@{ body = @([PSCustomObject]@{ filename = 'a.iso'; checksum = 'AA'; downloadHref = 'https://h/a' }) }
            }

            Get-RHSMImage -Version 9.4 -Filter '*qcow2' | Should -BeNullOrEmpty
        }
    }
}

Describe 'Save-RHSMImage (mocked download)' {
    BeforeEach {
        InModuleScope PSRHSM {
            Mock Get-RHSMAuthorizationHeader { @{ Authorization = 'Bearer t' } }
            Mock Invoke-WebRequest { Set-Content -Path $OutFile -Value 'hello' -NoNewline }
        }

        $hash = (Get-FileHash -InputStream ([IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes('hello')))).Hash
    }

    It 'sends the bearer header to the download link' {
        $image = [PSCustomObject]@{ DownloadHref = 'https://h/dl'; FileName = 'a.iso'; Checksum = $hash }

        Save-RHSMImage -InputObject $image -Path $TestDrive | Out-Null

        InModuleScope PSRHSM {
            Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
                $Uri -eq 'https://h/dl' -and $Headers.Authorization -eq 'Bearer t'
            }
        }
    }

    It 'derives the file name from the link when none is given' {
        $file = Save-RHSMImage -DownloadHref 'https://h/path/rhel.iso' -Path $TestDrive

        $file.Name | Should -Be 'rhel.iso'
    }

    It 'skips verification when no checksum is supplied' {
        { Save-RHSMImage -DownloadHref 'https://h/nochecksum.iso' -Path $TestDrive -ErrorAction Stop } | Should -Not -Throw
    }

    It 'refuses to overwrite an existing file without -Force' {
        $image = [PSCustomObject]@{ DownloadHref = 'https://h/dl'; FileName = 'exists.iso'; Checksum = $hash }
        Set-Content -Path (Join-Path $TestDrive 'exists.iso') -Value 'old' -NoNewline

        { Save-RHSMImage -InputObject $image -Path $TestDrive -ErrorAction Stop } | Should -Throw '*already exists*'
        Get-Content (Join-Path $TestDrive 'exists.iso') -Raw | Should -Be 'old'

        Save-RHSMImage -InputObject $image -Path $TestDrive -Force | Out-Null
        Get-Content (Join-Path $TestDrive 'exists.iso') -Raw | Should -Be 'hello'
    }

    It 'does not download with -WhatIf' {
        $image = [PSCustomObject]@{ DownloadHref = 'https://h/dl'; FileName = 'whatif.iso'; Checksum = $hash }

        Save-RHSMImage -InputObject $image -Path $TestDrive -WhatIf | Should -BeNullOrEmpty

        Test-Path (Join-Path $TestDrive 'whatif.iso') | Should -BeFalse
        InModuleScope PSRHSM { Should -Invoke Invoke-WebRequest -Times 0 -Exactly }
    }

    It 'removes a partial file and reports an error when the download fails' {
        InModuleScope PSRHSM {
            Mock Invoke-WebRequest {
                Set-Content -Path $OutFile -Value 'partial' -NoNewline
                throw 'connection reset'
            }
        }
        $image = [PSCustomObject]@{ DownloadHref = 'https://h/dl'; FileName = 'partial.iso'; Checksum = $hash }

        { Save-RHSMImage -InputObject $image -Path $TestDrive -ErrorAction Stop } | Should -Throw '*downloading the image*'
        Test-Path (Join-Path $TestDrive 'partial.iso') | Should -BeFalse
    }

    It 'continues with the remaining images after one fails' {
        $images = @(
            [PSCustomObject]@{ DownloadHref = $null; FileName = 'bad.iso'; Checksum = $hash }
            [PSCustomObject]@{ DownloadHref = 'https://h/ok'; FileName = 'ok.iso'; Checksum = $hash }
        )

        $result = Save-RHSMImage -InputObject $images -Path $TestDrive -ErrorAction SilentlyContinue

        @($result).Count | Should -Be 1
        $result.Name | Should -Be 'ok.iso'
    }
}
