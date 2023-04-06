#####################################################
# HelloID-Conn-Prov-Target-Nedap-AEOS-Enable
#
# Version: 1.0.0
#####################################################
# Initialize default values
$config = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$aRef = $AccountReference | ConvertFrom-Json
$success = $false
$auditLogs = [System.Collections.Generic.List[PSCustomObject]]::new()

$now = (Get-Date).ToUniversalTime()
$dateFormat ="yyyy-MM-ddTHH:mm:ss"

$account = [PSCustomObject]@{
    Id = $aref
    ArrivalDateTime = $now.ToString($dateFormat)    # 2018-11-25T15:44:07 <!-- XSD DateTime data type format -->   2049-06-09T17:15:04+02:00 <!-- UTC+2 -->
    LeaveDateTime = "2099-01-01T00:00:00"           # empty string does not clear value, so fill in a time far in the future.
}

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($config.IsDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

#region functions
function New-SoapbodyEnableEmployee {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject] $Account
    )
    $root = "sch:EmployeeChange"
    Write-output ('<{1}>{0}</{1}>' -f $( $Account.PSObject.Properties.foreach{if($_.Name -eq "Id" -or $_.Name -eq "ArrivalDateTime" -or  $_.Name -eq "LeaveDateTime"){'  <sch:{0}>{1}</sch:{0}>' -f $_.Name, $_.Value}} -join "`n") , $root)
}
function New-SoapbodyFindEmployee {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject] $Account
    )
    [system.text.StringBuilder] $soapFindEmployee = [system.text.StringBuilder]::new()
    $null = $soapFindEmployee.Append('<sch:EmployeeSearchInfo>')
    $null = $soapFindEmployee.Append('<sch:EmployeeInfo>')
    $null = $soapFindEmployee.Append("<sch:Id>$($Account.Id)</sch:Id>")
    $null = $soapFindEmployee.Append('</sch:EmployeeInfo>')
    $null = $soapFindEmployee.Append('</sch:EmployeeSearchInfo>')

    Write-Output $soapFindEmployee.ToString()
}
function Invoke-Nedap-AEOSRestMethod {
    [CmdletBinding()]
    param (

        [string]
        $Method = "POST",

        [string]
        $Uri = $Config.BaseUrl,

        [string]
        $SoapBody,

        [string]
        $ContentType = "text/xml; charset=UTF-8",

        [System.Collections.IDictionary]
        $Headers
    )
    process {

        try {

            $securePassword = $Config.Password | ConvertTo-SecureString -AsPlainText -Force
            [pscredential]$credential = New-Object System.Management.Automation.PSCredential ($config.UserName, $securePassword)

            [system.text.StringBuilder] $BodySB = [system.text.StringBuilder]::new()
            $null = $BodySB.Append('<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:sch="http://www.nedap.com/aeosws/schema">')
            $null = $BodySB.Append('<soapenv:Header/>')
            $null = $BodySB.Append('<soapenv:Body>')
            $null = $BodySB.Append($Soapbody)
            $null = $BodySB.Append('</soapenv:Body>')
            $null = $BodySB.Append('</soapenv:Envelope>')

            $splatParams = @{
                Uri    = $Uri
                Method = $Method
                ContentType = $ContentType
                Body = $BodySB.ToString()
            }
            if ($Headers) {
                Write-Verbose 'Adding Headers to request'
                $splatParams['Headers'] = $Headers
            }

            if (-not  [string]::IsNullOrEmpty($config.ProxyAddress)) {
                $splatParams['Proxy'] = $config.ProxyAddress
            }

            $Response = Invoke-RestMethod @splatParams -Verbose:$false  -Credential $Credential
            Write-output $Response
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
function Resolve-Nedap-AEOSError {
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
            ErrorDetails     = ''
            FriendlyMessage  = ''
        }
        $httpErrorObj.FriendlyMessage = $ErrorObject.Exception.Message

        if (-not [string]::IsNullOrWhiteSpace($ErrorObject.ErrorDetails.Message)) {
            $httpErrorObj.ErrorDetails = $ErrorObject.ErrorDetails.Message
        }
        elseif ($null -eq $ErrorObject.Exception.Response) {
                $httpErrorObj.ErrorDetails = $ErrorObject.Exception.Message
        }
        else {
            $streamReaderResponse = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
            if ( [string]::IsNullOrWhiteSpace($streamReaderResponse)){
                $httpErrorObj.ErrorDetails = $ErrorObject.Exception.Message
            }
            else{
                $httpErrorObj.ErrorDetails = $streamReaderResponse
            }
        }

        if ($ErrorObject.FriendlyMessage -like "*500 Internal Server Error*")
        {
            $httpErrorObj.FriendlyMessage += " $(httpErrorObj.ErrorDetails)"
        }

        Write-Output $httpErrorObj
    }
}

#endregion

# Begin
try {
    Write-Verbose "Verifying if a Nedap-AEOS account for [$($p.DisplayName)] exists"
    # Verify if the account must be updated
    $soapbody = New-SoapbodyFindEmployee -account $account
    $response = Invoke-Nedap-AEOSRestMethod   -SoapBody $soapbody
    $employeeInfo=$null;
    if ($null -ne $Response.Envelope.Body) {
        foreach ($Item in  $Response.Envelope.Body.EmployeeList){
            if ($Item.employee.EmployeeInfo.Id -eq $account.Id) {
                $employeeInfo = $Item.employee.EmployeeInfo
                break
            }
        }
    }
    # Make sure to fail the action if the account does not exist in the target system!
    if ($null -eq $employeeInfo) {
        throw "Nedap-AEOS account for: [$($p.DisplayName)] with Nedap Id [$aRef] not found. Possibily deleted"
    }

    # Add an auditMessage showing what will happen during enforcement
    if ($dryRun -eq $true) {
        Write-Warning "[DryRun] Enable Nedap-AEOS account for: [$($p.DisplayName)] will be executed during enforcement"
    }

    # Process
    if (-not($dryRun -eq $true)) {
        Write-Verbose "Enabling Nedap-AEOS account with accountReference: [$aRef]"

        $soapbody = New-SoapbodyEnableEmployee -Account $account
        $response = Invoke-Nedap-AEOSRestMethod -SoapBody $Soapbody

        $success = $true
        $auditLogs.Add([PSCustomObject]@{
                Message = 'Enable account was successful'
                IsError = $false
            })
    }
} catch {
    $success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-Nedap-AEOSError -ErrorObject $ex
        $auditMessage = "Could not enable Nedap-AEOS account. Error: $($errorObj.FriendlyMessage)"
        Write-Verbose "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        $auditMessage = "Could not enable Nedap-AEOS account. Error: $($ex.Exception.Message)"
        Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $auditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
# End
} finally {
    $result = [PSCustomObject]@{
        Success   = $success
        Auditlogs = $auditLogs
    }
    Write-Output $result | ConvertTo-Json -Depth 10
}
