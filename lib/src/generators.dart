// Copyright (c) 2018-2026, Denis Portnov. All rights reserved.
// Released under MIT License that can be found in the LICENSE file.

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
  static const int _epochOffsetMs = (2440587 - 2299160) * Duration.millisecondsPerDay;

  static final int _zeroMs = _epochOffsetMs + DateTime.now().millisecondsSinceEpoch;

  final Uint8List _buffer = Uint8List(16);

  final Uint8List _nodeId;

  int _lastElapsedIntervals = _sw.elapsedTicks ~/ _ticksPerInterval;

  int _extraIntervals = 0;

  int _clockSeq = _rng.nextInt(1 << 14);

  // validate or get new random node ID
  static Uint8List _getValidNodeId(Uint8List? nodeId) {
    if (nodeId == null) {
      nodeId = Uint8List(6);
      var u = _rng.nextInt(0x100000000);
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
  /// See [RFC 9562 section 6.3](https://www.rfc-editor.org/rfc/rfc9562.html#section-6.3).
  factory TimeUuidGenerator.fromLastUuid(Uuid state) {
    if (state.version != 1) {
      throw ArgumentError.value(state.version, 'version', 'UUID is not time-based');
    }

    final sb = state.toBytes();

    var clockSeq = ((sb[8] << 8) | sb[9]) & 0x3FFF;

    // create generator and get timestamp from it
    final g = TimeUuidGenerator(sb.sublist(10, 16));
    final gb = g.generate().toBytes();

    // if state is ahead of this generator, bump up clock sequence
    if (_compareTimestamp(gb, sb) < 0) {
      clockSeq++;
      clockSeq &= 0x3FFF;
    }

    g._clockSeq = clockSeq;

    return g;
  }

  static int _compareTimestamp(Uint8List left, Uint8List right) {
    for (final index in <int>[6, 7, 4, 5, 0, 1, 2, 3]) {
      final l = index == 6 ? left[index] & 0x0f : left[index];
      final r = index == 6 ? right[index] & 0x0f : right[index];
      if (l != r) return l - r;
    }
    return 0;
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
    } else {
      // Keep the generated timestamp ahead of the previous one. The clock may
      // advance by fewer intervals than were added while it was unchanged.
      _extraIntervals = _extraIntervals >= diff ? _extraIntervals - diff + 1 : 0;

      if (diff < 0) {
        // clock regression, bump clock sequence
        _clockSeq++;
        _clockSeq &= 0x3FFF;
      }
    }

    if (_extraIntervals > _intervalsPerMs) {
      throw StateError('Too many UUIDs requested');
    }

    final elapsedMs = elapsedIntervals ~/ _intervalsPerMs;
    final msIntervals = (elapsedIntervals - elapsedMs * _intervalsPerMs) + _extraIntervals;

    // print('  elapsedMs       : $elapsedMs');
    // print('  msIntervals     : $msIntervals');
    // print('  _extraIntervals : $_extraIntervals');

    final milliseconds = _zeroMs + elapsedMs;
    final quotient = milliseconds ~/ 429496;
    final remainder = milliseconds % 429496;
    final remainderIntervals = remainder * _intervalsPerMs + msIntervals - quotient * 7296;
    final timeLo = remainderIntervals % 0x100000000;
    final timeMidHi = quotient + remainderIntervals ~/ 0x100000000;

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

/// Backwards-compatible name for the UUIDv1 generator.
typedef UuidV1Generator = TimeUuidGenerator;

/// Generator for name-based UUIDs (v5)
/// SHA-1 hashing is used, MD5 is deprecated
class NameUuidGenerator {
  /// Name space IDs for some potentially interesting namespaces see
  /// [RFC 9562 section 6.6](https://www.rfc-editor.org/rfc/rfc9562.html#section-6.6)

  /// Name space for DNS
  /// '6ba7b810-9dad-11d1-80b4-00c04fd430c8'
  static final dnsNamespace = Uuid.parse('6ba7b810-9dad-11d1-80b4-00c04fd430c8');

  /// Name space for URL
  static final urlNamespace = Uuid.parse('6ba7b811-9dad-11d1-80b4-00c04fd430c8');

  /// Name space for ISO OID
  static final oidNamespace = Uuid.parse('6ba7b812-9dad-11d1-80b4-00c04fd430c8');

  /// Name space for X.500 DN
  static final x500namespace = Uuid.parse('6ba7b814-9dad-11d1-80b4-00c04fd430c8');

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
      u32 = rng.nextInt(0x100000000);

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

/// Generator for time-ordered UUIDv6 values.
class UuidV6Generator {
  final TimeUuidGenerator _v1Generator;

  UuidV6Generator([Uint8List? nodeId]) : _v1Generator = TimeUuidGenerator(nodeId);

  /// Restores generator state from a previously generated UUIDv6 value.
  factory UuidV6Generator.fromLastUuid(Uuid state) {
    if (state.version != 6) {
      throw ArgumentError.value(state.version, 'version', 'UUID must be version 6');
    }
    final v6 = state.toBytes();
    final v1 = Uint8List(16);
    v1[6] = (v6[0] >> 4) | 0x10;
    v1[7] = ((v6[0] & 0x0f) << 4) | (v6[1] >> 4);
    v1[4] = ((v6[1] & 0x0f) << 4) | (v6[2] >> 4);
    v1[5] = ((v6[2] & 0x0f) << 4) | (v6[3] >> 4);
    v1[0] = ((v6[3] & 0x0f) << 4) | (v6[4] >> 4);
    v1[1] = ((v6[4] & 0x0f) << 4) | (v6[5] >> 4);
    v1[2] = ((v6[5] & 0x0f) << 4) | (v6[6] & 0x0f);
    v1[3] = v6[7];
    for (var i = 8; i < 16; i++) {
      v1[i] = v6[i];
    }
    return UuidV6Generator._(TimeUuidGenerator.fromLastUuid(Uuid.fromBytes(v1)));
  }

  UuidV6Generator._(this._v1Generator);

  int get clockSequence => _v1Generator.clockSequence;

  Uint8List get nodeId => _v1Generator.nodeId;

  Uuid generate() {
    final v1 = _v1Generator.generate().toBytes();
    final bytes = Uint8List(16);
    bytes[0] = ((v1[6] & 0x0f) << 4) | (v1[7] >> 4);
    bytes[1] = ((v1[7] & 0x0f) << 4) | (v1[4] >> 4);
    bytes[2] = ((v1[4] & 0x0f) << 4) | (v1[5] >> 4);
    bytes[3] = ((v1[5] & 0x0f) << 4) | (v1[0] >> 4);
    bytes[4] = ((v1[0] & 0x0f) << 4) | (v1[1] >> 4);
    bytes[5] = ((v1[1] & 0x0f) << 4) | (v1[2] >> 4);
    bytes[6] = (v1[2] & 0x0f) | 0x60;
    bytes[7] = v1[3];
    for (var i = 8; i < 16; i++) {
      bytes[i] = v1[i];
    }
    return Uuid.fromBytes(bytes);
  }
}

/// Generator for time-ordered UUIDv7 values.
class UuidV7Generator {
  final Random _random;
  final int Function() _millisecondsSinceEpoch;
  int _lastMilliseconds = -1;
  Uint8List _randomValue = Uint8List(10);

  UuidV7Generator({Random? random, int Function()? millisecondsSinceEpoch})
    : _random = random ?? Random.secure(),
      _millisecondsSinceEpoch = millisecondsSinceEpoch ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// Restores this monotonic generator's state from a UUIDv7 value.
  factory UuidV7Generator.fromLastUuid(Uuid state, {Random? random, int Function()? millisecondsSinceEpoch}) {
    if (state.version != 7) {
      throw ArgumentError.value(state.version, 'version', 'UUID must be version 7');
    }
    final bytes = state.toBytes();
    var milliseconds = 0;
    for (var i = 0; i < 6; i++) {
      milliseconds = milliseconds * 256 + bytes[i];
    }
    final randomValue = Uint8List(10);
    randomValue[0] = bytes[6] & 0x0f;
    randomValue[1] = bytes[7];
    randomValue[2] = bytes[8] & 0x3f;
    for (var i = 3; i < 10; i++) {
      randomValue[i] = bytes[i + 6];
    }
    return UuidV7Generator._(
      random ?? Random.secure(),
      millisecondsSinceEpoch ?? (() => DateTime.now().millisecondsSinceEpoch),
      milliseconds,
      randomValue,
    );
  }

  UuidV7Generator._(this._random, this._millisecondsSinceEpoch, this._lastMilliseconds, this._randomValue);

  Uuid generate() {
    var milliseconds = _millisecondsSinceEpoch();
    if (milliseconds < _lastMilliseconds) milliseconds = _lastMilliseconds;
    if (milliseconds > _lastMilliseconds) {
      _lastMilliseconds = milliseconds;
      _randomValue = Uint8List(10);
      _randomValue[0] = _random.nextInt(16);
      _randomValue[1] = _random.nextInt(256);
      _randomValue[2] = _random.nextInt(64);
      for (var i = 3; i < 10; i++) {
        _randomValue[i] = _random.nextInt(256);
      }
    } else {
      var carry = true;
      for (var i = 9; i >= 0 && carry; i--) {
        final limit = i == 0
            ? 0x0f
            : i == 2
            ? 0x3f
            : 0xff;
        if (_randomValue[i] == limit) {
          _randomValue[i] = 0;
        } else {
          _randomValue[i]++;
          carry = false;
        }
      }
      if (carry) throw StateError('Too many UUIDs requested in one millisecond');
    }
    final bytes = Uint8List(16);
    for (var i = 5; i >= 0; i--) {
      bytes[i] = milliseconds % 256;
      milliseconds ~/= 256;
    }
    bytes[6] = _randomValue[0] | 0x70;
    bytes[7] = _randomValue[1];
    bytes[8] = _randomValue[2] | 0x80;
    for (var i = 3; i < 10; i++) {
      bytes[i + 6] = _randomValue[i];
    }
    return Uuid.fromBytes(bytes);
  }
}
