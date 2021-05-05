function Update-ServerPSA {
    <# =========================================================================
    .SYNOPSIS
        Update ArcGIS Server PSA Account
    .DESCRIPTION
        Update ArcGIS Server PSA Account
    .PARAMETER SecretId
        ID of Secrets Manager secret
    .PARAMETER BaseUri
        ArcGIS Server base URI (a.k.a., context)
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
        [Parameter(Mandatory, HelpMessage = 'ID of Secrets Manager secret')]
        [ValidatePattern('\w{2,3}/app/\w{3,5}/[portalAdmin|serverAdmin]')]
        [string] $SecretId,

        [Parameter(Mandatory, HelpMessage = 'Server base URI (a.k.a., context)')]
        [ValidatePattern('^https://[\w\.\-]+(/[\w]+)?$')]
        [System.Uri] $BaseUri
    )
    Begin {
        $server = @{
            token  = '{0}/admin/generateToken'
            user   = '{0}/admin/security/psa'
            update = '{0}/admin/security/psa/update'
        }
    }
    Process {
        $secret = (Get-SECSecretValue -SecretId $SecretId).SecretString | ConvertFrom-Json
        $secureString = $secret.password | ConvertTo-SecureString -AsPlainText -Force
        $entCreds = [System.Management.Automation.PSCredential]::new($secret.username, $secureString)

        $token = Get-ServerToken -URL ($server['token'] -f $BaseUri) -Credential $entCreds

        $restParams = @{
            Uri     = $server['user'] -f $BaseUri
            Method  = 'POST'
            Headers = @{ Referer = 'referer-value' }
            Body    = @{ f = 'pjson'; token = $token.token }
        }
        $status = Invoke-RestMethod @restParams

        if ( $status.disabled -eq $false ) {
            # CHANGE PASSWORD
            $newPW = Get-SECRandomPassword -ExcludePunctuation $true -PasswordLength 24

            $restParams = @{
                Uri     = $server['update'] -f $BaseUri
                Method  = 'POST'
                Headers = @{ Referer = 'referer-value' }
                Body    = @{ f = 'pjson'; token = $token.token; username = $secret.username; password = $newPW }
            }
            $rotate = Invoke-RestMethod @restParams

            if ( $rotate.status -eq 'success' ) {
                # UPDATE SECRET
                $secret.password = $newPW
                Write-SECSecretValue -SecretId $SecretId -SecretString ($secret | ConvertTo-Json -Compress)
            }
            else {
                Throw ('Error updating user password for app [{0}]' -f ($server['user'] -f $BaseUri))
            }
        }
        else {
            Throw ('Error retrieving user for app [{0}]' -f ($server['user'] -f $BaseUri))
        }
    }
}