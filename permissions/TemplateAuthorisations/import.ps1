####################################################################
# HelloID-Conn-Prov-Target-Nedap-AEOS-ImportPermissions-TemplateAuthorisation
# PowerShell V2
####################################################################

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

try {
    Write-Information 'Starting Nedap-AEOS permission TemplateAuthorisation entitlement import'

    # Setup credentials
    $securePassword = $actionContext.Configuration.Password | ConvertTo-SecureString -AsPlainText -Force
    $credential = [System.Management.Automation.PSCredential]::new($actionContext.Configuration.UserName, $securePassword)

    # Get all Permissions/Templates (details)
    $body = "<sch:TemplateSearchInfo><sch:TemplateInfo><sch:UnitOfAuthType>OnLine</sch:UnitOfAuthType></sch:TemplateInfo></sch:TemplateSearchInfo>"
    $response = Invoke-NedapAEOSRestMethod -Uri $actionContext.Configuration.BaseUrl -SoapBody $body -Credential $credential
    $permissionDetails = $response.Envelope.Body.TemplateList.Template
    $permissionDetailsGrouped = $permissionDetails | Group-Object -Property id -AsHashTable -AsString

    # Get all Employees

    # AEOS returns maximum of 1000 accounts per call, if there are more accounts in AEOS, pagination is needed. 
    $existingAccounts = @()
    $startRecordNo = 0
    $nrOfRecords = 1000

    do {
        $soapBody = "<sch:EmployeeSearchInfo><sch:EmployeeInfo></sch:EmployeeInfo><sch:SearchRange><sch:startRecordNo>$startRecordNo</sch:startRecordNo><sch:nrOfRecords>$nrOfRecords</sch:nrOfRecords></sch:SearchRange></sch:EmployeeSearchInfo>"
        $response = Invoke-NedapAEOSRestMethod -Uri $actionContext.Configuration.BaseUrl -SoapBody $soapBody -Credential $credential
        $importedAccounts = $response.Envelope.Body.EmployeeList.Employee.EmployeeInfo
        $existingAccounts += $importedAccounts
        $startRecordNo += $nrOfRecords
    } while ($importedAccounts.Count -eq $nrOfRecords)

    # Iterate through Employees and get their permissions
    foreach ($importedAccount in $existingAccounts) {
        $bodyGetCarrierProfiles = "<sch:CarrierIdProfile>$($importedAccount.id)</sch:CarrierIdProfile>"
        $responseCarrierIdProfile = Invoke-NedapAEOSRestMethod -Uri $actionContext.Configuration.BaseUrl -SoapBody $bodyGetCarrierProfiles -Credential $credential

        foreach ($importedPermission in $responseCarrierIdProfile.Envelope.Body.ProfileResult.AuthorisationOnline.TemplateAuthorisation) {
            Write-Information "Found TemplateId: $($importedPermission.TemplateId) for CarrierId: $($importedAccount.id)"
            $templateDetails = $permissionDetailsGrouped["$($importedPermission.TemplateId)"]
            $permission = @{
                PermissionReference = @{
                    Reference = "$($importedPermission.TemplateId)"
                }
                Description         = "$($templateDetails.Description)"
                DisplayName         = "$($templateDetails.Name)"
                AccountReferences   = @($importedAccount.id)
            }
            Write-Output $permission
        }
    }
    Write-Information 'Nedap-AEOS permission TemplateAuthorisation entitlement import completed'
} catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-NedapAEOSError -ErrorObject $ex
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
        Write-Error "Could not import Nedap-AEOS permission TemplateAuthorisation entitlements. Error: $($errorObj.FriendlyMessage)"
    } else {
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        Write-Error "Could not import Nedap-AEOS permission TemplateAuthorisation entitlements. Error: $($ex.Exception.Message)"
    }
}