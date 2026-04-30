##################################################
# HelloID-Conn-Prov-Target-Nedap-AEOS-Disable
# PowerShell V2
##################################################

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


function New-SoapBodyDisableEmployee {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Id
    )
    $now = (Get-Date).ToUniversalTime()
    $dateFormat = "yyyy-MM-ddTHH:mm:ss"

    $root = "sch:EmployeeChange"
    $body = "  <sch:Id>$Id</sch:Id>`n"
    $body += "  <sch:LeaveDateTime>$($now.ToString($dateFormat))</sch:LeaveDateTime>"

    Write-Output "<$root>`n$body`n</$root>"
}

function New-SoapBodyFindCarrierToken {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$CarrierId
    )
    $root = "sch:CarrierIdToken"
    Write-Output "<$root>$CarrierId</$root>"
}

function New-SoapBodyFindEmployeeById {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Id
    )
    [system.text.StringBuilder]$soapFindEmployee = [system.text.StringBuilder]::new()
    $null = $soapFindEmployee.Append('<sch:EmployeeSearchInfo>')
    $null = $soapFindEmployee.Append('<sch:EmployeeInfo>')
    $null = $soapFindEmployee.Append("<sch:Id>$Id</sch:Id>")
    $null = $soapFindEmployee.Append('</sch:EmployeeInfo>')
    $null = $soapFindEmployee.Append('</sch:EmployeeSearchInfo>')

    Write-Output $soapFindEmployee.ToString()
}


function New-SoapBodyWithdrawCarrierToken {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject]$Identifier
    )
    $root = "sch:IdentifierWithdraw"
    Write-Output "<$root><sch:IdentifierType>$($Identifier.IdentifierType)</sch:IdentifierType><sch:BadgeNumber>$($Identifier.BadgeNumber)</sch:BadgeNumber></$root>"
}
#endregion

try {
    # Verify if [aRef] has a value
    if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
        throw 'The account reference could not be found'
    }

    # Setup credentials
    $securePassword = $actionContext.Configuration.Password | ConvertTo-SecureString -AsPlainText -Force
    $credential = [System.Management.Automation.PSCredential]::new($actionContext.Configuration.UserName, $securePassword)

    Write-Information 'Verifying if a Nedap-AEOS account exists'
    $soapBody = New-SoapBodyFindEmployeeById -Id $actionContext.References.Account
    $response = Invoke-NedapAEOSRestMethod -Uri $actionContext.Configuration.BaseUrl -SoapBody $soapBody -Credential $credential
    $correlatedAccount = $response.Envelope.Body.EmployeeList.Employee.EmployeeInfo

    if ($null -ne $correlatedAccount) {
        $action = 'DisableAccount'
    } else {
        $action = 'NotFound'
    }

    # Process
    switch ($action) {
        'DisableAccount' {
            if (-not($actionContext.DryRun -eq $true)) {
                Write-Information "Disabling Nedap-AEOS account with accountReference: [$($actionContext.References.Account)]"

                # Withdraw all carrier tokens (badges) from the employee
                $soapBody = New-SoapBodyFindCarrierToken -CarrierId $correlatedAccount.Id
                $response = Invoke-NedapAEOSRestMethod -Uri $actionContext.Configuration.BaseUrl -SoapBody $soapBody -Credential $credential

                $identifier = $null
                if ($null -ne $Response.Envelope.Body) {
                    foreach ($Item in  $Response.Envelope.Body.IdentifierList.Identifier) {
                        $identifier = $Item
                        if ($null -ne $identifier) {
                            $soapBody = New-SoapBodyWithdrawCarrierToken -Identifier $identifier
                            $response = Invoke-NedapAEOSRestMethod -Uri $actionContext.Configuration.BaseUrl -SoapBody $soapBody -Credential $credential
                        }
                    }
                }

                # Disable the employee by setting LeaveDateTime to current time
                $soapBody = New-SoapBodyDisableEmployee -Id $actionContext.References.Account
                $response = Invoke-NedapAEOSRestMethod -Uri $actionContext.Configuration.BaseUrl -SoapBody $soapBody -Credential $credential
            } else {
                Write-Information "[DryRun] Disable Nedap-AEOS account with accountReference: [$($actionContext.References.Account)], will be executed during enforcement"
            }

            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Disable account [$($actionContext.References.Account)] was successful. Action initiated by: [$($actionContext.Origin)]"
                    IsError = $false
                })
            break
        }

        'NotFound' {
            Write-Information "Nedap-AEOS account: [$($actionContext.References.Account)] could not be found, indicating that it may have been deleted"
            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Nedap-AEOS account: [$($actionContext.References.Account)] could not be found, indicating that it may have been deleted. Action initiated by: [$($actionContext.Origin)]"
                    IsError = $false
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
        $auditLogMessage = "Could not disable Nedap-AEOS account. Error: $($errorObj.FriendlyMessage). Action initiated by: [$($actionContext.Origin)]"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        $auditLogMessage = "Could not disable Nedap-AEOS account. Error: $($_.Exception.Message). Action initiated by: [$($actionContext.Origin)]"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditLogMessage
            IsError = $true
        })
}