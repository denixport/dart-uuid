// Copyright (c) 2018-2024, Denis Portnov. All rights reserved.
// Released under MIT License that can be found in the LICENSE file.

library uuid_type.generators;

import 'dart:convert' show utf8;
import 'dart:math' show Random;
import 'dart:typed_data' show Uint8List;

import 'package:crypto/crypto.dart' show sha1;

import 'uuid.dart';

/// Generator of time-based v1 UUIDs
///
///
class TimeUuidGenerator {
  // 100ns intervals in 1 sec
  static const _intervalsPerSec = 10000000;

  static const _intervalsPerMs = 10000;

  // RNG used for creating random node & clock sequence
  static final _rng = Random();

  static final Stopwatch _sw = Stopwatch()..start();

  /// Frequency of the system clock used by this generator
  static final int clockFrequency = _sw.frequency;

  //static final double _ticksPerMs =
  //    clockFrequency / Duration.millisecondsPerSecond;

  // ticks per 100ns interval, round up to 1 in case of low-res system clock
  static final double _ticksPerInterval = clockFrequency / _intervalsPerSec;

  // Number of milliseconds between UUID (1582-10-15 00:00:00)
  // and Unix (1970-01-01 00:00:00) epochs
  static const int _epochOffsetMs =
      (2440587 - 2299160) * Duration.millisecondsPerDay;

  static final int _zeroMs =
      _epochOffsetMs + DateTime.now().millisecondsSinceEpoch;

  final Uint8List _buffer = Uint8List(16);

  final Uint8List _nodeId;

  int _lastElapsedIntervals = _sw.elapsedTicks ~/ _ticksPerInterval;

  int _extraIntervals = 0;

  int _clockSeq = _rng.nextInt(1 << 14);

  // validate or get new random node ID
  static Uint8List _getValidNodeId(Uint8List? nodeId) {
    if (nodeId == null) {
      nodeId = Uint8List(6);
      var u = _rng.nextInt(0xffffffff);
      nodeId[0] = (u >> 24) | 0x01; // multicast bit as recommended by RFC
      nodeId[1] = u >> 16;
      nodeId[2] = u >> 8;
      nodeId[3] = u;
      u = _rng.nextInt(0xFFFF);
      nodeId[4] = u >> 8;
      nodeId[5] = u;
    } else if (nodeId.length != 6) {
      throw ArgumentError('Node Id length should be 6 bytes');
    }

    return nodeId;
  }

  /// Creates new time-based UUID generator
  ///
  /// Clock sequence is initialized with random 14-bit value. If no [nodeId]
  /// is provided, random 6-byte node is generated
  TimeUuidGenerator([Uint8List? nodeId]) : _nodeId = _getValidNodeId(nodeId) {
    // init buffer with node bytes
    for (var i = 0; i < 6; i++) {
      _buffer[10 + i] = _nodeId[i];
    }
  }

  /// Creates new generator from previously generated [state] UUID.
  ///
  /// It takes clock sequence and node from provided [state].
  /// If timestamp of [state] is ahead of current time, clock sequence is
  /// increased.
  /// see (RFC 4122 4.2.1)[https://tools.ietf.org/html/rfc4122#section-4.2.1]
  factory TimeUuidGenerator.fromLastUuid(Uuid state) {
    if (state.version != 1) {
      throw ArgumentError.value(
          state.version, 'version', 'UUID is not time-based');
    }

    final sb = state.toBytes();

    var clockSeq = ((sb[8] << 8) | sb[9]) & 0x3FFF;

    // create generator and get timestamp from it
    final g = TimeUuidGenerator(sb.sublist(10, 16));
    final gb = g.generate().toBytes();

    // timestamp of the state UUID
    final stl = (sb[0] << 24) | (sb[1] << 16) | (sb[2] << 8) | sb[3];
    final stmh = (sb[4] << 8) | sb[5] | ((sb[6] << 24) & 0x0F) | (sb[7] << 16);

    // timestamp of newly generated UUID
    final gtl = (gb[0] << 24) | (gb[1] << 16) | (gb[2] << 8) | gb[3];
    final gtmh = (gb[4] << 8) | gb[5] | ((gb[6] << 24) & 0x0F) | (gb[7] << 16);

    // if state is ahead of this generator, bump up clock sequence
    if (((gtmh & 0xFFFF) - (stmh & 0xFFFF)) < 0 ||
        ((gtmh >> 16) - (stmh >> 16)) < 0 ||
        (gtl - stl) < 0) {
      clockSeq++;
      clockSeq &= 0x3FFF;
    }

    g._clockSeq = clockSeq;

    return g;
  }

  /// Returns current clock sequence for this generator
  int get clockSequence => _clockSeq;

  /// Returns Node ID for this generator
  Uint8List get nodeId => _nodeId.asUnmodifiableView();

  /// Generates UUID for current time
  Uuid generate() {
    final elapsedIntervals = _sw.elapsedTicks ~/ _ticksPerInterval;
    final diff = elapsedIntervals - _lastElapsedIntervals;

    // print('  elapsedIntervals      : $elapsedIntervals');
    // print('  _lastElapsedIntervals : $_lastElapsedIntervals');
    _lastElapsedIntervals = elapsedIntervals;

    if (diff == 0) {
      // account for low res clocks
      // same interval, bump extra intervals counter
      _extraIntervals++;

      if (_extraIntervals > _intervalsPerMs) {
        throw StateError('Too many UUIDs requested');
      }
    } else {
      _extraIntervals = 0;

      if (diff < 0) {
        // clock regression, bump clock sequence
        _clockSeq++;
        _clockSeq &= 0x3FFF;
      }
    }

    final elapsedMs = elapsedIntervals ~/ _intervalsPerMs;
    final msIntervals =
        (elapsedIntervals - elapsedMs * _intervalsPerMs) + _extraIntervals;

    // print('  elapsedMs       : $elapsedMs');
    // print('  msIntervals     : $msIntervals');
    // print('  _extraIntervals : $_extraIntervals');

    int ts, timeLo, timeMidHi;

    if ((1 << 32) != 0) {
      ts = (_zeroMs + elapsedMs) * _intervalsPerMs + msIntervals;
      timeLo = ts & 0xFFFFFFFF;
      timeMidHi = ts >> 32;
    } else {
      ts = _zeroMs + elapsedMs;

      timeLo = ((ts & 0xfffffff) * _intervalsPerMs + msIntervals) % 0x100000000;
      timeMidHi = (ts ~/ 0x100000000 * _intervalsPerMs) & 0xfffffff;

      // print('  ts          : $ts');
      // print('  timeLo      : $timeLo');
      // print('  timeMidHi   : $timeMidHi');
    }

    _buffer[0] = timeLo >> 24;
    _buffer[1] = timeLo >> 16;
    _buffer[2] = timeLo >> 8;
    _buffer[3] = timeLo;
    _buffer[4] = timeMidHi >> 8;
    _buffer[5] = timeMidHi;
    _buffer[6] = ((timeMidHi >> 24) & 0x0F) | 0x10; // version 1
    _buffer[7] = timeMidHi >> 16;
    _buffer[8] = ((_clockSeq >> 8) & 0x3F) | 0x80; // variant 1
    _buffer[9] = _clockSeq;
    // bytes (10-15) are already set with NodeId bytes

    return Uuid.fromBytes(_buffer);
  }
}

/// Generator for name-based UUIDs (v5)
/// SHA-1 hashing is used, MD5 is deprecated
class NameUuidGenerator {
  /// Name space IDs for some potentially interesting namespaces see
  /// [RFC 4122 Appendix C](https://tools.ietf.org/html/rfc4122#appendix-C)

  /// Name space for DNS
  /// '6ba7b810-9dad-11d1-80b4-00c04fd430c8'
  static final dnsNamespace =
      Uuid.parse('6ba7b810-9dad-11d1-80b4-00c04fd430c8');

  /// Name space for URL
  static final urlNamespace =
      Uuid.parse('6ba7b811-9dad-11d1-80b4-00c04fd430c8');

  /// Name space for ISO OID
  static final oidNamespace =
      Uuid.parse('6ba7b812-9dad-11d1-80b4-00c04fd430c8');

  /// Name space for X.500 DN
  static final x500namespace =
      Uuid.parse('6ba7b814-9dad-11d1-80b4-00c04fd430c8');

  // shared buffer
  static final Uint8List _buffer = Uint8List(16);

  // namespace bytes
  final Uint8List _nsBytes;

  /// Creates generator for [namespace]
  NameUuidGenerator(Uuid namespace) : _nsBytes = namespace.toBytes();

  /// Generates name-based v5 UUID for [nameBytes] bytes
  Uuid generateFromBytes(Uint8List nameBytes) {
    final bytes = sha1.convert(<int>[..._nsBytes, ...nameBytes]).bytes;
    assert(bytes.length >= 16);

    for (var i = 0; i < 16; ++i) {
      _buffer[i] = bytes[i];
    }

    _buffer[8] = (_buffer[8] & 0xBF) | 0x80; // variant 1
    _buffer[6] = (_buffer[6] & 0x0F) | 0x50; // version 5

    return Uuid.fromBytes(_buffer);
  }

  /// Generates name-based v5 UUID for [name] string
  Uuid generateFromString(String name) {
    return generateFromBytes(Uint8List.fromList(utf8.encode(name)));
  }
}

/// Generator for random-based UUIDs (v4)
class RandomUuidGenerator {
  /// Random number generator. By default it uses secure RNG returned
  /// by [Random.secure]
  final Random rng;

  // shared buffer
  static final Uint8List _buffer = Uint8List(16);

  /// Creates instance of generator
  ///
  /// If no [rng] provided, it uses secure random generator returned by `math`
  /// [Random.secure]
  RandomUuidGenerator([Random? rng]) : rng = rng ?? Random.secure();

  /// Generates random-based v4 UUID
  Uuid generate() {
    int u32;
    for (var i = 0; i < 4; i++) {
      u32 = rng.nextInt(0xffffffff);

      _buffer[i * 4] = u32 >> 24;
      _buffer[i * 4 + 1] = u32 >> 16;
      _buffer[i * 4 + 2] = u32 >> 8;
      _buffer[i * 4 + 3] = u32;
    }

    _buffer[8] = (_buffer[8] & 0x3f) | 0x80; // variant 1
    _buffer[6] = (_buffer[6] & 0x0f) | 0x40; // version 4

    return Uuid.fromBytes(_buffer);
  }
}
