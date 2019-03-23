// Copyright (c) 2018-2019, Denis Portnov. All rights reserved.
// Released under MIT License that can be found in the LICENSE file.

library uuid_type.generators;

import 'dart:convert' show utf8;
import 'dart:math' show Random;
import 'dart:typed_data' show Uint8List;
import 'package:crypto/crypto.dart' show Hash, sha1;
import 'uuid.dart';

final Uint8List _sharedByteBuffer = new Uint8List(16);
final Random _rng = new Random.secure();

/// Generator of time-based v1 UUIDs
///
///
class TimeBasedUuidGenerator {
  // offset between Gregorian and Unix epochs, in milliseconds
  static const epochOffset = (2440587 - 2299160) * 86400;

  static final _rng = new Random();
  static final Stopwatch _sw = new Stopwatch();
  static final int clockFrequency = _sw.frequency;
  // how many ticks system's clock can generate per millisecond
  // TODO: notes on firefox and safari
  static final int _ticksPerMs = _sw.frequency ~/ 1000;

  final int _zeroMs = new DateTime.now().millisecondsSinceEpoch + epochOffset;

  // clock sequence initialized with random value
  int _clockSeq = _rng.nextInt(1 << 14);

  int _lastTicks = 0;
  int _extraTicks = 0;

  // 6 bytes of node ID
  final Uint8List _nodeId;

  //
  final Uint8List _byteBuffer = new Uint8List(16);

  TimeBasedUuidGenerator._(this._lastTicks, this._clockSeq, this._nodeId);

  static Uint8List _getValidNodeId(Uint8List nodeId) {
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

    return nodeId;
  }

  ///
  TimeBasedUuidGenerator([Uint8List nodeId, @deprecated int clockSequence])
      : this._nodeId = _getValidNodeId(nodeId) {
    // start stopwatch
    _sw.start();
    // init buffer with node ID bytes
    for (int i = 0; i < 6; i++) {
      _byteBuffer[10 + i] = _nodeId[i];
    }
  }

  /// Creates new generator based on recently created UUID,
  /// takes timestamp, clock sequence and node ID.
  factory TimeBasedUuidGenerator.fromLastUuid(Uuid uuid) {
    if (uuid.version != 1) {
      throw ArgumentError.value(
          uuid.version,
          "uuid.version"
          "UUID is not time-based v1");
    }

    var b = uuid.bytes;

    var nodeId = new Uint8List(6);
    for (int i = 0; i < 6; i++) {
      nodeId[i] = b[10 + i];
    }

    // get timestamp from generator
    var g = TimeBasedUuidGenerator(nodeId);

    int gTimeLo, gTimeMidHi;
    // compiler trick for faster math in Dart vs JS
    if ((1 << 32) != 0) {
      int ts = g._zeroMs * 10000;
      gTimeLo = ts & 0xFFFFFFFF;
      gTimeMidHi = ts >> 32;
    } else {
      gTimeLo = ((g._zeroMs & 0xFFFFFFF) * 10000) % 0x100000000;
      gTimeMidHi = (g._zeroMs ~/ 0x100000000 * 10000) & 0xFFFFFFF;
    }

    int uTimeLo = (b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3];
    int uTimeMidHi = (b[4] << 8) | b[5] | ((b[6] << 24) & 0x0F) | (b[7] << 16);

    // check if state time is beyond generator's time
    int diff = ((gTimeMidHi & 0xFFFF) - (uTimeMidHi & 0xFFFF)) +
        (gTimeMidHi >> 16) - (uTimeMidHi >> 16) +
        (gTimeLo - uTimeLo);

    if (diff >= 0) {
      // no clock regression, keep original clock sequence
      g._clockSeq = ((b[8] << 8) & 0x3F) | b[9];
    }

    return g;
  }

  /// Current clock sequence
  int get clockSequence => _clockSeq;

  /// Node ID for this generator
  Uint8List get nodeId => new Uint8List.fromList(_nodeId);

  ///
  Uuid generate() {
    int ticks = _sw.elapsedTicks;
    int dt = ticks - _lastTicks;

    if (dt == 0) {
      // same tick, bump extra ticks counter
      ++_extraTicks;
    } else {
      if (dt < 0) {
        // clock regression, bump clock sequence
        _clockSeq++;
        _clockSeq &= 0x3FFF;
      }
      _lastTicks = ticks;
      _extraTicks = 0;
    }

    int ms = (ticks ~/ _ticksPerMs);
    int ns = ticks - ms * _ticksPerMs + _extraTicks;

    int timeLo, timeMidHi;
    // compiler trick for faster math in Dart vs JS
    if ((1 << 32) != 0) {
      int ts = (ms + _zeroMs) * 10000 + ns;
      timeLo = ts & 0xFFFFFFFF;
      timeMidHi = ts >> 32;
    } else {
      ms += _zeroMs;
      timeLo = ((ms & 0xFFFFFFF) * 10000 + ns) % 0x100000000;
      timeMidHi = (ms ~/ 0x100000000 * 10000) & 0xFFFFFFF;
    }

    _byteBuffer[0] = timeLo >> 24;
    _byteBuffer[1] = timeLo >> 16;
    _byteBuffer[2] = timeLo >> 8;
    _byteBuffer[3] = timeLo;
    _byteBuffer[4] = timeMidHi >> 8;
    _byteBuffer[5] = timeMidHi;
    _byteBuffer[6] = ((timeMidHi >> 24) & 0x0F) | 0x10; // version 1
    _byteBuffer[7] = timeMidHi >> 16;
    _byteBuffer[8] = ((_clockSeq >> 8) & 0x3F) | 0x80; // variant 1
    _byteBuffer[9] = _clockSeq;
    // bytes (10-15) are already set with NodeId bytes

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

  ///
  NameBasedUuidGenerator(Uuid namespace)
      : this._nsBytes = namespace.bytes,
        this.hash = sha1;

  ///
  Uuid get namespace => Uuid.fromBytes(_nsBytes);

  /// Generates namespace + name-based v5 UUID
  Uuid generate(String name) {
    assert(name != null);

    var digest = hash.convert(_nsBytes + utf8.encode(name)).bytes;
    assert(digest.length >= 16);

    for (int i = 0; i < 16; ++i) {
      _sharedByteBuffer[i] = digest[i];
    }

    _sharedByteBuffer[8] = (_sharedByteBuffer[8] & 0xBF) | 0x80; // variant 1
    _sharedByteBuffer[6] = (_sharedByteBuffer[6] & 0x0F) | 0x50; // version 5

    return new Uuid.fromBytes(_sharedByteBuffer);
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

      _sharedByteBuffer[i * 4] = (u32 >> 24);
      _sharedByteBuffer[i * 4 + 1] = (u32 >> 16);
      _sharedByteBuffer[i * 4 + 2] = (u32 >> 8);
      _sharedByteBuffer[i * 4 + 3] = u32;
    }

    _sharedByteBuffer[8] = (_sharedByteBuffer[8] & 0x3F) | 0x80; // variant 1
    _sharedByteBuffer[6] = (_sharedByteBuffer[6] & 0x0F) | 0x40; // version 4

    return new Uuid.fromBytes(_sharedByteBuffer);
  }
}
