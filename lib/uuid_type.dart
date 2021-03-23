// Copyright (c) 2018-2021, Denis Portnov. All rights reserved.
// Released under MIT License that can be found in the LICENSE file.

library uuid_type;

/// This library provides UUID type for Dart. It allows you to read UUID from
/// string and binary representations, use it as `Map` key,
/// compare and sort UUIDs and generate variants of UUID as defined in
/// [RFC 4122](https://tools.ietf.org/html/rfc4122)

export 'src/generators.dart';
export 'src/util.dart';
export 'src/uuid.dart';
