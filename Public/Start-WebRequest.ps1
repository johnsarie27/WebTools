function Start-WebRequest {
    <# =========================================================================
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
    ========================================================================= #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, HelpMessage = 'Json payload for pull-push process')]
        [ValidateScript({ Test-Json -Json $_ -Schema $EtlSchema })]
        [string] $Payload,

        [Parameter(HelpMessage = 'Credentials for URI')]
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
                'Token' {
                    $token = Get-PortalToken -Credential $Credential -URL $data.Dependency
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
        }
        if ( $data.Method ) {
            $params.Add('Method', $data.Method)
        }
        if ( $data.Headers ) {
            $headers = @{ }
            $data.Headers | Foreach-Object -Process { $headers.Add($_.Key, $_.Value) }
            $params.Add('Headers', $headers)
        }
        if ( $data.Body ) {
            if ( $data.Body -eq 'Source content' ) {
                if ( $headers.ContainsKey('Content-Type') -and $headers['Content-Type'] -eq 'application/json' ) {
                    # SKIP JSON VALIDITY CHECKS AND ALWAYS WRAP INTO JSON OBJECT FOR CONSISTENCY
                    $params.Add('Body', ('{"data":' + $Body + '}'))
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
            elseif ( $data.Body.GetType().FullName -eq 'System.String' ) {
                $params.Add('Body', $data.Body)
            }
            else {
                $params.Add('Body', (ConvertTo-Json -InputObject $data.Body -Compress))
            }
        }

        # IF DIGEST AUTHENTICATION IS USED AND THE URL SCHEME IS NOT HTTPS AN ERROR MESSAGE WILL BE
        # GENERATED PRODUCING A 401 UNAUTHORIZED. BE SURE TO USE HTTPS WHEN PASSING AUTHENTICATION
        if ( ([System.Uri] $params['Uri']).Scheme -ne 'https' ) {
            Write-Host -Object 'URL is NOT using Secure Protocol (HTTPS)'
        }

        Invoke-WebRequest @params
    }
}
