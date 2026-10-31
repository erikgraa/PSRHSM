function Convert-SecureStringToPlaintext {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [SecureString]$SecureString
    )

    process {
        switch ($PSVersionTable.PSEdition) {
            'Core' {
                $SecureString | ConvertFrom-SecureString -AsPlainText
            }

            default {
                $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)

                try {
                    [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
                }
                finally {
                    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
                }
            }
        }
    }
}
