<#
    .SYNOPSIS
    Clears the stored Red Hat Subscription Management session.

    .DESCRIPTION
    Removes the offline token and access token held in module scope.

    .EXAMPLE
    Disconnect-RHSubscription
#>

function Disconnect-RHSubscription {
    [CmdletBinding()]
    param ()

    process {
        $script:RHSession = $null
    }
}
