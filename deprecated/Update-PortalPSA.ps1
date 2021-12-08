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

        [Parameter(Mandatory, HelpMessage = 'Portal base URI (a.k.a., context)')]
        [ValidatePattern('^https://[\w\.\-]+(/[\w]+)?$')]
        [System.Uri] $BaseUri,

        [Parameter(Mandatory, ParameterSetName = '__crd', HelpMessage = 'AWS Credential object for AWS account')]
        [Amazon.SecurityToken.Model.Credentials] $Credential,

        [Parameter(Mandatory, ParameterSetName = '__crds', HelpMessage = 'AWS Region')]
        [ValidateScript({ $_ -in (Get-AWSRegion).Region })]
        [string] $Region
    )
    Begin {
        $portal = @{
            token  = '{0}/sharing/rest/generateToken'
            user   = '{0}/sharing/rest/community/users/{1}'
            update = '{0}/sharing/rest/community/users/{1}/update'
        }
    }
    Process {
        try {
            if ($PSCmdlet.ParameterSetName -eq '__crd') {
                $cmdCreds = @{ Credential = $Credential; Region = $Region }
                $secret = (Get-SECSecretValue -SecretId $SecretId @cmdCreds).SecretString | ConvertFrom-Json
            }
            else {
                $secret = (Get-SECSecretValue -SecretId $SecretId).SecretString | ConvertFrom-Json
            }
            $secureString = $secret.password | ConvertTo-SecureString -AsPlainText -Force
            $entCreds = [System.Management.Automation.PSCredential]::new($secret.username, $secureString)

            $token = Get-PortalToken -Context ($portal['token'] -f $BaseUri) -Credential $entCreds

            $restParams = @{
                Uri    = $portal['user'] -f $BaseUri, $secret.username
                Method = 'POST'
                Body   = @{ f = 'pjson'; token = $token.token }
            }
            $status = Invoke-RestMethod @restParams

            if ( $status.role -eq 'org_admin' ) {
                # CHANGE PASSWORD
                $pwParams = @{ ExcludePunctuation = $true; PasswordLength = 24 }
                if ($PSCmdlet.ParameterSetName -eq '__crd') { $pwParams['Credential'] = $Credential; $pwParams['Region'] = $Region }
                $newPW = Get-SECRandomPassword @pwParams

                $restParams = @{
                    Uri    = $portal['update'] -f $BaseUri, $secret.username
                    Method = 'POST'
                    Body   = @{ f = 'pjson'; token = $token.token; password = $newPW }
                }
                $rotate = Invoke-RestMethod @restParams

                if ( $rotate.success -eq $true ) {
                    # UPDATE SECRET
                    $secret.password = $newPW
                    $updateParams = @{ SecretId = $SecretId; SecretString = ($secret | ConvertTo-Json -Compress) }
                    if ($PSCmdlet.ParameterSetName -eq '__crd') { $updateParams['Credential'] = $Credential; $updateParams['Region'] = $Region }
                    Write-SECSecretValue @updateParams
                }
                else {
                    Throw ('Error updating user password for app [{0}]' -f ($portal['user'] -f $BaseUri))
                }
            }
            else {
                Throw ('Error retrieving user for app [{0}]' -f ($portal['user'] -f $BaseUri))
            }
        }
        catch {
            Throw $_.Exception.Message
            # THIS NEEDS TO WRITE TO A LOG
        }
    }
}