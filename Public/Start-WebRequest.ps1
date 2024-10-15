function Start-WebRequest {
    <#
    .SYNOPSIS
        Initiate web request using provided parameters
    .DESCRIPTION
        Validate input as Json with correct schema and intitiate pull-push process.
        There is not error catching in the Invoke-WebRequest as this should be done
        outside of this specific function.
    .PARAMETER Payload
        Json payload containing required information for web request
    .PARAMETER Credential
        Credentials for URI
    .PARAMETER Body
        Body of web request if not specified in the Payload
    .INPUTS
        System.String.
    .OUTPUTS
        Microsoft.PowerShell.Commands.BasicHtmlWebResponseObject.
    .EXAMPLE
        PS C:\> Start-WebRequest -Payload $p
        Uses the parameters in the payload parameter to call 'Invoke-WebRequest'
    .NOTES
        General notes
        This function requires the system running it has credentials to pull and
        decrypt SSM Parameters from Parameter Store.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, HelpMessage = 'Json payload for pull-push process')]
        [ValidateScript({ Test-Json -Json $_ -Schema $ETL_Schema })]
        [System.String] $Payload,

        [Parameter(HelpMessage = 'Credentials for URI')]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential] $Credential,

        [Parameter(HelpMessage = 'Body')]
        [System.Object] $Body
    )
    Process {
        $data = $Payload | ConvertFrom-Json

        $params = @{ Uri = $data.URL }

        if ( $PSBoundParameters.ContainsKey('Credential') ) {

            # DETERMINE AUTHENTICATION
            switch ($data.Auth.Type) {
                'ServerToken' {
                    # THE DEPENDENCY VALUE IN THE JSON PAYLOAD MUST BE SET TO THE ARCGIS SERVER CONTEXT
                    $token = Get-ServerToken -Credential $Credential -Context $data.Dependency
                    $params['Uri'] = $data.URL -f $token.token
                }
                'Token' {
                    # THE DEPENDENCY VALUE IN THE JSON PAYLOAD MUST BE SET TO THE PORTAL FOR ARCGIS CONTEXT
                    $token = Get-PortalToken -Credential $Credential -Context $data.Dependency
                    $params['Uri'] = $data.URL -f $token.token
                }
                'ApiKey' {
                    $params['Uri'] = $data.URL -f $Credential.GetNetworkCredential().Password
                }
                'Basic' {
                    $params.Add('Authentication', 'Basic')
                    $params.Add('Credential', $Credential)
                }
                default {
                    # THIS WORKS FOR DIGEST AUTH
                    $params.Add('Credential', $Credential)
                }
            }

            Write-Verbose -Message 'Credential object added'
        }
        if ( $data.Method ) {
            $params.Add('Method', $data.Method)

            Write-Verbose -Message ('Method set to {0}' -f $params.Method)
        }
        if ( $data.Headers ) {
            $headers = @{ }
            $data.Headers | Foreach-Object -Process { $headers.Add($_.Key, $_.Value) }
            $params.Add('Headers', $headers)

            Write-Verbose -Message 'Headers added: '
            Write-Verbose -Message ($params['Headers'] | ConvertTo-Json -Compress)
        }
        if ( $data.Body ) {
            # ADD PULLED CONTENT AS BODY
            if ( $data.Body -eq 'Source content' ) {
                if ( $headers -and $headers['Encapsulate'] -eq 'JSON' ) {
                    # SKIP JSON VALIDITY CHECKS AND ALWAYS WRAP INTO JSON OBJECT FOR CONSISTENCY
                    $params.Add('Body', ('{"data":' + $Body + '}'))

                    Write-Verbose -Message 'Body JSON encapsulated'
                    <# Write-Host -Object 'Attempting to validate Json'
                    try {
                        if ( Test-Json -Json $Body -ErrorAction SilentlyContinue ) { $params.Add('Body', $Body) }
                    }
                    catch {
                        $params.Add('Body', ('{"data":' + $Body + '}'))
                    } #>
                }
                else {
                    $params.Add('Body', $Body)
                }
            }
            # ADD BODY VALUE FROM PAYLOAD AS STRING
            elseif ( $data.Body.GetType().FullName -eq 'System.String' ) {
                $params.Add('Body', $data.Body)
                Write-Verbose -Message 'Body added as string'
            }
            # ADD BODY VALUES FROM PAYLOAD AS JSON
            else {
                $params.Add('Body', (ConvertTo-Json -InputObject $data.Body -Compress))
                Write-Verbose -Message 'Body added as JSON'
            }
        }

        # IF DIGEST AUTHENTICATION IS USED AND THE URL SCHEME IS NOT HTTPS AN ERROR MESSAGE WILL BE
        # GENERATED PRODUCING A 401 UNAUTHORIZED. BE SURE TO USE HTTPS WHEN PASSING AUTHENTICATION
        if ( ([System.Uri] $params['Uri']).Scheme -ne 'https' ) {
            Write-Warning -Message 'URL is NOT using Secure Protocol (HTTPS)'
        }

        Invoke-WebRequest @params
    }
}
