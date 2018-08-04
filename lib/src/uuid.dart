// Copyright (c) 2018, Denis Portnov. All rights reserved.
// Released under MIT License that can be found in the LICENSE file.

library uuid_type;

import 'dart:typed_data';

import 'hex.dart';

/// This object represents an UUID, 128 bit Universal Unique IDentifier
/// as defined in [RFC 4122](https://tools.ietf.org/html/rfc4122).
abstract class Uuid implements Comparable<Uuid> {
  /// Shared buffer for byte representation for all instances
  static final _byteBuffer = new Uint8List(16);

  /// Nil UUID
  /// (see [RFC 4122 4.1.7](https://tools.ietf.org/html/rfc4122#section-4.1.7))
  static Uuid get nil => new Uuid.fromBytes(new Uint8List(16));

  /// Creates a new [Uuid] from canonical string representation
  ///
  /// If argument is not a valid UUID string [FormatException] is thrown.
  /// For parsing various UUID formats use [Uuid.parse]
  factory Uuid(String source) {
    assert(source != null);

    if (source.length != 36) {
      throw new FormatException(
        'UUID string has invalid length (${source.length})'
      );
    }

    const bytePositions = const <int>[
      0, 2, 4, 6, 9, 11, 14, 16, 19, 21, 24, 26, 28, 30, 32, 34
    ];

    var chars = source.codeUnits;
    int i = 0;

    try {
      for (int pos in bytePositions) {
        _byteBuffer[i] = hexBytes[chars[pos]-0x30] << 4 |
          hexBytes[chars[pos+1]-0x30];
        i++;
      }
    } catch (e) {
      throw new FormatException('Invalid UUID string "$source"');
    }

    return new Uuid.fromBytes(_byteBuffer);
  }

  /// Creates [Uuid] from byte array
  ///
  /// Optional [offset] is used to read 16 bytes of UUID from larger arrays
  /// Could return [Uuid.nil] in case of zero byte array
  factory Uuid.fromBytes(Uint8List bytes, [int offset]) = _Uuid.fromBytes;

  /// Returns representation of this [Uuid] as [Uint8List]
  /// The returned list is a copy, making it possible to change the list
  /// without affecting the [Uuid] instance.
  Uint8List get bytes;

  /// Returns hash code for this UUID
  ///
  /// Both [hashCode] and [operator ==] should be overridden to properly
  /// represent UUID state
  @override
  int get hashCode;

  /// Returns [Variant] defined in
  /// [RFC 4122](https://tools.ietf.org/html/rfc4122#section-4.1.1)
  Variant get variant;

  /// Returns UUID version defined in
  /// [RFC 4122](https://tools.ietf.org/html/rfc4122#section-4.1.3)
  int get version;

  /// Compares this UUID to [Object] assuming it represents another UUID
  @override
  bool operator ==(Object other);

  /// Compares this UUID to another [Uuid]
  ///
  /// Comparison is done in lexicographical order
  int compareTo(Uuid other);

  /// Returns canonical string representation of this [Uuid]
  String toString();

  /// Parses [source] as [Uuid]
  ///
  /// Throws [FormatException] in case of invalid UUID representation
  ///
  /// The [source] must be in one of the following UUID formats
  /// - Canonical string: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxxxx
  /// - Hex string of 36 chars: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  /// - URN: urn:uuid:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxxxx
  /// - Canonical GUID: {xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxxxx}
  /// - Hex GUID: {xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx}
  static Uuid parse(String source) {
    assert(source != null);

    var s = source.trim();

    if (s.length == 36) { // assume canonical
      return new Uuid(source);
    } else if (s.length == 1 + 36 + 1) { //assume GUID
      if (!(s[0] == '{' && s[s.length - 1] == '}')) {
        throw new FormatException('Invalid GUID string "$source"');
      }
      return new Uuid(s.substring(1, s.length - 1));
    } else if (s.length == 9 + 36) { // assume URN
      if (! s.startsWith('urn:uuid:')) {
        throw new FormatException('Invalid UUID URN string "$source"');
      }
      return new Uuid(source.substring(9));
    } else if (s.length == 1 + 32 + 1) { // hex GUID
      if (!(s[0] == '{' && s[s.length - 1] == '}')) {
        throw new FormatException('Invalid GUID string "$source"');
      }
      s = s.substring(1, s.length - 1);
    }

    if (s.length != 32) {
      throw new FormatException('Invalid UUID string "$source"');
    }

    // parse hex representation
    var chars = s.codeUnits;
    int pos = 0;
    try {
      for (int i = 0; i < 16; i++) {
        _byteBuffer[i] =
          hexBytes[chars[pos]-0x30] << 4 | hexBytes[chars[pos+1]-0x30];
        pos += 2;
      }
      return new Uuid.fromBytes(_byteBuffer);
    } catch (e) {
      throw new FormatException('Invalid UUID string "$source"');
    }
  }

  /// Parses [source] as [Uuid]
  ///
  /// Like [parse] except that this function returns `null` for invalid inputs
  //  instead of throwing.
  static Uuid tryParse(String source) {
    Uuid u;
    try {
      u = Uuid.parse(source);
    } catch (e) {}
    return u;
  }
}

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

class _Uuid implements Uuid {
  static const nil = const _Uuid._(0, 0, 0, 0);

  // Buffer to hold 36 chars canonical string
  static final Uint8List _stringBuffer = new Uint8List.fromList(const <int>[
    0,0,0,0,0,0,0,0,0x2D,
    0,0,0,0,0x2D,
    0,0,0,0,0x2D,
    0,0,0,0,0x2D,
    0,0,0,0,0,0,0,0,0,0,0,0
  ]); // time_low

  // UUID is stored as 4 x 32bit values
  final int x; // time_low
  final int y; // time_mid | time_hi_and_version
  final int z; // clk_seq_hi_res | clk_seq_low | node (0-1)
  final int w; // node (2-5)

  /// Implements [Uuid.fromBytes]
  factory _Uuid.fromBytes(Uint8List bytes, [int offset = 0]) {
    assert(bytes != null);

    if (offset + 16 > bytes.length) {
      throw new ArgumentError();
    }

    int x = (bytes[offset] << 24) | (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) | bytes[offset + 3];
    int y = (bytes[offset + 4] << 24) | (bytes[offset + 5] << 16) |
      (bytes[offset + 6] << 8) | bytes[offset + 7];
    int z = (bytes[offset + 8] << 24) | (bytes[offset + 9] << 16) |
      (bytes[offset + 10] << 8) | bytes[offset + 11];
    int w = (bytes[offset + 12] << 24) | (bytes[offset + 13] << 16) |
      (bytes[offset + 14] << 8) | bytes[offset + 15];

    if (y == 0 && z == 0 && x == 0 && w == 0) return nil;

    return new _Uuid._(x, y, z, w);
  }

  const _Uuid._(this.x, this.y, this.z, this.w);

  Uint8List get bytes {
    var buffer = new Uint8List(16);
    buffer[0] = (x >> 24);
    buffer[1] = (x >> 16);
    buffer[2] = (x >> 8);
    buffer[3] = x;

    buffer[4] = (y >> 24);
    buffer[5] = (y >> 16);
    buffer[6] = (y >> 8);
    buffer[7] = y;

    buffer[8] = (z >> 24);
    buffer[9] = (z >> 16);
    buffer[10] = (z >> 8);
    buffer[11] = z;

    buffer[12] = (w >> 24);
    buffer[13] = (w >> 16);
    buffer[14] = (w >> 8);
    buffer[15] = w;

    return buffer;
  }

  @override
  int get hashCode {
    const m = 0x5BD1E995;
    const n = 16;
    const r = 24;

    int hash = n;

    int k = x * m;
    k ^= k >> r;
    k *= m;

    hash ^= k;
    hash *= m;

    k = y * m;
    k ^= k >> r;
    k *= m;

    hash ^= k;
    hash *= m;

    k = z * m;
    k ^= k >> r;
    k *= m;

    hash ^= k;
    hash *= m;

    k = w * m;
    k ^= k >> r;
    k *= m;

    hash ^= k;
    hash *= m;

    return hash;
  }

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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is _Uuid && this.x == other.x &&
      this.y == other.y && this.z == other.z && this.w == other.w) {
      return true;
    } else if (other is Uuid) {
      return compareTo(other) == 0;
    }
    return false;
  }

  /// Implements [Comparable.compareTo] for [Uuid]
  int compareTo(Uuid other) {
    // compare version first
    int diff = version - other.version;
    if (diff != 0) diff;

    if (other is _Uuid) {
      diff = x - other.x;
      if (diff != 0) return diff;
      diff = y - other.y;
      if (diff != 0) return diff;
      diff = z - other.z;
      if (diff != 0) return diff;
      diff = w - other.w;
      if (diff != 0) return diff;

      return 0;
    }

    return -1 * other.compareTo(this);
  }

  /// Implements [Uuid.toString]
  String toString() {
    var b = this.bytes;

    _stringBuffer[0] = hexDigitsLower[b[0] >> 4];
    _stringBuffer[1] = hexDigitsLower[b[0] & 0x0F];
    _stringBuffer[2] = hexDigitsLower[b[1] >> 4];
    _stringBuffer[3] = hexDigitsLower[b[1] & 0x0F];
    _stringBuffer[4] = hexDigitsLower[b[2] >> 4];
    _stringBuffer[5] = hexDigitsLower[b[2] & 0x0F];
    _stringBuffer[6] = hexDigitsLower[b[3] >> 4];
    _stringBuffer[7] = hexDigitsLower[b[3] & 0x0F];

    _stringBuffer[9] = hexDigitsLower[b[4] >> 4];
    _stringBuffer[10] = hexDigitsLower[b[4] & 0x0F];
    _stringBuffer[11] = hexDigitsLower[b[5] >> 4];
    _stringBuffer[12] = hexDigitsLower[b[5] & 0x0F];

    _stringBuffer[14] = hexDigitsLower[b[6] >> 4];
    _stringBuffer[15] = hexDigitsLower[b[6] & 0x0F];
    _stringBuffer[16] = hexDigitsLower[b[7] >> 4];
    _stringBuffer[17] = hexDigitsLower[b[7] & 0x0F];

    _stringBuffer[19] = hexDigitsLower[b[8] >> 4];
    _stringBuffer[20] = hexDigitsLower[b[8] & 0x0F];
    _stringBuffer[21] = hexDigitsLower[b[9] >> 4];
    _stringBuffer[22] = hexDigitsLower[b[9] & 0x0F];

    _stringBuffer[24] = hexDigitsLower[b[10] >> 4];
    _stringBuffer[25] = hexDigitsLower[b[10] & 0x0F];
    _stringBuffer[26] = hexDigitsLower[b[11] >> 4];
    _stringBuffer[27] = hexDigitsLower[b[11] & 0x0F];
    _stringBuffer[28] = hexDigitsLower[b[12] >> 4];
    _stringBuffer[29] = hexDigitsLower[b[12] & 0x0F];
    _stringBuffer[30] = hexDigitsLower[b[13] >> 4];
    _stringBuffer[31] = hexDigitsLower[b[13] & 0x0F];
    _stringBuffer[32] = hexDigitsLower[b[14] >> 4];
    _stringBuffer[33] = hexDigitsLower[b[14] & 0x0F];
    _stringBuffer[34] = hexDigitsLower[b[15] >> 4];
    _stringBuffer[35] = hexDigitsLower[b[15] & 0x0F];

    return new String.fromCharCodes(_stringBuffer);
  }
}