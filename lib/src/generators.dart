// Copyright (c) 2018-2020, Denis Portnov. All rights reserved.
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
  static const _epochOffset = (2440587 - 2299160) * 86400 * 1000;

  //
  static final _rng = Random();

  //
  static final Stopwatch _sw = Stopwatch();

  /// Frequency of the system's clock used by this generator
  static final int clockFrequency = _sw.frequency;

  // how many ticks system's clock can generate per millisecond
  // TODO: notes on firefox (and safari?) weird behaviour
  static final int _ticksPerMs = _sw.frequency ~/ 1000;

  // same but per 100ns interval, round up to 1 for low-res system clock
  static final int _ticksPer100Ns =
      _sw.frequency ~/ 10000000 == 0 ? 1 : _sw.frequency ~/ 10000000;

  // "zero" point in time from which all timestamps are calculated
  static final int _zeroMs =
      DateTime.now().millisecondsSinceEpoch + _epochOffset;

  // clock sequence, initialized with random value
  int _clockSeq = _rng.nextInt(1 << 14);

  // ticks used for last generated UUID
  int _lastTicks = 0;

  // extra ticks counter for low-res clocks
  int _extraTicks = 0;

  // 6 bytes of node ID
  final Uint8List _nodeId;

  //
  final Uint8List _byteBuffer = Uint8List(16);

  // validate or get new random node ID
  static Uint8List _getValidNodeId(Uint8List nodeId) {
    if (nodeId != null) {
      if (nodeId.length != 6) {
        throw ArgumentError("Node Id length should be 6 bytes");
      }
    } else {
      nodeId = Uint8List(6);
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

  /// Creates new time-based generator
  ///
  /// Clock sequence is initialized with random 14 bit value. If no [nodeId]
  /// is provided, it generates random 6 byte node ID
  TimeBasedUuidGenerator([Uint8List nodeId, @deprecated int clockSequence])
      : _nodeId = _getValidNodeId(nodeId) {
    // make sure stopwatch is started
    _sw.start();
    // init buffer with node ID bytes
    for (int i = 0; i < 6; i++) {
      _byteBuffer[10 + i] = _nodeId[i];
    }
  }

  /// Creates new generator from previously generated [state] UUID.
  ///
  /// It takes clock sequence and node ID from provided [state].
  /// If timestamp of [state] is ahead of current time, clock sequence is
  /// increased see (
  /// RFC 4122 4.2.1)[https://tools.ietf.org/html/rfc4122#section-4.2.1]
  factory TimeBasedUuidGenerator.fromLastUuid(Uuid state) {
    if (state.version != 1) {
      throw ArgumentError.value(
          state.version, "version", "UUID is not time-based");
    }

    var sb = state.bytes;

    var clockSeq = ((sb[8] << 8) | sb[9]) & 0x3FFF;
    var nodeId = Uint8List(6);
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

    // if state is ahead of this generator, bump up clock sequence
    if ((gtmh & 0xFFFF) - (utmh & 0xFFFF) < 0 ||
        (gtmh >> 16) - (utmh >> 16) < 0 ||
        (gtl - utl) < 0) {
      clockSeq++;
      clockSeq &= 0x3FFF;
    }

    g._clockSeq = clockSeq;

    return g;
  }

  /// Returns current clock sequence for this generator
  int get clockSequence => _clockSeq;

  /// Returns Node ID for this generator
  Uint8List get nodeId => Uint8List.fromList(_nodeId);

  /// Generates UUID for current time
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

    return Uuid.fromBytes(_byteBuffer);
  }
}

/// Generator for namespace and name-based UUIDs (v5)
/// Only SHA1 is supported, MD5 is deprecated
class NameBasedUuidGenerator {
  /// Name space IDs for some potentially interesting name spaces see
  /// [RFC 4122 Appendix C](https://tools.ietf.org/html/rfc4122#appendix-C)

  /// Name space for DNS
  static final namespaceDns = Uuid("6ba7b810-9dad-11d1-80b4-00c04fd430c8");

  /// Name space for URL
  static final namespaceUrl = Uuid("6ba7b811-9dad-11d1-80b4-00c04fd430c8");

  /// Name space for ISO OID
  static final namespaceOid = Uuid("6ba7b812-9dad-11d1-80b4-00c04fd430c8");

  /// Name space for X.500 DN
  static final namespaceX500 = Uuid("6ba7b814-9dad-11d1-80b4-00c04fd430c8");

  /// `Hash` instance, only `hash.sha1` is supported.
  static final Hash hash = sha1;

  // namespace bytes
  final Uint8List _nsBytes;

  /// Creates generator for [namespace]
  NameBasedUuidGenerator(Uuid namespace) : _nsBytes = namespace.bytes;

  /// Returns namespace [Uuid] for this generator
  Uuid get namespace => Uuid.fromBytes(_nsBytes);

  //
  static final Uint8List _byteBuffer = Uint8List(16);

  /// Generates name-based v5 UUID for [name]
  Uuid generate(String name) {
    assert(name != null);

    var digest = hash.convert(_nsBytes + utf8.encode(name)).bytes;
    assert(digest.length >= 16);

    for (int i = 0; i < 16; ++i) {
      _byteBuffer[i] = digest[i];
    }

    _byteBuffer[8] = (_byteBuffer[8] & 0xBF) | 0x80; // variant 1
    _byteBuffer[6] = (_byteBuffer[6] & 0x0F) | 0x50; // version 5

    return Uuid.fromBytes(_byteBuffer);
  }

  /// Returns new [NameBasedUuidGenerator] for [namespace]
  NameBasedUuidGenerator withNamespace(Uuid namespace) =>
      NameBasedUuidGenerator(namespace);
}

/// Generator for random-based UUIDs (v4)
class RandomBasedUuidGenerator {
  /// Random number generator. By default it uses secure RNG returned
  /// by [Random.secure]
  final Random rng;

  /// Creates instance of generator
  ///
  /// If no [rng] provided, it uses secure random generator returned by `math`
  /// [Random.secure]
  RandomBasedUuidGenerator([Random rng]) : rng = rng ?? Random.secure();

  // shared byte buffer for UUIDs created by this generator
  static final Uint8List _byteBuffer = Uint8List(16);

  /// Generates random-based v4 UUID
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

    return Uuid.fromBytes(_byteBuffer);
  }
}
