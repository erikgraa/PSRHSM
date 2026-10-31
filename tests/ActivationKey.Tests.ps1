BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\src\PSRHSM.psd1') -Force
}

AfterAll {
    Remove-Module PSRHSM -ErrorAction SilentlyContinue
}

Describe 'Invoke-RHSMApiRequest (POST and API version)' {
    BeforeEach {
        InModuleScope PSRHSM {
            $script:RHSMSession = [PSCustomObject]@{
                BaseUri      = 'https://example.test/management/v1'
                OfflineToken = ConvertTo-SecureString 'offline' -AsPlainText -Force
                AccessToken  = ConvertTo-SecureString 'access' -AsPlainText -Force
                ExpiresAt    = (Get-Date).AddHours(1)
            }
            Mock Invoke-RestMethod { 'ok' }
        }
    }

    It 'swaps the API version in the base URI' {
        InModuleScope PSRHSM {
            Invoke-RHSMApiRequest -Path 'activation_keys' -ApiVersion v2 | Out-Null

            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $Uri -eq 'https://example.test/management/v2/activation_keys' -and $Method -eq 'Get'
            }
        }
    }

    It 'sends a JSON body with a POST' {
        InModuleScope PSRHSM {
            Invoke-RHSMApiRequest -Path 'activation_keys' -Method Post -Body @{ name = 'k' } | Out-Null

            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'Post' -and $ContentType -eq 'application/json' -and ($Body | ConvertFrom-Json).name -eq 'k'
            }
        }
    }

    It 'rejects an invalid API version' {
        InModuleScope PSRHSM {
            { Invoke-RHSMApiRequest -Path 'x' -ApiVersion 'latest' } | Should -Throw
        }
    }
}

Describe 'Get-RHSMActivationKey' {
    It 'queries the v2 endpoint and unwraps the body' {
        InModuleScope PSRHSM {
            Mock Invoke-RHSMApiRequest {
                [PSCustomObject]@{ body = @(
                    [PSCustomObject]@{ name = 'prod-rhel9' }
                    [PSCustomObject]@{ name = 'dev-rhel9' }
                ) }
            }

            $keys = @(Get-RHSMActivationKey)

            $keys.Count | Should -Be 2
            $keys[0].PSObject.TypeNames[0] | Should -Be 'PSRHSM.ActivationKey'
            Should -Invoke Invoke-RHSMApiRequest -Times 1 -Exactly -ParameterFilter { $Path -eq 'activation_keys' -and $ApiVersion -eq 'v2' }
        }
    }

    It 'filters by name' {
        InModuleScope PSRHSM {
            Mock Invoke-RHSMApiRequest {
                [PSCustomObject]@{ body = @(
                    [PSCustomObject]@{ name = 'prod-rhel9' }
                    [PSCustomObject]@{ name = 'dev-rhel9' }
                ) }
            }

            @(Get-RHSMActivationKey -Name 'prod-*').name | Should -Be 'prod-rhel9'
        }
    }

    It 'accepts a response without a body wrapper' {
        InModuleScope PSRHSM {
            Mock Invoke-RHSMApiRequest { @([PSCustomObject]@{ name = 'a' }, [PSCustomObject]@{ name = 'b' }) }

            @(Get-RHSMActivationKey).Count | Should -Be 2
        }
    }
}

Describe 'New-RHSMActivationKey' {
    BeforeEach {
        InModuleScope PSRHSM {
            Mock Invoke-RHSMApiRequest { [PSCustomObject]@{ body = [PSCustomObject]@{ name = 'prod-rhel9' } } }
        }
    }

    It 'posts only the specified properties using camelCase names' {
        InModuleScope PSRHSM {
            $result = New-RHSMActivationKey -Name 'prod-rhel9' -ReleaseVersion 9.4 -ServiceLevel Premium -Usage Production

            $result.name | Should -Be 'prod-rhel9'
            $result.PSObject.TypeNames[0] | Should -Be 'PSRHSM.ActivationKey'

            Should -Invoke Invoke-RHSMApiRequest -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'Post' -and $Path -eq 'activation_keys' -and $ApiVersion -eq 'v2' -and
                $Body.name -eq 'prod-rhel9' -and
                $Body.releaseVersion -eq '9.4' -and
                $Body.serviceLevel -eq 'Premium' -and
                $Body.usage -eq 'Production' -and
                -not $Body.ContainsKey('description') -and
                -not $Body.ContainsKey('role')
            }
        }
    }

    It 'sends all fields when all are specified' {
        InModuleScope PSRHSM {
            New-RHSMActivationKey -Name 'k' -Description 'd' -ReleaseVersion 9.4 -Role 'Red Hat Enterprise Linux Server' -ServiceLevel Premium -Usage Production | Out-Null

            Should -Invoke Invoke-RHSMApiRequest -Times 1 -Exactly -ParameterFilter {
                @('name', 'description', 'releaseVersion', 'role', 'serviceLevel', 'usage' | Where-Object { $Body.ContainsKey($_) }).Count -eq 6
            }
        }
    }

    It 'does not call the API with -WhatIf' {
        InModuleScope PSRHSM {
            New-RHSMActivationKey -Name 'k' -WhatIf | Should -BeNullOrEmpty

            Should -Invoke Invoke-RHSMApiRequest -Times 0 -Exactly
        }
    }

    It 'requires a name' {
        { New-RHSMActivationKey -Name '' } | Should -Throw
    }
}
