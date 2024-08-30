# UUID type for Dart
[![Build Status](https://travis-ci.org/denixport/dart-uuid.svg?branch=master)](https://travis-ci.org/denixport/dart-uuid)
![Pub](https://img.shields.io/pub/vpre/uuid_type.svg)
![GitHub](https://img.shields.io/github/license/denixport/dart-uuid.svg)

This package provides implementation of Universally Unique Identifier 
([UUID](https://en.wikipedia.org/wiki/Universally_unique_identifier)) for Dart, 
and supports generation, parsing and formatting of UUIDs.
 
Features:
* [x] Creates UUID from string and byte-array, as well as GUID and URN strings
* [x] Provides access to variant, version and byte data of UUID
* [x] Generates RFC4122 version 1, version 4, or version 5 UUIDs
* [x] Implements `Comparable` for UUID comparison and lexicographical sorting
* [x] Runs in web, server, and flutter

RFC Version support:
- [x] v1, based on timestamp and MAC address
- [ ] v2, based on timestamp, MAC address and POSIX UID/GID (DCE 1.1) **Not planned**
- [ ] v3, based on MD5 hashing **Not planned**
- [x] v4, based on random numbers
- [x] v5, based on SHA-1 hashing
- [ ] v6, A re-ordering of UUID version 1 so it is sortable as an opaque sequence of bytes
- [ ] v7, An entirely new time-based UUID bit layout sourced from the widely implemented and well known Unix Epoch timestamp source
- [ ] v8, A free-form UUID format which has no explicit requirements except maintaining backward compatibility.

## Requirements
- Dart SDK >= 2.12.0
- `crypto` package 

## Getting Started

### Installation
1. Add an entry in your `pubspec.yaml` for `uuid_type`
```yaml
dependencies:
  uuid_type: ^2.1.0
```
2. Run `pub get` (`flutter packages get` for Flutter)
3. Import
```dart
import 'package:uuid_type/uuid_type.dart';
```

### Usage
Generate UUIDs
```dart
import 'package:uuid_type/uuid_type.dart';

void main() {
  var u = TimeUuidGenerator().generate();
  print(u.toString());

  u = NameUuidGenerator(NameUuidGenerator.urlNamespace).generateFromString('https://dart.dev/');
  print(u.toString());

  u = RandomUuidGenerator().generate();
  print(u.toString());
}
```

See more [examples](example/main.dart) and 
[Documentation](https://pub.dartlang.org/documentation/uuid_type/latest/)

## Release notes
See [CHANGELOG](CHANGELOG.md)

## Features and Bugs
Please file bugs and feature requests at the [issue tracker][tracker].

[tracker]: https://github.com/denixport/dart-uuid/issues
