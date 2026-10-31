BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\src\PSRedHat.psd1') -Force
}

Describe 'Get-RHImage' {
    It 'queries every version and architecture and filters by file name' {
        InModuleScope PSRedHat {
            Mock Invoke-RHApiRequest {
                [PSCustomObject]@{ body = @(
                    [PSCustomObject]@{ filename = 'x-dvd.iso'; checksum = 'AA'; downloadHref = 'https://h/a' }
                    [PSCustomObject]@{ filename = 'x-boot.iso'; checksum = 'BB'; downloadHref = 'https://h/b' }
                ) }
            }

            $result = @(Get-RHImage -Version 9.4, 9.5 -Architecture x86_64, aarch64 -Filter '*dvd*')

            $result.Count | Should -Be 4
            $result[0].PSObject.TypeNames | Should -Contain 'PSRedHat.Image'
            Should -Invoke Invoke-RHApiRequest -Times 4 -Exactly
        }
    }
}

Describe 'Get-RHSystem' {
    It 'pages through systems and filters by name' {
        InModuleScope PSRedHat {
            $script:calls = 0
            Mock Invoke-RHApiRequest {
                $script:calls++
                $count = if ($script:calls -eq 1) { 100 } else { 1 }
                [PSCustomObject]@{ body = 1..$count | ForEach-Object { [PSCustomObject]@{ name = ('web{0}-{1}' -f $script:calls, $_) } } }
            }

            @(Get-RHSystem).Count | Should -Be 101
            $script:calls | Should -Be 2
            @(Get-RHSystem -Name 'web2-*').Count | Should -Be 0
        }
    }
}

Describe 'Save-RHImage' {
    BeforeEach {
        InModuleScope PSRedHat {
            Mock Get-RHAuthorizationHeader { @{ Authorization = 'Bearer t' } }
            Mock Invoke-WebRequest { Set-Content -Path $OutFile -Value 'hello' -NoNewline }
        }

        $hash = (Get-FileHash -InputStream ([IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes('hello')))).Hash
    }

    It 'saves multiple images from the pipeline and via -InputObject' {
        $images = 1..2 | ForEach-Object {
            [PSCustomObject]@{ DownloadHref = "https://h/$_"; FileName = "f$_.iso"; Checksum = $hash }
        }

        @($images | Save-RHImage -Path $TestDrive).Count | Should -Be 2
        @(Save-RHImage -InputObject $images -Path $TestDrive -Force).Count | Should -Be 2
    }

    It 'removes the file and errors on checksum mismatch' {
        $image = [PSCustomObject]@{ DownloadHref = 'https://h/x'; FileName = 'bad.iso'; Checksum = ('0' * 64) }

        { Save-RHImage -InputObject $image -Path $TestDrive -ErrorAction Stop } | Should -Throw '*checksum mismatch*'
        Test-Path (Join-Path $TestDrive 'bad.iso') | Should -BeFalse
    }
}
