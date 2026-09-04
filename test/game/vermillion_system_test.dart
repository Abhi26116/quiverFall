import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/hazard_store.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/telegraph.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'boss_test_support.dart';

/// Vermillion, the Long Burn — P1/P2 (docs/06 §5): a single body that
/// walks toward the player, laying a lethal ground puddle behind it on a
/// fixed cadence — the arena floor "progressively becoming lethal" is
/// simply many of `EnemyAttack.dropPuddle`'s own hazards accumulating. P2
/// adds a continuous ignite aura and a periodic charge (ADR 0037).
void main() {
  final ContentLibrary content = loadContentWithBosses();
  const double health = 1.0e7;
  const double centerX = 8.0;
  const double centerY = 4.5;

  ({SimWorld world, int primary}) spawnVermillion({
    double playerX = centerX + 3.0,
    double playerY = centerY,
  }) {
    final SimWorld world = SimWorld(seed: 808, content: content)
      ..autoFire = false;
    world.spawnPlayer(playerX, playerY);
    final int primary =
        world.spawnVermillion(centerX, centerY, health: health);
    return (world: world, primary: primary);
  }

  List<int> trailOf(SimWorld world, int primary) {
    final List<int> out = <int>[];
    for (int i = 0; i < world.hazards.capacity; i++) {
      if (!world.hazards.isAlive(i)) continue;
      if (world.hazards.kindAt(i) != HazardKind.puddle) continue;
      if (world.hazards.ownerAt(i) != primary) continue;
      out.add(i);
    }
    return out;
  }

  group('spawn', () {
    test('a single, unplated body', () {
      final (:world, :primary) = spawnVermillion();
      expect(world.entities.health[primary], health);
      expect(world.entities.maxHealth[primary], health);
      expect(world.enemies.isPlated(primary), isFalse);
      expect(trailOf(world, primary), isEmpty);
    });
  });

  group('P1', () {
    test('walks toward the player', () {
      final (:world, :primary) = spawnVermillion();
      final double startX = world.entities.posX[primary];

      for (int i = 0; i < 60; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.posX[primary], greaterThan(startX));
    });

    test('lays a trail segment roughly once a second', () {
      final (:world, :primary) = spawnVermillion();

      for (int i = 0; i < 65; i++) {
        world.tick(InputSnapshot());
      }
      expect(trailOf(world, primary), hasLength(1));

      for (int i = 0; i < 60; i++) {
        world.tick(InputSnapshot());
      }
      expect(trailOf(world, primary), hasLength(2));
    });

    test('the trail damages a player standing in it over time', () {
      final (:world, :primary) = spawnVermillion(playerX: centerX + 2.0);
      final int player = world.player.index;
      world.entities.health[player] = 100.0;
      world.entities.maxHealth[player] = 100.0;

      for (int i = 0; i < 65; i++) {
        world.tick(InputSnapshot());
      }
      expect(trailOf(world, primary), isNotEmpty);

      // Keep the player pinned on the segment's own spot for a full second.
      final int segment = trailOf(world, primary).first;
      final double segX = world.hazards.x[segment];
      final double segY = world.hazards.y[segment];
      for (int i = 0; i < 60; i++) {
        world.entities.posX[player] = segX;
        world.entities.posY[player] = segY;
        world.tick(InputSnapshot());
      }

      expect(world.entities.health[player], lessThan(100.0));
    });

    test('segments persist rather than expiring immediately', () {
      final (:world, :primary) = spawnVermillion();

      for (int i = 0; i < 65; i++) {
        world.tick(InputSnapshot());
      }
      expect(trailOf(world, primary), hasLength(1));

      // Well short of the 20s lifetime.
      for (int i = 0; i < 300; i++) {
        world.tick(InputSnapshot());
      }
      expect(trailOf(world, primary), isNotEmpty);
    });

    test('halts and lays no further trail once past P2', () {
      final (:world, :primary) = spawnVermillion();
      for (int i = 0; i < 30; i++) {
        world.tick(InputSnapshot());
      }
      world.enemies.bossPhase[primary] = 2;
      // `MovementSystem` still integrates the velocity `moveToward` set on
      // the tick just before the phase changed — one tick's worth of
      // residual drift, then `Steering.halt` (called later that same tick)
      // has actually taken effect. `posBefore` is captured after that
      // transitional tick, not before it.
      world.tick(InputSnapshot());
      final double posBefore = world.entities.posX[primary];
      final int trailBefore = trailOf(world, primary).length;

      // Comfortably under the first detonation interval, so this is
      // purely a "no new segment appears" check — P3's own detonation is
      // covered separately below.
      for (int i = 0; i < 50; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.posX[primary], posBefore);
      expect(trailOf(world, primary), hasLength(trailBefore));
    });
  });

  group('P3: sequenced detonation', () {
    ({SimWorld world, int primary}) spawnWithThreeSegments() {
      final (:world, :primary) = spawnVermillion();
      // Trail interval is 1.0s; three full drops land at t = 1s, 2s, 3s.
      for (int i = 0; i < 210; i++) {
        world.tick(InputSnapshot());
      }
      return (world: world, primary: primary);
    }

    test('lays no further trail once P3 begins, and the existing trail '
        'stays untouched before its own turn', () {
      final (:world, :primary) = spawnWithThreeSegments();
      expect(trailOf(world, primary), hasLength(3));

      world.enemies.bossPhase[primary] = 2;
      world.tick(InputSnapshot());

      // Comfortably under the first per-segment interval (6.0/3 == 2.0s).
      for (int i = 0; i < 100; i++) {
        world.tick(InputSnapshot());
      }

      expect(trailOf(world, primary), hasLength(3));
    });

    test('detonates the oldest segment first, on the derived per-segment '
        'interval', () {
      final (:world, :primary) = spawnWithThreeSegments();
      world.enemies.bossPhase[primary] = 2;

      // Just past 2.0s (6.0/3) — the first of three should be gone.
      for (int i = 0; i < 121; i++) {
        world.tick(InputSnapshot());
      }
      expect(trailOf(world, primary), hasLength(2));

      // Just past 4.0s total — the second gone too.
      for (int i = 0; i < 120; i++) {
        world.tick(InputSnapshot());
      }
      expect(trailOf(world, primary), hasLength(1));

      // Just past 6.0s total — the whole trail is gone.
      for (int i = 0; i < 120; i++) {
        world.tick(InputSnapshot());
      }
      expect(trailOf(world, primary), isEmpty);
    });

    test('a detonation deals the derived heavy hit to a player standing '
        'on that segment', () {
      final (:world, :primary) = spawnWithThreeSegments();
      final List<int> segments = trailOf(world, primary);
      // The oldest — least `remaining` — is the first to detonate.
      final int oldest = segments.reduce((int a, int b) =>
          world.hazards.remaining[a] < world.hazards.remaining[b] ? a : b);
      final double x = world.hazards.x[oldest];
      final double y = world.hazards.y[oldest];

      // Vermillion spends the whole of `spawnWithThreeSegments` walking
      // toward (and eventually standing on) the player's own default
      // spawn point, so the player has already taken some incidental P1
      // trail damage by now — already covered by its own dedicated test
      // above, not what this one is measuring. Move well clear of the
      // whole trail and reset health explicitly, rather than assume the
      // default position was ever safe (ADR 0039's own lesson).
      final int player = world.player.index;
      world.entities.posX[player] = centerX;
      world.entities.posY[player] = centerY - 4.0;
      world.entities.health[player] = 100.0;
      world.enemies.bossPhase[primary] = 2;
      world.tick(InputSnapshot());
      expect(world.entities.health[player], 100.0);

      // Wait almost the entire first interval before stepping onto the
      // segment, so the player's own exposure to its ordinary ambient
      // burn (unrelated to the detonation burst) is only a couple of
      // ticks — negligible against the burst itself.
      for (int i = 0; i < 118; i++) {
        world.tick(InputSnapshot());
      }
      world.entities.posX[player] = x;
      world.entities.posY[player] = y;
      for (int i = 0; i < 3; i++) {
        world.tick(InputSnapshot());
      }

      // 0.09 * 2.10 == 18.9% of max health.
      expect(world.entities.health[player], closeTo(100.0 * (1 - 0.189), 1.0));
    });
  });

  group('P2', () {
    test('the ignite aura damages a nearby player on its very first tick',
        () {
      // Close enough to also sit on the charge's own eventual path — kept
      // well clear of that by stopping long before the charge's own
      // 37-tick resolve (see the dedicated charge test below).
      final (:world, :primary) = spawnVermillion(playerX: centerX + 0.5);
      world.enemies.bossPhase[primary] = 1;
      final int player = world.player.index;
      expect(world.entities.health[player], 100.0);

      // The aura's own cooldown starts at zero, so its first tick fires
      // immediately, on the very first call.
      for (int i = 0; i < 5; i++) {
        world.tick(InputSnapshot());
      }

      // 4%/s * 0.6s — the trail's own burn rate, discretised.
      expect(world.entities.health[player], closeTo(100.0 * (1 - 0.024), 1e-6));
    });

    test('a player outside the aura takes nothing before the charge lands',
        () {
      final (:world, :primary) = spawnVermillion(playerX: centerX + 7.0);
      world.enemies.bossPhase[primary] = 1;
      final int player = world.player.index;

      // Well short of both the first aura re-tick and the charge's own
      // resolve (both ~36 ticks away) — Vermillion is halted here for the
      // wind-up, still at its own spawn point, 7u from the player.
      for (int i = 0; i < 20; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.health[player], 100.0);
    });

    test('winds up a visible line before charging', () {
      final (:world, :primary) = spawnVermillion(playerX: centerX + 5.0);
      world.enemies.bossPhase[primary] = 1;

      world.tick(InputSnapshot());

      final int telegraphSlot = world.enemies.telegraphSlot[primary];
      expect(telegraphSlot, greaterThanOrEqualTo(0));
      expect(world.telegraphs.severityAt(telegraphSlot), TelegraphSeverity.warning);
    });

    test('the charge deals the derived heavy hit and moves Vermillion to '
        "the line's own far end", () {
      // Outside the 3u aura the whole time up to the resolve (halted
      // during the wind-up, still at its own spawn point), but on the
      // charge's own path — 5u east, short of the charge's own 6u reach.
      final (:world, :primary) = spawnVermillion(playerX: centerX + 5.0);
      world.enemies.bossPhase[primary] = 1;
      final int player = world.player.index;
      final double startX = world.entities.posX[primary];

      // The wind-up resolves on tick 37 (stateTimer starts at 0.6s = 36
      // decrements, so it first reads <= 0 on the 37th call). Stopping
      // there, not later, matters: the charge lands Vermillion within the
      // aura's own 3u reach of this same player, so one tick further
      // would add a second, aura-sourced hit this test does not want to
      // account for.
      for (int i = 0; i < 37; i++) {
        world.tick(InputSnapshot());
      }

      // 9% * 2.10 — the same derived "heavy hit" Hollow Warden's shot,
      // Skarn's slam and Gaunt's shockwave already use.
      expect(world.entities.health[player], closeTo(100.0 * (1 - 0.189), 1e-6));
      expect(world.entities.posX[primary], greaterThan(startX + 3.0));
    });
  });
}
