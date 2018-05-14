import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:uuid_type/uuid_type.dart';

const zeroList = const <int>[
  0x00, 0x00, 0x00, 0x00,
  0x00, 0x00,
  0x00, 0x00,
  0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00
];

const fullList = const <int>[
  0xFF, 0xFF, 0xFF, 0xFF,
  0xFF, 0xFF,
  0xFF, 0xFF,
  0xFF, 0xFF,
  0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
];

const uuidBytes = const <String, List<int>>{
  "nil": zeroList,
  "ns-dns": const [
    0x6B, 0xA7, 0xB8, 0x10,
    0x9D, 0xAD,
    0x11, 0xD1,
    0x80, 0xB4,
    0x00, 0xC0, 0x4F, 0xD4, 0x30, 0xC8
  ],
  "ns-url": const [
    0x6B, 0xA7, 0xB8, 0x11,
    0x9D, 0xAD,
    0x11, 0xD1,
    0x80, 0xB4,
    0x00, 0xC0, 0x4F, 0xD4, 0x30, 0xC8
  ],
  "ns-oid": const [
    0x6B, 0xA7, 0xB8, 0x12,
    0x9D, 0xAD,
    0x11, 0xD1,
    0x80, 0xB4,
    0x00, 0xC0, 0x4F, 0xD4, 0x30, 0xC8
  ],
  "ns-x500": const [
    0x6B, 0xA7, 0xB8, 0x14,
    0x9D, 0xAD,
    0x11, 0xD1,
    0x80, 0xB4,
    0x00, 0xC0, 0x4F, 0xD4, 0x30, 0xC8
  ],
};

const uuidNsStrings = const <String, String>{
  "nil": "00000000-0000-0000-0000-000000000000",
  "ns-dns": "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
  "ns-url": "6ba7b811-9dad-11d1-80b4-00c04fd430c8",
  "ns-oid": "6ba7b812-9dad-11d1-80b4-00c04fd430c8",
  "ns-x500": "6ba7b814-9dad-11d1-80b4-00c04fd430c8",
};

const validStrings = const <String>[
  // canonical, lower case
  '6ba7b811-9dad-11d1-80b4-00c04fd430c8',
  // canonical, upper case
  '6BA7B811-9DAD-11D1-80B4-00C04fD430C8',
  // hex
  '6ba7b8119dad11d180b400c04fd430c8',
  // hex uppercase
  '6BA7B8119DAD11D180B400C04FD430C8',
  // hex mixed case
  '6Ba7b8119Dad11d180B400c04fD430c8',
  // GUID
  '{6ba7b811-9dad-11d1-80b4-00c04fd430c8}',
  '{6ba7b8119dad11d180b400c04fd430c8}',
  // URN
  'urn:uuid:6ba7b811-9dad-11d1-80b4-00c04fd430c8',
];

const invalidStrings = const <String>[
  // too short
  '6ba7b811-9dad-11d1-80b4-00c04fd430',
  // too long
  '6ba7b811-9dad-11d1-80b4-00c04fd430000',
  // extra markup
  '6ba7b811-9dad-11d1-80b4-00c0-4fd43000',
  // invalid URN
  'urn uuid 6ba7b811-9dad-11d1-80b4-00c04fd430c8',
  'urn:uuid:6ba7b8119dad11d180b400c04fd430c8',
  // invalid GUID
  '[6ba7b811-9dad-11d1-80b4-00c04fd430c8]',
  // too short hex
  '6ba7b8119dad11d180b400c04fd430',
  // too long hex
  '6ba7b8119dad11d180b400c04fd430c800',
  // invalid hex chars
  'xxxxb811-9dad-11d1-80b4-00c04fd430',
  'xxxxb8119dad11d180b400c04fd430',
];

const nilStrings = const <String>[
  '00000000-0000-0000-0000-000000000000',
  '00000000000000000000000000000000',
  '{00000000-0000-0000-0000-000000000000}',
  '{00000000000000000000000000000000}',
  'urn:uuid:00000000-0000-0000-0000-000000000000',
];

const testVariants = const <Variant>[
  Variant.ncs, // 0 0 0
  Variant.ncs, // 0 0 1
  Variant.ncs, // 0 1 0
  Variant.ncs, // 0 1 1
  Variant.rfc4122, // 1 0 0
  Variant.rfc4122, // 1 0 1
  Variant.microsoft, // 1 1 0
  Variant.future, // 1 1 1
];

Uint8List l2b(List<int> list) {
  return new Uint8List.fromList(list);
}

Uuid testNil = new Uuid.fromBytes(l2b(zeroList));

void main() {
  group('UUID', () {
    group('Constructors', () {
      test('Can be created from canonical string', () {
        var u = new Uuid(uuidNsStrings['ns-dns']);

        expect(u.variant, Variant.rfc4122);
        expect(u.version, 1);
        expect(u.toString(), uuidNsStrings['ns-dns']);
      });

      test('Invalid string throws', () {
        invalidStrings.forEach((String source) {
          expect(() => new Uuid(source), throwsFormatException);
        });
      });

      test('Non-canonical hex string throws', () {
        expect(() => new Uuid(validStrings[2]), throwsFormatException);
      });

      test('Can be created from byte array', () {
        var u = new Uuid.fromBytes(l2b(uuidBytes['ns-dns']));

        expect(u.variant, Variant.rfc4122);
        expect(u.version, 1);
        expect(u.bytes, equals(uuidBytes['ns-dns']));
      });

      test('Byte array with slice length <> 16 throws', () {
        expect(() => new Uuid.fromBytes(new Uint8List(0)), throwsArgumentError);
        expect(() => new Uuid.fromBytes(new Uint8List(17), 2), throwsArgumentError);
      });



      /*
      test('Invalid version for RFC variant throws', () {
        var bytes = l2b(fullList);
        // set RFC variant
        bytes[8] = (bytes[8] & 0x3f) | 0x80;

        // set version 0 (< 1)
        bytes[6] = (bytes[6] & 0x0f) | 0x00;
        expect(() => new Uuid.fromBytes(bytes), throwsUnsupportedError);

        // set version 6 (> 5)
        bytes[6] = (bytes[6] & 0x0f) | 0x60;
        expect(() => new Uuid.fromBytes(bytes), throwsUnsupportedError);
      });
      */
    });

    group('Parsing', () {
      test('Can be parsed from various formats', () {
        var std = validStrings[0];

        validStrings.forEach((String source) {
          expect((Uuid.parse(source)).toString(), std);
        });
      });

      test('Invalid string throws FormatException', () {
        invalidStrings.forEach((String source) {
          //print('  source = $source');
          expect(() => Uuid.parse(source), throwsFormatException);
        });
      });
    });

    group('Nil', () {
      test('Zero byte array creates Nil UUID', () {
        expect(identical(testNil, Uuid.nil), true);
      });

      test('Nil string creates Nil UUID', () {
        expect(identical(new Uuid(uuidNsStrings['nil']), Uuid.nil), true);
      });

      test('Nil strings are parsed to Nil UUID', () {
        nilStrings.forEach((String source) {
          expect(identical(Uuid.parse(source), Uuid.nil), true);
        });
      });
    });

    group('Accessors', () {
      test('Shows correct variant', () {
        var bytes = l2b(fullList);
        for (int i = 0; i <= 7; i++) {
          bytes[8] = 0x00 | i << 5;
          expect(new Uuid.fromBytes(bytes).variant, testVariants[i]);

          bytes[8] = 0x1F | i << 5;
          expect(new Uuid.fromBytes(bytes).variant, testVariants[i]);
        }
      });

      test('Shows correct version', () {
        var bytes = l2b(fullList);
        // set RFC variant
        bytes[8] = (bytes[8] & 0x3F) | 0x80;

        for (int v = 0; v <= 15; v++) {
          bytes[6] = 0x00 | v << 4;
          expect(new Uuid.fromBytes(bytes).version, v);

          bytes[6] = 0x0F | v << 4;
          expect(new Uuid.fromBytes(bytes).version, v);
        }
      });
    });

    group('Comparison', () {
      test('Equality operator overloading works', () {
        expect(new Uuid.fromBytes(l2b(uuidBytes['nil'])) == Uuid.nil, true);
      });

      test('compareTo works', () {
        var dns = new Uuid.fromBytes(l2b(uuidBytes['ns-dns']));
        // todo(): better test case here
        var u = new Uuid.fromBytes(new Uint8List.fromList(<int>[
          0x7d, 0x44, 0x48, 0x40,
          0x9d, 0xc0,
          0x11, 0xd1,
          0xb2, 0x45,
          0x5f, 0xfd, 0xce, 0x74, 0xfa,
          0xd2
        ]));

        expect(Comparable.compare(Uuid.nil, testNil) == 0, true);
        expect(Comparable.compare(Uuid.nil, u) < 0, true);
        expect(Comparable.compare(u, Uuid.nil) > 0, true);
        expect(Comparable.compare(u, u) == 0, true);
        expect(Comparable.compare(u, dns) > 0, true);
        expect(Comparable.compare(dns, u) < 0, true);
      });

      test('Node comparison works', () {
        var ua = new Uuid('00000000-0000-1000-8000-100000000000');
        var ub = new Uuid('00000000-0000-1000-8000-010000000000');

        expect(Comparable.compare(ua, ub) > 0, true);
      });

      // todo(denix) compare versions <> 1

      test('UUIDs with the same hashCode are equal', () {
        var ua = new Uuid('00000000-0000-1000-8000-100000000000');
        var ub = new Uuid('00000000-0000-1000-8000-100000000000');

        expect(ua.hashCode == ub.hashCode, true);
        expect(ua == ub, true);
      });
    });

    group('Bytes', () {
      test('Returns same bytes', () {
        uuidBytes.forEach((k, v) {
          var bytes = l2b(v);
          expect(new Uuid.fromBytes(bytes).bytes, equals(bytes));
        });
      });

      test('Buffer', () {
        var u1 = new Uuid.fromBytes(l2b(uuidBytes['ns-dns']));
        var u2 = new Uuid.fromBytes(l2b(uuidBytes['ns-url']));
        expect(u2.bytes, equals(uuidBytes['ns-url']));
        expect(u1.bytes, equals(uuidBytes['ns-dns']));
      });
    });

    group('Serialization', () {
      test('Returns correct string', () {
        uuidBytes.forEach((k, v) {
          expect(new Uuid.fromBytes(l2b(v)).toString(), uuidNsStrings[k]);
        });
      });
    });
  });
}
