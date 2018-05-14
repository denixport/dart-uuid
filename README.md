# UUID type for Dart 2 [WIP]
[![Build Status](https://travis-ci.org/denixport/dart-uuid.svg?branch=master)](https://travis-ci.org/denixport/dart-uuid)

**Not yet tested for production use!**

This package provides implementation of Universally Unique Identifier ([UUID](https://en.wikipedia.org/wiki/Universally_unique_identifier)). 
Supported both creation and parsing of UUIDs.
 
Features:
* [x] Creates UUID from string and byte-array representations
* [x] Provides access to variant, version and byte representation of UUID
* [ ] Generates RFC4122 version 1 UUIDs
* [x] Generates RFC4122 version 4 UUIDs
* [x] Generates RFC4122 version 5 UUIDs (SHA-1 only)
* [x] Implements `Comparable` for UUID comparison and lexicographical sorting
* [x] Overrides `hashCode` and `==` operator for usage as `Map` keys
* [x] Runs on Dart VM and in browser

UUID Version support:
- [ ] v1, based on timestamp and MAC address (RFC 4122) **[WIP]**
- [ ] v2, based on timestamp, MAC address and POSIX UID/GID (DCE 1.1) **Not planned**
- [ ] v3, based on MD5 hashing (RFC 4122) **Not planned**
- [x] v4, based on random numbers (RFC 4122)
- [x] v5, based on SHA-1 hashing (RFC 4122)

## Requirements
- Dart 2 (tested with >=2.0.0-dev.50.0). Should also work with Dart 1.24, but not tested.
- `crypto` package

## Getting Started

### Installation
1. Add an entry in your `pubspec.yaml` for `uuid_type`
```yaml
dependencies:
  uuid_type: ^0.6.0
```
2. Run `pub install`

## Usage

## API
[TBD]

## Examples
[TBD]
