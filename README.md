# UUID type for Dart 2
[![Build Status](https://travis-ci.org/denixport/dart-uuid.svg?branch=master)](https://travis-ci.org/denixport/dart-uuid)
![Pub](https://img.shields.io/pub/vpre/uuid_type.svg)
![GitHub](https://img.shields.io/github/license/denixport/dart-uuid.svg)

This package provides implementation of Universally Unique Identifier 
([UUID](https://en.wikipedia.org/wiki/Universally_unique_identifier)) for Dart, 
and supports generation, parsing and formatting of UUIDs.
 
Features:
* [x] Creates UUID from string and byte-array, as well as GUID and URN strings
* [x] Provides access to variant, version and byte data of UUID
* [x] Generates RFC4122 time-based v1, random-based v4, and namespace & name-based v5 UUIDs
* [x] Implements `Comparable` for UUID comparison and lexicographical sorting
* [x] Runs on Dart VM and in browser

RFC 4122 Version support:
- [x] v1, based on timestamp and MAC address (RFC 4122)
- [ ] v2, based on timestamp, MAC address and POSIX UID/GID (DCE 1.1) **Not planned**
- [ ] v3, based on MD5 hashing (RFC 4122) **Not planned**
- [x] v4, based on random numbers (RFC 4122)
- [x] v5, based on SHA-1 hashing (RFC 4122)

## Requirements
- Dart 2 (tested with >=2.0.0). Should also work with Dart 1.24, but not tested.
- `crypto` package to generate name based UUIDs

## Getting Started

### Installation
1. Add an entry in your `pubspec.yaml` for `uuid_type`
```yaml
dependencies:
  uuid_type: ^1.0.0
```
2. Run `pub get` (`flutter packages get` for Flutter)
3. Import
```dart
import 'package:uuid_type/uuid_type.dart';
```

### Usage
[API](https://pub.dartlang.org/documentation/uuid_type/latest/)

## Release notes
See [CHANGELOG](CHANGELOG.md)

## Features and Bugs
Please file bugs and feature requests at the [issue tracker][tracker].


[tracker]: https://github.com/denixport/dart-uuid/issues
