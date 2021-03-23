import 'dart:math';

import 'package:test/test.dart';
import 'package:uuid_type/uuid_type.dart';

import 'test_data.dart';

class RandomMock implements Random {
  final List<int> buffer;
  int ptr = 0;

  RandomMock(this.buffer);

  @override
  int nextInt(int max) {
    ptr++;
    ptr ~/= buffer.length;
    return buffer[ptr];
  }

  @override
  double nextDouble() => 0.0;

  @override
  bool nextBool() => true;
}

void main() {
  group('Time-based generator (v1)', () {
    test('Generates UUID with correct variant and version', () {
      final uuid = TimeUuidGenerator().generate();

      expect(uuid.variant, Variant.rfc4122);
      expect(uuid.version, 1);
    });

    test('Generates unique UUID sequence', () {
      const N = 10000;
      final g = TimeUuidGenerator();

      final uuids = List<Uuid>.generate(N, (int index) => g.generate());

      var prev = uuids[0];
      for (var i = 1; i < N; i++) {
        expect(uuids[i], greaterThan(prev));

        prev = uuids[i];
      }
    });

    test('Can be created from state', () {
      final g1 = TimeUuidGenerator();
      final state = g1.generate();

      final g2 = TimeUuidGenerator.fromLastUuid(state);
      final uuid = g2.generate();

      expect(uuid, greaterThan(state));
      expect(g2.clockSequence, equals(g1.clockSequence));
      expect(g2.nodeId, equals(g1.nodeId));
    });

    test('Updates clock sequence on clock regression', () {
      var state = Uuid.parse('fffffff0-ffff-1fff-8000-000000000000');
      var g = TimeUuidGenerator.fromLastUuid(state);

      expect(g.clockSequence, 1);
    });

    test('Multiple generators produce unique UUIDs', () {
      var umap = <Uuid, bool>{};
      var gens = <TimeUuidGenerator>[
        TimeUuidGenerator(),
        TimeUuidGenerator(),
        TimeUuidGenerator(),
        TimeUuidGenerator(),
        TimeUuidGenerator()
      ];

      var gi = 0;
      for (var i = 0; i < gens.length * 1000; i++) {
        final u = gens[gi].generate();

        expect(umap.containsKey(u), isFalse, reason: '$u already generated');

        umap[u] = true;

        gi++;
        gi %= gens.length;
      }
    });
  });

  group('Random-based generator (v4)', () {
    test('Generates UUID with correct variant and version', () {
      var uuid = RandomUuidGenerator().generate();

      expect(uuid.variant, Variant.rfc4122);
      expect(uuid.version, 4);
    });

    test('Uses uint32 values correctly', () {
      final rnd =
          RandomMock(<int>[0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff]);

      // final expected = Uuid.fromBytes(l2b(const <int>[
      //   0xFF, 0xFF, 0xFF, 0xFF, //
      //   0xFF, 0xFF,
      //   0x4F, 0xFF,
      //   0xBF, 0xFF,
      //   0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
      // ]));

      final uuid = RandomUuidGenerator(rnd).generate();

      expect(uuid, Uuid.parse('ffffffff-ffff-4fff-bfff-ffffffffffff'));
    });
  });

  group('Name-based generator (v5)', () {
    test('Generates UUID with correct variant and version', () {
      final uuid = NameUuidGenerator(NameUuidGenerator.dnsNamespace)
          .generateFromString('');

      expect(uuid.variant, Variant.rfc4122);
      expect(uuid.version, 5);
    });

    test('Generates correct UUIDs', () {
      var gen = NameUuidGenerator(NameUuidGenerator.dnsNamespace);
      for (var i = 0; i < testNamesDns.length; i += 2) {
        expect(gen.generateFromString(testNamesDns[i]).toString(),
            testNamesDns[i + 1]);
      }
    });

    test('Generates equal UUIDs for equal names', () {
      var gen = NameUuidGenerator(NameUuidGenerator.dnsNamespace);
      var u1 = gen.generateFromString('dart.dev');
      var u2 = gen.generateFromString('dart.dev');

      expect(u1 == u2, isTrue);
      expect(u1.toBytes(), u2.toBytes());
      expect(u1.toString(), u2.toString());
    });
  });
}
