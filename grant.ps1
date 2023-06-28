#####################################################
# HelloID-Conn-Prov-Target-Nedap-AEOS-Entitlement-Grant
#
# Version: 1.0.0
#####################################################
# Initialize default values
$config = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$aRef = $AccountReference | ConvertFrom-Json
$pRef = $permissionReference | ConvertFrom-Json
$success = $false
$auditLogs = [System.Collections.Generic.List[PSCustomObject]]::new()

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

    Write-Verbose "Verifying if a Nedap-AEOS account for [$($p.DisplayName)] exists"
    $bodyGetCarrierProfiles = '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:sch="http://www.nedap.com/aeosws/schema">
            <soapenv:Header/>
            <soapenv:Body>
                <sch:CarrierIdProfile>{0}</sch:CarrierIdProfile>
            </soapenv:Body>
        </soapenv:Envelope>
        ' -f "$aRef"
    $splat = @{
        Headers = $Headers
        Uri     = $config.BaseUrl
        Method  = 'Post'
        body    = $bodyGetCarrierProfiles
    }
    $result = Invoke-RestMethod @splat  -Verbose:$false


    # Add an auditMessage showing what will happen during enforcement
    if ($dryRun -eq $true) {
        Write-Warning "[DryRun] Grant Nedap-AEOS entitlement: [$($pRef.DisplayName)] to: [$($p.DisplayName)] will be executed during enforcement"
    }

    # Process
    if (-not($dryRun -eq $true)) {
        Write-Verbose "Granting Nedap-AEOS entitlement: [$($pRef.DisplayName)]"
        if ($result.Envelope.Body.ProfileResult.AuthorisationOnline.TemplateAuthorisation.TemplateId -eq "$($pRef.Reference)") {
            Write-Verbose "[$($pRef.DisplayName)] Already granted, no action required"
        }
        else {
            [xml]$bodyAddAuth = '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:sch="http://www.nedap.com/aeosws/schema">
               <soapenv:Header/>
               <soapenv:Body>
                  <sch:ProfileAdd>
                     <sch:CarrierId></sch:CarrierId>
                     <sch:AuthorisationOnline>
                        <sch:TemplateAuthorisation>
                           <sch:Enabled></sch:Enabled>
                           <sch:TemplateId></sch:TemplateId>
                           <sch:DateFrom></sch:DateFrom>
                        </sch:TemplateAuthorisation>
                     </sch:AuthorisationOnline>
                  </sch:ProfileAdd>
               </soapenv:Body>
            </soapenv:Envelope>'


            $profileadd = $bodyAddAuth.Envelope.Body.ProfileAdd
            $template = $profileadd.AuthorisationOnline.TemplateAuthorisation

            $profileadd.CarrierId = "$aRef"
            $template.Enabled = 'true'
            $template.TemplateId = "$($pRef.Reference)"
            $template.DateFrom = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')

            $splat = @{
                Headers = $Headers
                Uri     = $config.BaseUrl
                Method  = 'Post'
                body    = $bodyAddAuth
            }
            $result = Invoke-RestMethod @splat -Verbose:$false
        }
        $success = $true
        $auditLogs.Add([PSCustomObject]@{
                Message = "Grant Nedap-AEOS entitlement: [$($pRef.DisplayName)] was successful"
                IsError = $false
            })
    }
}
catch {
    Write-Verbose "Error at Line '$($PSItem.InvocationInfo.ScriptLineNumber)': $($PSItem.InvocationInfo.Line). Error: $($PSItem.Exception.Message) $($PSItem.ErrorDetails)" -verbose
    if ([string]::IsNullOrEmpty($PSItem.ErrorDetails)) {
        $auditMessage = "Could not grant Nedap-AEOS account. Error: $($PSItem.Exception.Message)"
    }
    else {
        $auditMessage = "Could not grant Nedap-AEOS account. Error: $($PSItem.ErrorDetails)"
    }
    $auditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}
finally {
    $result = [PSCustomObject]@{
        Success   = $success
        Auditlogs = $auditLogs
    }
    Write-Output $result | ConvertTo-Json -Depth 10
}
