import 'dart:typed_data';

import 'package:uuid_type/uuid_type.dart';

void main() {
  //
  // UUID type
  //

  // create UUID from string
  var u1 = Uuid.parse('6ba7b811-9dad-11d1-80b4-00c04fd430c8');

  // print version & variant
  print('$u1 (version: ${u1.version} variant: ${u1.variant})');
  // -> version: = 1 variant: Variant.rfc4122

  // create UUID from byte array
  var u2 = Uuid.fromBytes(Uint8List.fromList(<int>[
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
  var u3 = Uuid.parse('urn:uuid:6ba7b811-9dad-11d1-80b4-00c04fd430c8');

  // UUIDs are equal
  print(u3 == u1); // -> true

  // parse GUID
  var u4 = Uuid.parse('{6BA7B811-9DAD-11D1-80B4-00C04FD430C8}');

  // UUIDs are equal
  print(u4 == u1); // -> true

  // create old NCS UUID (example from AIX docs )
  var u5 = Uuid.fromBytes(Uint8List.fromList(const <int>[
    0x34, 0xdc, 0x23, 0xaf, //
    0xf0, 0x00,
    0x00, 0x00,
    0x0d,
    0x00, 0x00, 0x7c, 0x5f, 0x00, 0x00, 0x00
  ]));
  print('$u5 (version: ${u5.version} variant: ${u5.variant})');
  // -> 34dc23af-f000-0000-0d00-007c5f000000 (version: 0 variant: Variant.ncs)

  // compare time-based UUIDs
  u1 = Uuid.parse('846f6b72-8c28-11eb-8b99-9b0e27e8a471');
  u2 = Uuid.parse('846f7338-8c28-11eb-8ba2-9769eccf7efc');
  print(u2 >= u1);
  // -> true

  //
  // Generators
  //

  Uuid u;

  // generate time-based UUID (with random node ID)
  u = TimeUuidGenerator().generate();
  print('$u (version: ${u.version} variant: ${u.variant})');
  // -> ... (version: 1 variant: Variant.rfc4122)

  // generate name + namespace based UUID
  u = NameUuidGenerator(NameUuidGenerator.urlNamespace)
      .generateFromString('https://dart.dev/');
  print('$u (version: ${u.version} variant: ${u.variant})');
  // -> 51aa5a34-f12a-5843-89aa-2e687a910904 (version: 5 variant: Variant.rfc4122)

  // generate random-based UUID
  u = RandomUuidGenerator().generate();
  print('$u (version: ${u.version} variant: ${u.variant})');
  // -> ... (version: 4 variant: Variant.rfc4122)

  //
  // Utility
  //

  // generate time-based UUID string
  print(uuid.v1());

  // generate random-based UUID string
  print(uuid.v4());

  // generate name-based (SHA1) UUID string
  print(uuid.v5('6ba7b811-9dad-11d1-80b4-00c04fd430c8', 'https://dart.dev/'));
  // -> 51aa5a34-f12a-5843-89aa-2e687a910904

  // compare UUIDs
  print(uuid.compare('6ba7b811-9dad-11d1-80b4-00c04fd430c8',
      '6ba7b811-9dad-11d1-80b4-00c04fd430c8'));
  // -> 0
}
