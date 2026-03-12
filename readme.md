# HelloID-Conn-Prov-Target-Nedap-AEOS

> [!IMPORTANT]
> This connector has been upgraded from version 1 to a PowerShell v2 connector without access to a test environment. As a result, the code could not be tested on an actual system and should be treated accordingly.

> [!IMPORTANT]
> This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.

<p align="center">
  <img src="https://www.tools4ever.nl/assets/connectors/helloid-conn-prov-target-nedap-aeos.png">
</p>

## Table of contents

- [HelloID-Conn-Prov-Target-Nedap-AEOS](#helloid-conn-prov-target-nedap-aeos)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Supported features](#supported-features)
  - [Getting started](#getting-started)
    - [HelloID Icon URL](#helloid-icon-url)
    - [Requirements](#requirements)
    - [Connection settings](#connection-settings)
    - [Correlation configuration](#correlation-configuration)
    - [Field mapping](#field-mapping)
    - [Account Reference](#account-reference)
  - [Remarks](#remarks)
    - [Account lifecycle](#account-lifecycle)
    - [Permissions](#permissions)
    - [Field order requirement](#field-order-requirement)
    - [Known AEOS API issues](#known-aeos-api-issues)
  - [Development resources](#development-resources)
    - [API endpoints](#api-endpoints)
    - [API documentation](#api-documentation)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Target-Nedap-AEOS_ is a _target_ connector. _Nedap-AEOS_ provides a set of SOAP API's that allow you to programmatically interact with its data. The HelloID connector uses explicit SOAP messages to communicate with the AEOS web service.

## Supported features

The following features are available:

| Feature                                   | Supported | Actions                         | Remarks                          |
| ----------------------------------------- | --------- | ------------------------------- | -------------------------------- |
| **Account Lifecycle**                     | ✅         | Create, Update, Enable, Disable |                                  |
| **Permissions**                           | ✅         | Retrieve, Grant, Revoke         | Based on authorization templates |
| **Resources**                             | ❌         | -                               |                                  |
| **Entitlement Import: Accounts**          | ✅         | -                               |                                  |
| **Entitlement Import: Permissions**       | ✅         | -                               |                                  |
| **Governance Reconciliation Resolutions** | ✅         | -                               |                                  |

## Getting started

### HelloID Icon URL
URL of the icon used for the HelloID Provisioning target system.
```
https://raw.githubusercontent.com/Tools4everBV/HelloID-Conn-Prov-Target-Nedap-AEOS/refs/heads/main/Icon.png
```

### Requirements

- **SOAP Web Service Access**: The Nedap AEOS SOAP web service must be enabled and accessible.
- **Valid Credentials**: A valid username and password with appropriate permissions to manage employees and authorization templates.

### Connection settings

The following settings are required to connect to the API.

| Setting  | Description                                                  | Mandatory |
| -------- | ------------------------------------------------------------ | --------- |
| UserName | The UserName to connect to the SOAP API                      | Yes       |
| Password | The Password to connect to the SOAP API                      | Yes       |
| BaseUrl  | The URL to the SOAP API (e.g., https://`<server ip>`/aeosws) | Yes       |

### Correlation configuration

The correlation configuration is used to specify which properties will be used to match an existing account within _Nedap-AEOS_ to a person in _HelloID_.

| Setting                   | Value         |
| ------------------------- | ------------- |
| Enable correlation        | `True`        |
| Person correlation field  | `ExternalId`  |
| Account correlation field | `PersonnelNo` |

> [!TIP]
> _For more information on correlation, please refer to our correlation [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems/correlation.html) pages_.

### Field mapping

The field mapping can be imported by using the _fieldMapping.json_ file.

> [!IMPORTANT]
> The AEOS API requires fields to appear in a specific order in the SOAP XML. The connector preserves this order using a custom sorting function.

### Account Reference

The account reference is populated with the `Id` property from _Nedap-AEOS_ (the employee ID).

## Remarks
> [!IMPORTANT]
> The import functionality for Account Access should not be used when taking this connector into production. The enable action should be executed because only then the LeaveDateTime will be set for the existing accounts. Otherwise the extensions of the contracts are not handled correctly. The LeaveDateTime is **only** set in the enable and disable event of the lifecycle. 

### Account lifecycle

- **Create Account**: The connector creates accounts in a disabled state by setting the `ArrivalDateTime` to a date far in the future (2099-01-01). The `Id` field is auto-generated by AEOS.
- **Update Account**: The connector compares the current account with the desired state and only updates changed properties.
- **Enable Account**: Sets the `ArrivalDateTime` to the current time and `LeaveDateTime` to a far future date. The `LeaveDateTime` cannot be cleared, so it's set to a far future date instead.
- **Disable Account**: Sets the `LeaveDateTime` to the current time and withdraws all carrier tokens (badges) from the employee.
- Badges are only removed from the account when disabling. Creating and assigning badges
- **Delete Account**: Delete account is not implemented as part of the life cycle of the account.



### Permissions
Permissions are based on authorization templates in AEOS:
- The permissions script retrieves all OnLine authorization templates using the `findTemplate` endpoint with `UnitOfAuthType=OnLine`.
- Grant permission assigns an authorization template to an employee using the `addCarrierAuthorizations` endpoint.
- Revoke permission removes an authorization template assignment using the `removeCarrierAuthorizations` endpoint.
- The connector checks if a template is already assigned before granting or already removed before revoking.

### Field order requirement

The AEOS SOAP API is sensitive to field order in the XML. The connector uses PowerShell objects where properties are defined in a specific order. Do not reorder fields in the account object as this may cause API errors.

### Known AEOS API issues

- **Duplicate Template Assignments**: AEOS may allow the same authorization template to be assigned multiple times to a single user. When this occurs, the connector cannot determine which assignment to revoke and will throw an error. This should not occur during normal HelloID operation but may happen if manual assignments are made outside of HelloID.
- **LeaveDateTime Cannot Be Cleared**: When enabling an account, the `LeaveDateTime` field cannot be cleared, so it's set to a far future date (2099-01-01).


  Here is a code example how one might automatically remove one of the templates by adding the from date to specify a specific template
```powershell
  $auditLogs.Add([PSCustomObject]@{
    Message = "Revoke Nedap-AEOS entitlement: [$($pRef.DisplayName)] was Partial successful"
    IsError = $true
  })
  [xml]$bodyRemoveAuth = '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/ap/envelope/" xmlns:sch="http://www.nedap.com/aeosws/schema">
  <soapenv:Header/>
  <soapenv:Body>
    <sch:ProfileRemove>
        <sch:CarrierId></sch:CarrierId>
        <sch:AuthorisationOnlineId>
          <sch:TemplateAuthorisation>
              <sch:TemplateId></sch:TemplateId>
              <sch:DateFrom>{0}</sch:DateFrom>
          </sch:TemplateAuthorisation>
        </sch:AuthorisationOnlineId>
    </sch:ProfileRemove>
  </soapenv:Body>
  </soapenv:Envelope>
  ' -f ($templates | Select-Object -First 1).DateFrom
```

## Development resources

### API endpoints

The following SOAP operations are used by the connector:

| Endpoint (SOAP action) | Description                                      |
| ---------------------- | ------------------------------------------------ |
| EmployeeAdd            | Create a new employee                            |
| EmployeeChange         | Update an existing employee                      |
| EmployeeSearchInfo     | Search for employees                             |
| CarrierIdProfile       | Retrieve carrier profile (for permission checks) |
| CarrierIdToken         | Find carrier tokens (badges) assigned to a user  |
| IdentifierWithdraw     | Withdraw (remove) a carrier token from a user    |
| TemplateSearchInfo     | Search for authorization templates               |
| ProfileAdd             | Add authorization template to an employee        |
| ProfileRemove          | Remove authorization template from an employee   |

### API documentation

The AEOS SOAP Web Service documentation is available as a PDF from Nedap. Contact your Nedap or Tools4ever representative or check the AEOS documentation for `aeos_soap_webservice_icm_en.pdf`.

## Getting help

> [!TIP]
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html) pages_.


## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/

> [!TIP]
> _For more information on correlation, please refer to our correlation [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems/correlation.html) pages_.
