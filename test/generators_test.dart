import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:uuid_type/uuid_type.dart';

// RNG buffer of four 32bit unsigned ints
const Uint32x4 = const <int>[0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF];

const randSample = const <int>[
  0xFF, 0xFF, 0xFF, 0xFF,
  0xFF, 0xFF,
  0x4F, 0xFF,
  0xBF, 0xFF,
  0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
];

class RandomMock implements Random {
  List<int> buffer = [0, 0, 0, 0];
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

var namesDns = <String>[
  "hello.example.com", "fdda765f-fc57-5604-a269-52a7df8164ec", //
  "www.example.com", "2ed6657d-e927-568b-95e1-2665a8aea6a2",
  "python.org", "886313e1-3b8a-5372-9b90-0c9aee199e5d",
  "дарт.рф", "ee15950c-7674-5695-a2dc-11d0ed0a7fdd"
];

void main() {
  group('Time-based generator (v1)', () {

  });

  group('Random-based generator (v4)', () {
    test('Generates UUID with correct variant and version', () {
      var gen = new RandomBasedUuidGenerator();
      var uuid = gen.generate();

      expect(uuid.variant, equals(Variant.rfc4122));
      expect(uuid.version, equals(4));
    });

    test('Uses uint32 values correctly', () {
      var expected = new Uuid.fromBytes(new Uint8List.fromList(randSample));

      var rnd = new RandomMock(Uint32x4);
      var uuid = new RandomBasedUuidGenerator(rnd).generate();

      expect(uuid, equals(expected));
    });
  });

  group('Name-based generator (v5)', () {
    test('Generates correct UUIDs', () {
      var gen = new NameBasedUuidGenerator(NameBasedUuidGenerator.namespaceDns);
      for (int i = 0; i < namesDns.length; i += 2) {
        expect(gen.generate(namesDns[i]).toString(), equals(namesDns[i+1]));
      }
    });

    test('Generates equal UUIDs for equal names', () {
      var gen = new NameBasedUuidGenerator(NameBasedUuidGenerator.namespaceDns);
      var u1 = gen.generate("dart.org");
      var u2 = gen.generate("dart.org");

      expect(u1 == u2, equals(true));
      expect(u1.bytes, equals(u2.bytes));
      expect(u1.toString(), equals(u2.toString()));
    });
  });

}
