function Get-SecurityPolicy {
    <# =========================================================================
    .SYNOPSIS
        Get security policy
    .DESCRIPTION
        Get Portal user security policy
    .PARAMETER Context
        Target Portal context
    .PARAMETER Token
        Portal token
    .INPUTS
        None.
    .OUTPUTS
        System.Object.
    .EXAMPLE
        PS C:\> Get-SecurityPolicy -Context 'https://arcgis.com/arcgis' -Token $token
        Get security policy for Portal user
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
        [String] $Token,

        [Parameter(HelpMessage = 'Portal application ID')]
        [ValidateNotNullOrEmpty()]
        [String] $Id = '0123456789ABCDEF'
    )
    Process {
        $restParams = @{
            Uri    = '{0}/sharing/rest/portals/{1}/securityPolicy' -f $Context, $Id
            Method = 'POST'
            Body   = @{
                f     = 'pjson'
                token = $Token
            }
        }

        Invoke-RestMethod @restParams
    }
}