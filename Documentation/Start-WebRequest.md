# Start-WebRequest

## SYNOPSIS
Initiate web request using provided parameters

## SYNTAX

```
Start-WebRequest [-Payload] <String> [[-Credential] <PSCredential>] [[-Body] <Object>] [<CommonParameters>]
```

## DESCRIPTION
Validate input as Json with correct schema and intitiate pull-push process.
There is not error catching in the Invoke-WebRequest as this should be done
outside of this specific function.

## EXAMPLES

### EXAMPLE 1
```
Start-WebRequest -Payload $p
Uses the parameters in the payload parameter to call 'Invoke-WebRequest'
```

## PARAMETERS

### -Payload
Json payload containing required information for web request

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -Credential
Credentials for URI

```yaml
Type: PSCredential
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Body
Body of web request if not specified in the Payload

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String.
## OUTPUTS

### Microsoft.PowerShell.Commands.BasicHtmlWebResponseObject.
## NOTES
General notes
This function requires the system running it has credentials to pull and
decrypt SSM Parameters from Parameter Store.

## RELATED LINKS
