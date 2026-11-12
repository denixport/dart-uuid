import 'dart:math';

import 'package:test/test.dart';
import 'package:uuid_type/uuid_type.dart';

import 'test_data.dart';

class RandomMock implements Random {
  final List<int> buffer;
  int ptr = 0;
  int? max;

  RandomMock(this.buffer);

  @override
  int nextInt(int max) {
    this.max = max;
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
      final state = Uuid.parse('fffffff0-ffff-1fff-8000-000000000000');
      final g = TimeUuidGenerator.fromLastUuid(state);

      expect(g.clockSequence, 1);
    });

    test('Multiple generators produce unique UUIDs', () {
      final umap = <Uuid, bool>{};
      final gens = <TimeUuidGenerator>[
        TimeUuidGenerator(),
        TimeUuidGenerator(),
        TimeUuidGenerator(),
        TimeUuidGenerator(),
        TimeUuidGenerator(),
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

    test('Node ID is not modifiable', () {
      expect(() => TimeUuidGenerator().nodeId[0] = 0, throwsA(TypeMatcher<UnsupportedError>()));
    });
  });

  group('Random-based generator (v4)', () {
    test('Generates UUID with correct variant and version', () {
      final uuid = RandomUuidGenerator().generate();

      expect(uuid.variant, Variant.rfc4122);
      expect(uuid.version, 4);
    });

    test('Uses uint32 values correctly', () {
      final rnd = RandomMock(<int>[0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff]);

      // final expected = Uuid.fromBytes(l2b(const <int>[
      //   0xFF, 0xFF, 0xFF, 0xFF, //
      //   0xFF, 0xFF,
      //   0x4F, 0xFF,
      //   0xBF, 0xFF,
      //   0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
      // ]));

      final uuid = RandomUuidGenerator(rnd).generate();

      expect(rnd.max, 1 << 32);
      expect(uuid, Uuid.parse('ffffffff-ffff-4fff-bfff-ffffffffffff'));
    });
  });

  group('Name-based generator (v5)', () {
    test('Generates UUID with correct variant and version', () {
      final uuid = NameUuidGenerator(NameUuidGenerator.dnsNamespace).generateFromString('');

      expect(uuid.variant, Variant.rfc4122);
      expect(uuid.version, 5);
    });

    test('Generates correct UUIDs', () {
      final gen = NameUuidGenerator(NameUuidGenerator.dnsNamespace);
      for (var i = 0; i < testNamesDns.length; i += 2) {
        expect(gen.generateFromString(testNamesDns[i]).toString(), testNamesDns[i + 1]);
      }
    });

    test('Generates equal UUIDs for equal names', () {
      final gen = NameUuidGenerator(NameUuidGenerator.dnsNamespace);
      final u1 = gen.generateFromString('dart.dev');
      final u2 = gen.generateFromString('dart.dev');

      expect(u1 == u2, isTrue);
      expect(u1.toBytes(), u2.toBytes());
      expect(u1.toString(), u2.toString());
    });
  });

  group('Time-ordered generator (v6)', () {
    test('Generates sortable UUIDs with the correct variant and version', () {
      final generator = UuidV6Generator();
      final first = generator.generate();
      final second = generator.generate();
      expect(first.variant, Variant.rfc4122);
      expect(first.version, 6);
      expect(second, greaterThan(first));
    });

    test('Can be restored from its last UUID', () {
      final state = UuidV6Generator().generate();
      final next = UuidV6Generator.fromLastUuid(state).generate();
      expect(next, greaterThan(state));
    });
  });

  group('Time-ordered generator (v7)', () {
    test('Generates monotonic UUIDs within the same millisecond', () {
      final generator = UuidV7Generator(
        random: RandomMock(<int>[0, 0, 0]),
        millisecondsSinceEpoch: () => 1645557742000,
      );
      final first = generator.generate();
      final second = generator.generate();
      expect(first.toString().substring(0, 13), '017f22e2-79b0');
      expect(first.variant, Variant.rfc4122);
      expect(first.version, 7);
      expect(second, greaterThan(first));
    });

    test('Can be restored from its last UUID', () {
      const milliseconds = 1645557742000;
      final state = UuidV7Generator(
        random: RandomMock(<int>[0, 0, 0]),
        millisecondsSinceEpoch: () => milliseconds,
      ).generate();
      final next = UuidV7Generator.fromLastUuid(
        state,
        random: RandomMock(<int>[0, 0, 0]),
        millisecondsSinceEpoch: () => milliseconds,
      ).generate();
      expect(next, greaterThan(state));
    });
  });
}
