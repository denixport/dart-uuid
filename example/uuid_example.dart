import 'dart:typed_data';
import 'package:uuid_type/uuid_type.dart';

void main() {
  // create UUID from canonical string
  Uuid u1 = Uuid("6ba7b811-9dad-11d1-80b4-00c04fd430c8");

  // print version & variant
  print("ver = ${u1.version}"); // -> ver = 1

  // print variant
  print("variant = ${u1.variant}"); // -> variant = Variant.rfc4122

  // create UUID from byte array
  var namespaceUrlBytes = new Uint8List.fromList(<int>[
    0x6b, 0xa7, 0xb8, 0x11, //
    0x9d, 0xad,
    0x11, 0xd1,
    0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8
  ]);

  Uuid u2 = Uuid.fromBytes(namespaceUrlBytes);

  // UUIDs are equal
  print(u2 == u1);  // -> true
  
  // print as string
  print(u2); // -> 6ba7b811-9dad-11d1-80b4-00c04fd430c8

  // parse URN
  Uuid u3 = Uuid.parse("urn:uuid:6ba7b811-9dad-11d1-80b4-00c04fd430c8");

  // UUIDs are equal
  print(u3 == u1);  // -> true

  // creates old NCS UUID (example from AIX docs )
  var ncsBytes = new Uint8List.fromList(<int>[
    0x34, 0xdc, 0x23, 0xaf, //
    0xf0, 0x00,
    0x00, 0x00,
    0x0d,
    0x00, 0x00, 0x7c, 0x5f, 0x00, 0x00, 0x00
  ]);
  Uuid u4 = Uuid.fromBytes(ncsBytes);
  print("$u4 (ver: ${u4.version} var: ${u4.variant})");
}