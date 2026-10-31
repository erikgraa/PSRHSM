BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\src\PSRHSM.psd1') -Force
}

Describe 'Get-RHSMImage' {
    It 'queries every version and architecture and filters by file name' {
        InModuleScope PSRHSM {
            Mock Invoke-RHSMApiRequest {
                [PSCustomObject]@{ body = @(
                    [PSCustomObject]@{ filename = 'x-dvd.iso'; checksum = 'AA'; downloadHref = 'https://h/a' }
                    [PSCustomObject]@{ filename = 'x-boot.iso'; checksum = 'BB'; downloadHref = 'https://h/b' }
                ) }
            }

            $result = @(Get-RHSMImage -Version 9.4, 9.5 -Architecture x86_64, aarch64 -Filter '*dvd*')

            $result.Count | Should -Be 4
            $result[0].PSObject.TypeNames | Should -Contain 'PSRHSM.Image'
            Should -Invoke Invoke-RHSMApiRequest -Times 4 -Exactly
        }
    }
}

Describe 'Get-RHSMSystem' {
    It 'pages through systems and filters by name' {
        InModuleScope PSRHSM {
            $script:calls = 0
            Mock Invoke-RHSMApiRequest {
                $script:calls++
                $count = if ($script:calls -eq 1) { 100 } else { 1 }
                [PSCustomObject]@{ body = 1..$count | ForEach-Object { [PSCustomObject]@{ name = ('web{0}-{1}' -f $script:calls, $_) } } }
            }

            @(Get-RHSMSystem).Count | Should -Be 101
            $script:calls | Should -Be 2
            @(Get-RHSMSystem -Name 'web2-*').Count | Should -Be 0
        }
    }
}

Describe 'Get-RHSMSubscription' {
    It 'returns subscriptions and filters by name' {
        InModuleScope PSRHSM {
            Mock Invoke-RHSMApiRequest {
                [PSCustomObject]@{ body = @(
                    [PSCustomObject]@{ subscriptionName = 'Red Hat Developer Subscription' }
                    [PSCustomObject]@{ subscriptionName = 'Other' }
                ) }
            }

            @(Get-RHSMSubscription).Count | Should -Be 2
            @(Get-RHSMSubscription -Name '*Developer*').Count | Should -Be 1
        }
    }
}

Describe 'Get-RHSMOrganization' {
    It 'unwraps the body when present' {
        InModuleScope PSRHSM {
            Mock Invoke-RHSMApiRequest { [PSCustomObject]@{ body = [PSCustomObject]@{ name = 'Acme' } } }
            (Get-RHSMOrganization).name | Should -Be 'Acme'
        }
    }

    It 'returns the response itself when there is no body' {
        InModuleScope PSRHSM {
            Mock Invoke-RHSMApiRequest { [PSCustomObject]@{ name = 'Acme' } }
            (Get-RHSMOrganization).name | Should -Be 'Acme'
        }
    }
}

Describe 'Save-RHSMImage' {
    BeforeEach {
        InModuleScope PSRHSM {
            Mock Get-RHSMAuthorizationHeader { @{ Authorization = 'Bearer t' } }
            Mock Invoke-WebRequest { Set-Content -Path $OutFile -Value 'hello' -NoNewline }
        }

        $hash = (Get-FileHash -InputStream ([IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes('hello')))).Hash
    }

    It 'saves multiple images from the pipeline and via -InputObject' {
        $images = 1..2 | ForEach-Object {
            [PSCustomObject]@{ DownloadHref = "https://h/$_"; FileName = "f$_.iso"; Checksum = $hash }
        }

        @($images | Save-RHSMImage -Path $TestDrive).Count | Should -Be 2
        @(Save-RHSMImage -InputObject $images -Path $TestDrive -Force).Count | Should -Be 2
    }

    It 'removes the file and errors on checksum mismatch' {
        $image = [PSCustomObject]@{ DownloadHref = 'https://h/x'; FileName = 'bad.iso'; Checksum = ('0' * 64) }

        { Save-RHSMImage -InputObject $image -Path $TestDrive -ErrorAction Stop } | Should -Throw '*checksum mismatch*'
        Test-Path (Join-Path $TestDrive 'bad.iso') | Should -BeFalse
    }
}
