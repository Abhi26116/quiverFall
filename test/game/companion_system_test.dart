import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'enemy_test_support.dart';

/// `CompanionSystem` — a friendly, independently-acting body fighting
/// alongside the player (docs/07 §7.3: Zea's own Skyhawk/Falconry,
/// Mirelle's own Hall of Mirrors clone). This file is about the generic
/// primitive only — no hero-specific wiring exists yet; see ADR 0071.
void main() {
  final ContentLibrary content = loadEnemies();
  const double centerX = 8.0;
  const double centerY = 4.5;

  ({SimWorld world, int companion}) arena({
    double damageShare = 0.35,
    double fireRate = 1.5,
    double lifetimeSeconds = double.infinity,
    bool alwaysCrit = false,
    double followOffsetX = 0,
    double followOffsetY = 0,
  }) {
    final SimWorld world = SimWorld(seed: 707, content: content)
      ..autoFire = false
      ..playerAttack = 100.0;
    world.spawnPlayer(centerX, centerY);
    final int companion = world.spawnCompanion(
      centerX,
      centerY,
      damageShare: damageShare,
      fireRate: fireRate,
      lifetimeSeconds: lifetimeSeconds,
      alwaysCrit: alwaysCrit,
      followOffsetX: followOffsetX,
      followOffsetY: followOffsetY,
    );
    return (world: world, companion: companion);
  }

  group('spawn', () {
    test('places a single companion body', () {
      final (:world, :companion) = arena();
      expect(companion, greaterThanOrEqualTo(0));
      expect(world.entities.alive[companion], 1);
      expect(world.entities.kindOf(companion), EntityKind.companion);
    });
  });

  group('following', () {
    test('moves toward the player plus its own follow offset', () {
      final (:world, :companion) = arena(followOffsetX: 2.0);

      for (int i = 0; i < 60; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.posX[companion], closeTo(centerX + 2.0, 0.2));
      expect(world.entities.posY[companion], closeTo(centerY, 0.2));
    });

    test('halts and never crashes when the player is gone', () {
      final (:world, :companion) = arena();
      world.entities.despawn(world.player);

      expect(() => world.tick(InputSnapshot()), returnsNormally);
      expect(world.entities.velX[companion], 0);
      expect(world.entities.velY[companion], 0);
    });
  });

  group('firing', () {
    test('deals playerAttack * damageShare to the nearest enemy, laying a '
        'player-owned Windline', () {
      final (:world, :companion) = arena();
      final int mote = world.spawnEnemy(EnemyArchetype.mote, centerX + 3.0, centerY);
      world.enemies.speedScale[mote] = 0;
      world.entities.maxHealth[mote] = 1.0e5;
      world.entities.health[mote] = 1.0e5;

      final double before = world.entities.health[mote];
      world.tick(InputSnapshot());

      expect(world.entities.health[mote], closeTo(before - 35.0, 1e-6));
      expect(world.windlines.liveCount, greaterThan(0));
      // The one live segment is owned by the player's own sentinel, the
      // same one every Confluence-relevant consumer already treats as
      // "the player's own trail."
      bool foundPlayerOwned = false;
      for (int s = 0; s < world.windlines.capacity; s++) {
        if (world.windlines.isAlive(s) && world.windlines.ownerAt(s) == 0) {
          foundPlayerOwned = true;
        }
      }
      expect(foundPlayerOwned, isTrue);
    });

    test('no target, no shot — the cooldown stays ready rather than owing '
        'a backlog', () {
      final (:world, :companion) = arena();

      for (int i = 0; i < 120; i++) {
        world.tick(InputSnapshot());
      }

      final int mote = world.spawnEnemy(EnemyArchetype.mote, centerX + 3.0, centerY);
      world.enemies.speedScale[mote] = 0;
      world.entities.maxHealth[mote] = 1.0e5;
      world.entities.health[mote] = 1.0e5;
      final double before = world.entities.health[mote];

      world.tick(InputSnapshot());

      expect(world.entities.health[mote], lessThan(before));
    });

    test('fires again after its own cooldown, not before', () {
      final (:world, :companion) = arena();
      final int mote = world.spawnEnemy(EnemyArchetype.mote, centerX + 3.0, centerY);
      world.enemies.speedScale[mote] = 0;
      world.entities.maxHealth[mote] = 1.0e5;
      world.entities.health[mote] = 1.0e5;

      world.tick(InputSnapshot());
      final double afterFirst = world.entities.health[mote];

      // Well within the 1/1.5s = 0.667s cooldown.
      for (int i = 0; i < 20; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.entities.health[mote], afterFirst);

      // Past the cooldown.
      for (int i = 0; i < 30; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.entities.health[mote], lessThan(afterFirst));
    });

    test('Bonded-style crit: doubles at the player\'s own crit multiplier '
        'only while at Tier III', () {
      final (:world, :companion) = arena(alwaysCrit: true);
      final int mote = world.spawnEnemy(EnemyArchetype.mote, centerX + 3.0, centerY);
      world.enemies.speedScale[mote] = 0;
      world.entities.maxHealth[mote] = 1.0e5;
      world.entities.health[mote] = 1.0e5;

      // Not yet at Tier III on tick 1 — the ordinary, uncritted hit.
      world.tick(InputSnapshot());
      final double base = 1.0e5 - world.entities.health[mote];
      expect(base, closeTo(35.0, 1e-6));

      // Force Tier III and let the next shot land.
      world.playerDraw.drawSeconds = 999;
      for (int i = 0; i < 60; i++) {
        world.tick(InputSnapshot());
      }
      final double afterSecondShot = 1.0e5 - world.entities.health[mote];
      final double secondShot = afterSecondShot - base;
      expect(secondShot, closeTo(35.0 * world.combat.critMultiplier, 0.5));
    });
  });

  group('lifetime', () {
    test('a finite-lifetime companion despawns once its own time runs out',
        () {
      final (:world, :companion) = arena(lifetimeSeconds: 1.0);

      for (int i = 0; i < 59; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.entities.alive[companion], 1);

      for (int i = 0; i < 5; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.entities.alive[companion], 0);
    });

    test('a permanent companion (default lifetime) never expires', () {
      final (:world, :companion) = arena();

      for (int i = 0; i < 1200; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.alive[companion], 1);
    });
  });

  group('room clear', () {
    test('clearRoom despawns every companion', () {
      final (:world, :companion) = arena();
      expect(world.entities.alive[companion], 1);

      world.clearRoom();

      expect(world.entities.alive[companion], 0);
    });
  });
}
