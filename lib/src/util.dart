// Copyright (c) 2018-2024, Denis Portnov. All rights reserved.
// Released under MIT License that can be found in the LICENSE file.

import 'generators.dart';
import 'uuid.dart';

/// Canonical instance of UUID utility class
const uuid = UuidUtil._();

/// UUID utility class for convenient UUID string generation
class UuidUtil {
  static TimeUuidGenerator? _timeGen;

  static RandomUuidGenerator? _randGen;

  static UuidV6Generator? _v6Gen;

  static UuidV7Generator? _v7Gen;

  const UuidUtil._();

  /// Generates time-based UUID string
  String v1() {
    _timeGen ??= TimeUuidGenerator();

    return _timeGen!.generate().toString();
  }

  /// Generates random-based UUID string
  String v4() {
    _randGen ??= RandomUuidGenerator();

    return _randGen!.generate().toString();
  }

  /// Generates name-based UUID string
  String v5(String namespace, String name) {
    return NameUuidGenerator(Uuid.parse(namespace)).generateFromString(name).toString();
  }

  /// Generates a time-ordered UUIDv6 string.
  String v6() {
    _v6Gen ??= UuidV6Generator();

    return _v6Gen!.generate().toString();
  }

  /// Generates a time-ordered UUIDv7 string.
  String v7() {
    _v7Gen ??= UuidV7Generator();

    return _v7Gen!.generate().toString();
  }

  /// Compares to UUID strings
  int compare(String uuid1, String uuid2) {
    return Uuid.parse(uuid1).compareTo(Uuid.parse(uuid2));
  }
}
