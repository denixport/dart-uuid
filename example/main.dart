import 'dart:typed_data';
import 'package:uuid_type/uuid_type.dart';

void main() {
  //
  // UUID type
  //

  // create UUID from canonical string
  Uuid u1 = Uuid("6ba7b811-9dad-11d1-80b4-00c04fd430c8");

  // print version & variant
  print("$u1 (ver: ${u1.version} var: ${u1.variant})");
  // -> ver: = 1 var: Variant.rfc4122

  // create UUID from byte array
  Uuid u2 = Uuid.fromBytes(Uint8List.fromList(<int>[
    0x6b, 0xa7, 0xb8, 0x11, //
    0x9d, 0xad,
    0x11, 0xd1,
    0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8
  ]));

  // UUIDs are equal
  print(u2 == u1); // -> true

  // print as string
  print(u2); // -> 6ba7b811-9dad-11d1-80b4-00c04fd430c8

  // parse URN
  Uuid u3 = Uuid.parse("urn:uuid:6ba7b811-9dad-11d1-80b4-00c04fd430c8");

  // UUIDs are equal
  print(u3 == u1); // -> true

  // parse GUID
  Uuid u4 = Uuid.parse("{6BA7B811-9DAD-11D1-80B4-00C04FD430C8}");

  // UUIDs are equal
  print(u4 == u1); // -> true

  // create old NCS UUID (example from AIX docs )
  Uuid u5 = Uuid.fromBytes(Uint8List.fromList(<int>[
    0x34, 0xdc, 0x23, 0xaf, //
    0xf0, 0x00,
    0x00, 0x00,
    0x0d,
    0x00, 0x00, 0x7c, 0x5f, 0x00, 0x00, 0x00
  ]));
  print("$u5 (ver: ${u5.version} var: ${u5.variant})");
  // -> 34dc23af-f000-0000-0d00-007c5f000000 (ver: 0 var: Variant.ncs)

  //
  // Generators
  //

  Uuid u;

  // generate time-based UUID (with random node ID and clock sequence)
  var timeGen = TimeBasedUuidGenerator();
  u = timeGen.generate();
  print("$u (ver: ${u.version} var: ${u.variant})");
  // -> 3ca0b269-5169-11e9-8a43-2351df82a100 (ver: 1 var: Variant.rfc4122)

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
  // -> c9321b3a-93b1-48bf-a842-b4eb3b2bc0e6 (ver: 4 var: Variant.rfc4122)
}
