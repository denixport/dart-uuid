import 'dart:typed_data';
import 'hex.dart';

/// UUID variant according to RFC4122
enum Variant {
  ncs, // Reserved, NCS backward compatibility.
  rfc4122, // The variant specified in RFC4122
  microsoft, // Reserved, Microsoft Corporation backward compatibility.
  future // Reserved for future definition
}

abstract class Uuid implements Comparable<Uuid> {
  static Uuid get nil => new Uuid.fromBytes(new Uint8List(16));

  static final _byteBuffer = new Uint8List(16);

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

  factory Uuid.fromBytes(Uint8List bytes, [int offset]) = _Uuid.fromBytes;

  Variant get variant;

  int get version;

  //Uint8List get bytes;

  int get hashCode;

  bool operator ==(Object other);

  int compareTo(Uuid other);

  Uint8List toBytes();

  String toString();

  ///
  static Uuid parse(String source) {
    assert(source != null);

    if (source.length == 36) { // canonical
      return new Uuid(source);
    } else if (source.length == 1 + 36 + 1) { //assume GUID
      if (!(source[0] == '{' && source[source.length - 1] == '}')) {
        throw new FormatException('Invalid GUID string "$source"');
      }
      return new Uuid(source.substring(1, source.length - 1));
    } else if (source.length == 9 + 36) { // assume URN
      if (! source.startsWith('urn:uuid:')) {
        throw new FormatException('Invalid URN string "$source"');
      }
      return new Uuid(source.substring(9));
    } else if (source.length == 1 + 32 + 1) { // hex GUID
      if (!(source[0] == '{' && source[source.length - 1] == '}')) {
        throw new FormatException('Invalid GUID string "$source"');
      }
      source = source.substring(1, source.length - 1);
    }

    if (source.length != 32) {
      throw new FormatException('Invalid UUID string "$source"');
    }

    // parse hex representation
    var chars = source.codeUnits;
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

  ///
  static Uuid tryParse(String source) {
    Uuid u;
    try {
      u = Uuid.parse(source);
    } catch (e) {}
    return u;
  }
}


class _Uuid implements Uuid {
  static const nil = const _Uuid._(0, 0, 0, 0);

  final int x; // time_low
  final int y; // time_mid | time_hi_and_version
  final int z; // clk_seq_hi_res | clk_seq_low | node (0-1)
  final int w; // node (2-5)

  const _Uuid._(this.x, this.y, this.z, this.w);

  ///
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

  ///
  Variant get variant {
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

  ///
  int get version => (y & 0xF000) >> 12;

  //
  @override
  int get hashCode {
    const m = 0xC6A4A7935BD1E995;
    const n = m * 16;
    const r = 47;

    int hash = n;

    int k = (x << 28) | (y & 0x0F);
    k *= m;
    k ^= k >> r;
    k *= m;

    hash ^= k;
    hash *= m;

    k = ((z & 0x3F) << 28) | w;
    k *= m;
    k ^= k >> r;
    k *= m;

    hash ^= k;
    hash *= m;

    return hash;
  }

  ///
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

  ///
  int compareTo(Uuid other) {
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

  ///
  Uint8List toBytes() {
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

  static final Uint8List _stringBuffer = new Uint8List.fromList(const <int>[
    0,0,0,0,0,0,0,0,0x2D,
    0,0,0,0,0x2D,
    0,0,0,0,0x2D,
    0,0,0,0,0x2D,
    0,0,0,0,0,0,0,0,0,0,0,0
  ]);

  ///
  String toString() {
    var b = toBytes();

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