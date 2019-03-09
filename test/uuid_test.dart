import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:uuid_type/uuid_type.dart';
import 'test_data.dart';

void main() {
  group("UUID", () {
    group("Constructing", () {
      test("Can be created from canonical string", () {
        var u = new Uuid(nsStrings["dns"]);

        expect(u.variant, Variant.rfc4122);
        expect(u.version, 1);
        expect(u.toString(), nsStrings["dns"]);
      });

      test("Invalid string throws", () {
        invalidStrings.forEach((String source) {
          expect(() => new Uuid(source), throwsFormatException);
        });
      });

      test("Non-canonical hex string throws", () {
        expect(() => new Uuid(validStrings[2]), throwsFormatException);
      });

      test("Can be created from byte array", () {
        var u = new Uuid.fromBytes(l2b(nsBytes["dns"]));

        expect(u.variant, Variant.rfc4122);
        expect(u.version, 1);
        expect(u.bytes, nsBytes["dns"]);
      });

      test("Byte array with slice length <> 16 throws", () {
        expect(() => new Uuid.fromBytes(new Uint8List(0)), throwsArgumentError);
        expect(() => new Uuid.fromBytes(new Uint8List(17), 2),
            throwsArgumentError);
      });
    });

    group("Parsing", () {
      test("Can be parsed from various formats", () {
        var std = validStrings[0];

        validStrings.forEach((String source) {
          expect((Uuid.parse(source)).toString(), std);
        });
      });

      test("Invalid string throws FormatException", () {
        invalidStrings.forEach((String source) {
          expect(() => Uuid.parse(source), throwsFormatException);
        });
      });
    });

    group("Nil", () {
      test("Zero byte array creates Nil UUID", () {
        expect(identical(testNil, Uuid.nil), isTrue);
      });

      test("Nil string creates Nil UUID", () {
        expect(identical(new Uuid(nsStrings["nil"]), Uuid.nil), isTrue);
      });

      test("Nil strings are parsed to Nil UUID", () {
        nilStrings.forEach((String source) {
          expect(identical(Uuid.parse(source), Uuid.nil), isTrue);
        });
      });
    });

    group("Accessors", () {
      test("Shows correct variant", () {
        var bytes = l2b(fullList);
        for (int i = 0; i <= 7; i++) {
          bytes[8] = 0x00 | i << 5;
          expect(new Uuid.fromBytes(bytes).variant, testVariants[i]);

          bytes[8] = 0x1F | i << 5;
          expect(new Uuid.fromBytes(bytes).variant, testVariants[i]);
        }
      });

      test("Shows correct version", () {
        var bytes = l2b(fullList);
        // set RFC variant
        bytes[8] = (bytes[8] & 0x3F) | 0x80;

        for (int v = 0; v <= 15; v++) {
          bytes[6] = 0x00 | v << 4;
          expect(new Uuid.fromBytes(bytes).version, equals(v));

          bytes[6] = 0x0F | v << 4;
          expect(new Uuid.fromBytes(bytes).version, equals(v));
        }
      });
    });

    group("Comparison", () {
      test("Equality operator overloading works", () {
        expect(new Uuid.fromBytes(l2b(nsBytes["nil"])) == Uuid.nil, isTrue);
      });

      // todo(): better test case here
      test("compareTo works", () {
        var dns = new Uuid.fromBytes(l2b(nsBytes["dns"]));
        var u = new Uuid.fromBytes(new Uint8List.fromList(<int>[
          0x7D, 0x44, 0x48, 0x40, //
          0x9D, 0xC0,
          0x11, 0xD1,
          0xB2, 0x45,
          0x5F, 0xFD, 0xCE, 0x74, 0xFA,
          0xD2
        ]));

        expect(Comparable.compare(Uuid.nil, testNil) == 0, isTrue);
        expect(Comparable.compare(Uuid.nil, u) < 0, isTrue);
        expect(Comparable.compare(u, Uuid.nil) > 0, isTrue);
        expect(Comparable.compare(u, u) == 0, isTrue);
        expect(Comparable.compare(u, dns) > 0, isTrue);
        expect(Comparable.compare(dns, u) < 0, isTrue);
      });

      test("Node comparison works", () {
        var ua = new Uuid("00000000-0000-1000-8000-100000000000");
        var ub = new Uuid("00000000-0000-1000-8000-010000000000");
        expect(Comparable.compare(ua, ub) > 0, isTrue);
      });

      test("Same UUIDs have same hashCode", () {
        var ua = new Uuid("00000000-0000-1000-8000-100000000000");
        var ub = new Uuid("00000000-0000-1000-8000-100000000000");
        expect(ua.hashCode, ub.hashCode);
      });

      test("hashCode doesn't overflow", () {
        var u = new Uuid("ffffffff-ffff-50ff-bfff-ffffffffffff");
        expect(u.hashCode, 1073786624);
      });
    });

    group("Bytes", () {
      test("Returns same bytes", () {
        nsBytes.forEach((k, v) {
          var bytes = l2b(v);
          expect(new Uuid.fromBytes(bytes).bytes, bytes);
        });
      });

      test("Buffer", () {
        var u1 = new Uuid.fromBytes(l2b(nsBytes["dns"]));
        var u2 = new Uuid.fromBytes(l2b(nsBytes["url"]));
        expect(u2.bytes, nsBytes["url"]);
        expect(u1.bytes, nsBytes["dns"]);
      });
    });

    group("Serialization", () {
      test("Returns correct string", () {
        nsBytes.forEach((String k, List<int> v) {
          expect(new Uuid.fromBytes(l2b(v)).toString(), nsStrings[k]);
        });
      });
    });
  });
}
