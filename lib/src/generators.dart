// Copyright (c) 2018-2019, Denis Portnov. All rights reserved.
// Released under MIT License that can be found in the LICENSE file.

library uuid_type.generators;

import 'dart:convert' show utf8;
import 'dart:math' show Random;
import 'dart:typed_data' show Uint8List;
import 'package:crypto/crypto.dart' show Hash, sha1;
import 'uuid.dart';

final Uint8List _byteBuffer = new Uint8List(16);
final Random _rng = new Random.secure();

/// Generator of time-based v1 UUIDs
///
///
class TimeBasedUuidGenerator {
  ///
  static const epoch = (2440587 - 2299160) * 86400 * 10000000;

  int _ms;
  int _ns;
  int _clkSeq;
  final Uint8List _node;

  TimeBasedUuidGenerator([Uint8List nodeId, int clockSequence])
      : this._clkSeq = clockSequence ?? _rng.nextInt(1 << 14),
        this._node = nodeId ?? _randomNodeBytes();

  // Creates generator with random clock sequence and node
  TimeBasedUuidGenerator.random()
      : this._clkSeq = _rng.nextInt(1 << 14),
        this._node = _randomNodeBytes();

  // TODO:
  factory TimeBasedUuidGenerator.fromUuidState(Uuid uuid) {
    if (uuid.version != 1) {
      throw ArgumentError.value(
          uuid.version,
          "uuid.version"
          "UUID is not time-based v1");
    }

    var bytes = uuid.bytes;

    return new TimeBasedUuidGenerator(
        new Uint8List.fromList(bytes.sublist(10)), bytes[8] << 8 | bytes[9]);
  }

  static Uint8List _randomNodeBytes() {
    var nb = new Uint8List(6);

    int u = _rng.nextInt(0xFFFFFFFF);
    nb[0] = (u >> 24) | 0x01; // | multicast bit
    nb[1] = u >> 16;
    nb[2] = u >> 8;
    nb[3] = u;
    u = _rng.nextInt(0xFFFF);
    nb[4] = u >> 8;
    nb[5] = u;

    return nb;
  }

  Uuid generate() {
    int ms = new DateTime.now().millisecondsSinceEpoch;
    int ns = 0;
    if (ms == _ms) {
      ns = _ns + 1;
      // @todo 32bit wrap
    } else if (ms < _ms) {
      _clkSeq++;
      // @todo 32bit wrap
    }

    _ms = ms;
    _ns = ns;

    ms += epoch;

    int msb = (ms ~/ 0x100000000 * 10000) & 0x0FFFFFFF;
    int lsb = ((ms & 0x0FFFFFFF) * 10000 + ns) % 0x100000000;

    _byteBuffer[0] = msb >> 24;
    _byteBuffer[1] = msb >> 16;
    _byteBuffer[2] = msb >> 8;
    _byteBuffer[3] = msb;
    _byteBuffer[4] = lsb >> 24;
    _byteBuffer[5] = lsb >> 16;
    _byteBuffer[6] = ((lsb >> 8) & 0x0F) | 0x10; // version 1
    _byteBuffer[7] = lsb;

    _byteBuffer[8] = ((_clkSeq >> 8) & 0x3F) | 0x80; // variant 1
    _byteBuffer[9] = _clkSeq;

    for (var i = 10; i < 16; i++) {
      _byteBuffer[i] = _node[i - 10];
    }

    return new Uuid.fromBytes(_byteBuffer);
  }
}

/// Generator for namespace and name-based UUIDs (v5)
/// Only SHA1 algo is supported, MD5 is deprecated
class NameBasedUuidGenerator {
  static final namespaceDns = Uuid("6ba7b810-9dad-11d1-80b4-00c04fd430c8");
  static final namespaceUrl = Uuid("6ba7b811-9dad-11d1-80b4-00c04fd430c8");
  static final namespaceOid = Uuid("6ba7b812-9dad-11d1-80b4-00c04fd430c8");
  static final namespaceX500 = Uuid("6ba7b814-9dad-11d1-80b4-00c04fd430c8");

  /// `Hash` instance, only `hash.sha1` is allowed.
  final Hash hash;

  /// UUID namespace
  final Uuid namespace;

  NameBasedUuidGenerator(this.namespace) : this.hash = sha1;

  /// Generates namespace + name-based v5 UUID
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

  /// Returns new [NameBasedUuidGenerator] for provided [namespace]
  NameBasedUuidGenerator withNamespace(Uuid namespace) {
    return new NameBasedUuidGenerator(namespace);
  }
}

/// Generator for random-based UUIDs (v4)
class RandomBasedUuidGenerator {
  // Random number generator
  final Random rng;

  /// Creates instance of generator
  ///
  /// By default it uses secure random generator provided by `math`
  /// `math.Random` can be provided as custom RNG
  RandomBasedUuidGenerator([Random rng]) : this.rng = rng ?? _rng;

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
