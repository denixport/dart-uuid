// Copyright (c) 2018-2019, Denis Portnov. All rights reserved.
// Released under MIT License that can be found in the LICENSE file.

library uuid_type.generators;

import 'dart:convert' show utf8;
import 'dart:math' show Random;
import 'dart:typed_data' show Uint8List;
import 'package:crypto/crypto.dart' show Hash, sha1;
import 'uuid.dart';

/// Generator of time-based v1 UUIDs
///
///
class TimeBasedUuidGenerator {
  // offset between Gregorian and Unix epochs, in milliseconds
  static const epochOffset = (2440587 - 2299160) * 86400 * 1000;
  static final _rng = new Random();

  static final Stopwatch _sw = new Stopwatch()..start();

  /// Frequency of the clock used by this generator
  static final int clockFrequency = _sw.frequency;
  // how many ticks system's clock can generate per millisecond
  // TODO: notes on firefox and safari
  static final int _ticksPerMs = _sw.frequency ~/ 1000;
  // same but per 100ns interval
  static final int _ticksPer100Ns =
      _sw.frequency ~/ 10000000 == 0 ? 1 : _sw.frequency ~/ 10000000;
  //
  static final int _zeroMs =
      new DateTime.now().millisecondsSinceEpoch + epochOffset;

  // clock sequence initialized with random value
  int _clockSeq = _rng.nextInt(1 << 14);

  int _lastTicks = 0;
  int _extraTicks = 0;

  // 6 bytes of node ID
  final Uint8List _nodeId;

  //
  final Uint8List _byteBuffer = new Uint8List(16);

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
    // init buffer with node ID bytes
    for (int i = 0; i < 6; i++) {
      _byteBuffer[10 + i] = _nodeId[i];
    }
  }

  /// Creates new generator based on recently created UUID,
  /// takes timestamp, clock sequence and node ID.
  factory TimeBasedUuidGenerator.fromLastUuid(Uuid state) {
    if (state.version != 1) {
      throw ArgumentError.value(
          state.version, "version", "UUID is not time-based");
    }

    var sb = state.bytes;

    var clockSeq = ((sb[8] << 8) | sb[9]) & 0x3FFF;
    var nodeId = new Uint8List(6);
    for (int i = 0; i < 6; i++) {
      nodeId[i] = sb[10 + i];
    }

    // timestamp of the state UUID
    int utl = (sb[0] << 24) | (sb[1] << 16) | (sb[2] << 8) | sb[3];
    int utmh = (sb[4] << 8) | sb[5] | ((sb[6] << 24) & 0x0F) | (sb[7] << 16);

    // create generator and get timestamp from it
    var g = TimeBasedUuidGenerator(nodeId);
    var gb = g.generate().bytes;

    int gtl = (gb[0] << 24) | (gb[1] << 16) | (gb[2] << 8) | gb[3];
    int gtmh = (gb[4] << 8) | gb[5] | ((gb[6] << 24) & 0x0F) | (gb[7] << 16);

    // if state is ahead, bump clock sequence
    if ((gtmh & 0xFFFF) - (utmh & 0xFFFF) < 0 ||
        (gtmh >> 16) - (utmh >> 16) < 0 ||
        (gtl - utl) < 0) {
      clockSeq++;
      clockSeq &= 0x3FFF;
    }

    g._clockSeq = clockSeq;

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
      // account for low res clocks
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
    int ns = (ticks - ms * _ticksPerMs) ~/ _ticksPer100Ns + _extraTicks;

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
  static final Hash hash = sha1;
  //
  static final Uint8List _byteBuffer = new Uint8List(16);
  //
  final Uint8List _nsBytes;

  ///
  NameBasedUuidGenerator(Uuid namespace) : this._nsBytes = namespace.bytes;

  ///
  Uuid get namespace => Uuid.fromBytes(_nsBytes);

  /// Generates namespace + name-based v5 UUID
  Uuid generate(String name) {
    assert(name != null);

    var digest = hash.convert(_nsBytes + utf8.encode(name)).bytes;
    assert(digest.length >= 16);

    for (int i = 0; i < 16; ++i) {
      _byteBuffer[i] = digest[i];
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
  //
  static final Uint8List _byteBuffer = new Uint8List(16);

  /// Random number generator
  final Random rng;

  /// Creates instance of generator
  ///
  /// By default it uses secure random generator provided by `math`
  /// `math.Random` can be provided as custom RNG
  RandomBasedUuidGenerator([Random rng]) : this.rng = rng ?? Random.secure();

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
