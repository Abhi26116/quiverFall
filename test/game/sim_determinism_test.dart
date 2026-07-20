import 'package:quiverfall/game/sim/arena.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

/// The Phase 2 exit criterion.
///
/// docs/12-architecture.md §12.0 promises that the same seed plus the same
/// inputs produce the same run, byte for byte. Replays, build sharing, the
/// balance harness, and any future server-side validation all rest on it, and
/// it is the kind of property that silently stops being true unless a test
/// argues with every change.
void main() {
  /// A deterministic, non-trivial input sequence. Deliberately not random-
  /// looking noise: it walks the stick through the dead zone, past full
  /// deflection, and into the arena walls, so the test exercises normalisation
  /// and collision clamping rather than just straight-line motion.
  void driveTick(InputSnapshot input, int tick) {
    final double t = tick * 0.05;
    input.set(
      _wave(t) * 1.4,
      _wave(t * 0.7 + 1.3) * 1.4,
      ultimate: tick % 97 == 0,
    );
  }

  SimWorld buildWorld(int seed) {
    final SimWorld world = SimWorld(
      seed: seed,
      arena: Arena.standard(
        walls: const <Rect>[
          Rect.fromLTWH(6.0, 3.0, 1.2, 3.0),
          Rect.fromLTWH(11.0, 1.0, 1.0, 2.0),
        ],
      ),
    );
    world.spawnPlayer(3.0, 4.5);
    for (int i = 0; i < 12; i++) {
      world.spawnAt(
        EntityKind.enemy,
        2.0 + i * 1.05,
        1.5 + (i % 4) * 1.6,
        radius: 0.3,
        health: 40,
      );
    }
    return world;
  }

  /// Runs [ticks] steps and returns a fingerprint of the final world state.
  String simulate(int seed, int ticks) {
    final SimWorld world = buildWorld(seed);
    final InputSnapshot input = InputSnapshot();

    for (int t = 0; t < ticks; t++) {
      driveTick(input, t);
      world.tick(input);
    }
    return _fingerprint(world);
  }

  group('determinism', () {
    test('600 ticks from the same seed produce identical state', () {
      final String a = simulate(20260719, 600);
      final String b = simulate(20260719, 600);

      expect(a, b);
    });

    test('repeated runs stay identical across many trials', () {
      final String reference = simulate(7, 600);
      for (int trial = 0; trial < 8; trial++) {
        expect(simulate(7, 600), reference, reason: 'diverged on trial $trial');
      }
    });

    test('different seeds are allowed to differ', () {
      // Movement here is input-driven, so seeds need not diverge yet — but the
      // seed must at least be plumbed through and reachable.
      expect(SimWorld(seed: 1).rng.nextInt64(),
          isNot(SimWorld(seed: 2).rng.nextInt64()));
    });

    test('simulating in two halves equals simulating in one pass', () {
      // Proves no hidden per-call state outside the world: pausing at a room
      // boundary and resuming must not perturb the run.
      final SimWorld single = buildWorld(99);
      final InputSnapshot input = InputSnapshot();
      for (int t = 0; t < 600; t++) {
        driveTick(input, t);
        single.tick(input);
      }

      final SimWorld split = buildWorld(99);
      final InputSnapshot input2 = InputSnapshot();
      for (int t = 0; t < 250; t++) {
        driveTick(input2, t);
        split.tick(input2);
      }
      for (int t = 250; t < 600; t++) {
        driveTick(input2, t);
        split.tick(input2);
      }

      expect(_fingerprint(split), _fingerprint(single));
    });

    test('tick count and elapsed time advance exactly', () {
      final SimWorld world = buildWorld(1);
      final InputSnapshot input = InputSnapshot();
      for (int t = 0; t < 600; t++) {
        world.tick(input);
      }

      expect(world.tickCount, 600);
      expect(
        world.elapsedSeconds,
        closeTo(600 * SimConfig.fixedStep, 1e-9),
      );
    });
  });

  group('input handling', () {
    test('diagonal movement is not faster than cardinal', () {
      // The classic bug that makes every optimal path diagonal.
      final SimWorld cardinal = buildWorld(1);
      final SimWorld diagonal = buildWorld(1);

      final InputSnapshot east = InputSnapshot()..set(1, 0);
      final InputSnapshot northEast = InputSnapshot()..set(1, 1);

      for (int i = 0; i < 30; i++) {
        cardinal.tick(east);
        diagonal.tick(northEast);
      }

      final int c = cardinal.player.index;
      final int d = diagonal.player.index;

      final double cardinalDist =
          (cardinal.entities.posX[c] - 3.0).abs();
      final double dx = diagonal.entities.posX[d] - 3.0;
      final double dy = diagonal.entities.posY[d] - 4.5;
      final double diagonalDist = _hypot(dx, dy);

      expect(diagonalDist, closeTo(cardinalDist, 0.01));
    });

    test('input inside the dead zone does not move the player', () {
      final SimWorld world = buildWorld(1);
      final int i = world.player.index;
      final double startX = world.entities.posX[i];

      final InputSnapshot tiny = InputSnapshot()..set(0.05, 0.05);
      for (int t = 0; t < 60; t++) {
        world.tick(tiny);
      }

      expect(world.entities.posX[i], startX);
    });

    test('the player is confined to the arena', () {
      final SimWorld world = buildWorld(1);
      final InputSnapshot hardRight = InputSnapshot()..set(1, 1);

      for (int t = 0; t < 600; t++) {
        world.tick(hardRight);
      }

      final int i = world.player.index;
      expect(world.entities.posX[i],
          lessThanOrEqualTo(SimConfig.arenaWidth));
      expect(world.entities.posY[i],
          lessThanOrEqualTo(SimConfig.arenaHeight));
      expect(world.entities.posX[i], greaterThanOrEqualTo(0));
      expect(world.entities.posY[i], greaterThanOrEqualTo(0));
    });

    test('walls block movement', () {
      final SimWorld world = SimWorld(
        seed: 1,
        arena: Arena.standard(
          walls: const <Rect>[Rect.fromLTWH(4.0, 0.0, 1.0, 9.0)],
        ),
      );
      world.spawnPlayer(2.0, 4.5);

      final InputSnapshot east = InputSnapshot()..set(1, 0);
      for (int t = 0; t < 300; t++) {
        world.tick(east);
      }

      // Stopped at the wall face, not through it.
      expect(world.entities.posX[world.player.index], lessThan(4.0));
    });
  });

  group('input tape quantisation', () {
    test('round-trips within one quantisation step', () {
      final InputSnapshot original = InputSnapshot()..set(0.62, -0.31);
      final int byte = original.toTapeByte();

      final InputSnapshot restored = InputSnapshot()..fromTapeByte(byte);

      // 4 bits per axis over [-1, 1] gives a step of 2/15.
      expect(restored.stickX, closeTo(0.62, 2 / 15));
      expect(restored.stickY, closeTo(-0.31, 2 / 15));
    });

    test('a quantised tape replays identically', () {
      // The property that matters: recording quantises, so playback receives
      // exactly what was recorded and a replay cannot desync from rounding.
      final List<int> tape = <int>[];
      final SimWorld recorded = buildWorld(5);
      final InputSnapshot live = InputSnapshot();

      for (int t = 0; t < 600; t++) {
        driveTick(live, t);
        final int byte = live.toTapeByte();
        tape.add(byte);
        live.fromTapeByte(byte);
        recorded.tick(live);
      }

      final SimWorld replayed = buildWorld(5);
      final InputSnapshot fromTape = InputSnapshot();
      for (int t = 0; t < 600; t++) {
        fromTape.fromTapeByte(tape[t]);
        replayed.tick(fromTape);
      }

      expect(_fingerprint(replayed), _fingerprint(recorded));
    });
  });
}

/// Compact but sensitive summary of world state.
///
/// Positions are rendered at full precision: the point is to catch a divergence
/// of one ULP, since that is how non-determinism actually appears.
String _fingerprint(SimWorld world) {
  final StringBuffer buffer = StringBuffer()
    ..write('t=${world.tickCount};')
    ..write('n=${world.entities.liveCount};');

  final int high = world.entities.highWater;
  for (int i = 0; i < high; i++) {
    if (world.entities.alive[i] == 0) continue;
    buffer
      ..write(i)
      ..write(':')
      ..write(world.entities.posX[i].toStringAsExponential(17))
      ..write(',')
      ..write(world.entities.posY[i].toStringAsExponential(17))
      ..write(',')
      ..write(world.entities.facing[i].toStringAsExponential(17))
      ..write(';');
  }
  return buffer.toString();
}

/// Deterministic pseudo-wave, so the test does not depend on dart:math's
/// platform-specific trig for its *input* signal.
double _wave(double t) {
  final double x = t % 4.0;
  if (x < 1.0) return x;
  if (x < 2.0) return 2.0 - x;
  if (x < 3.0) return -(x - 2.0);
  return -(4.0 - x);
}

double _hypot(double a, double b) {
  final double s = a * a + b * b;
  double guess = s;
  // Newton iterations — avoids importing dart:math for one call and keeps the
  // test's own arithmetic as deterministic as the code under test.
  for (int i = 0; i < 24; i++) {
    if (guess == 0) return 0;
    guess = 0.5 * (guess + s / guess);
  }
  return guess;
}
