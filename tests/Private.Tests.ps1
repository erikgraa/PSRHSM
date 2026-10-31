BeforeAll {
    Get-ChildItem -Path (Join-Path $PSScriptRoot '..\src\private') -Filter *.ps1 | ForEach-Object { . $_.FullName }
}

Describe 'Convert-SecureStringToPlaintext' {
    It 'converts a SecureString back to plaintext' {
        $secure = ConvertTo-SecureString -String 'p@ssw0rd' -AsPlainText -Force
        Convert-SecureStringToPlaintext -SecureString $secure | Should -Be 'p@ssw0rd'
    }
}

Describe 'Test-RHSMFileHash' {
    BeforeAll {
        $file = Join-Path $TestDrive 'a.bin'
        Set-Content -Path $file -Value 'hello' -NoNewline
        $hash = (Get-FileHash -Path $file -Algorithm SHA256).Hash
    }

    It 'returns true for a matching checksum' {
        Test-RHSMFileHash -Path $file -Checksum $hash | Should -BeTrue
    }

    It 'is case-insensitive' {
        Test-RHSMFileHash -Path $file -Checksum $hash.ToLower() | Should -BeTrue
    }

    It 'returns false for a mismatching checksum' {
        Test-RHSMFileHash -Path $file -Checksum ('0' * 64) | Should -BeFalse
    }
}

Describe 'Invoke-RHSMApiRequest' {
    BeforeEach {
        $script:RHSMSession = $null
    }

    It 'throws when not connected' {
        { Invoke-RHSMApiRequest -Path 'images' } | Should -Throw '*Not connected*'
    }

    It 'refreshes an expired token and builds the query string' {
        $script:RHSMSession = [PSCustomObject]@{
            BaseUri      = 'https://example.test/v1'
            OfflineToken = ConvertTo-SecureString 'off' -AsPlainText -Force
            AccessToken  = ConvertTo-SecureString 'old' -AsPlainText -Force
            ExpiresAt    = (Get-Date).AddMinutes(-1)
        }

        Mock Get-RHSMAccessToken { [PSCustomObject]@{ AccessToken = (ConvertTo-SecureString 'new' -AsPlainText -Force); ExpiresAt = (Get-Date).AddHours(1) } }
        Mock Invoke-RestMethod { 'ok' }

        Invoke-RHSMApiRequest -Path '/images' -Query @{ limit = 10 } | Should -Be 'ok'

        Should -Invoke Get-RHSMAccessToken -Times 1
        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
            $Uri -eq 'https://example.test/v1/images?limit=10' -and $Headers.Authorization -eq 'Bearer new'
        }
    }
}
