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
    .PARAMETER Credential
        AWS Credential object for AWS account
    .PARAMETER Region
        AWS Region
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
        [System.Uri] $BaseUri,

        [Parameter(Mandatory, HelpMessage = 'AWS Credential object for AWS account')]
        [Amazon.SecurityToken.Model.Credentials] $Credential,

        [Parameter(Mandatory, HelpMessage = 'AWS Region')]
        [ValidateScript( { $_ -in (Get-AWSRegion).Region })]
        [string] $Region
    )
    Begin {
        $cmdCreds = @{ Credential = $Credential; Region = $Region }

        $server = @{
            token  = '{0}/admin/generateToken'
            user   = '{0}/admin/security/psa'
            update = '{0}/admin/security/psa/update'
        }
    }
    Process {
        try {
            $secret = (Get-SECSecretValue -SecretId $SecretId @cmdCreds).SecretString | ConvertFrom-Json
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
                $newPW = Get-SECRandomPassword -ExcludePunctuation $true -PasswordLength 24 @cmdCreds

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
                    Write-SECSecretValue -SecretId $SecretId -SecretString ($secret | ConvertTo-Json -Compress) @cmdCreds
                }
                else {
                    Throw ('Error updating user password for app [{0}]' -f ($server['user'] -f $BaseUri))
                }
            }
            else {
                Throw ('Error retrieving user for app [{0}]' -f ($server['user'] -f $BaseUri))
            }
        }
        catch {
            Throw $_.Exception.Message
            # THIS NEEDS TO WRITE TO A LOG
        }
    }
}