import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'boss_test_support.dart';

/// Silversong — "a resonant bell-figure that hunts the player's mechanic
/// rather than their HP" (docs/06 §3). No damage anywhere in this fight;
/// every test here is about `DrawState.drawLockRemaining`/`drawSeconds`,
/// never `entities.health`. P2 adds resonance pillars (ADR 0036).
void main() {
  final ContentLibrary content = loadContentWithBosses();
  const double health = 1.0e7;
  const double centerX = 8.0;
  const double centerY = 4.5;

  ({SimWorld world, int primary}) spawnSilversong({
    double playerX = centerX + 3.0,
    double playerY = centerY,
  }) {
    final SimWorld world = SimWorld(seed: 707, content: content)
      ..autoFire = false;
    world.spawnPlayer(playerX, playerY);
    final int primary = world.spawnSilversong(centerX, centerY, health: health);
    return (world: world, primary: primary);
  }

  List<int> pillarsOf(SimWorld world, int primary) {
    final List<int> out = <int>[];
    for (int j = 0; j < world.entities.highWater; j++) {
      if (world.entities.alive[j] == 0) continue;
      if (world.enemies.bossParent[j] != primary) continue;
      out.add(j);
    }
    return out;
  }

  group('spawn', () {
    test('a single, stationary, undamaging body', () {
      final (:world, :primary) = spawnSilversong();
      expect(world.entities.health[primary], health);
      expect(world.entities.maxHealth[primary], health);
    });
  });

  group('the scream', () {
    test('locks the Draw for a nearby player once it resolves', () {
      final (:world, :primary) = spawnSilversong();
      expect(primary, greaterThanOrEqualTo(0));

      // Wind-up is 0.6s; resolve lands on/around tick 36.
      for (int i = 0; i < 40; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.playerDraw.drawLockRemaining, greaterThan(2.0));
      expect(world.playerDraw.isDrawLocked, isTrue);
    });

    test('deals no HP damage at all', () {
      final (:world, :primary) = spawnSilversong();
      expect(primary, greaterThanOrEqualTo(0));
      final int player = world.player.index;

      for (int i = 0; i < 300; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.health[player], 100.0);
    });

    test('a player who dodges out of the cone before it resolves is not '
        'locked', () {
      final (:world, :primary) = spawnSilversong();
      expect(primary, greaterThanOrEqualTo(0));

      // The wind-up's own aim is fixed the instant it begins — one tick in.
      world.tick(InputSnapshot());
      // Well outside the 5u range and off to the side.
      world.entities.posX[world.player.index] = centerX;
      world.entities.posY[world.player.index] = centerY + 8.9;

      for (int i = 0; i < 39; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.playerDraw.drawLockRemaining, 0.0);
    });

    test('being locked freezes Draw progress, not just the tier ceiling',
        () {
      final (:world, :primary) = spawnSilversong();
      expect(primary, greaterThanOrEqualTo(0));

      for (int i = 0; i < 40; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.playerDraw.isDrawLocked, isTrue);

      final double before = world.playerDraw.drawSeconds;
      for (int i = 0; i < 30; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.playerDraw.drawSeconds, before);
    });

    test('recurs — a second lock lands after the first cycle', () {
      final (:world, :primary) = spawnSilversong();
      expect(primary, greaterThanOrEqualTo(0));

      // First resolve ~0.6s; cooldown 2.5s; second wind-up begins at ~3.1s,
      // resolves at ~3.7s (222 ticks). Sampled comfortably after that.
      for (int i = 0; i < 230; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.playerDraw.drawLockRemaining, greaterThan(2.0));
    });
  });

  group('P2: resonance pillars', () {
    test('a pillar forms with a brief telegraph, then solidifies', () {
      final (:world, :primary) = spawnSilversong();
      world.enemies.bossPhase[primary] = 1;

      world.tick(InputSnapshot());
      final List<int> pillars = pillarsOf(world, primary);
      expect(pillars.length, 1);
      final int pillar = pillars.first;
      expect(world.enemies.state[pillar], AiState.windUp.index);
      expect(world.enemies.telegraphSlot[pillar], greaterThanOrEqualTo(0));
      expect(world.enemies.untargetable[pillar], 1);

      // Forming wind-up is 0.6s (36 ticks) — comfortable margin past it.
      for (int i = 0; i < 40; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.enemies.state[pillar], isNot(AiState.windUp.index));
      expect(world.enemies.telegraphSlot[pillar], -1);
    });

    test('a solidified pillar Draw-locks a player who stands in it', () {
      final (:world, :primary) = spawnSilversong();
      world.enemies.bossPhase[primary] = 1;
      world.tick(InputSnapshot());
      final int pillar = pillarsOf(world, primary).first;

      for (int i = 0; i < 40; i++) {
        world.tick(InputSnapshot());
      }

      final int player = world.player.index;
      world.entities.posX[player] = world.entities.posX[pillar];
      world.entities.posY[player] = world.entities.posY[pillar];
      world.playerDraw.drawLockRemaining = 0;
      world.tick(InputSnapshot());

      expect(world.playerDraw.drawLockRemaining, greaterThan(2.0));
    });

    test('a pillar still forming does not lock anyone standing on it', () {
      final (:world, :primary) = spawnSilversong();
      world.enemies.bossPhase[primary] = 1;
      world.tick(InputSnapshot());
      final int pillar = pillarsOf(world, primary).first;

      final int player = world.player.index;
      world.entities.posX[player] = world.entities.posX[pillar];
      world.entities.posY[player] = world.entities.posY[pillar];
      world.playerDraw.drawLockRemaining = 0;
      world.tick(InputSnapshot());

      expect(world.playerDraw.drawLockRemaining, 0.0);
    });

    test('pillars accumulate over time, up to the cap', () {
      final (:world, :primary) = spawnSilversong();
      world.enemies.bossPhase[primary] = 1;

      // Comfortably past enough 4.0s intervals (240 ticks each) to reach
      // the 5-pillar cap.
      for (int i = 0; i < 1300; i++) {
        world.tick(InputSnapshot());
      }

      expect(pillarsOf(world, primary).length, 5);
    });

    test("the primary's own death despawns every pillar", () {
      final (:world, :primary) = spawnSilversong();
      world.enemies.bossPhase[primary] = 1;
      world.tick(InputSnapshot());
      expect(pillarsOf(world, primary), isNotEmpty);

      world.entities.health[primary] = 0;
      world.tick(InputSnapshot());

      expect(pillarsOf(world, primary), isEmpty);
    });
  });

  group('P3: permanent Draw-lock', () {
    test('stops screaming and stops growing pillars — the lock itself is '
        'now ambient', () {
      final (:world, :primary) = spawnSilversong();
      world.tick(InputSnapshot());
      expect(world.enemies.telegraphSlot[primary], greaterThanOrEqualTo(0));

      world.enemies.bossPhase[primary] = 1;
      world.tick(InputSnapshot());
      for (int i = 0; i < 40; i++) {
        world.tick(InputSnapshot());
      }
      final int pillarCountInP2 = pillarsOf(world, primary).length;
      expect(pillarCountInP2, greaterThan(0));

      world.enemies.bossPhase[primary] = 2;
      world.tick(InputSnapshot());
      expect(world.enemies.telegraphSlot[primary], -1);

      for (int i = 0; i < 300; i++) {
        world.tick(InputSnapshot());
      }
      expect(pillarsOf(world, primary).length, pillarCountInP2,
          reason: 'P3 grows no further pillars — any already standing are '
              'harmless leftovers');
    });

    test('locks the player permanently, anywhere in the room — Draw-lock '
        'only denies tier progress, so Momentum still builds', () {
      final (:world, :primary) = spawnSilversong(
        // Far from the boss's own body and from where any pillar could
        // have landed — the ambient lock must not depend on position.
        playerX: centerX + 6.0,
        playerY: centerY + 3.0,
      );
      world.enemies.bossPhase[primary] = 2;

      world.tick(InputSnapshot());
      expect(world.playerDraw.isDrawLocked, isTrue);
      expect(world.playerDraw.drawSeconds, 0.0);

      // Standing still for well over a Tier III's own threshold never
      // ramps the Draw while the lock holds.
      for (int i = 0; i < 200; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.playerDraw.isDrawLocked, isTrue);
      expect(world.playerDraw.tier, DrawTier.one);
    });
  });
}
