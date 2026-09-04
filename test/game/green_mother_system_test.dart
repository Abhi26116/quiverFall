import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'boss_test_support.dart';

/// The Green Mother — "Spawns Knitters continuously; the Mother heals from
/// each. A raw DPS check" (docs/06 §8). Almost every test here is really
/// testing that the *existing* Knitter/Toxin machinery reaches a boss body
/// correctly, not new code of this boss's own.
void main() {
  final ContentLibrary content = loadContentWithBosses();
  const double health = 1.0e7;
  const double centerX = 8.0;
  const double centerY = 4.5;

  ({SimWorld world, int primary}) spawnGreenMother({
    double playerX = centerX + 6.0,
    double playerY = centerY,
  }) {
    final SimWorld world = SimWorld(seed: 808808, content: content)
      ..autoFire = false;
    world.spawnPlayer(playerX, playerY);
    final int primary = world.spawnGreenMother(centerX, centerY, health: health);
    return (world: world, primary: primary);
  }

  List<int> knittersOf(SimWorld world, int primary) {
    final List<int> found = <int>[];
    for (int j = 0; j < world.entities.highWater; j++) {
      if (world.entities.alive[j] == 0) continue;
      if (world.enemies.spawnerSlot[j] != primary) continue;
      found.add(j);
    }
    return found;
  }

  group('spawn', () {
    test('a single, stationary body', () {
      final (:world, :primary) = spawnGreenMother();
      expect(world.entities.health[primary], health);
      expect(world.entities.maxHealth[primary], health);
      expect(world.entities.posX[primary], centerX);
      expect(world.entities.posY[primary], centerY);
    });
  });

  group('summoning Knitters', () {
    test('spawns a real, independent Knitter on its first cycle', () {
      final (:world, :primary) = spawnGreenMother();
      expect(primary, greaterThanOrEqualTo(0));

      // Wind-up is 0.5s; resolve lands on/around tick 30.
      for (int i = 0; i < 35; i++) {
        world.tick(InputSnapshot());
      }

      final List<int> knitters = knittersOf(world, primary);
      expect(knitters.length, 1);
      expect(world.enemies.liveAdds[primary], 1);
      final int add = knitters.first;
      // A real, ordinary enemy — not a boss child: it has its own content
      // definition and runs its own Choir-family AI.
      expect(world.entities.contentIndex[add], greaterThanOrEqualTo(0));
      expect(world.entities.kind[add], EntityKind.enemy.index);
    });

    test('spawns roughly one Knitter per second, continuously', () {
      final (:world, :primary) = spawnGreenMother();
      // Each cycle after the first is a 1.0s cooldown plus a 0.5s wind-up
      // (90 ticks); the fourth spawn lands at tick 300. Run comfortably
      // past it.
      for (int i = 0; i < 320; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.enemies.liveAdds[primary], greaterThanOrEqualTo(4));
    });

    test('never exceeds the spawn cap even when idle forever', () {
      final (:world, :primary) = spawnGreenMother();
      // Simulates "already at the cap" without needing to wait out 16 real
      // spawn cycles to reach it organically.
      world.enemies.liveAdds[primary] = 16;

      for (int i = 0; i < 400; i++) {
        world.tick(InputSnapshot());
      }

      expect(knittersOf(world, primary), isEmpty);
    });
  });

  group('the DPS check', () {
    test('the Mother heals once a Knitter is close enough, reduced by Toxin',
        () {
      double healedWith(int toxinStacks) {
        final (:world, :primary) = spawnGreenMother();

        // Let a Knitter spawn naturally first, at full health — lowering
        // the Mother's own health *before* one exists would trip
        // `BossPhaseSystem` past P1 immediately (20% is already below the
        // P2/P3 thresholds) and stop her from ever spawning one at all.
        for (int i = 0; i < 35; i++) {
          world.tick(InputSnapshot());
        }
        expect(knittersOf(world, primary), isNotEmpty);

        world.entities.health[primary] = world.entities.maxHealth[primary] * 0.2;
        final double before = world.entities.health[primary];

        for (int i = 0; i < 30; i++) {
          world.status.toxinStacks[primary] = toxinStacks;
          world.tick(InputSnapshot());
        }
        return world.entities.health[primary] - before;
      }

      final double clean = healedWith(0);
      final double poisoned = healedWith(10);

      expect(clean, greaterThan(0));
      expect(poisoned, lessThan(clean * 0.6));
    });

    test('more live Knitters heal faster — this really is a DPS race', () {
      final (:world, :primary) = spawnGreenMother();

      // Let several cycles land first, at full health — lowering it before
      // any Knitter exists would trip `BossPhaseSystem` past P1 and stop
      // her from spawning any at all.
      for (int i = 0; i < 260; i++) {
        world.tick(InputSnapshot());
      }
      final int knitterCount = knittersOf(world, primary).length;
      expect(knitterCount, greaterThan(1));

      world.entities.health[primary] = world.entities.maxHealth[primary] * 0.1;
      final double before = world.entities.health[primary];
      for (int i = 0; i < 30; i++) {
        world.tick(InputSnapshot());
      }
      final double healedByMany = world.entities.health[primary] - before;

      // A single Knitter, same starting deficit, same window. Blocks
      // Green Mother's own further spawning so the comparison stays
      // exactly one Knitter throughout, rather than waiting out a full
      // real cycle per add.
      final (world: soloWorld, primary: soloPrimary) = spawnGreenMother();
      soloWorld.enemies.attackCooldown[soloPrimary] = 1.0e9;
      soloWorld.entities.health[soloPrimary] =
          soloWorld.entities.maxHealth[soloPrimary] * 0.1;
      soloWorld.spawnEnemy(EnemyArchetype.knitter, centerX + 0.4, centerY);
      final double before2 = soloWorld.entities.health[soloPrimary];
      for (int i = 0; i < 30; i++) {
        soloWorld.tick(InputSnapshot());
      }
      final double healedBySingle = soloWorld.entities.health[soloPrimary] - before2;

      expect(healedByMany, greaterThan(healedBySingle));
    });
  });

  group('past P1', () {
    test('stops spawning and clears its own live spawn telegraph', () {
      final (:world, :primary) = spawnGreenMother();
      // Mid its very first wind-up (0.5s = ~30 ticks) — caught with a live
      // telegraph, not after it has already resolved.
      for (int i = 0; i < 10; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.enemies.telegraphSlot[primary], greaterThanOrEqualTo(0));

      world.enemies.bossPhase[primary] = 1;
      world.tick(InputSnapshot());
      expect(world.enemies.telegraphSlot[primary], -1);

      final int liveAddsBefore = world.enemies.liveAdds[primary];
      for (int i = 0; i < 400; i++) {
        world.tick(InputSnapshot());
      }
      // No further spawns — the count can only have gone down (organic
      // deaths never happen here) or stayed put, never up.
      expect(world.enemies.liveAdds[primary], lessThanOrEqualTo(liveAddsBefore));
    });
  });
}
