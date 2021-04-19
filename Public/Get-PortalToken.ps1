function Get-PortalToken {
    <# =========================================================================
    .SYNOPSIS
        Generate token
    .DESCRIPTION
        Generate token for ArcGIS Portal
    .PARAMETER URL
        Target ArcGIS Portal URL
    .PARAMETER Credential
        PowerShell credential object containing username and password
    .PARAMETER Expiration
        Token expiration time in minutes
    .INPUTS
        None.
    .OUTPUTS
        System.String.
    .EXAMPLE
        PS C:\> Get-PortalToken -Domain mydomain.com -Credential $creds
        Generate token for mydomain.com
    .NOTES
        This works just fine inside the boundary but doesn't work outside.
        Need to review WAF deny logs to determine why.

        -- SERVER ENDPONITS --
        https://myDomain.com/arcgis/admin/login
        https://myDomain.com/arcgis/admin/generateToken
    ========================================================================= #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, HelpMessage = 'Target Portal URL')]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_.AbsoluteUri -match 'https://[\w\/\.-]+[rest|admin]\/generateToken' })]
        [System.Uri] $URL,

        [Parameter(Mandatory, HelpMessage = 'PS Credential object containing un and pw')]
        [ValidateNotNullOrEmpty()]
        [pscredential] $Credential,

        [Parameter(HelpMessage = 'Token expiration time in minutes')]
        [ValidateRange(1,900)]
        [int] $Expiration = 60
    )

    Process {
        $restParams = @{
            Uri    = $URL.AbsoluteUri #'https://myDomain.com/arcgis/sharing/rest/generateToken'
            Method = "POST"
            Body   = @{
                username   = $Credential.UserName
                password   = $Credential.GetNetworkCredential().password
                client     = 'requestip' #'referer'
                #referer    = '{0}://{1}' -f $URL.Scheme, $URL.Authority
                expiration = $Expiration #minutes
                f          = 'pjson'
            }
        }

        try { $response = Invoke-RestMethod @restParams }
        catch { $response = $_.Exception.Response }

        # CHECK FOR ERRORS AND RETURN
        if ( -not $response.token ) {
            # CHECK FOR VALID JSON WITH ERROR DETAILS
            if ( $response.error ) {
                if ( $response.error.details.GetType().FullName -eq 'System.Object[]' ) { $details = $response.error.details -join "; " }
                else { $details = $response.error.details }

                $tokens = @($response.error.code, $response.error.message, $details)
                $msg = "Request failed with response:`n`tcode: {0}`n`tmessage: {1}`n`tdetails: {2}" -f $tokens
            }
            elseif ( $response.ReasonPhrase ) { $msg = $response.ReasonPhrase }
            else { $msg = "Request failed with unknown error" }

            Throw $msg
        }
        else {
            $response
        }
    }
}