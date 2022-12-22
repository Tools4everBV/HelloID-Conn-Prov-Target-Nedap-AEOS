#####################################################
# HelloID-Conn-Prov-Target-Nedap-AEOS-Permissions
#
# Version: 1.0.0
#####################################################
# Initialize default values
$config = $configuration | ConvertFrom-Json

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($config.IsDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

try {
    # Set Authentication Header
    $pair = "$($config.userName):$( $config.Password)"
    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
    $Headers = @{
        Authorization = "Basic $encodedCreds"
    }


    # !-- OnLine, OffLine, Loxs -->
    $body = '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:sch="http://www.nedap.com/aeosws/schema">
        <soapenv:Header/>
        <soapenv:Body>
            <sch:TemplateSearchInfo>
                <sch:TemplateInfo>
                    <sch:UnitOfAuthType>OnLine</sch:UnitOfAuthType>
                </sch:TemplateInfo>
            </sch:TemplateSearchInfo>
        </soapenv:Body>
        </soapenv:Envelope>'
    $splat = @{
        Headers = $Headers
        Uri     = $config.BaseUrl
        Method  = 'Post'
        body    = $body
    }
    $result = Invoke-RestMethod @splat -Verbose:$false

    foreach ($template in $result.envelope.body.templateList.Template ) {
        Write-Output ([PSCustomObject]@{
                DisplayName    = $template.Name
                Identification = @{
                    DisplayName = $template.Name
                    Reference   = $template.Id
                }
            }) | ConvertTo-Json
    }
} catch {
    Write-Verbose "$($PSItem.errordetails.message)" -Verbose
    Write-Verbose "Error at Line '$($PSItem.InvocationInfo.ScriptLineNumber)': $($PSItem.InvocationInfo.Line). Error: $($PSItem.Exception.Message)" -Verbose
}
