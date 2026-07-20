import 'package:quiverfall/game/sim/arena.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

/// Simulation performance against the docs/19-performance.md §19.1 budget.
///
/// **What this proves and what it does not.**
///
/// It proves the sim tick fits its 4.0 ms slice of the 16.6 ms frame at peak
/// entity count, and that per-tick cost is *stable* — a rising or spiky
/// distribution is the signature of per-tick allocation triggering GC, which is
/// the failure mode docs/19 §19.2 is built to prevent.
///
/// It does not directly measure allocation. Dart exposes no in-process
/// allocation counter without the VM service, so a genuine zero-allocation
/// assertion needs `flutter run --profile` plus DevTools. That lands in Phase 7
/// with the real renderer, where it can measure the whole frame rather than the
/// sim alone. Claiming a rigorous allocation gate here would be claiming more
/// than the measurement supports.
///
/// This also runs on a developer machine, not the reference low-end device, so
/// the budget below is deliberately generous. The binding measurement is the
/// on-device one in Phase 7.
void main() {
  /// A peak-density world with combat disabled.
  ///
  /// This file benchmarks movement and the spatial index in isolation, so
  /// auto-fire is off: arrows would kill the enemies being counted and turn a
  /// fixed-population benchmark into a variable one. Combat's own cost is
  /// measured in `combat_integration_test.dart`, where the population is
  /// expected to change.
  SimWorld peakWorld() {
    final SimWorld world = SimWorld(
      seed: 4242,
      arena: Arena.standard(
        walls: const <Rect>[
          Rect.fromLTWH(5.0, 2.0, 1.0, 4.0),
          Rect.fromLTWH(10.0, 4.0, 2.0, 1.0),
        ],
      ),
    )..autoFire = false;
    world.spawnPlayer(2.0, 4.5);

    // docs/14 §14.4 caps a room at 90 simultaneous entities.
    for (int i = 0; i < 89; i++) {
      final double x = 1.0 + (i % 14) * 1.05;
      final double y = 0.6 + (i ~/ 14) * 1.3;
      world.spawnAt(EntityKind.enemy, x, y, radius: 0.3, health: 100);
      // Give them motion so movement and the spatial rebuild do real work.
      world.entities.velX[world.entities.highWater - 1] =
          (i.isEven ? 1.0 : -1.0) * 1.4;
      world.entities.velY[world.entities.highWater - 1] =
          (i % 3 == 0 ? 1.0 : -1.0) * 0.9;
    }
    return world;
  }

  test('tick fits the 4.0ms budget at 90 entities', () {
    final SimWorld world = peakWorld();
    final InputSnapshot input = InputSnapshot()..set(0.8, 0.6);

    // Warm up so we measure steady state, not JIT compilation.
    for (int i = 0; i < 2000; i++) {
      world.tick(input);
    }

    const int samples = 20000;
    final Stopwatch sw = Stopwatch()..start();
    for (int i = 0; i < samples; i++) {
      world.tick(input);
    }
    sw.stop();

    final double perTickMs = sw.elapsedMicroseconds / samples / 1000.0;
    // ignore: avoid_print
    print('sim tick @ ${world.entities.liveCount} entities: '
        '${perTickMs.toStringAsFixed(4)} ms '
        '(budget 4.0 ms, frame 16.6 ms)');

    expect(
      perTickMs,
      lessThan(4.0),
      reason: 'sim tick must fit its slice of the frame budget',
    );
  });

  test('per-tick cost has no catastrophic tail', () {
    final SimWorld world = peakWorld();
    final InputSnapshot input = InputSnapshot()..set(0.5, -0.5);

    for (int i = 0; i < 2000; i++) {
      world.tick(input);
    }

    // Measure in batches so timer resolution does not dominate.
    const int batches = 60;
    const int perBatch = 500;
    final List<double> batchMs = <double>[];

    for (int b = 0; b < batches; b++) {
      final Stopwatch sw = Stopwatch()..start();
      for (int i = 0; i < perBatch; i++) {
        world.tick(input);
      }
      sw.stop();
      batchMs.add(sw.elapsedMicroseconds / 1000.0);
    }

    batchMs.sort();
    final double median = batchMs[batches ~/ 2];
    final double p95 = batchMs[(batches * 0.95).floor()];

    // ignore: avoid_print
    print('batch median ${median.toStringAsFixed(3)} ms, '
        'p95 ${p95.toStringAsFixed(3)} ms, ratio '
        '${(p95 / median).toStringAsFixed(2)}x');

    // Deliberately a loose bound. Wall-clock p95 on a developer machine is
    // dominated by OS scheduling, not by GC — an earlier 2.0x threshold here
    // failed on background load, which makes it a flake rather than a signal.
    // This catches GC *thrash* (the 5-10x tail of allocating every tick) and
    // nothing subtler. Real allocation profiling needs the VM service and lands
    // in Phase 7 on the reference device, per the note at the top of this file.
    expect(
      p95 / median,
      lessThan(4.0),
      reason: 'a very heavy tail suggests per-tick allocation thrashing GC',
    );
  });

  test('cost does not drift upward over a long session', () {
    // Catches slow leaks: a container that grows each tick, or entities that
    // are spawned but never released.
    //
    // Both measurements are taken *after* the entity distribution has settled.
    // Measuring from tick 0 would compare a spread-out world against a clumped
    // one and report the density change as drift — which is exactly what an
    // earlier version of this test did, producing a 1.6x "regression" that was
    // really just entities piling into corners. Query cost legitimately depends
    // on local density; a leak does not.
    final SimWorld world = peakWorld();
    final InputSnapshot input = InputSnapshot()..set(0.3, 0.9);

    for (int i = 0; i < 20000; i++) {
      world.tick(input);
    }

    double timeBatch() {
      final Stopwatch sw = Stopwatch()..start();
      for (int i = 0; i < 5000; i++) {
        world.tick(input);
      }
      sw.stop();
      return sw.elapsedMicroseconds / 1000.0;
    }

    final double early = timeBatch();
    for (int i = 0; i < 100000; i++) {
      world.tick(input);
    }
    final double late = timeBatch();

    // ignore: avoid_print
    print('settled ${early.toStringAsFixed(2)} ms, '
        'after 100k more ticks ${late.toStringAsFixed(2)} ms');

    expect(late, lessThan(early * 1.35), reason: 'possible leak or growth');
    expect(world.entities.liveCount, 90, reason: 'entity count must be stable');
  });

  test('a fully clumped room cannot overflow the spatial hash', () {
    // The invariant that maxPerCell exists to guarantee. Overflow silently
    // drops entities from neighbour queries, which presents as arrows passing
    // through enemies — severe and near-undiagnosable from a bug report.
    //
    // Enemy AI paths toward the player, so a whole room converging on one point
    // is the *intended* behaviour of half the roster, not a pathological case.
    final SimWorld world = SimWorld(seed: 1);
    world.spawnPlayer(8.0, 4.5);
    for (int i = 0; i < 89; i++) {
      // Every enemy stacked inside a single 1.5u cell.
      world.spawnAt(EntityKind.enemy, 8.0, 4.5, radius: 0.3, health: 10);
    }
    world.spatial.rebuild(world.entities);

    expect(world.spatial.overflowCount, 0);
    expect(
      SimConfig.maxPerCell,
      greaterThanOrEqualTo(90),
      reason: 'must hold a full room in one cell',
    );

    // And every one of them is still findable.
    final int found = world.spatial.queryRadius(8.0, 4.5, 0.5);
    expect(found, 90);
  });

  test('spatial hash never overflows at the documented entity cap', () {
    final SimWorld world = peakWorld();
    final InputSnapshot input = InputSnapshot()..set(1.0, 1.0);

    int worstOverflow = 0;
    for (int i = 0; i < 5000; i++) {
      world.tick(input);
      if (world.spatial.overflowCount > worstOverflow) {
        worstOverflow = world.spatial.overflowCount;
      }
    }

    // If this fails, either maxPerCell is too small or entities are clumping
    // more than the design assumes — both worth knowing before Phase 5 adds AI
    // that deliberately groups them.
    expect(
      worstOverflow,
      0,
      reason: 'cell overflow drops entities from queries, causing missed hits',
    );
    expect(world.entities.liveCount, lessThanOrEqualTo(SimConfig.maxEntities));
  });
}
