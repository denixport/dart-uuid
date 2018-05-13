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

void main() {
  group('Random-based generator (v4)', () {
    test('Generates v4 UUID with correct variant and version', () {
      var gen = new RandomUuidGenerator();
      var uuid = gen.generate();

      expect(uuid.variant, Variant.rfc4122);
      expect(uuid.version, 4);
    });

    test('Uses uint32 values correctly', () {
      var expected = new Uuid.fromBytes(new Uint8List.fromList(randSample));

      var rnd = new RandomMock(Uint32x4);
      var uuid = new RandomUuidGenerator(rnd).generate();

      expect(uuid == expected, true);
    });
  });
}
