#################################################
# HelloID-Conn-Prov-Target-Nedap-AEOS-Create
# PowerShell V2
#################################################

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
            Write-Information "$($BodySB.ToString())"
            $Response = Invoke-RestMethod @splatParams -Verbose:$false -Credential $Credential
            Write-Output $Response
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

function New-SoapBodyFindEmployeeByPersonnelNo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$PersonnelNo
    )
    [system.text.StringBuilder]$soapFindEmployee = [system.text.StringBuilder]::new()
    $null = $soapFindEmployee.Append('<sch:EmployeeSearchInfo>')
    $null = $soapFindEmployee.Append('<sch:EmployeeInfo>')
    $null = $soapFindEmployee.Append("<sch:PersonnelNo>$PersonnelNo</sch:PersonnelNo>")
    $null = $soapFindEmployee.Append('</sch:EmployeeInfo>')
    $null = $soapFindEmployee.Append('</sch:EmployeeSearchInfo>')

    Write-Output $soapFindEmployee.ToString()
}

function New-SoapBodyAddEmployee {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject]$Account
    )
    $root = 'sch:EmployeeAdd'
    $sortOrderEmployee =  @(
        'Id', 'NetworkId', 'CarrierType', 'UnitId', 'ArrivalDateTime', 'LeaveDateTime', 'NrMovements', 'ReadOnly',
        'FreeField', 'LastName', 'PersonnelNo', 'FirstName', 'MiddleName', 'Gender', 'Title', 'PhoneNo',
        'Language', 'MobilePhoneNo', 'Email', 'ContactPersonId', 'DepartmentId'
    )
    $sortedAccount = $Account | Select-Object ($sortOrderEmployee | Where-Object { $account.PSObject.Properties.Name -contains $_ })
    Write-Output ('<{1}>{0}</{1}>' -f $( $sortedAccount.PSObject.Properties.foreach{ if ($_.Name -ne "Id") { '  <sch:{0}>{1}</sch:{0}>' -f $_.Name, $_.Value } } -join "`n") , $root)
}
#endregion

try {
    # Initial Assignments
    $outputContext.AccountReference = 'Currently not available'

    # Setup credentials
    $securePassword = $actionContext.Configuration.Password | ConvertTo-SecureString -AsPlainText -Force
    $credential = [System.Management.Automation.PSCredential]::new($actionContext.Configuration.UserName, $securePassword)

    # Validate correlation configuration
    if ($actionContext.CorrelationConfiguration.Enabled) {
        $correlationField = $actionContext.CorrelationConfiguration.AccountField
        $correlationValue = $actionContext.CorrelationConfiguration.PersonFieldValue

        if ([string]::IsNullOrEmpty($($correlationField))) {
            throw 'Correlation is enabled but not configured correctly'
        }
        if ([string]::IsNullOrEmpty($($correlationValue))) {
            throw 'Correlation is enabled but [accountFieldValue] is empty. Please make sure it is correctly mapped'
        }

        # Search for employee by PersonnelNo
        $soapBody = New-SoapBodyFindEmployeeByPersonnelNo -PersonnelNo $correlationValue
        $response = Invoke-NedapAEOSRestMethod -Uri $actionContext.Configuration.BaseUrl -SoapBody $soapBody -Credential $credential

        $correlatedAccount = $response.Envelope.Body.EmployeeList.Employee.EmployeeInfo
        if (($correlatedAccount | Measure-Object).count -gt 1) {
            throw "Multiple accounts found for person where $correlationField is: [$correlationValue]"
        }
    }

    if ($null -eq $correlatedAccount) {
        $action = 'CreateAccount'
    } else {
        $action = 'CorrelateAccount'
    }

    # Set ArrivalDateTime to far future to create account as disabled
    $actionContext.Data | Add-Member @{
        ArrivalDateTime = '2099-01-01T00:00:00'
    } -Force

    # Process
    switch ($action) {
        'CreateAccount' {
            # Make sure to test with special characters and if needed; add utf8 encoding.
            $soapBody = New-SoapBodyAddEmployee -Account $actionContext.Data
            if (-not($actionContext.DryRun -eq $true)) {
                Write-Information 'Creating and correlating Nedap-AEOS account'
                $response = Invoke-NedapAEOSRestMethod -Uri $actionContext.Configuration.BaseUrl -SoapBody $soapBody -Credential $credential
                $outputContext.Data = $response.Envelope.Body.EmployeeResult | Select-Object -Property $outputContext.Data.PSObject.Properties.Name
                $outputContext.AccountReference = $response.Envelope.Body.EmployeeResult.Id
            } else {
                Write-Information '[DryRun] Create and correlate Nedap-AEOS account, will be executed during enforcement'
            }
            $auditLogMessage = "Create account was successful. AccountReference is: [$($outputContext.AccountReference)]"
            break
        }

        'CorrelateAccount' {
            Write-Information 'Correlating Nedap-AEOS account'
            $outputContext.Data = $correlatedAccount | Select-Object -Property $outputContext.Data.PSObject.Properties.Name
            $outputContext.AccountReference = $correlatedAccount.Id
            $outputContext.AccountCorrelated = $true
            $auditLogMessage = "Correlated account: [$($outputContext.AccountReference)] on field: [$($correlationField)] with value: [$($correlationValue)]"
            break
        }
    }

    $outputContext.success = $true
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Action  = $action
            Message = $auditLogMessage
            IsError = $false
        })
} catch {
    $outputContext.success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-NedapAEOSError -ErrorObject $ex
        $auditLogMessage = "Could not create or correlate Nedap-AEOS account. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        $auditLogMessage = "Could not create or correlate Nedap-AEOS account. Error: $($ex.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditLogMessage
            IsError = $true
        })
}