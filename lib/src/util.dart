// Copyright (c) 2018-2020, Denis Portnov. All rights reserved.
// Released under MIT License that can be found in the LICENSE file.

library uuid_type.util;

import 'dart:typed_data' show Uint8List;

import 'generators.dart';
import 'uuid.dart';

/// Canonical instance of UUID utility class
final uuid = UuidUtil._();

/// UUID utility class for convinient UUID string gemeration
class UuidUtil {
  const UuidUtil._();

  /// Generates time-based UUID string
  String v1([Uint8List? nodeId]) {
    return TimeBasedUuidGenerator(nodeId).generate().toString();
  }

  /// Generates random-based UUID string
  String v4() {
    return RandomBasedUuidGenerator().generate().toString();
  }

  /// Generates name-based UUID string
  String v5(String namespace, String name) {
    return NameBasedUuidGenerator(Uuid(namespace)).generate(name).toString();
  }

  /// Compares to UUID strings
  int compare(String uuid1, String uuid2) {
    return Uuid(uuid1).compareTo(Uuid(uuid2));
  }
}
