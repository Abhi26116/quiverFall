import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/telegraph.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'boss_test_support.dart';

/// Arclight — "Chains lightning between itself and any active Swarmlings;
/// killing adds breaks the chain" (docs/06 §7). Unlike every prior boss,
/// this one's own mechanic runs through entities it creates rather than
/// itself — most tests here find a real, independently-alive Swarmling and
/// check the chain to it, rather than reading Arclight's own state alone.
void main() {
  final ContentLibrary content = loadContentWithBosses();
  const double health = 1.0e7;
  const double centerX = 8.0;
  const double centerY = 4.5;

  ({SimWorld world, int primary}) spawnArclight({
    double playerX = centerX + 6.0,
    double playerY = centerY,
  }) {
    final SimWorld world = SimWorld(seed: 707707, content: content)
      ..autoFire = false;
    world.spawnPlayer(playerX, playerY);
    final int primary = world.spawnArclight(centerX, centerY, health: health);
    return (world: world, primary: primary);
  }

  List<int> swarmlingsOf(SimWorld world, int primary) {
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
      final (:world, :primary) = spawnArclight();
      expect(world.entities.health[primary], health);
      expect(world.entities.maxHealth[primary], health);
      expect(world.entities.posX[primary], centerX);
      expect(world.entities.posY[primary], centerY);
    });
  });

  group('summoning Swarmlings', () {
    test('spawns four real, independent Swarmlings on its first cycle', () {
      final (:world, :primary) = spawnArclight();
      expect(primary, greaterThanOrEqualTo(0));

      // Wind-up is 0.5s; resolve lands on/around tick 30.
      for (int i = 0; i < 35; i++) {
        world.tick(InputSnapshot());
      }

      final List<int> swarmlings = swarmlingsOf(world, primary);
      expect(swarmlings.length, 4);
      expect(world.enemies.liveAdds[primary], 4);
      // A real, ordinary enemy — not a boss child: it has its own content
      // definition and runs its own flocking AI, unlike every other boss's
      // own inert children.
      for (final int slot in swarmlings) {
        expect(world.entities.contentIndex[slot], greaterThanOrEqualTo(0));
        expect(world.entities.kind[slot], EntityKind.enemy.index);
      }
    });

    test('never exceeds the spawn cap even when idle forever', () {
      final (:world, :primary) = spawnArclight();
      // Simulates "already at the cap" without needing to wait out 4
      // real spawn cycles (16s+) to reach it organically.
      world.enemies.liveAdds[primary] = 16;

      for (int i = 0; i < 400; i++) {
        world.tick(InputSnapshot());
      }

      expect(swarmlingsOf(world, primary), isEmpty);
    });
  });

  group('the chain', () {
    test('a fresh add only warns — no damage yet', () {
      final (:world, :primary) = spawnArclight();
      for (int i = 0; i < 35; i++) {
        world.tick(InputSnapshot());
      }
      final List<int> swarmlings = swarmlingsOf(world, primary);
      expect(swarmlings, isNotEmpty);
      final int add = swarmlings.first;

      // Put the player squarely on the segment from Arclight to the add,
      // and freeze the add in place so the geometry stays exact for this
      // one tick.
      final double addX = world.entities.posX[add];
      final double addY = world.entities.posY[add];
      world.entities.velX[add] = 0;
      world.entities.velY[add] = 0;
      final int player = world.player.index;
      world.entities.posX[player] = (centerX + addX) / 2;
      world.entities.posY[player] = (centerY + addY) / 2;

      world.tick(InputSnapshot());

      expect(world.enemies.telegraphSlot[add], greaterThanOrEqualTo(0));
      expect(world.telegraphs.severityAt(world.enemies.telegraphSlot[add]),
          TelegraphSeverity.warning);
      expect(world.entities.health[player], 100.0);
    });

    test('goes lethal and damages a player standing on it', () {
      final (:world, :primary) = spawnArclight();
      for (int i = 0; i < 35; i++) {
        world.tick(InputSnapshot());
      }
      final List<int> swarmlings = swarmlingsOf(world, primary);
      expect(swarmlings, isNotEmpty);
      final int add = swarmlings.first;

      final double addX = world.entities.posX[add];
      final double addY = world.entities.posY[add];
      world.entities.velX[add] = 0;
      world.entities.velY[add] = 0;
      // Skip past the per-add warning window directly, rather than
      // simulating it out — the warning itself is covered above.
      world.enemies.bossTimer[add] = 0;

      final int player = world.player.index;
      world.entities.posX[player] = (centerX + addX) / 2;
      world.entities.posY[player] = (centerY + addY) / 2;

      world.tick(InputSnapshot());

      expect(world.entities.health[player], lessThan(100.0));
    });

    test('a player clear of every chain takes no damage', () {
      final (:world, :primary) = spawnArclight();
      for (int i = 0; i < 35; i++) {
        world.tick(InputSnapshot());
      }
      final List<int> swarmlings = swarmlingsOf(world, primary);
      expect(swarmlings, isNotEmpty);
      for (final int add in swarmlings) {
        world.enemies.bossTimer[add] = 0;
      }

      final int player = world.player.index;
      world.entities.posX[player] = centerX;
      world.entities.posY[player] = centerY + 8.9;

      world.tick(InputSnapshot());

      expect(world.entities.health[player], 100.0);
    });

    test('killing an add ends its own chain', () {
      final (:world, :primary) = spawnArclight();
      for (int i = 0; i < 35; i++) {
        world.tick(InputSnapshot());
      }
      final List<int> swarmlings = swarmlingsOf(world, primary);
      expect(swarmlings, isNotEmpty);
      final int add = swarmlings.first;
      expect(world.enemies.telegraphSlot[add], greaterThanOrEqualTo(0));

      final int liveAddsBefore = world.enemies.liveAdds[primary];
      world.entities.health[add] = 0;
      world.tick(InputSnapshot());

      expect(world.entities.alive[add], 0);
      expect(world.enemies.liveAdds[primary], liveAddsBefore - 1);
    });
  });

  group('past P1', () {
    test('stops spawning and clears every live chain', () {
      final (:world, :primary) = spawnArclight();
      for (int i = 0; i < 35; i++) {
        world.tick(InputSnapshot());
      }
      final List<int> swarmlings = swarmlingsOf(world, primary);
      expect(swarmlings, isNotEmpty);
      final int add = swarmlings.first;
      expect(world.enemies.telegraphSlot[add], greaterThanOrEqualTo(0));

      world.enemies.bossPhase[primary] = 1;
      world.tick(InputSnapshot());
      expect(world.enemies.telegraphSlot[add], -1);

      final int liveAddsBefore = world.enemies.liveAdds[primary];
      for (int i = 0; i < 400; i++) {
        world.tick(InputSnapshot());
      }
      // No further spawns — the count can only have gone down (organic
      // deaths never happen here) or stayed put, never up.
      expect(world.enemies.liveAdds[primary], lessThanOrEqualTo(liveAddsBefore));
      expect(swarmlingsOf(world, primary).length,
          lessThanOrEqualTo(swarmlings.length));
    });
  });
}
