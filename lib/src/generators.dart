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
  /// Shared buffer for byte representation for all instances
  static final _byteBuffer = new Uint8List(16);

  /// Difference in milliseconds between Gregorian and Unix epochs
  static const epochDiff = (2440587 - 2299160) * 86400 * 10000000;

  // recent milliseconds since Unix epoch
  int _lastMs = 0;
  // recent additional 100-nanosecond intervals
  int _lastNs = 0;
  // clock sequence
  int _clkSeq;
  // 6 bytes of node ID
  final Uint8List _nodeId;

  TimeBasedUuidGenerator._(
      this._lastMs, this._lastNs, this._clkSeq, this._nodeId);

  static Uint8List _setNodeId(Uint8List nodeId) {
    assert(nodeId.length == 6);

    if (nodeId == null) {
      nodeId = new Uint8List(6);
      int u = _rng.nextInt(0xFFFFFFFF);
      nodeId[0] = (u >> 24) | 0x01; // | multicast bit
      nodeId[1] = u >> 16;
      nodeId[2] = u >> 8;
      nodeId[3] = u;
      u = _rng.nextInt(0xFFFF);
      nodeId[4] = u >> 8;
      nodeId[5] = u;
    }

    for (int i = 0; i < 6; i++) {
      _byteBuffer[i + 10] = nodeId[i];
    }

    return nodeId;
  }

  // TODO: validate clock sequence
  TimeBasedUuidGenerator([Uint8List nodeId, int clockSequence])
      : this._clkSeq = clockSequence ?? _rng.nextInt(1 << 14),
        this._nodeId = _setNodeId(nodeId);

  /// Creates new generator based on recently created UUID,
  /// takes clock sequence and node ID from UUID.
  factory TimeBasedUuidGenerator.fromStateUuid(Uuid uuid) {
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

  int get clockSequence => _clkSeq;

  Uint8List get nodeId => new Uint8List.fromList(_nodeId);

  Uuid generate() {
    DateTime current = new DateTime.now();

    int ms = current.millisecondsSinceEpoch;
    int ns = current.microsecond * 10;

    if (ms == _lastMs && ns == 0) {
      ns = _lastNs + 1;
    } else if (ms < _lastMs) {
      _clkSeq++;
      _clkSeq &= 0x3FFF;
    }

    if (ns > 9999) {
      throw new StateError("Can not create more than 10M UUID/sec");
    }

    _lastMs = ms;
    _lastNs = ns;

    ms += epochDiff;

    var timeLow = ((ms & 0x0FFFFFFF) * 10000 + ns) % 0x100000000;
    var timeMidHi = (ms ~/ 0x100000000 * 10000) & 0x0FFFFFFF;

    _byteBuffer[0] = timeLow >> 24;
    _byteBuffer[1] = timeLow >> 16;
    _byteBuffer[2] = timeLow >> 8;
    _byteBuffer[3] = timeLow;
    _byteBuffer[4] = timeMidHi >> 24;
    _byteBuffer[5] = timeMidHi >> 16;
    _byteBuffer[6] = ((timeMidHi >> 8) & 0x0F) | 0x10; // version 1
    _byteBuffer[7] = timeMidHi;
    _byteBuffer[8] = ((_clkSeq >> 8) & 0x3F) | 0x80; // variant 1
    _byteBuffer[9] = _clkSeq;

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

  final Uint8List _nsBytes;

  NameBasedUuidGenerator(Uuid namespace)
      : this._nsBytes = namespace.bytes,
        this.hash = sha1;

  Uuid get namespace => Uuid.fromBytes(_nsBytes);

  /// Generates namespace + name-based v5 UUID
  Uuid generate(String name) {
    assert(name != null);

    var h = hash.convert(_nsBytes + utf8.encode(name)).bytes;
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
