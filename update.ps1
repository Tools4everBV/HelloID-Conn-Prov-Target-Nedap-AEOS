#################################################
# HelloID-Conn-Prov-Target-Nedap-AEOS-Update
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

function New-SoapBodyChangeEmployee {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject]$Account,

        [Parameter(Mandatory)]
        [PSCustomObject] $PropertiesChanged
    )
    $root = 'sch:EmployeeChange'
    $sortOrderEmployee = @(
        'Id', 'NetworkId', 'CarrierType', 'UnitId', 'ArrivalDateTime', 'LeaveDateTime', 'NrMovements', 'ReadOnly',
        'FreeField', 'LastName', 'PersonnelNo', 'FirstName', 'MiddleName', 'Gender', 'Title', 'PhoneNo',
        'Language', 'MobilePhoneNo', 'Email', 'ContactPersonId', 'DepartmentId'
    )
    $sortedAccount = $Account | Select-Object ($sortOrderEmployee | Where-Object { $account.PSObject.Properties.Name -contains $_ })
    Write-output ('<{1}>{0}</{1}>' -f $( $sortedAccount.PSObject.Properties.foreach{ if ($_.Name -eq "Id" -or ($_.Name -in $propertiesChanged.Name) ) { '  <sch:{0}>{1}</sch:{0}>' -f $_.Name, $_.Value } } -join "`n") , $root)
}

function Get-CurrentAccount {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject]$Account,

        [Parameter(Mandatory)]
        [PSCustomObject]$CorrelatedAccount
    )
    $CurrentAccount = [PSCustomObject]@{}
    $null = $Account.PSObject.Properties.foreach{ $CurrentAccount | Add-Member -MemberType NoteProperty  -Name $($_.Name) -Value  $CorrelatedAccount.$($_.Name) }
    Write-Output $CurrentAccount
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
    $correlatedAccountXml = $response.Envelope.Body.EmployeeList.Employee.EmployeeInfo

    if ($null -ne $correlatedAccountXml) {
        $correlatedAccount = Get-CurrentAccount -Account $actionContext.Data -CorrelatedAccount $correlatedAccountXml
        $outputContext.PreviousData = $correlatedAccount | Select-Object -Property $actionContext.Data.PSObject.Properties.Name

        # Always compare the account against the current account in target system
        $splatCompareProperties = @{
            ReferenceObject  = @($correlatedAccount.PSObject.Properties)
            DifferenceObject = @($actionContext.Data.PSObject.Properties)
        }
        $propertiesChanged = Compare-Object @splatCompareProperties -PassThru | Where-Object { $_.SideIndicator -eq '=>' }
        if ($propertiesChanged) {
            $action = 'UpdateAccount'
        } else {
            $action = 'NoChanges'
        }
    } else {
        $action = 'NotFound'
    }

    # Process
    switch ($action) {
        'UpdateAccount' {
            Write-Information "Account property(s) required to update: $($propertiesChanged.Name -join ', ')"

            if (-not($actionContext.DryRun -eq $true)) {
                Write-Information "Updating Nedap-AEOS account with accountReference: [$($actionContext.References.Account)]"

                $actionContext.Data | Add-Member @{
                    id = $actionContext.References.Account
                } -Force
                $soapBody = New-SoapBodyChangeEmployee -Account $actionContext.Data -PropertiesChanged $propertiesChanged
                $response = Invoke-NedapAEOSRestMethod -Uri $actionContext.Configuration.BaseUrl -SoapBody $soapBody -Credential $credential
            } else {
                Write-Information "[DryRun] Update Nedap-AEOS account with accountReference: [$($actionContext.References.Account)], will be executed during enforcement"
            }

            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Update account was successful, Account property(s) updated: [$($propertiesChanged.Name -join ',')]"
                    IsError = $false
                })
            break
        }

        'NoChanges' {
            Write-Information "No changes to Nedap-AEOS account with accountReference: [$($actionContext.References.Account)]"
            $outputContext.Success = $true
            break
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
    $outputContext.Success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-NedapAEOSError -ErrorObject $ex
        $auditLogMessage = "Could not update Nedap-AEOS account. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        $auditLogMessage = "Could not update Nedap-AEOS account. Error: $($ex.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditLogMessage
            IsError = $true
        })
}
