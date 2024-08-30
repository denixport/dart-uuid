import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:uuid_type/uuid_type.dart';

import 'test_data.dart';

void main() {
  group('UUID', () {
    group('Constructors', () {
      test('Can be created from bytes', () {
        var u = Uuid.fromBytes(dnsNsBytes);

        expect(u.variant, Variant.rfc4122);
        expect(u.version, 1);
        expect(u.toBytes(), dnsNsBytes);
      });

      test('Byte array with slice length <> 16 throws error', () {
        expect(() => Uuid.fromBytes(Uint8List(0)), throwsArgumentError);
        expect(() => Uuid.fromBytes(Uint8List(17), 2), throwsArgumentError);
      });

      test('Zero byte array creates Nil UUID', () {
        expect(identical(testNil, Uuid.nil), isTrue);
      });
    });

    group('Parsing', () {
      test('Can be parsed from various formats', () {
        final expected = validStrings[0];
        for (var source in validStrings) {
          expect((Uuid.parse(source)).toString(), expected);
        }
      });

      test('Invalid string throws FormatException', () {
        for (var source in invalidStrings) {
          expect(() => Uuid.parse(source), throwsFormatException);
        }
      });

      test('Nil strings are parsed to Nil UUID', () {
        for (var source in nilStrings) {
          expect(identical(Uuid.parse(source), Uuid.nil), isTrue);
        }
      });
    });

    group('Accessors', () {
      test('Shows correct variant', () {
        final bytes = l2b(maxByteList);
        for (var v = Variant.ncs.index; v <= Variant.future.index; v++) {
          bytes[8] = 0x00 | v << 5;
          expect(Uuid.fromBytes(bytes).variant, testVariants[v]);

          bytes[8] = 0x1f | v << 5;
          expect(Uuid.fromBytes(bytes).variant, testVariants[v]);
        }
      });

      test('Shows correct version', () {
        final bytes = l2b(maxByteList);
        // set RFC variant
        bytes[8] = (bytes[8] & 0x3f) | 0x80;

        for (var v = 0; v <= 15; v++) {
          bytes[6] = 0x00 | v << 4;
          expect(Uuid.fromBytes(bytes).version, equals(v));

          bytes[6] = 0x0f | v << 4;
          expect(Uuid.fromBytes(bytes).version, equals(v));
        }
      });
    });

    group('Comparison', () {
      test('Equality operator overloading works', () {
        expect(Uuid.fromBytes(nilBytes) == Uuid.nil, isTrue);
      });

      test('Base class compares correctly', () {
        final dns = Uuid.fromBytes(dnsNsBytes);
        final u = Uuid.parse('7d444840-9dc0-11d1-b245-5ffdce74fad2');

        expect(Comparable.compare(Uuid.nil, testNil) == 0, isTrue);
        expect(Comparable.compare(Uuid.nil, u) < 0, isTrue);
        expect(Comparable.compare(u, Uuid.nil) > 0, isTrue);
        expect(Comparable.compare(u, u) == 0, isTrue);
        expect(Comparable.compare(u, dns) > 0, isTrue);
        expect(Comparable.compare(dns, u) < 0, isTrue);
      });

      test('Time-based UUIDs are compared by timestamp', () {
        final older = Uuid.parse('00000001-0000-1000-0000-000000000000');
        final newer = Uuid.parse('00000002-0000-1000-0000-000000000000');

        expect(Comparable.compare(newer, older) > 0, isTrue);

        // same timestamp compared in lexicographical order
        final ua = Uuid.parse('00000000-1233-4235-8000-000000000000');
        final ub = Uuid.parse('00000000-1234-4234-8000-000000000000');
        expect(Comparable.compare(ua, ub) > 0, isFalse);
      });

      test('Node comparison works', () {
        var ua = Uuid.parse('00000000-0000-1000-8000-100000000000');
        var ub = Uuid.parse('00000000-0000-1000-8000-010000000000');
        expect(Comparable.compare(ua, ub) > 0, isTrue);
      });

      test('Same UUIDs have same hashCode', () {
        var ua = Uuid.parse('00000000-0000-1000-8000-100000000000');
        var ub = Uuid.parse('00000000-0000-1000-8000-100000000000');
        expect(ua.hashCode, ub.hashCode);
      });

      test('hashCode does not overflow', () {
        var u = Uuid.parse('ffffffff-ffff-50ff-bfff-ffffffffffff');
        expect(u.hashCode, 1073786624);
      });
    });

    group('Serialization', () {
      test('Returns correct string', () {
        expect(Uuid.fromBytes(dnsNsBytes).toString(), dnsNsString);
      });
    });
  });
}
