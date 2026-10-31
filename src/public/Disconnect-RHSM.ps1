<#
    .SYNOPSIS
    Clears the stored Red Hat Subscription Management session.

    .DESCRIPTION
    Removes the offline token and access token held in module scope.

    .EXAMPLE
    Disconnect-RHSM
#>

function Disconnect-RHSM {
    [CmdletBinding()]
    param ()

    process {
        $script:RHSMSession = $null
    }
}
