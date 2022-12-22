
#####################################################
# HelloID-Conn-Prov-Target-Nedap-AEOS-Create
#
# Version: 1.0.0
#####################################################
# Initialize default values
$config = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$success = $false
$auditLogs = [System.Collections.Generic.List[PSCustomObject]]::new()

# Account mapping
# NOTE do not change de order of the attributes in the Account object, the AEOS API demands them in a specific order.
$account = [PSCustomObject]@{
    Id          = $null                      # autogenerated, but leave dummy in account object to ensure that it will be the first attribute
    # NetworkId = $null                      # autogenerated?
    # CarrierType = $null                    # autogenerated?
    # UnitId = $null                         # autogenerated?
    ArrivalDateTime = "2200-01-01T00:00:00"  # 2018-11-25T15:44:07 <!-- XSD DateTime data type format --> Set to a date in the far future to create account as disabled
    # LeaveDateTime = $null                  # 2049-06-09T17:15:04+02:00 <!-- UTC+2 -->
    # NrMovements = $null
    # ReadOnly = $null
    # FreeField = $null                      # list of objects with free fields {DefinitionId,Name,Value}, currently not supported in this connector
    LastName    = $p.Name.FamilyName         # <!-- String, max. 50 characters -->
    PersonnelNo = $p.ExternalId              # <!-- String, max. 50 characters -->
    FirstName   = $p.Name.GivenName          # <!-- String, max. 40 characters -->
    MiddleName  = $p.Name.FamilyNamePrefix
    Gender      = "Unknown"                  # <!-- Male, Female, Unknown -->
    # Title = $null                          # <!-- String, max. 25 characters -->
    # PhoneNo = $null                        # <!-- String, max. 25 characters -->  <!-- Do not use spaces or hyphens if dialers (such as SMS servers)  need to process this phone number. -->
    Language    = "nl"                       # <!-- ar, de, dk, en, es, fa, fr, it, iw, nl, no, pl, pt, ru, sv,zh_CN --> <!-- String, max. 12 characters (but most are unused) -->
    # MobilePhoneNo = $null                  # <!-- String, max. 25 characters -->
    Email       = $p.Accounts.MicrosoftActiveDirectory.mail   # <!-- String, max. 128 characters -->
    # ContactPersonId = $null                 # <!-- Long. You can find this ID with findPerson -->
    # DepartmentId = $null                    # <!-- Long. You can find this ID with findDepartment -->
}

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($config.IsDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

# Set to true if accounts in the target system must be updated
$updatePerson = $false

#region functions
function New-SoapbodyFindEmployee {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject] $Account
    )
    [system.text.StringBuilder] $soapFindEmployee = [system.text.StringBuilder]::new()
    $null = $soapFindEmployee.Append('<sch:EmployeeSearchInfo>')
    $null = $soapFindEmployee.Append('<sch:EmployeeInfo>')
    $null = $soapFindEmployee.Append("<sch:PersonnelNo>$($Account.PersonnelNo)</sch:PersonnelNo>")
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

function New-SoapbodyAddEmployee {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject] $Account
    )
    $root = "sch:EmployeeAdd"
   Write-output ('<{1}>{0}</{1}>' -f $( $Account.PSObject.Properties.foreach{if ($_.Name -ne "Id"){'  <sch:{0}>{1}</sch:{0}>' -f $_.Name, $_.Value}} -join "`n") , $root)

}

function New-SoapbodyChangeEmployee {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject] $Account
    )
    $root = "sch:EmployeeChange"
   Write-output ('<{1}>{0}</{1}>' -f $( $Account.PSObject.Properties.foreach{'  <sch:{0}>{1}</sch:{0}>' -f $_.Name, $_.Value} -join "`n") , $root)

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
    # Verify if a user must be either [created and correlated], [updated and correlated] or just [correlated]

    $Soapbody = New-SoapbodyFindEmployee -account $account
    $response = Invoke-Nedap-AEOSRestMethod   -SoapBody $Soapbody

    $EmployeeInfo = $null;
    if ($null -ne $Response.Envelope.Body) {

        foreach ($Item in  $Response.Envelope.Body.EmployeeList) {

            if ($Item.employee.EmployeeInfo.PersonnelNo -eq $account.PersonnelNo) {

                $EmployeeInfo = $Item.employee.EmployeeInfo
                break
            }
        }
    }

    if ($null -eq $EmployeeInfo) {
        $action = 'Create-Correlate'
    }
    elseif ($updatePerson -eq $true) {
        $action = 'Update-Correlate'
    }
    else {
        $action = 'Correlate'
    }

    # Add a warning message showing what will happen during enforcement
    if ($dryRun -eq $true) {
        Write-Warning "[DryRun] $action Nedap-AEOS account for: [$($p.DisplayName)], will be executed during enforcement"
    }
    # Process
    if (-not($dryRun -eq $true)) {
        switch ($action) {
            'Create-Correlate' {
                Write-Verbose "Creating and correlating Nedap-AEOS account"
                $Soapbody = New-SoapbodyAddEmployee  -account $account
                $response = Invoke-Nedap-AEOSRestMethod -SoapBody $Soapbody
                $account.Id =   $Response.Envelope.Body.EmployeeResult.Id
                $accountReference = $account.Id
                break
            }

            'Update-Correlate' {
                Write-Verbose "Updating and correlating Nedap-AEOS account"
                $account.Id = $EmployeeInfo.Id
                $accountReference = $account.Id
                $Soapbody = New-SoapbodyChangeEmployee  -account $account
                $response = Invoke-Nedap-AEOSRestMethod -SoapBody $Soapbody

                break
            }
            'Correlate' {
                Write-Verbose "Correlating Nedap-AEOS account"
                $account.Id = $EmployeeInfo.Id
                $accountReference = $account.Id
                break
            }
        }

        $success = $true
        $auditLogs.Add([PSCustomObject]@{
                Message = "$action account was successful. AccountReference is: [$accountReference]"
                IsError = $false
            })
    }
}
catch {
    $success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-Nedap-AEOSError -ErrorObject $ex
        $auditMessage = "Could not $action Nedap-AEOS account. Error: $($errorObj.FriendlyMessage)"
        Write-Verbose "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    }
    else {
        $auditMessage = "Could not $action Nedap-AEOS account. Error: $($ex.Exception.Message)"
        Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $auditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
    # End
}
finally {
    $result = [PSCustomObject]@{
        Success          = $success
        AccountReference = $accountReference
        Auditlogs        = $auditLogs
        Account          = $account
    }
    Write-Output $result | ConvertTo-Json -Depth 10
}
