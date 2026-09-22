# Change Log

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com), and this project adheres to [Semantic Versioning](https://semver.org).

## [1.0.3] - 14-09-2026

### Added
- support for freefields
- support for resolving departmentId using departmentName
- support for KeyCabinet authorization template (untested)
- supportscript for retrieving definitionId's

### Changed
- moved withdrawal of carrier token(s) to the delete event instead of disable event

### Fixed
- in the update event, make sure the Id is supplied correctly

## [1.0.2] - 15-12-2025

### Fixed
 - If a users has more then one badge (carrier), the code didn't work.

## [1.0.1] - 10-03-2026

Small adjustments after implementation of this connector after drycoded conversion to PSV2. 

### Added
- import scripts (accounts & permissions)
    - added paging because the SOAP endpoint only returns 1000 records

### Changed
- import permissions script
    - fixed script, didn't produce any results. Join on templateAuthorization was incorrect. Interpretation of the data was incorrect.
- readme
    - changed icon url to use the icon in this repository
    - removed reference to forum

## [1.0.0] - 15-12-2025

This is the first official release of _HelloID-Conn-Prov-Target-Nedap-AEOS_. This release is based on template version _v3.2.0_.

### Added

### Changed

### Deprecated

### Removed