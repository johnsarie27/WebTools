function Update-PortalPSA {
    <# =========================================================================
    .SYNOPSIS
        Update Portal for ArcGIS PSA Account
    .DESCRIPTION
        Update Portal for ArcGIS PSA Account
    .PARAMETER BaseUri
        Portal base URI (a.k.a., context)
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
        [Parameter(Mandatory, HelpMessage = 'Portal base URI (a.k.a., context)')]
        [ValidatePattern('^https://[\w\.\-]+(/[\w]+)?$')]
        [System.Uri] $BaseUri,

        [Parameter(Mandatory, HelpMessage = 'PSCredential object containing current username and password')]
        [System.Management.Automation.PSCredential] $Credential,

        [Parameter(Mandatory, HelpMessage = 'PSCredential object containing new password')]
        [System.Management.Automation.PSCredential] $NewPassword
    )
    Begin {
        $portal = @{
            token  = '{0}/sharing/rest/generateToken'
            user   = '{0}/sharing/rest/community/users/{1}'
            update = '{0}/sharing/rest/community/users/{1}/update'
        }
    }
    Process {
        # GET TOKEN
        $token = Get-PortalToken -URL ($portal['token'] -f $BaseUri) -Credential $Credential

        $restParams = @{
            Uri    = $portal['user'] -f $BaseUri, $Credential.GetNetworkCredential().UserName
            Method = 'POST'
            Body   = @{ f = 'pjson'; token = $token.token }
        }
        $status = Invoke-RestMethod @restParams

        if ( $status.role -eq 'org_admin' ) {
            # CHANGE PASSWORD
            $restParams = @{
                Uri    = $portal['update'] -f $BaseUri, $Credential.GetNetworkCredential().UserName
                Method = 'POST'
                Body   = @{
                    f        = 'pjson'
                    token    = $token.token
                    password = $NewPassword.GetNetworkCredential().Password
                }
            }
            $rotate = Invoke-RestMethod @restParams

            if ( $rotate.success -eq $true ) {
                [pscustomobject] @{ Success = $true }
            }
            else {
                $details = $rotate.error.details | Out-String
                $errArray = @($rotate.error.code, $rotate.error.messageCode, $rotate.error.message, $details)
                Throw ('{0} -- {1} -- {2} -- {3}' -f $errArray)
            }
        }
        else {
            Throw ('Error retrieving user for app [{0}]' -f ($portal['user'] -f $BaseUri))
        }
    }
}