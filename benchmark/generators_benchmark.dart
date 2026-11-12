// Copyright (c) 2018-2026, Denis Portnov. All rights reserved.
// Released under MIT License that can be found in the LICENSE file.

// Micro-benchmark for UUID generators.
//
// Native (AOT):
//   dart compile exe benchmark/generators_benchmark.dart -o build/bench && build/bench
// JavaScript:
//   dart compile js -O2 benchmark/generators_benchmark.dart -o build/bench.js
//   node -e "globalThis.self = globalThis; require('./build/bench.js')"
//
// Seeded `Random` instances are used where possible so the numbers reflect the
// generator's own work rather than the cost of `Random.secure()`.

import 'dart:math' show Random;

import 'package:uuid_type/uuid_type.dart';

void _run(String name, Object Function() body, {int iterations = 1000000}) {
  // v1/v6 throw after 10,000 UUIDs in one millisecond, so keep their batches small.
  final warmup = iterations < 100000 ? iterations : 100000;
  for (var i = 0; i < warmup; i++) {
    body();
  }

  final sw = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    body();
  }
  sw.stop();

  final nsPerOp = sw.elapsedMicroseconds * 1000 / iterations;
  print('${name.padRight(32)} ${nsPerOp.toStringAsFixed(1).padLeft(8)} ns/op');
}

void main() {
  const fixedMs = 1700000000000;
  var advancingMs = fixedMs;

  final v1 = TimeUuidGenerator();
  final v4 = RandomUuidGenerator(Random(1));
  final v4Secure = RandomUuidGenerator();
  final v5 = NameUuidGenerator(NameUuidGenerator.urlNamespace);
  final v6 = UuidV6Generator();
  // Every call sees a new millisecond: exercises the random refill path.
  final v7Refill = UuidV7Generator(random: Random(1), millisecondsSinceEpoch: () => advancingMs++);
  // Every call sees the same millisecond: exercises the monotonic counter path.
  final v7Counter = UuidV7Generator(random: Random(1), millisecondsSinceEpoch: () => fixedMs);
  final v7Secure = UuidV7Generator();

  final lastV1 = v1.generate();
  final lastV6 = v6.generate();
  final lastV7 = v7Refill.generate();

  for (var round = 1; round <= 2; round++) {
    print('--- round $round ---');
    _run('v1 generate', v1.generate, iterations: 5000);
    _run('v1 fromLastUuid', () => TimeUuidGenerator.fromLastUuid(lastV1), iterations: 5000);
    _run('v4 generate (seeded Random)', v4.generate);
    _run('v4 generate (Random.secure)', v4Secure.generate, iterations: 200000);
    _run('v5 generateFromString', () => v5.generateFromString('https://example.com'), iterations: 200000);
    _run('v6 generate', v6.generate, iterations: 5000);
    _run('v6 fromLastUuid', () => UuidV6Generator.fromLastUuid(lastV6), iterations: 5000);
    _run('v7 generate (new ms, refill)', v7Refill.generate);
    _run('v7 generate (same ms, counter)', v7Counter.generate);
    _run('v7 generate (Random.secure)', v7Secure.generate, iterations: 200000);
    _run('v7 fromLastUuid', () => UuidV7Generator.fromLastUuid(lastV7), iterations: 200000);
  }
}
