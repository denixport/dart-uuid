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

const isJs = (1 << 32) == 0;

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

  static Uint8List _checkValidNodeId(Uint8List nodeId) {
    if (nodeId != null) {
      if (nodeId.length != 6) {
        throw ArgumentError("Node Id length should be 6 bytes");
      }
    } else {
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

  ///
  TimeBasedUuidGenerator([Uint8List nodeId, @deprecated int clockSequence])
      : this._clkSeq = _rng.nextInt(1 << 14),
        this._nodeId = _checkValidNodeId(nodeId);

  /// Creates new generator based on recently created UUID,
  /// takes clock sequence and node ID from UUID.
  factory TimeBasedUuidGenerator.fromLastUuid(Uuid uuid) {
    if (uuid.version != 1) {
      throw ArgumentError.value(
          uuid.version,
          "uuid.version"
          "UUID is not time-based v1");
    }

    var b = uuid.bytes;

    int timeLo = (b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3];
    int timeMidHi = (b[4] << 24) | (b[5] << 16) | (b[6] << 8) | b[7];

    int ts;
    if (!isJs) {
      ts = (timeLo << 32) | timeMidHi;
    } else {
      ts = timeLo * 0x100000000 + timeMidHi;
    }

    int ms = ts ~/ 10000;
    int ns = ts - ms * 10000;

    return new TimeBasedUuidGenerator._(
        ms, ns, b[8] << 8 | b[9], new Uint8List.fromList(b.sublist(10)));
  }

  ///
  int get clockSequence => _clkSeq;

  ///
  Uint8List get nodeId => new Uint8List.fromList(_nodeId);

  ///
  Uuid generate() {
    DateTime current = new DateTime.now();

    int ms = current.millisecondsSinceEpoch;
    int ns = current.microsecond * 10;

    if (ms == _lastMs && (ns == 0 || ns <= _lastNs)) {
      ns = _lastNs + 1;

      if (ns > 9999) {
        throw new StateError("Can not generate more than 10M UUID/sec");
      }
    } else if (ms < _lastMs) {
      // clock regression
      _clkSeq++;
      _clkSeq &= 0x3FFF;
    }

    _lastMs = ms;
    _lastNs = ns;

    ms += epochDiff;

    int timeLo, timeMidHi;
    var ts = ms * 10000 + ns;

    if (!isJs) {
      timeLo = ts & 0xFFFFFFFF;
      timeMidHi = ts >> 32;
    } else {
      timeLo = ts % 0x100000000;
      timeMidHi = ts ~/ 0x100000000;
    }

    _byteBuffer[0] = timeLo >> 24;
    _byteBuffer[1] = timeLo >> 16;
    _byteBuffer[2] = timeLo >> 8;
    _byteBuffer[3] = timeLo;
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
/// Only SHA1 is supported, MD5 is deprecated
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
  NameBasedUuidGenerator withNamespace(Uuid namespace) =>
      new NameBasedUuidGenerator(namespace);
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
