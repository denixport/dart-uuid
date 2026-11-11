# UUID type for Dart

[![CI](https://github.com/denixport/dart-uuid/actions/workflows/ci.yml/badge.svg)](https://github.com/denixport/dart-uuid/actions/workflows/ci.yml)
[![pub package](https://img.shields.io/pub/v/uuid_type.svg)](https://pub.dev/packages/uuid_type)
![License](https://img.shields.io/github/license/denixport/dart-uuid.svg)

This package provides implementation of Universally Unique Identifier 
([UUID](https://en.wikipedia.org/wiki/Universally_unique_identifier)) for Dart, 
and supports generation, parsing and formatting of UUIDs.
 
## Features

* [x] Creates UUIDs from strings and byte arrays, including GUID and URN strings
* [x] Provides access to UUID variant, version, and byte data
* [x] Generates RFC 9562 versions 1, 4, and 5 UUIDs
* [x] Implements `Comparable` for UUID comparison and lexicographical sorting
* [x] Runs on the web, server, and Flutter

### RFC version support

- [x] v1, based on timestamp and MAC address
- [ ] v2, based on timestamp, MAC address and POSIX UID/GID (DCE 1.1) **Not planned**
- [ ] v3, based on MD5 hashing **Not planned**
- [x] v4, based on random numbers
- [x] v5, based on SHA-1 hashing
- [ ] v6, A re-ordering of UUID version 1 so it is sortable as an opaque sequence of bytes
- [ ] v7, An entirely new time-based UUID bit layout sourced from the widely implemented and well known Unix Epoch timestamp source
- [ ] v8, A free-form UUID format which has no explicit requirements except maintaining backward compatibility.

## Requirements

- Dart SDK ^3.8.0
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
[documentation](https://pub.dev/documentation/uuid_type/latest/).

## Release notes
See [CHANGELOG](CHANGELOG.md)

## Features and Bugs

Please file bugs and feature requests at the [issue tracker][tracker].

[tracker]: https://github.com/denixport/dart-uuid/issues
