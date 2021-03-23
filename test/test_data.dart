import 'dart:typed_data';

import 'package:uuid_type/uuid_type.dart';

Uint8List l2b(List<int> list) => Uint8List.fromList(list);

Uuid testNil = Uuid.fromBytes(nilBytes);

const dnsNsString = '6ba7b810-9dad-11d1-80b4-00c04fd430c8';
const urlNsString = '6ba7b811-9dad-11d1-80b4-00c04fd430c8';
const oidNsString = '6ba7b812-9dad-11d1-80b4-00c04fd430c8';
const x500NsString = '6ba7b814-9dad-11d1-80b4-00c04fd430c8';

var x = <int>[1, 2, 3] as Uint8List;

final nilBytes = l2b(<int>[
  0x00, 0x00, 0x00, 0x00, //
  0x00, 0x00,
  0x00, 0x00,
  0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00
]);

final dnsNsBytes = l2b(<int>[
  0x6B, 0xA7, 0xB8, 0x10, //
  0x9D, 0xAD,
  0x11, 0xD1,
  0x80, 0xB4,
  0x00, 0xC0, 0x4F, 0xD4, 0x30, 0xC8
]);

final urlNsBytes = l2b(<int>[
  0x6B, 0xA7, 0xB8, 0x11, //
  0x9D, 0xAD,
  0x11, 0xD1,
  0x80, 0xB4,
  0x00, 0xC0, 0x4F, 0xD4, 0x30, 0xC8
]);

const maxByteList = <int>[
  0xFF, 0xFF, 0xFF, 0xFF, //
  0xFF, 0xFF,
  0xFF, 0xFF,
  0xFF, 0xFF,
  0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
];

const validStrings = <String>[
  // canonical, lower case
  '6ba7b811-9dad-11d1-80b4-00c04fd430c8',
  // canonical, upper case
  '6BA7B811-9DAD-11D1-80B4-00C04fD430C8',
  // hex
  '6ba7b8119dad11d180b400c04fd430c8',
  // hex uppercase
  '6BA7B8119DAD11D180B400C04FD430C8',
  // hex mixed case
  '6Ba7b8119Dad11d180B400c04fD430c8',
  // GUID
  '{6ba7b811-9dad-11d1-80b4-00c04fd430c8}',
  '{6ba7b8119dad11d180b400c04fd430c8}',
  // URN
  'urn:uuid:6ba7b811-9dad-11d1-80b4-00c04fd430c8',
];

const invalidStrings = <String>[
  // too short
  '6ba7b811-9dad-11d1-80b4-00c04fd430',
  // too long
  '6ba7b811-9dad-11d1-80b4-00c04fd430000',
  // extra dashes
  '6ba7b811-9dad-11d1-80b4-00c0-4fd43000',
  // dashes in wrong position
  '6ba7b811-9dad-11d180-b4-00c04fd430c8',
  // invalid URN
  'urn uuid 6ba7b811-9dad-11d1-80b4-00c04fd430c8',
  'urn:uuid:6ba7b8119dad11d180b400c04fd430c8',
  // invalid GUID
  '[6ba7b811-9dad-11d1-80b4-00c04fd430c8]',
  // too short hex
  '6ba7b8119dad11d180b400c04fd430',
  // too long hex
  '6ba7b8119dad11d180b400c04fd430c800',
  // invalid hex chars
  'xxxxb811-9dad-11d1-80b4-00c04fd430',
  'xxxxb8119dad11d180b400c04fd430',
];

const nilStrings = <String>[
  '00000000-0000-0000-0000-000000000000',
  '00000000000000000000000000000000',
  '{00000000-0000-0000-0000-000000000000}',
  '{00000000000000000000000000000000}',
  'urn:uuid:00000000-0000-0000-0000-000000000000',
];

const testVariants = <Variant>[
  Variant.ncs, // 0 0 0
  Variant.ncs, // 0 0 1
  Variant.ncs, // 0 1 0
  Variant.ncs, // 0 1 1
  Variant.rfc4122, // 1 0 0
  Variant.rfc4122, // 1 0 1
  Variant.microsoft, // 1 1 0
  Variant.future, // 1 1 1
];

const testNamesDns = <String>[
  'hello.example.com', 'fdda765f-fc57-5604-a269-52a7df8164ec', //
  'www.example.com', '2ed6657d-e927-568b-95e1-2665a8aea6a2',
  'python.org', '886313e1-3b8a-5372-9b90-0c9aee199e5d',
  'Bücher.example', '3b2e4e71-46e9-5d45-bb2b-0384d899603a',
  'дарт.рф', 'ee15950c-7674-5695-a2dc-11d0ed0a7fdd'
];
