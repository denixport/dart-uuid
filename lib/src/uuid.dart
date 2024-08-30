// Copyright (c) 2018-2024, Denis Portnov. All rights reserved.
// Released under MIT License that can be found in the LICENSE file.

library uuid_type;

import 'dart:typed_data' show Uint8List;

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
  /// Nil UUID
  /// (see [RFC 4122 4.1.7](https://tools.ietf.org/html/rfc4122#section-4.1.7))
  static Uuid get nil => Uuid.fromBytes(Uint8List(16));

  // Shared buffer for byte representation for all instances
  static final _buffer = Uint8List(16);

  /// Creates [Uuid] from byte array
  ///
  /// Optional [offset] is used to read 16 bytes of UUID from larger arrays
  /// Would return [Uuid.nil] when zero byte array is provided
  factory Uuid.fromBytes(Uint8List bytes, [int offset]) = _Uuid.fromBytes;

  @override
  int get hashCode;

  /// Variant defined in
  /// [RFC 4122](https://tools.ietf.org/html/rfc4122#section-4.1.1)
  Variant get variant;

  /// Version defined in
  /// [RFC 4122](https://tools.ietf.org/html/rfc4122#section-4.1.3)
  int get version;

  @override
  bool operator ==(Object other);

  /// Greater than operator,  see [compareTo] for rules
  bool operator >(Uuid other);

  /// Greater than or equal operator, see [compareTo] for rules
  bool operator >=(Uuid other);

  /// Less than operator, see [compareTo] for rules
  bool operator <(Uuid other);

  /// Less than or equal operator, see [compareTo] for rules
  bool operator <=(Uuid other);

  /// Compares this UUID to another [Uuid]
  ///
  /// First, compares by version
  /// then, if it's time-based v1 UUID, compares timestamps,
  /// then compares all bytes lexically
  @override
  int compareTo(Uuid other) {
    final ver = version;
    var diff = ver - other.version;

    if (diff != 0) return diff;

    var a = toBytes();
    var b = other.toBytes();

    if (ver == 1) {
      for (var pos in const <int>[7, 4, 5, 0, 1, 2, 3]) {
        diff = a[pos] - b[pos];
        if (diff != 0) return diff;
      }
      return 0;
    }

    // other versions, compare in lexicographical order
    for (var pos = 0; pos < 16; pos++) {
      diff = a[pos] - b[pos];
      if (diff != 0) return diff;
    }

    return 0;
  }

  /// Returns byte array of this UUID
  Uint8List toBytes();

  /// Returns canonical string representation
  @override
  String toString();

  // Converts 2 hex chars into one byte, returns value < 0 if not hex chars
  static int _hexChars2Byte(int c1, int c2) {
    const hexBytes = <int>[
      0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, //
      0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
      0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0f,
      0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
      0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
      0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
      0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f
    ];

    c1 -= 0x30;
    if (c1 < 0 || c1 >= hexBytes.length) return -2;

    c2 -= 0x30;
    if (c2 < 0 || c2 >= hexBytes.length) return -1;

    var b1 = hexBytes[c1];
    if (b1 == 0xff) return -2;

    var b2 = hexBytes[c2];
    if (b2 == 0xff) return -1;

    return (b1 << 4) | b2;
  }

  // parses standard UUID string into _buffer
  static FormatException? _parseStd(String source) {
    const bytePositions = <int>[
      0, 2, 4, 6, 9, 11, 14, 16, 19, 21, 24, 26, 28, 30, 32, 34 //
    ];
    const dashPositions = <int>[8, 13, 18, 23];

    var chars = source.codeUnits;
    assert(chars.length == 36);

    // check '-' positions
    for (var pos in dashPositions) {
      if (chars[pos] != 0x2d) {
        return FormatException('Separator char expected', source, pos);
      }
    }

    var i = 0;
    for (var pos in bytePositions) {
      var b = _hexChars2Byte(chars[pos], chars[pos + 1]);
      if (b < 0) {
        return FormatException('Invalid hex char', source, pos + b + 2);
      }
      _buffer[i++] = b;
    }

    return null;
  }

  // Parses UUID string into _buffer, returns FormatException if parsing fails
  static FormatException? _parse(String source) {
    if (source.length == 36) {
      return _parseStd(source);
    } else if (source.length == 1 + 36 + 1) {
      // GUID
      if (!(source[0] == '{' && source[source.length - 1] == '}')) {
        return FormatException('Invalid GUID string', source);
      }
      return _parseStd(source.substring(1, source.length - 1));
    } else if (source.length == 1 + 32 + 1) {
      // hex GUID
      if (!(source[0] == '{' && source[source.length - 1] == '}')) {
        return FormatException('Invalid GUID string', source);
      }
      source = source.substring(1, source.length - 1);
    } else if (source.length == 9 + 36) {
      // URN
      if (!source.startsWith('urn:uuid:')) {
        return FormatException('Invalid UUID URN string', source);
      }
      return _parseStd(source.substring(9));
    }

    if (source.length != 32) {
      return FormatException('Invalid UUID hex string length', source);
    }

    // parse 32-char hex

    var chars = source.codeUnits;

    for (var i = 0; i < 16; i++) {
      var b = _hexChars2Byte(chars[2 * i], chars[2 * i + 1]);
      if (b < 0) {
        return FormatException('Invalid hex char', source, 2 * i + b + 2);
      }
      _buffer[i] = b;
    }

    return null;
  }

  /// Parses [source] string as [Uuid]. Parsing is case insensitive.
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
    return Uuid.fromBytes(_buffer);
  }

  /// Parses [source] as [Uuid]. Parsing is case insensitive.
  ///
  /// Like [parse] except it returns `null` for invalid inputs
  ///  instead of throwing.
  static Uuid? tryParse(String source) {
    if (_parse(source) != null) return null;
    return Uuid.fromBytes(_buffer);
  }
}

class _Uuid implements Uuid {
  static const nil = _Uuid._(0, 0, 0, 0);

  // Shared buffer for byte representation for all instances
  static final _buffer = Uint8List(16);

  // Shared buffer of canonical string representation
  static final Uint8List _strBuffer = Uint8List.fromList(const <int>[
    0, 0, 0, 0, 0, 0, 0, 0, 0x2D, //
    0, 0, 0, 0, 0x2D,
    0, 0, 0, 0, 0x2D,
    0, 0, 0, 0, 0x2D,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  ]); // time_low

  // UUID is stored as 4 x 32bit unsigned integers
  final int x; // time_low
  final int y; // time_mid | time_hi_and_version
  final int z; // clk_seq_hi_res | clk_seq_low | node (0-1)
  final int w; // node (2-5)

  /// Implements [Uuid.fromBytes]
  factory _Uuid.fromBytes(Uint8List bytes, [int offset = 0]) {
    if (offset < 0 || (offset + 16 > bytes.length)) {
      throw ArgumentError('Invalid offset');
    }

    var x = (bytes[offset + 0] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];
    var y = (bytes[offset + 4] << 24) |
    (bytes[offset + 5] << 16) |
    (bytes[offset + 6] << 8) |
    bytes[offset + 7];
    var z = (bytes[offset + 8] << 24) |
    (bytes[offset + 9] << 16) |
    (bytes[offset + 10] << 8) |
    bytes[offset + 11];
    var w = (bytes[offset + 12] << 24) |
    (bytes[offset + 13] << 16) |
    (bytes[offset + 14] << 8) |
    bytes[offset + 15];

    if ((y | z | x | w) == 0) return nil;

    return _Uuid._(x, y, z, w);
  }

  const _Uuid._(this.x, this.y, this.z, this.w);

  @override
  Variant get variant {
    assert((z >> 29) >= 0 && (z >> 29) <= 7);

    const variants = <Variant>[
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

  @override
  int get version => (y & 0xF000) >> 12;

  @override
  int get hashCode => (x ^ y) ^ (z ^ w);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is _Uuid &&
        x == other.x &&
        y == other.y &&
        z == other.z &&
        w == other.w) {
      return true;
    } else if (other is Uuid) {
      return compareTo(other) == 0;
    }
    return false;
  }

  @override
  bool operator >(Uuid other) => compareTo(other) > 0;

  @override
  bool operator >=(Uuid other) => compareTo(other) >= 0;

  @override
  bool operator <(Uuid other) => compareTo(other) < 0;

  @override
  bool operator <=(Uuid other) => compareTo(other) <= 0;

  @override
  int compareTo(Uuid other) {
    final ver = version;
    var diff = ver - other.version;

    if (diff != 0) return diff;

    if (other is! _Uuid) return -1 * other.compareTo(this);

    // compare timestamps for v1 UUIDs
    if (ver == 1) {
      // time hi
      diff = (y & 0xffff) - (other.y & 0xffff);
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

  @override
  Uint8List toBytes() {
    _buffer[0] = x >> 24;
    _buffer[1] = x >> 16;
    _buffer[2] = x >> 8;
    _buffer[3] = x;
    _buffer[4] = y >> 24;
    _buffer[5] = y >> 16;
    _buffer[6] = y >> 8;
    _buffer[7] = y;
    _buffer[8] = z >> 24;
    _buffer[9] = z >> 16;
    _buffer[10] = z >> 8;
    _buffer[11] = z;
    _buffer[12] = w >> 24;
    _buffer[13] = w >> 16;
    _buffer[14] = w >> 8;
    _buffer[15] = w;

    return _buffer.sublist(0);
  }

  @override
  String toString() {
    const hexcu = <int>[
      0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, // 0-9
      0x61, 0x62, 0x63, 0x64, 0x65, 0x66 // a-f
    ];

    _strBuffer[0] = hexcu[((x >> 24) & 0xff) >> 4];
    _strBuffer[1] = hexcu[(x >> 24) & 0x0f];
    _strBuffer[2] = hexcu[((x >> 16) & 0xff) >> 4];
    _strBuffer[3] = hexcu[(x >> 16) & 0x0f];
    _strBuffer[4] = hexcu[((x >> 8) & 0xff) >> 4];
    _strBuffer[5] = hexcu[(x >> 8) & 0x0f];
    _strBuffer[6] = hexcu[(x & 0xff) >> 4];
    _strBuffer[7] = hexcu[x & 0x0f];

    _strBuffer[9] = hexcu[((y >> 24) & 0xff) >> 4];
    _strBuffer[10] = hexcu[(y >> 24) & 0x0f];
    _strBuffer[11] = hexcu[((y >> 16) & 0xff) >> 4];
    _strBuffer[12] = hexcu[(y >> 16) & 0x0f];

    _strBuffer[14] = hexcu[((y >> 8) & 0xff) >> 4];
    _strBuffer[15] = hexcu[(y >> 8) & 0x0f];
    _strBuffer[16] = hexcu[(y & 0xff) >> 4];
    _strBuffer[17] = hexcu[y & 0x0f];

    _strBuffer[19] = hexcu[((z >> 24) & 0xff) >> 4];
    _strBuffer[20] = hexcu[(z >> 24) & 0x0f];
    _strBuffer[21] = hexcu[((z >> 16) & 0xff) >> 4];
    _strBuffer[22] = hexcu[(z >> 16) & 0x0f];

    _strBuffer[24] = hexcu[((z >> 8) & 0xff) >> 4];
    _strBuffer[25] = hexcu[(z >> 8) & 0x0f];
    _strBuffer[26] = hexcu[(z & 0xff) >> 4];
    _strBuffer[27] = hexcu[z & 0x0f];
    _strBuffer[28] = hexcu[((w >> 24) & 0xff) >> 4];
    _strBuffer[29] = hexcu[(w >> 24) & 0x0f];
    _strBuffer[30] = hexcu[((w >> 16) & 0xff) >> 4];
    _strBuffer[31] = hexcu[(w >> 16) & 0x0f];
    _strBuffer[32] = hexcu[((w >> 8) & 0xff) >> 4];
    _strBuffer[33] = hexcu[(w >> 8) & 0x0f];
    _strBuffer[34] = hexcu[(w & 0xff) >> 4];
    _strBuffer[35] = hexcu[w & 0x0f];

    return String.fromCharCodes(_strBuffer);
  }
}
