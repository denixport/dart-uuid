import 'dart:math';

import 'package:test/test.dart';
import 'package:uuid_type/uuid_type.dart';

import 'test_data.dart';

class RandomMock implements Random {
  final List<int> buffer;
  int ptr = 0;

  RandomMock(this.buffer);

  int nextInt(int max) {
    ptr++;
    ptr ~/= buffer.length;
    return buffer[ptr];
  }

  double nextDouble() => 0.0;

  bool nextBool() => true;
}

void main() {
  group("Time-based generator (v1)", () {
    test("Generates UUID with correct variant and version", () {
      var gen = TimeBasedUuidGenerator();
      var uuid = gen.generate();

      expect(uuid.variant, Variant.rfc4122);
      expect(uuid.version, 1);
    });

    test("Generates unique UUID sequence", () {
      var gen = TimeBasedUuidGenerator();
      const N = 10000;
      var uuids = List.generate(N, (int index) => gen.generate());

      // check
      var prev = uuids[0];
      for (var i = 1; i < N; i++) {
        expect(uuids[i], greaterThan(prev));
        prev = uuids[i];
      }
    });

    test("Can be created from state", () {
      var g1 = TimeBasedUuidGenerator();
      var state = g1.generate();

      var g2 = TimeBasedUuidGenerator.fromLastUuid(state);
      var uuid = g2.generate();

      expect(uuid, greaterThan(state));

      expect(g2.clockSequence, equals(g1.clockSequence));
      expect(g2.nodeId, equals(g1.nodeId));
    });

    test("Updates clock sequence on clock regression", () {
      var state = Uuid("fffffff0-ffff-1fff-8000-000000000000");

      var g = TimeBasedUuidGenerator.fromLastUuid(state);
      expect(g.clockSequence, 1);
    });

    test("Multiple generators produce unique ids", () {
      var umap = <Uuid, int>{};
      var gens = <TimeBasedUuidGenerator>[
        TimeBasedUuidGenerator(),
        TimeBasedUuidGenerator(),
        TimeBasedUuidGenerator(),
        TimeBasedUuidGenerator(),
        TimeBasedUuidGenerator()
      ];

      var gi = 0;
      for (var i = 0; i < gens.length * 100; i++) {
        var key = gens[gi].generate();

        expect(umap.containsKey(key), isFalse);

        umap[key] = gi;
        gi++;
        gi %= gens.length;
      }
    });
  });

  group("Random-based generator (v4)", () {
    test("Generates UUID with correct variant and version", () {
      var gen = RandomBasedUuidGenerator();
      var uuid = gen.generate();

      expect(uuid.variant, Variant.rfc4122);
      expect(uuid.version, 4);
    });

    test("Uses uint32 values correctly", () {
      var rnd =
          RandomMock(<int>[0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF]);

      var expected = Uuid.fromBytes(l2b(const <int>[
        0xFF, 0xFF, 0xFF, 0xFF, //
        0xFF, 0xFF,
        0x4F, 0xFF,
        0xBF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
      ]));

      var uuid = RandomBasedUuidGenerator(rnd).generate();

      expect(uuid, expected);
    });
  });

  group("Name-based generator (v5)", () {
    test("Generates UUID with correct variant and version", () {
      var gen = NameBasedUuidGenerator(NameBasedUuidGenerator.namespaceDns);
      var uuid = gen.generate("");

      expect(uuid.variant, Variant.rfc4122);
      expect(uuid.version, 5);
    });

    test("Generates correct UUIDs", () {
      var gen = NameBasedUuidGenerator(NameBasedUuidGenerator.namespaceDns);
      for (int i = 0; i < testNamesDns.length; i += 2) {
        expect(gen.generate(testNamesDns[i]).toString(), testNamesDns[i + 1]);
      }
    });

    test("Generates equal UUIDs for equal names", () {
      var gen = NameBasedUuidGenerator(NameBasedUuidGenerator.namespaceDns);
      var u1 = gen.generate("dart.org");
      var u2 = gen.generate("dart.org");

      expect(u1 == u2, isTrue);
      expect(u1.bytes, u2.bytes);
      expect(u1.toString(), u2.toString());
    });
  });
}
