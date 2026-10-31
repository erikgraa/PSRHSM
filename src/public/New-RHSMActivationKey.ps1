<#
    .SYNOPSIS
    Creates an activation key.

    .DESCRIPTION
    Creates an activation key with POST /api/rhsm/v2/activation_keys on the RHSM API. Only the parameters you specify are sent.

    .PARAMETER Name
    Specifies the activation key name.

    .PARAMETER Description
    Specifies a description.

    .PARAMETER ReleaseVersion
    Specifies the release version, e.g. 9.4.

    .PARAMETER Role
    Specifies the system role, e.g. 'Red Hat Enterprise Linux Server'.

    .PARAMETER ServiceLevel
    Specifies the service level (SLA), e.g. 'Premium'.

    .PARAMETER Usage
    Specifies the usage, e.g. 'Production'.

    .NOTES
    The accepted values for Role, ServiceLevel and Usage are defined by Red Hat and are not validated by this module.
    The response shape follows the RHSM OpenAPI specification, which requires a Red Hat login to view; if the response has a 'body' property it is returned, otherwise the response itself.

    .EXAMPLE
    Connect-RHSM -OfflineToken $token
    New-RHSMActivationKey -Name 'prod-rhel9' -ReleaseVersion 9.4 -ServiceLevel Premium -Usage Production

    .OUTPUTS
    [PSCustomObject].

    .LINK
    https://access.redhat.com/management/api/rhsm#/activation_keys
#>

function New-RHSMActivationKey {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [Parameter(Mandatory = $false)]
        [String]$Description,

        [Parameter(Mandatory = $false)]
        [String]$ReleaseVersion,

        [Parameter(Mandatory = $false)]
        [String]$Role,

        [Parameter(Mandatory = $false)]
        [String]$ServiceLevel,

        [Parameter(Mandatory = $false)]
        [String]$Usage
    )

    process {
        $body = @{ name = $Name }

        foreach ($property in 'Description', 'ReleaseVersion', 'Role', 'ServiceLevel', 'Usage') {
            if ($PSBoundParameters.ContainsKey($property)) {
                # API field names are camelCase
                $body[$property.Substring(0, 1).ToLower() + $property.Substring(1)] = $PSBoundParameters[$property]
            }
        }

        if (-not $PSCmdlet.ShouldProcess($Name, 'Create activation key')) {
            return
        }

        $response = Invoke-RHSMApiRequest -Path 'activation_keys' -Method Post -Body $body -ApiVersion 'v2'
        $item = if ($response -isnot [Array] -and $response.PSObject.Properties['body']) { $response.body } else { $response }

        foreach ($key in @($item)) {
            if ($null -eq $key) { continue }
            $key.PSObject.TypeNames.Insert(0, 'PSRHSM.ActivationKey')
            $key
        }
    }
}
