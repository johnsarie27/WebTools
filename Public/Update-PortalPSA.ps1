function Update-PortalPSA {
    <# =========================================================================
    .SYNOPSIS
        Update Portal for ArcGIS PSA Account
    .DESCRIPTION
        Update Portal for ArcGIS PSA Account
    .PARAMETER SecretId
        ID of Secrets Manager secret
    .PARAMETER BaseUri
        Portal base URI (a.k.a., context)
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

        [Parameter(Mandatory, HelpMessage = 'Portal base URI (a.k.a., context)')]
        [ValidatePattern('^https://[\w\.\-]+(/[\w]+)?$')]
        [System.Uri] $BaseUri
    )
    Begin {
        $portal = @{
            token  = '{0}/sharing/rest/generateToken'
            user   = '{0}/sharing/rest/community/users/{1}'
            update = '{0}/sharing/rest/community/users/{1}/update'
        }
    }
    Process {
        $secret = (Get-SECSecretValue -SecretId $SecretId).SecretString | ConvertFrom-Json
        $secureString = $secret.password | ConvertTo-SecureString -AsPlainText -Force
        $entCreds = [System.Management.Automation.PSCredential]::new($secret.username, $secureString)

        $token = Get-PortalToken -URL ($portal['token'] -f $BaseUri) -Credential $entCreds

        $restParams = @{
            Uri    = $portal['user'] -f $BaseUri, $secret.username
            Method = 'POST'
            Body   = @{ f = 'pjson'; token = $token.token }
        }
        $status = Invoke-RestMethod @restParams

        if ( $status.role -eq 'org_admin' ) {
            # CHANGE PASSWORD
            $newPW = Get-SECRandomPassword -ExcludePunctuation $true -PasswordLength 24

            $restParams = @{
                Uri    = $portal['update'] -f $BaseUri, $secret.username
                Method = 'POST'
                Body   = @{ f = 'pjson'; token = $token.token; password = $newPW }
            }
            $rotate = Invoke-RestMethod @restParams

            if ( $rotate.success -eq $true ) {
                # UPDATE SECRET
                $secret.password = $newPW
                Write-SECSecretValue -SecretId $SecretId -SecretString ($secret | ConvertTo-Json -Compress)
            }
            else {
                Throw ('Error updating user password for app [{0}]' -f ($portal['user'] -f $BaseUri))
            }
        }
        else {
            Throw ('Error retrieving user for app [{0}]' -f ($portal['user'] -f $BaseUri))
        }
    }
}