#####################################################
# HelloID-Conn-Prov-Target-Nedap-AEOS-Entitlement-Revoke
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
    #Get
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
    try {
        $responseCarrierIdProfile = Invoke-RestMethod @splat  -Verbose:$false
        $action = 'Found'
        $dryRunMessage = "Revoke Nedap-AEOS entitlement: [$($pRef.DisplayName)] to: [$($p.DisplayName)] will be executed during enforcement"

    }
    catch {
        if ($($_.ErrorDetails -match 'Carrier not found' )) {
            $action = 'NotFound'
            $dryRunMessage = "Nedap-AEOS account for: [$($p.DisplayName)] not found. Possibily already deleted. Skipping action"
        }
        else {
            throw $_

        }
    }
    Write-Verbose $dryRunMessage

    # Add an auditMessage showing what will happen during enforcement
    if ($dryRun -eq $true) {
        Write-Warning "[DryRun] $dryRunMessage"
    }

    # Process
    if (-not($dryRun -eq $true)) {
        switch ($action) {
            'Found' {
                Write-Verbose "Revoking Nedap-AEOS entitlement: [$($pRef.DisplayName)]"
                write-verbose "Templates currently assigned [$($responseCarrierIdProfile.Envelope.Body.ProfileResult.AuthorisationOnline.TemplateAuthorisation.TemplateId -join ', ')]"
                if ($pRef.Reference -notin $responseCarrierIdProfile.Envelope.Body.ProfileResult.AuthorisationOnline.TemplateAuthorisation.TemplateId  ) {
                    Write-Verbose "[$($pRef.DisplayName)] Already removed, no action required"
                }
                else {
                    # Create a warning when an identical template is assigned multiple times. (Bug in Webservice)
                    $templates = $responseCarrierIdProfile.Envelope.Body.ProfileResult.AuthorisationOnline.TemplateAuthorisation | Where-Object { $_.TemplateId -eq $pref.Reference }
                    if (($templates | Measure-Object).count -gt 1) {
                        throw "TemplateId [$($pref.Reference)] is multiple times assigned to User. Cannot be processed."
                    }
                    [xml]$bodyRemoveAuth = '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:sch="http://www.nedap.com/aeosws/schema">
                        <soapenv:Header/>
                        <soapenv:Body>
                            <sch:ProfileRemove>
                            <sch:CarrierId></sch:CarrierId>
                            <sch:AuthorisationOnlineId>
                                <sch:TemplateAuthorisation>
                                    <sch:TemplateId></sch:TemplateId>
                                </sch:TemplateAuthorisation>
                            </sch:AuthorisationOnlineId>
                            </sch:ProfileRemove>
                        </soapenv:Body>
                        </soapenv:Envelope>
                        '
                    $bodyRemoveAuth.Envelope.Body.ProfileRemove.CarrierId = "$aRef"
                    $bodyRemoveAuth.Envelope.Body.ProfileRemove.AuthorisationOnlineId.TemplateAuthorisation.TemplateId = "$($pRef.Reference)"

                    $splat = @{
                        Headers = $Headers
                        Uri     = $config.BaseUrl
                        Method  = 'Post'
                        body    = $bodyRemoveAuth
                    }
                    $null = Invoke-RestMethod @splat -Verbose:$false
                }
                $auditLogs.Add([PSCustomObject]@{
                        Message = "Revoke Nedap-AEOS entitlement: [$($pRef.DisplayName)] was successful"
                        IsError = $false
                    })
                break
            }

            'NotFound' {
                $auditLogs.Add([PSCustomObject]@{
                        Message = "Nedap-AEOS account for: [$($p.DisplayName)] not found. Possibily already deleted. Skipping action"
                        IsError = $false
                    })
                break
            }
        }
        $success = $true
    }
}
catch {
    Write-Verbose "Error at Line '$($PSItem.InvocationInfo.ScriptLineNumber)': $($PSItem.InvocationInfo.Line). Error: $($PSItem.Exception.Message) $($PSItem.ErrorDetails)" -verbose
    if ([string]::IsNullOrEmpty($PSItem.ErrorDetails)) {
        $auditMessage = "Could not revoke Nedap-AEOS account. Error: $($PSItem.Exception.Message)"
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
