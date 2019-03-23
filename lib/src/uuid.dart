// Copyright (c) 2018-2019, Denis Portnov. All rights reserved.
// Released under MIT License that can be found in the LICENSE file.

library uuid_type;

import 'dart:typed_data' show Uint8List;
import 'hex.dart';

/// UUID variant according to RFC4122
enum Variant {
  /// Reserved, NCS backward compatibility.
  ncs,

  /// The variant specified in RFC 4122
  rfc4122,

  /// Reserved, Microsoft Corporation backward compatibility.
  microsoft,

  /// Reserved for future definition
  future
}

/// This object represents an UUID, 128 bit Universal Unique Identifier
/// as defined in [RFC 4122](https://tools.ietf.org/html/rfc4122).
abstract class Uuid implements Comparable<Uuid> {
  /// Shared buffer for byte representation for all instances
  static final _byteBuffer = new Uint8List(16);

  /// Nil UUID
  /// (see [RFC 4122 4.1.7](https://tools.ietf.org/html/rfc4122#section-4.1.7))
  static Uuid get nil => new Uuid.fromBytes(new Uint8List(16));

  /// Creates a new [Uuid] from canonical string representation
  ///
  /// If argument is not a valid UUID string `FormatException` is thrown.
  /// For parsing various UUID formats use [Uuid.parse]
  factory Uuid(String source) {
    if (source.length != 36) {
      throw new FormatException(
          "UUID string has invalid length (${source.length})", source);
    }

    var e = _parseCanonical(source);
    if (e != null) throw e;

    return new Uuid.fromBytes(_byteBuffer);
  }

  /// Creates [Uuid] from byte array
  ///
  /// Optional [offset] is used to read 16 bytes of UUID from larger arrays
  /// Would return [Uuid.nil] when zero byte array is provided
  factory Uuid.fromBytes(Uint8List bytes, [int offset]) = _Uuid.fromBytes;

  /// Returns representation of this [Uuid] as [Uint8List]
  /// The returned list is a copy, making it possible to change the list
  /// without affecting the [Uuid] instance.
  Uint8List get bytes;

  @override
  int get hashCode;

  /// Returns [Variant] defined in
  /// [RFC 4122](https://tools.ietf.org/html/rfc4122#section-4.1.1)
  Variant get variant;

  /// Returns UUID version defined in
  /// [RFC 4122](https://tools.ietf.org/html/rfc4122#section-4.1.3)
  int get version;

  @override
  bool operator ==(Object other);

  bool operator >(Uuid other);
  bool operator >=(Uuid other);
  bool operator <(Uuid other);
  bool operator <=(Uuid other);

  /// Compares this UUID to another [Uuid]
  ///
  /// First, compares by version
  /// then, if it's time-based UUID, compares timestamps
  /// then compares all bytes lexically
  int compareTo(Uuid other) {
    int ver = version;
    int diff = ver - other.version;
    if (diff != 0) return diff;

    var a = bytes;
    var b = other.bytes;

    if (ver == 1) {
      for (int pos in const <int>[7, 4, 5, 0, 1, 2, 3]) {
        diff = a[pos] - b[pos];
        if (diff != 0) return diff;
      }
      return 0;
    }

    for (int pos = 0; pos < 16; pos++) {
      diff = a[pos] - b[pos];
      if (diff != 0) return diff;
    }

    return 0;
  }

  /// Returns canonical string representation of this [Uuid]
  String toString();

  /// Parses [source] as [Uuid]
  ///
  /// Throws [FormatException] in case of invalid UUID representation
  ///
  /// The [source] must be in one of the following UUID formats
  /// - Canonical string: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxxxx
  /// - Hex string (36 chars): xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  /// - URN: urn:uuid:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxxxx
  /// - Canonical GUID: {xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxxxx}
  /// - Hex GUID: {xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx}
  static Uuid parse(String source) {
    var e = _parse(source);
    if (e != null) throw e;
    return new Uuid.fromBytes(_byteBuffer);
  }

  /// Parses [source] as [Uuid]
  ///
  /// Like [parse] except it returns `null` for invalid inputs
  //  instead of throwing.
  static Uuid tryParse(String source) {
    if (_parse(source) != null) return null;
    return new Uuid.fromBytes(_byteBuffer);
  }

  ///
  static FormatException _parseCanonical(String source) {
    const bytePositions = const <int>[
      0, 2, 4, 6, 9, 11, 14, 16, 19, 21, 24, 26, 28, 30, 32, 34 //
    ];
    const dashPositions = const <int>[8, 13, 18, 23];

    var chars = source.codeUnits;

    int pos;

    // check '-' positions
    for (pos in dashPositions) {
      if (chars[pos] != 0x2D) {
        return new FormatException("Invalid UUID string", source, pos);
      }
    }

    int n0, n1;
    for (pos = 0; pos < 16; pos++) {
      n0 = hexToNibble(chars[bytePositions[pos]]);
      if (n0 == -1) {
        return new FormatException("Invalid char in UUID string", source, pos);
      }

      n1 = hexToNibble(chars[bytePositions[pos] + 1]);
      if (n1 == -1) {
        return new FormatException(
            "Invalid char in UUID string", source, pos + 1);
      }
      _byteBuffer[pos] = n0 << 4 | n1;
    }

    return null;
  }

  /// Fills [_byteBuffer] with bytes decoded from hex
  static FormatException _parse(String source) {
    if (source.length == 36) {
      return _parseCanonical(source);
    } else if (source.length == 1 + 36 + 1) {
      // GUID
      if (!(source[0] == '{' && source[source.length - 1] == '}')) {
        return new FormatException("Invalid GUID string", source);
      }
      return _parseCanonical(source.substring(1, source.length - 1));
    } else if (source.length == 1 + 32 + 1) {
      // hex GUID
      if (!(source[0] == '{' && source[source.length - 1] == '}')) {
        return new FormatException("Invalid GUID string", source);
      }
      source = source.substring(1, source.length - 1);
    } else if (source.length == 9 + 36) {
      // URN
      if (!source.startsWith('urn:uuid:')) {
        return new FormatException("Invalid UUID URN string", source);
      }
      return _parseCanonical(source.substring(9));
    }

    if (source.length != 32) {
      return new FormatException("Invalid UUID hex string", source);
    }

    // parse hex
    var chars = source.codeUnits;
    int n0, n1;
    for (int i = 0; i < 16; i++) {
      n0 = hexToNibble(chars[2 * i]);
      if (n0 == -1) {
        return new FormatException("Invalid char in UUID string", source, i);
      }

      n1 = hexToNibble(chars[2 * i + 1]);
      if (n1 == -1) {
        return new FormatException(
            "Invalid char in UUID string", source, i + 1);
      }

      _byteBuffer[i] = n0 << 4 | n1;
    }

    return null;
  }
}

class _Uuid implements Uuid {
  static const nil = const _Uuid._(0, 0, 0, 0);

  // Buffer to hold 36 chars of canonical string representation
  static final Uint8List _stringBuffer = new Uint8List.fromList(const <int>[
    0, 0, 0, 0, 0, 0, 0, 0, 0x2D, //
    0, 0, 0, 0, 0x2D,
    0, 0, 0, 0, 0x2D,
    0, 0, 0, 0, 0x2D,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  ]); // time_low

  // UUID is stored as 4 x 32bit values
  final int x; // time_low
  final int y; // time_mid | time_hi_and_version
  final int z; // clk_seq_hi_res | clk_seq_low | node (0-1)
  final int w; // node (2-5)

  /// Implements [Uuid.fromBytes]
  factory _Uuid.fromBytes(Uint8List bytes, [int offset = 0]) {
    assert(bytes != null);

    if (offset < 0 || (offset + 16 > bytes.length)) {
      throw new ArgumentError('Invalid offset');
    }

    int x = (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
    int y = (bytes[offset + 4] << 24) |
        (bytes[offset + 5] << 16) |
        (bytes[offset + 6] << 8) |
        bytes[offset + 7];
    int z = (bytes[offset + 8] << 24) |
        (bytes[offset + 9] << 16) |
        (bytes[offset + 10] << 8) |
        bytes[offset + 11];
    int w = (bytes[offset + 12] << 24) |
        (bytes[offset + 13] << 16) |
        (bytes[offset + 14] << 8) |
        bytes[offset + 15];

    if ((y | z | x | w) == 0) return nil;

    return new _Uuid._(x, y, z, w);
  }

  const _Uuid._(this.x, this.y, this.z, this.w);

  Uint8List get bytes => new Uint8List.fromList(<int>[
        x >> 24, x >> 16, x >> 8, x, //
        y >> 24, y >> 16, y >> 8, y,
        z >> 24, z >> 16, z >> 8, z,
        w >> 24, w >> 16, w >> 8, w,
      ]);

  int get hashCode => (x ^ y) ^ (z ^ w);

  Variant get variant {
    assert((z >> 29) >= 0 && (z >> 29) <= 7);

    const variants = const <Variant>[
      Variant.ncs, // 0 0 0
      Variant.ncs, // 0 0 1
      Variant.ncs, // 0 1 0
      Variant.ncs, // 0 1 1
      Variant.rfc4122, // 1 0 0
      Variant.rfc4122, // 1 0 1
      Variant.microsoft, // 1 1 0
      Variant.future, // 1 1 1
    ];

    return variants[z >> 29];
  }

  int get version => (y & 0xF000) >> 12;

  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is _Uuid &&
        this.x == other.x &&
        this.y == other.y &&
        this.z == other.z &&
        this.w == other.w) {
      return true;
    } else if (other is Uuid) {
      return compareTo(other) == 0;
    }
    return false;
  }

  bool operator >(Uuid other) => compareTo(other) > 0;
  bool operator >=(Uuid other) => compareTo(other) >= 0;
  bool operator <(Uuid other) => compareTo(other) < 0;
  bool operator <=(Uuid other) => compareTo(other) <= 0;

  ///
  int compareTo(Uuid other) {
    int ver = version;

    int diff = ver - other.version;
    if (diff != 0) return diff;

    if (other is _Uuid) {
      // compare timestamps for v1 UUIDs
      if (ver == 1) {
        // time hi
        diff = (y & 0xFFFF) - (other.y & 0xFFFF);
        if (diff != 0) return diff;

        // time mid
        diff = (y >> 16) - (other.y >> 16);
        if (diff != 0) return diff;

        // time lo
        diff = x - other.x;
        if (diff != 0) return diff;
      } else {
        diff = x - other.x;
        if (diff != 0) return diff;

        diff = y - other.y;
        if (diff != 0) return diff;
      }

      diff = z - other.z;
      if (diff != 0) return diff;

      diff = w - other.w;
      if (diff != 0) return diff;

      return 0;
    }

    return -1 * other.compareTo(this);
  }

  String toString() {
    _stringBuffer[0] = hexCodeUnits[((x >> 24) & 0xFF) >> 4];
    _stringBuffer[1] = hexCodeUnits[(x >> 24) & 0x0F];
    _stringBuffer[2] = hexCodeUnits[((x >> 16) & 0xFF) >> 4];
    _stringBuffer[3] = hexCodeUnits[(x >> 16) & 0x0F];
    _stringBuffer[4] = hexCodeUnits[((x >> 8) & 0xFF) >> 4];
    _stringBuffer[5] = hexCodeUnits[(x >> 8) & 0x0F];
    _stringBuffer[6] = hexCodeUnits[(x & 0xFF) >> 4];
    _stringBuffer[7] = hexCodeUnits[x & 0x0F];

    _stringBuffer[9] = hexCodeUnits[((y >> 24) & 0xFF) >> 4];
    _stringBuffer[10] = hexCodeUnits[(y >> 24) & 0x0F];
    _stringBuffer[11] = hexCodeUnits[((y >> 16) & 0xFF) >> 4];
    _stringBuffer[12] = hexCodeUnits[(y >> 16) & 0x0F];

    _stringBuffer[14] = hexCodeUnits[((y >> 8) & 0xFF) >> 4];
    _stringBuffer[15] = hexCodeUnits[(y >> 8) & 0x0F];
    _stringBuffer[16] = hexCodeUnits[(y & 0xFF) >> 4];
    _stringBuffer[17] = hexCodeUnits[y & 0x0F];

    _stringBuffer[19] = hexCodeUnits[((z >> 24) & 0xFF) >> 4];
    _stringBuffer[20] = hexCodeUnits[(z >> 24) & 0x0F];
    _stringBuffer[21] = hexCodeUnits[((z >> 16) & 0xFF) >> 4];
    _stringBuffer[22] = hexCodeUnits[(z >> 16) & 0x0F];

    _stringBuffer[24] = hexCodeUnits[((z >> 8) & 0xFF) >> 4];
    _stringBuffer[25] = hexCodeUnits[(z >> 8) & 0x0F];
    _stringBuffer[26] = hexCodeUnits[(z & 0xFF) >> 4];
    _stringBuffer[27] = hexCodeUnits[z & 0x0F];
    _stringBuffer[28] = hexCodeUnits[((w >> 24) & 0xFF) >> 4];
    _stringBuffer[29] = hexCodeUnits[(w >> 24) & 0x0F];
    _stringBuffer[30] = hexCodeUnits[((w >> 16) & 0xFF) >> 4];
    _stringBuffer[31] = hexCodeUnits[(w >> 16) & 0x0F];
    _stringBuffer[32] = hexCodeUnits[((w >> 8) & 0xFF) >> 4];
    _stringBuffer[33] = hexCodeUnits[(w >> 8) & 0x0F];
    _stringBuffer[34] = hexCodeUnits[(w & 0xFF) >> 4];
    _stringBuffer[35] = hexCodeUnits[w & 0x0F];

    return new String.fromCharCodes(_stringBuffer);
  }
}
