// Copyright (c) 2018, Denis Portnov. All rights reserved.
// Released under MIT License that can be found in the LICENSE file.

library uuid_type.generators;

import 'dart:convert' show utf8;
import 'dart:math' show Random;
import 'dart:typed_data' show Uint8List;
import 'package:crypto/crypto.dart' show Hash, sha1;
import 'node.dart';
import 'uuid.dart';


final Uint8List _byteBuffer = new Uint8List(16);
final _rng = new Random.secure();

///
class TimeBasedUuidGenerator {
  static const epoch = (2440587 - 2299160) * 86400 * 10000000;

  int _ms;
  int _ns;
  int _clkSeq;
  final NodeId _node;

  TimeBasedUuidGenerator([NodeId nodeId, int clockSequence])
      : this._ms = 0,
        this._ns = 0,
        this._clkSeq = clockSequence ?? _rng.nextInt(1 << 14),
        this._node = nodeId ?? _randomNode();

  TimeBasedUuidGenerator.random()
      : this._ms = 0,
        this._ns = 0,
        this._clkSeq = _rng.nextInt(1 << 14),
        this._node = _randomNode();


  factory TimeBasedUuidGenerator.fromUuidState(Uuid state) {
    if (state.version != 1) {
      throw ArgumentError('Invalid version for time-based UUID');
    }
  }
  /*
    : this._ms = _getUuidMs(state),
      this._ns = _getUuidNs(state),
      this._clkSeq = _getUuidClkSeq(state),
      this._node = new NodeId.fromBytes(state.bytes, 10);

  static int _getUuidMs(Uuid state) {
    return 0;
  }
  static int _getUuidNs(Uuid state) {
    return 0;
  }
  static int _getUuidClkSeq(Uuid state) {
    return 0;
  }
  */

  static NodeId _randomNode() {
    var u = _rng.nextInt(0xFFFFFFFF);
    _byteBuffer[10] = (u >> 24) | 0x01; // | multicast bit
    _byteBuffer[11] = u >> 16;
    _byteBuffer[12] = u >> 8;
    _byteBuffer[13] = u;
    u = _rng.nextInt(0xFFFF);
    _byteBuffer[14] = u >> 8;
    _byteBuffer[15] = u;

    return new NodeId.fromBytes(_byteBuffer, 10);
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
    _byteBuffer[6] = lsb >> 8;
    _byteBuffer[7] = lsb;

    _byteBuffer[8] = _clkSeq >> 8;
    _byteBuffer[9] = _clkSeq;

    var nodeBytes = _node.bytes;
    for (var i = 10; i < 16; i++) {
      _byteBuffer[i] = nodeBytes[i-10];
    }

    _byteBuffer[8] = (_byteBuffer[8] & 0x3F) | 0x80; // variant 1
    _byteBuffer[6] = (_byteBuffer[6] & 0x0F) | 0x10; // version 1

    return new Uuid.fromBytes(_byteBuffer);
  }
}

/// Generator for namespace and name-based UUIDs (v5)
/// Only SHA1 algo is supported, MD5 is deprecated
class NameBasedUuidGenerator {
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

  /// Returns new [NameBasedUuidGenerator] for provided [namespace]
  NameBasedUuidGenerator withNamespace(Uuid namespace) {
    return new NameBasedUuidGenerator(namespace);
  }
}

/// Generator for random-based UUIDs (v4)
class RandomUuidGenerator {
  // Random number generator
  final Random rng;

  /// Creates instance of generator
  ///
  /// By default it uses secure random generator provided by [math]
  /// [math.Random] can be provided as custom RNG
  RandomUuidGenerator([Random rng]) : this.rng = rng ?? _rng;

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