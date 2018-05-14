// Copyright (c) 2018, Denis Portnov. All rights reserved.
// Released under MIT License that can be found in the LICENSE file.

library uuid_type.generators;

import 'dart:convert' show utf8;
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

import 'uuid.dart';

/// Generator for namespace and name-based UUIDs (v5)
/// Only SHA1 algo is supported, MD5 is deprecated
class NameBasedUuidGenerator {
  static final _byteBuffer = new Uint8List(16);

  /// [Hash] instance, only [hash.sha1] is allowed.
  final Hash hash;

  /// UUID namespace
  final Uuid namespace;

  NameBasedUuidGenerator(this.namespace) : this.hash = sha1;

  /// Generates namespace + name-based v5 UUID
  /// If [namespace] is not provided will use [defaultNamespace]
  /// If [defaultNamespace] is not set will throw [StateError]
  Uuid generate(String name) {
    assert(name != null);

    var h = hash.convert(namespace.bytes + utf8.encode(name)).bytes;
    assert(h.length >= 16);
    for (int i = 0; i < 16; ++i) {
      _byteBuffer[i] = h[i];
    }

    _byteBuffer[8] = (_byteBuffer[8] & 0xBF) | 0x80; // variant 1
    _byteBuffer[6] = (_byteBuffer[6] & 0x0F) | 0x50; // version 5

    return new Uuid.fromBytes(_byteBuffer);
  }
}

/// Generator for random-based UUIDs (v4)
class RandomUuidGenerator {
  static final _byteBuffer = new Uint8List(16);

  final Random rng;

  /// Creates instance of generator
  ///
  /// By default it uses secure random generator provided by [math]
  /// [math.Random] can be provided as custom RNG
  RandomUuidGenerator([Random rng]) : this.rng = rng ?? new Random.secure();

  /// Generates random UUID
  Uuid generate() {
    int u32;
    for (int i = 0; i < 4; i++) {
      u32 = rng.nextInt(0xFFFFFFFF);

      _byteBuffer[i * 4] = (u32 >> 24);
      _byteBuffer[i * 4 + 1] = (u32 >> 16);
      _byteBuffer[i * 4 + 2] = (u32 >> 8);
      _byteBuffer[i * 4 + 3] = u32;
    }

    _byteBuffer[8] = (_byteBuffer[8] & 0x3F) | 0x80; // variant 1
    _byteBuffer[6] = (_byteBuffer[6] & 0x0F) | 0x40; // version 4

    return new Uuid.fromBytes(_byteBuffer);
  }
}