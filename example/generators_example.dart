import 'package:uuid_type/uuid_type.dart';

void main() {
  // generate time-based UUID (with random node ID and clock sequence)
  var timeGen = TimeBasedUuidGenerator();
  var u = timeGen.generate();
  print("$u (ver: ${u.version} var: ${u.variant})");

  // generate name + namespace based UUID
  var nsUrl = Uuid("6ba7b811-9dad-11d1-80b4-00c04fd430c8");
  var nameGen = NameBasedUuidGenerator(nsUrl);
  u = nameGen.generate("https://www.dartlang.org/");
  print("$u (ver: ${u.version} var: ${u.variant})");
  // -> be147d8c-1052-5e2d-97d4-178c644b6ea9 (ver: 5 var: Variant.rfc4122)

  // generate random-based UUID
  var randGen = RandomBasedUuidGenerator();
  u = randGen.generate();
  print("$u (ver: ${u.version} var: ${u.variant})");
}