################################################################
# HelloID-Conn-Prov-Target-Nedap-AEOS-GrantPermission-TemplateAuthorisation
# PowerShell V2
################################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

#region functions
function Resolve-NedapAEOSError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            ScriptLineNumber = $ErrorObject.InvocationInfo.ScriptLineNumber
            Line             = $ErrorObject.InvocationInfo.Line
            ErrorDetails     = $ErrorObject.Exception.Message
            FriendlyMessage  = $ErrorObject.Exception.Message
        }
        if (-not [string]::IsNullOrWhiteSpace($ErrorObject.ErrorDetails.Message)) {
            $httpErrorObj.ErrorDetails = $ErrorObject.ErrorDetails.Message
        } elseif ($null -eq $ErrorObject.Exception.Response) {
            $httpErrorObj.ErrorDetails = $ErrorObject.Exception.Message
        } else {
            $streamReaderResponse = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
            if ( [string]::IsNullOrWhiteSpace($streamReaderResponse)) {
                $httpErrorObj.ErrorDetails = $ErrorObject.Exception.Message
            } else {
                $httpErrorObj.ErrorDetails = $streamReaderResponse
            }
        }
        if ($ErrorObject.FriendlyMessage -like '*500 Internal Server Error*') {
            $httpErrorObj.FriendlyMessage += " $($httpErrorObj.ErrorDetails)"
        }
        Write-Output $httpErrorObj
    }
}

function Invoke-NedapAEOSRestMethod {
    [CmdletBinding()]
    param (
        [string]
        $Method = 'POST',

        [string]
        $Uri,

        [string]
        $SoapBody,

        [string]
        $ContentType = 'text/xml; charset=UTF-8',

        [System.Management.Automation.PSCredential]
        $Credential
    )
    process {
        try {
            [system.text.StringBuilder]$BodySB = [system.text.StringBuilder]::new()
            $null = $BodySB.Append('<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:sch="http://www.nedap.com/aeosws/schema">')
            $null = $BodySB.Append('<soapenv:Header/>')
            $null = $BodySB.Append('<soapenv:Body>')
            $null = $BodySB.Append($SoapBody)
            $null = $BodySB.Append('</soapenv:Body>')
            $null = $BodySB.Append('</soapenv:Envelope>')

            $splatParams = @{
                Uri         = $Uri
                Method      = $Method
                ContentType = $ContentType
                Body        = $BodySB.ToString()
            }

            $Response = Invoke-RestMethod @splatParams -Verbose:$false -Credential $Credential
            Write-Output $Response
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
#endregion

# Begin
try {
    # Verify if [aRef] has a value
    if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
        throw 'The account reference could not be found'
    }

    # Setup credentials
    $securePassword = $actionContext.Configuration.Password | ConvertTo-SecureString -AsPlainText -Force
    $credential = [System.Management.Automation.PSCredential]::new($actionContext.Configuration.UserName, $securePassword)
    Write-Information 'Verifying if a Nedap-AEOS account exists and checking current permissions'
    try {
        # Get current carrier profile to check if permission already exists
        $bodyGetCarrierProfiles = "<sch:CarrierIdProfile>$($actionContext.References.Account)</sch:CarrierIdProfile>"
        $responseCarrierIdProfile = Invoke-NedapAEOSRestMethod -Uri $actionContext.Configuration.BaseUrl -SoapBody $bodyGetCarrierProfiles -Credential $credential

        $action = 'GrantPermission'
    } catch {
        if ($($_.ErrorDetails -match 'Carrier not found')) {
            $action = 'NotFound'
        } else {
            throw $_
        }
    }

    # Process
    switch ($action) {
        'GrantPermission' {
            # Check if permission is already granted
            if ($responseCarrierIdProfile.Envelope.Body.ProfileResult.AuthorisationOnline.TemplateAuthorisation.TemplateId -contains $actionContext.References.Permission.Reference) {
                Write-Information "[$($actionContext.PermissionDisplayName)] Already granted, no action required"
            } else {
                Write-Information "Granting Nedap-AEOS permission: [$($actionContext.PermissionDisplayName)] - [$($actionContext.References.Permission.Reference)]"
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

                $profileAdd = $bodyAddAuth.Envelope.Body.ProfileAdd
                $template = $profileAdd.AuthorisationOnline.TemplateAuthorisation

                $profileAdd.CarrierId = "$($actionContext.References.Account)"
                $template.Enabled = 'true'
                $template.TemplateId = "$($actionContext.References.Permission.Reference)"
                $template.DateFrom = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
                if (-not($actionContext.DryRun -eq $true)) {
                    $result = Invoke-NedapAEOSRestMethod -Uri $actionContext.Configuration.BaseUrl -SoapBody $bodyAddAuth.Envelope.Body.InnerXML -Credential $credential
                } else {
                    Write-Information "[DryRun] Grant Nedap-AEOS permission: [$($actionContext.PermissionDisplayName)] - [$($actionContext.References.Permission.Reference)], will be executed during enforcement"
                }
            }
            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Grant permission [$($actionContext.PermissionDisplayName)] was successful"
                    IsError = $false
                })
        }

        'NotFound' {
            Write-Information "Nedap-AEOS account: [$($actionContext.References.Account)] could not be found, indicating that it may have been deleted"
            $outputContext.Success = $false
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Nedap-AEOS account: [$($actionContext.References.Account)] could not be found, indicating that it may have been deleted"
                    IsError = $true
                })
            break
        }
    }
} catch {
    $outputContext.success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-NedapAEOSError -ErrorObject $ex
        $auditLogMessage = "Could not grant Nedap-AEOS permission. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        $auditLogMessage = "Could not grant Nedap-AEOS permission. Error: $($_.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditLogMessage
            IsError = $true
        })
}