
# HelloID-Conn-Prov-Target-Nedap-AEOS

| :information_source: Information |
|:---------------------------|
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements. |

<p align="center">
  <img src="assets/nedap-aeos.jpg">
</p>

## Table of contents

- [HelloID-Conn-Prov-Target-Nedap-AEOS](#helloid-conn-prov-target-nedap-aeos)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Getting started](#getting-started)
    - [Connection settings](#connection-settings)
    - [Prerequisites](#prerequisites)
    - [Remarks](#remarks)
  - [Setup the connector](#setup-the-connector)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Target-Nedap-AEOS_ is a _target_ connector. Nedap-AEOS provides a set of SOAP API's that allow you to programmatically interact with its data. The HelloID connector uses the API endpoints listed in the table below.

| Endpoint                  | Description |
|---	 |---	|
|addEmployee                | Create an employee           |
|changeEmployee             | update an employee |
|findEmployee               | Search for an employee |
|findCarrierToken           | Search for badges assigned to an employee |
|withdrawCarrierToken       | removes an assiged badge from an employee |
|findTemplate               | lists the available authorization  templates  |
|addCarrierAuthorizations   | assigns an authorization template to an employee           |
|removeCarrierAuthorizations  | removes an authorization template assignment from an employee            |

The following lifecycle events are available:

| Event  | Description | Notes |
|---	 |---	|---	|
| create.ps1 | Create (or update) and correlate an Account | - |
| update.ps1 | Update the Account | - |
| enable.ps1 | Enable the Account | - |
| disable.ps1 | Disable the Account | - |
| delete.ps1 | This is not available/supported in the current connector


## Getting started

### Connection settings

The following settings are required to connect to the API.

| Setting      | Description                        | Mandatory   |
| ------------ | -----------                        | ----------- |
| UserName     | The UserName to connect to the API | Yes         |
| Password     | The Password to connect to the API | Yes         |
| BaseUrl      | The URL to the API https://`<server ip`>/aeosws | Yes         |
| IsDebug      | to enable/disable the debug logging |

### Prerequisites
No special Prerequisites.

### Remarks
- This connector uses the explicit SOAP messages from the wsdl rather than the function names from de wsdl.
- All api calls may require the fields to be in a specific order so do not change the order of the fields in the $account object.
- Create Account will correlate the employee account with `findEmployee` based on the `PersonnelNo` field, and create (addEmployee) or update (changeEmployee) the employee account as required. The account reference used by HelloId is the `Id` field of the employee. The `ArrivalDateTime` is set to the far future in order to create the account as disabled.
- Enable Account uses `changeEmployee` endpoint and sets the `ArrivalDateTime` to the current time and `LeaveDateTime` to the far future (because in cannot clear the leaveDateTime).
- Disable Account uses `changeEmployee` endpoint and sets the  `LeaveDateTime` to the current time. It also uses `FindCarrierToken` and `withdrawCarrierToken` to remove any badges from the account.
- Delete account is not implemented as part of the life cycle of the account.
- Badges are only removed from the account when disabling. Creating and assigning badges
(Carrier tokens) is not part of this implementation.
- Permissions are based on the available Permission Templates in AEOS. The permissions script collects a list of available Templates, and the grant en revoke scripts will add/remove (`addCarrierAuthorizations` and `removeCarrierAuthorizations`) an permission template to/from an Employee.

- Nedap AEOS Issue found: A template can be assigned multiple times to a single user. Which can cause a problem with revoking the template: *Could not revoke Nedap-AEOS account. Error: TemplateId [305] is multiple times assigned to User. Stop Processing!*
  Note that this should not occur under normal operation, unless manual assignments are made outside of HelloId

  Here is a code example how one might automatically remove one of the templates by adding the from date to specify a specific template
```powershell
    # $auditLogs.Add([PSCustomObject]@{
    #    Message = "Revoke Nedap-AEOS entitlement: [$($pRef.DisplayName)] was Partial successful"
    #    IsError = $true
    # })
    # [xml]$bodyRemoveAuth = '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:sch="http://www.nedap.com/aeosws/schema">
    # <soapenv:Header/>
    # <soapenv:Body>
    #    <sch:ProfileRemove>
    #       <sch:CarrierId></sch:CarrierId>
    #       <sch:AuthorisationOnlineId>
    #          <sch:TemplateAuthorisation>
    #             <sch:TemplateId></sch:TemplateId>
    #             <sch:DateFrom>{0}</sch:DateFrom>
    #          </sch:TemplateAuthorisation>
    #       </sch:AuthorisationOnlineId>
    #    </sch:ProfileRemove>
    # </soapenv:Body>
    # </soapenv:Envelope>
    # ' -f ($templates | Select-Object -First 1).DateFrom
```


A new functionality is the possibility to update the account in the target system during the correlation process. By default, this behavior is disabled. Meaning, the account will only be created or correlated.

You can change this behavior in the `create.ps1` by setting the boolean `$updatePerson` to the value of `$true`.

> Be aware that this might have unexpected implications.

## Setup the connector

No special configuration required

## Getting help
>  For extended information about the api of AEOS see the `aeos_soap_webservice_icm_en.pdf` document in this repo

> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012558020-Configure-a-custom-PowerShell-target-system) pages_

> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/
