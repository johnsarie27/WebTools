function Update-ServerPSA {
    <# =========================================================================
    .SYNOPSIS
        Update ArcGIS Server PSA Account
    .DESCRIPTION
        Update ArcGIS Server PSA Account
    .PARAMETER BaseUri
        ArcGIS Server base URI (a.k.a., context)
    .PARAMETER Credential
        PSCredential object containing current username and password
    .PARAMETER NewPassowrd
        PSCredential object containing new password
    .INPUTS
        None.
    .OUTPUTS
        System.Object.
    .EXAMPLE
        PS C:\> <example usage>
        Explanation of what the example does
    .NOTES
        General notes
    ========================================================================= #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, HelpMessage = 'Server base URI (a.k.a., context)')]
        [ValidatePattern('^https://[\w\.\-]+(/[\w]+)?$')]
        [System.Uri] $BaseUri,

        [Parameter(Mandatory, HelpMessage = 'PSCredential object containing current username and password')]
        [System.Management.Automation.PSCredential] $Credential,

        [Parameter(Mandatory, HelpMessage = 'PSCredential object containing new password')]
        [System.Management.Automation.PSCredential] $NewPassword
    )
    Begin {
        $server = @{
            token  = '{0}/admin/generateToken'
            user   = '{0}/admin/security/psa'
            update = '{0}/admin/security/psa/update'
        }
    }
    Process {
        # GET TOKEN
        $token = Get-ServerToken -URL ($server['token'] -f $BaseUri) -Credential $Credential

        # CHECK USER STATUS
        $restParams = @{
            Uri     = $server['user'] -f $BaseUri
            Method  = 'POST'
            Headers = @{ Referer = 'referer-value' }
            Body    = @{ f = 'pjson'; token = $token.token }
        }
        $status = Invoke-RestMethod @restParams

        if ( $status.disabled -eq $false ) {
            # CHANGE PASSWORD
            $restParams = @{
                Uri     = $server['update'] -f $BaseUri
                Method  = 'POST'
                Headers = @{ Referer = 'referer-value' }
                Body    = @{
                    f        = 'pjson'
                    token    = $token.token
                    username = $Credential.GetNetworkCredential().UserName
                    password = $NewPassword.GetNetworkCredential().Password
                }
            }
            $rotate = Invoke-RestMethod @restParams

            if ( $rotate.status -eq 'success' ) { [pscustomobject] @{ Success = $true } }
            else { Throw ('Error updating user password for app [{0}]' -f ($server['user'] -f $BaseUri)) }
        }
        else {
            Throw ('Error retrieving user for app [{0}]' -f ($server['user'] -f $BaseUri))
        }
    }
}