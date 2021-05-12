function Get-ServerToken {
    <# =========================================================================
    .SYNOPSIS
        Generate token
    .DESCRIPTION
        Generate token for ArcGIS Server
    .PARAMETER URL
        Target ArcGIS Server URL
    .PARAMETER Credential
        PowerShell credential object containing username and password
    .PARAMETER Expiration
        Token expiration time in minutes
    .INPUTS
        None.
    .OUTPUTS
        System.Object.
    .EXAMPLE
        PS C:\> Get-ServerToken -URL https://mydomain.com/arcgis -Credential $creds
        Generate token for mydomain.com
    .NOTES
        -- SERVER ENDPONITS --
        https://myDomain.com/arcgis/admin/login
        https://myDomain.com/arcgis/admin/generateToken
    ========================================================================= #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, HelpMessage = 'Target Portal URL')]
        [ValidateNotNullOrEmpty()]
        [ValidateScript( { $_.AbsoluteUri -match 'https://[\w\/\.-]+admin\/generateToken' })]
        [System.Uri] $URL,

        [Parameter(Mandatory, HelpMessage = 'PS Credential object containing un and pw')]
        [ValidateNotNullOrEmpty()]
        [pscredential] $Credential,

        [Parameter(HelpMessage = 'Token expiration time in minutes')]
        [ValidateRange(1, 900)]
        [int] $Expiration = 60
    )

    Process {
        $restParams = @{
            Uri    = $URL.AbsoluteUri
            Method = "POST"
            Body   = @{
                username   = $Credential.UserName
                password   = $Credential.GetNetworkCredential().password
                client     = 'referer'
                referer    = 'referer'
                expiration = $Expiration #minutes
                f          = 'pjson'
            }
        }

        # WHEN USING THE VALUES ABOVE FOR CLIENT AND REFERER, YOU MUST ADD THE HEADER BELOW TO ANY SUBSEQUENT CALLS
        # Headers = @{ Referer = 'referer-value' }

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
            else { $msg = "Request failed with unknown error. Username and/or password may be incorrect." }

            Throw $msg
        }
        else {
            $response
        }
    }
}