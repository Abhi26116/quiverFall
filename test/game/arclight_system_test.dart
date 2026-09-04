import 'dart:math' as math;

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

  group('P2: the charged grid', () {
    test('damages a player standing on a currently-live cell', () {
      final (:world, :primary) = spawnArclight();
      world.enemies.bossPhase[primary] = 1;
      world.tick(InputSnapshot());

      final bool liveIsEven = world.enemies.comboStep[primary] == 0;
      final int player = world.player.index;
      // Cell (0,0) is even parity; cell (1,0) is odd — pick whichever is
      // currently live. Read *after* repositioning: the tick just above
      // may already have caught the player's own default spawn point on
      // a live cell, so 100.0 is not a safe assumed baseline.
      world.entities.posX[player] = liveIsEven ? 1.0 : 3.0;
      world.entities.posY[player] = 1.0;
      final double before = world.entities.health[player];

      // Well inside the 1.5s cycle (90 ticks) — the parity read above
      // must still hold. No Swarmling has had time to spawn yet (0.5s
      // wind-up) to confound this with contact damage.
      for (int i = 0; i < 40; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.health[player], lessThan(before));
    });

    test('a player on the opposite parity takes nothing further', () {
      final (:world, :primary) = spawnArclight();
      world.enemies.bossPhase[primary] = 1;
      world.tick(InputSnapshot());

      final bool liveIsEven = world.enemies.comboStep[primary] == 0;
      final int player = world.player.index;
      world.entities.posX[player] = liveIsEven ? 3.0 : 1.0;
      world.entities.posY[player] = 1.0;
      final double before = world.entities.health[player];

      for (int i = 0; i < 40; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.health[player], before);
    });

    test('flips parity on its own 1.5s cycle', () {
      final (:world, :primary) = spawnArclight();
      world.enemies.bossPhase[primary] = 1;
      world.tick(InputSnapshot());
      final int firstParity = world.enemies.comboStep[primary];

      // Comfortably past 1.5s (90 ticks).
      for (int i = 0; i < 95; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.enemies.comboStep[primary], isNot(firstParity));
    });
  });

  group('P3: the untargetable orbit and four conduits', () {
    List<int> conduitsOf(SimWorld world, int primary) {
      final List<int> found = <int>[];
      for (int j = 0; j < world.entities.highWater; j++) {
        if (world.entities.alive[j] == 0) continue;
        if (world.enemies.bossParent[j] != primary) continue;
        found.add(j);
      }
      return found;
    }

    test('the primary becomes untargetable and genuinely unkillable', () {
      final (:world, :primary) = spawnArclight();
      world.enemies.bossPhase[primary] = 2;
      world.tick(InputSnapshot());

      expect(world.enemies.untargetable[primary], 1);
      // A full-circle plate with a near-zero flat factor — the same
      // conditional-invulnerability shape Weeping Gate's own plate and
      // the Green Mother's own bloom already use — rather than a literal
      // 0, which `_armourFor` would treat as "no plate at all".
      expect(world.enemies.isPlated(primary), isTrue);
      expect(world.enemies.plateHalfArc[primary], closeTo(math.pi, 1e-9));
      expect(world.enemies.plateFlatFactor[primary], greaterThan(0.0));
    });

    test('places four independently-healthed, targetable conduits', () {
      final (:world, :primary) = spawnArclight();
      world.enemies.bossPhase[primary] = 2;
      world.tick(InputSnapshot());

      final List<int> conduits = conduitsOf(world, primary);
      expect(conduits.length, 4);
      final Set<int> childIndices = <int>{};
      for (final int c in conduits) {
        expect(world.enemies.untargetable[c], 0);
        expect(world.entities.health[c], closeTo(health / 4, 1));
        childIndices.add(world.enemies.bossChildIndex[c]);
      }
      expect(childIndices, <int>{0, 1, 2, 3});
    });

    test('killing every conduit kills the primary — the room can clear',
        () {
      final (:world, :primary) = spawnArclight();
      world.enemies.bossPhase[primary] = 2;
      world.tick(InputSnapshot());
      final List<int> conduits = conduitsOf(world, primary);
      expect(conduits.length, 4);

      for (final int c in conduits) {
        world.entities.health[c] = 0;
      }
      // A few ticks' margin: one for the ordinary death pass to reap the
      // conduits, one more for `_tickP3` to see them all gone and zero
      // the primary's own health, and one more for that to be reaped in
      // turn.
      for (int i = 0; i < 10; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.alive[primary], 0);
    });

    test('three of four conduits dead leaves the primary alive', () {
      final (:world, :primary) = spawnArclight();
      world.enemies.bossPhase[primary] = 2;
      world.tick(InputSnapshot());
      final List<int> conduits = conduitsOf(world, primary);

      for (int k = 0; k < 3; k++) {
        world.entities.health[conduits[k]] = 0;
      }
      world.tick(InputSnapshot());

      expect(world.entities.alive[primary], 1);
    });
  });

  group('P3 also stops the chains and the grid', () {
    test('stops spawning and clears every live chain', () {
      final (:world, :primary) = spawnArclight();
      for (int i = 0; i < 35; i++) {
        world.tick(InputSnapshot());
      }
      final List<int> swarmlings = swarmlingsOf(world, primary);
      expect(swarmlings, isNotEmpty);
      final int add = swarmlings.first;
      expect(world.enemies.telegraphSlot[add], greaterThanOrEqualTo(0));

      world.enemies.bossPhase[primary] = 2;
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

    test('stops the grid — its own parity and cooldown both stay put', () {
      final (:world, :primary) = spawnArclight();
      world.enemies.bossPhase[primary] = 1;
      for (int i = 0; i < 30; i++) {
        world.tick(InputSnapshot());
      }
      final int parityBefore = world.enemies.comboStep[primary];
      final double cooldownBefore = world.enemies.bossSweepAngle[primary];

      world.enemies.bossPhase[primary] = 2;
      // Comfortably past several more 1.5s cycles' worth, were the grid
      // still ticking.
      for (int i = 0; i < 400; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.enemies.comboStep[primary], parityBefore);
      expect(world.enemies.bossSweepAngle[primary], cooldownBefore);
    });
  });
}
