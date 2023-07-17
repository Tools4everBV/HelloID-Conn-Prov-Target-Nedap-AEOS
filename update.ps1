#####################################################
# HelloID-Conn-Prov-Target-Nedap-AEOS-Update
#
# Version: 1.1.0
#####################################################
# Initialize default values
$config = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$aRef = $AccountReference | ConvertFrom-Json
$success = $false
$auditLogs = [System.Collections.Generic.List[PSCustomObject]]::new()

function New-AeosName {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [object]
        $person
    )

    if ([string]::IsNullOrEmpty($person.Name.Initials)) {
        $initials = $person.Name.Initials
    }
    else {
        $initials = $person.Name.Initials[0..9] -join ""        # Max 10 chars
    }

    if ([string]::IsNullOrEmpty($person.Name.FamilyNamePrefix)) {
        $prefix = ""
    }
    else {
        $prefix = $person.Name.FamilyNamePrefix + " "
    }

    if ([string]::IsNullOrEmpty($person.Name.FamilyNamePartnerPrefix)) {
        $partnerPrefix = ""
    }
    else {
        $partnerPrefix = $person.Name.FamilyNamePartnerPrefix + " "
    }

    $AeosSurname = switch ($person.Name.Convention) {
        "B" { $person.Name.FamilyName }
        "BP" { $person.Name.FamilyName + " - " + $partnerprefix + $person.Name.FamilyNamePartner }
        "P" { $person.Name.FamilyNamePartner }
        "PB" { $person.Name.FamilyNamePartner + " - " + $prefix + $person.Name.FamilyName }
        default { $prefix + $person.Name.FamilyName }
    }

    $AeosPrefix = switch ($person.Name.Convention) {
        "B" { $prefix }
        "BP" { $prefix }
        "P" { $partnerPrefix }
        "PB" { $partnerPrefix }
        default { $prefix }
    }

    $output = [PSCustomObject]@{
        prefixes = $AeosPrefix
        surname  = $AeosSurname
        initials = $Initials
    }
    Write-Output $output
}

## Account mapping
$account = [PSCustomObject]@{
    Id              = $aRef                                      # correlation attribute
    # ArrivalDateTime = $null                                   # 2018-11-25T15:44:07 <!-- XSD DateTime data type format -->
    # LeaveDateTime   = $null                                     # 2049-06-09T17:15:04+02:00 <!-- UTC+2 -->
    LastName        = (New-AeosName -Person $p).surname         # <!-- String, max. 50 characters -->
    PersonnelNo     = $p.ExternalId                             # <!-- String, max. 50 characters -->
    FirstName       = $p.Name.GivenName                         # <!-- String, max. 40 characters -->
    MiddleName      = (New-AeosName -Person $p).prefixes
    Gender          = "Unknown"                                 # <!-- Male, Female, Unknown -->
    Email           = $p.Accounts.MicrosoftActiveDirectory.mail # <!-- String, max. 128 characters -->
    Language        = "nl"                                      # <!-- ar, de, dk, en, es, fa, fr, it, iw, nl, no, pl, pt, ru, sv,zh_CN --> <!-- String, max. 12 characters (but most are unused) -->
    # NetworkId       = $null                                   # autogenerated?
    # CarrierType     = $null                                   # autogenerated?
    # UnitId          = $null                                   # autogenerated?
    # NrMovements     = $null
    # ReadOnly        = $null
    # FreeField       = $null                                   # list of objects with free fields {DefinitionId,Name,Value}, currently not supported in this connector
    # Title           = $null                                   # <!-- String, max. 25 characters -->
    # PhoneNo         = $null                                   # <!-- String, max. 25 characters -->  <!-- Do not use spaces or hyphens if dialers (such as SMS servers)  need to process this phone number. -->
    # MobilePhoneNo   = $null                                   # <!-- String, max. 25 characters -->
    # ContactPersonId = $null                                   # <!-- Long. You can find this ID with findPerson -->
    # DepartmentId    = $null                                   # <!-- Long. You can find this ID with findDepartment -->
}

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($config.IsDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

#region functions
function Get-CurrentAccount {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject] $Account,

        [Parameter(Mandatory)]
        [PSCustomObject] $EmployeeInfo

    )
    $CurrentAccount = [PSCustomObject]@{}

    $null = $Account.PSObject.Properties.foreach{ $CurrentAccount | Add-Member -MemberType NoteProperty  -Name $($_.Name) -Value  $EmployeeInfo.$($_.Name) }
    write-output $CurrentAccount

}
function New-SoapbodyChangeEmployee {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject] $Account,

        [Parameter(Mandatory)]
        [PSCustomObject] $propertiesChanged
    )
    $root = "sch:EmployeeChange"
    # Id property is always required as this specifies the object to change, other properties only when changed
    Write-output ('<{1}>{0}</{1}>' -f $( $Account.PSObject.Properties.foreach{ if ($_.Name -eq "Id" -or ($_.Name -in $propertiesChanged.Name) ) { '  <sch:{0}>{1}</sch:{0}>' -f $_.Name, $_.Value } } -join "`n") , $root)
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
                Uri         = $Uri
                Method      = $Method
                ContentType = $ContentType
                Body        = $BodySB.ToString()
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
            if ( [string]::IsNullOrWhiteSpace($streamReaderResponse)) {
                $httpErrorObj.ErrorDetails = $ErrorObject.Exception.Message
            }
            else {
                $httpErrorObj.ErrorDetails = $streamReaderResponse
            }
        }

        if ($ErrorObject.FriendlyMessage -like "*500 Internal Server Error*") {
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
    $employeeInfo = $null;
    if ($null -ne $Response.Envelope.Body) {
        foreach ($Item in  $Response.Envelope.Body.EmployeeList) {
            if ($Item.employee.EmployeeInfo.Id -eq $account.Id) {
                $employeeInfo = $Item.employee.EmployeeInfo
                break
            }
        }
    }
    if ($null -eq $EmployeeInfo) {
        throw "Nedap-AEOS account for: [$($p.DisplayName)] not found. Possibily deleted"
    }
    $currentAccount = Get-CurrentAccount -Account $account -EmployeeInfo $employeeInfo


    # Always compare the account against the current account in target system

    $splatCompareProperties = @{
        ReferenceObject  = @($currentAccount.PSObject.Properties)
        DifferenceObject = @($account.PSObject.Properties)
    }
    $propertiesChanged = (Compare-Object @splatCompareProperties -PassThru).Where({ $_.SideIndicator -eq '=>' -and ($_.name -ne 'Id') })
    if (($null -ne $propertiesChanged) -and ($propertiesChanged.count -ne 0)) {
        $action = 'Update'
        $dryRunMessage = "Account property(s) required to update: [$($propertiesChanged.name -join ",")]"
    }
    elseif (-not($propertiesChanged)) {
        $action = 'NoChanges'
        $dryRunMessage = 'No changes will be made to the account during enforcement'
    }

    Write-Verbose $dryRunMessage

    # Add an auditMessage showing what will happen during enforcement
    if ($dryRun -eq $true) {
        Write-Warning "[DryRun] $dryRunMessage"
    }

    # Process
    if (-not($dryRun -eq $true)) {
        switch ($action) {
            'Update' {
                Write-Verbose "Updating Nedap-AEOS account with accountReference: [$aRef]"
                $soapbody = New-SoapbodyChangeEmployee -Account $account -propertiesChanged $propertiesChanged
                $response = Invoke-Nedap-AEOSRestMethod -SoapBody $soapbody

                $success = $true
                $auditLogs.Add([PSCustomObject]@{
                        Message = 'Update account was successful'
                        IsError = $false
                    })
                break
            }

            'NoChanges' {
                Write-Verbose "No changes to Nedap-AEOS account with accountReference: [$aRef]"

                $success = $true
                $auditLogs.Add([PSCustomObject]@{
                        Message = 'No changes where required for the account'
                        IsError = $false
                    })
                break
            }
        }
    }
}
catch {
    $success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-Nedap-AEOSError -ErrorObject $ex
        $auditMessage = "Could not update Nedap-AEOS account. Error: $($errorObj.FriendlyMessage)"
        Write-Verbose "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    }
    else {
        $auditMessage = "Could not update Nedap-AEOS account. Error: $($ex.Exception.Message)"
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
        Success   = $success
        Account   = $account
        Auditlogs = $auditLogs
    }
    Write-Output $result | ConvertTo-Json -Depth 10
}
