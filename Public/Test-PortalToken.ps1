function Test-PortalToken {
    <# =========================================================================
    .SYNOPSIS
        Test Portal token for validity
    .DESCRIPTION
        Test Portal token for validity
    .PARAMETER Context
        Target Portal context
    .PARAMETER Token
        Portal token
    .INPUTS
        None.
    .OUTPUTS
        System.Object.
    .EXAMPLE
        PS C:\> Test-PortalToken -Context 'https://arcgis.com/arcgis' -Token $token
        Tests to see if the token $token is valid
    .NOTES
        General notes
    ========================================================================= #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, HelpMessage = 'Target Portal context')]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_.AbsoluteUri -match '^https://[\w\/\.-]+[^/]$' })]
        [System.Uri] $Context,

        [Parameter(Mandatory, HelpMessage = 'Portal token')]
        [ValidatePattern('[\w=-]+')]
        [String] $Token
    )
    Process {
        $restParams = @{
            Uri    = '{0}/sharing/rest/portals/self' -f $Context
            Method = 'POST'
            Body   = @{
                f     = 'pjson'
                token = $Token
            }
        }
        $self = Invoke-RestMethod @restParams

        if ( $self.error ) {
            Write-Warning -Message 'Invalid token'
            $self
        }
        elseif ( $self.user.username -eq $secret.username ) {
            Write-Output -InputObject ('Token has been validated for user: {0}' -f $self.user.username)
        }
        elseif ( $self.appInfo ) {
            Write-Output -InputObject ('Token belongs to App ID: []' -f $self.appInfo.appId)
        }
    }
}