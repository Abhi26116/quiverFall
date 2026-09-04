import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'boss_test_support.dart';

/// The Weeping Gate — "A stationary arch that never moves and never
/// directly attacks... Opens portals spawning waves that escalate through
/// the full enemy roster" (docs/06 §10). Unlike every prior boss, the
/// Gate's own body deals no damage at all in P1 — every test here is about
/// what it spawns, not about it.
void main() {
  final ContentLibrary content = loadContentWithBosses();
  const double health = 1.0e7;
  const double centerX = 8.0;
  const double centerY = 4.5;

  ({SimWorld world, int primary}) spawnGate({
    double playerX = centerX + 3.0,
    double playerY = centerY,
  }) {
    final SimWorld world = SimWorld(seed: 100010, content: content)
      ..autoFire = false;
    world.spawnPlayer(playerX, playerY);
    final int primary = world.spawnWeepingGate(centerX, centerY, health: health);
    return (world: world, primary: primary);
  }

  List<int> addsOf(SimWorld world, int primary) {
    final List<int> found = <int>[];
    for (int j = 0; j < world.entities.highWater; j++) {
      if (world.entities.alive[j] == 0) continue;
      if (world.enemies.spawnerSlot[j] != primary) continue;
      found.add(j);
    }
    return found;
  }

  group('spawn', () {
    test('a single, stationary, unplated body', () {
      final (:world, :primary) = spawnGate();
      expect(world.entities.health[primary], health);
      expect(world.entities.maxHealth[primary], health);
      expect(world.entities.posX[primary], centerX);
      expect(world.entities.posY[primary], centerY);
      expect(world.enemies.plateHealth[primary], 0.0);
    });

    test('never itself lands a hit — only what it spawns can', () {
      final (:world, :primary) = spawnGate();
      expect(primary, greaterThanOrEqualTo(0));

      for (int i = 0; i < 300; i++) {
        world.tick(InputSnapshot());
      }

      // Spawned enemies (Motes and friends) reaching and hitting the
      // player is expected — that is the entire point of this boss. What
      // must never happen is a `playerHit` event whose own source is the
      // Gate's own slot.
      for (int i = 0; i < world.events.count; i++) {
        if (world.events.typeAt(i) != SimEventType.playerHit) continue;
        expect(world.events.entityBAt(i), isNot(primary),
            reason: 'the Gate itself must never be a playerHit source');
      }
    });
  });

  group('opening portals', () {
    test('spawns a real, independent enemy on its first cycle', () {
      final (:world, :primary) = spawnGate();
      expect(primary, greaterThanOrEqualTo(0));

      // Wind-up is 0.5s; resolve lands on/around tick 30.
      for (int i = 0; i < 35; i++) {
        world.tick(InputSnapshot());
      }

      final List<int> adds = addsOf(world, primary);
      expect(adds.length, 1);
      final int add = adds.first;
      expect(world.entities.contentIndex[add], greaterThanOrEqualTo(0));
      expect(world.entities.kind[add], EntityKind.enemy.index);
    });

    test('never exceeds the spawn cap even when idle forever', () {
      final (:world, :primary) = spawnGate();
      // Simulates "already at the cap" without needing to wait out 16 real
      // spawn cycles to reach it organically.
      world.enemies.liveAdds[primary] = 16;

      for (int i = 0; i < 400; i++) {
        world.tick(InputSnapshot());
      }

      expect(addsOf(world, primary), isEmpty);
    });

    test('the roster widens over time — later spawns are not limited to '
        'only the first archetype', () {
      final (:world, :primary) = spawnGate();

      // Comfortably past several 15s tier-unlock windows.
      for (int i = 0; i < 5400; i++) {
        world.tick(InputSnapshot());
      }

      final Set<int> distinctArchetypes = <int>{};
      for (final int add in addsOf(world, primary)) {
        distinctArchetypes.add(world.entities.contentIndex[add]);
      }
      expect(distinctArchetypes.length, greaterThan(1),
          reason: 'expected more than one archetype across a long P1');
    });

    test('a portal telegraphs before anything actually spawns', () {
      final (:world, :primary) = spawnGate();
      world.tick(InputSnapshot());
      expect(world.enemies.telegraphSlot[primary], greaterThanOrEqualTo(0));
      // Nothing has spawned yet — still mid wind-up.
      expect(addsOf(world, primary), isEmpty);
    });
  });

  group('P2: Riftborn pairs and the conditional plate', () {
    test('a portal now spawns two Riftborn at once, not one', () {
      final (:world, :primary) = spawnGate();
      world.enemies.bossPhase[primary] = 1;

      // Wind-up is 0.5s; resolve lands on/around tick 30.
      for (int i = 0; i < 35; i++) {
        world.tick(InputSnapshot());
      }

      final List<int> adds = addsOf(world, primary);
      expect(adds.length, 2,
          reason: 'P2 portals should spawn a pair, not a single enemy');
      for (final int add in adds) {
        expect(world.entities.contentIndex[add], greaterThanOrEqualTo(0));
        expect(world.entities.kind[add], EntityKind.enemy.index);
      }
    });

    test('the plate is open while fewer than three other enemies live', () {
      final (:world, :primary) = spawnGate();
      world.enemies.bossPhase[primary] = 1;
      world.tick(InputSnapshot());
      expect(world.enemies.plateHealth[primary], 0.0);
    });

    test('the plate shuts once three or more other enemies are alive', () {
      final (:world, :primary) = spawnGate();
      world.enemies.bossPhase[primary] = 1;
      world.spawnEnemy(EnemyArchetype.mote, centerX + 6.0, centerY);
      world.spawnEnemy(EnemyArchetype.mote, centerX + 6.0, centerY + 1.0);
      world.spawnEnemy(EnemyArchetype.mote, centerX + 6.0, centerY + 2.0);

      world.tick(InputSnapshot());

      expect(world.enemies.plateHealth[primary], world.entities.maxHealth[primary]);
    });

    test('the plate re-opens once the live count drops back below three',
        () {
      final (:world, :primary) = spawnGate();
      world.enemies.bossPhase[primary] = 1;
      final int a = world.spawnEnemy(EnemyArchetype.mote, centerX + 6.0, centerY);
      world.spawnEnemy(EnemyArchetype.mote, centerX + 6.0, centerY + 1.0);
      world.spawnEnemy(EnemyArchetype.mote, centerX + 6.0, centerY + 2.0);
      world.tick(InputSnapshot());
      expect(world.enemies.plateHealth[primary], greaterThan(0.0));

      world.entities.health[a] = 0;
      world.tick(InputSnapshot());
      world.tick(InputSnapshot());

      expect(world.enemies.plateHealth[primary], 0.0);
    });
  });

  group('P3: all portals open at once', () {
    List<int> p3PortalsOf(SimWorld world, int primary) {
      final List<int> found = <int>[];
      for (int j = 0; j < world.entities.highWater; j++) {
        if (world.entities.alive[j] == 0) continue;
        if (world.enemies.bossParent[j] != primary) continue;
        found.add(j);
      }
      return found;
    }

    test('stops the primary\'s own single-portal cycle and forces the '
        'plate back open', () {
      final (:world, :primary) = spawnGate();
      world.tick(InputSnapshot());
      expect(world.enemies.telegraphSlot[primary], greaterThanOrEqualTo(0));

      world.enemies.bossPhase[primary] = 2;
      world.tick(InputSnapshot());
      expect(world.enemies.telegraphSlot[primary], -1);
      expect(world.enemies.plateHealth[primary], 0.0);

      // The primary's own telegraph never comes back — every portal from
      // here on is owned by one of the new portal children instead.
      for (int i = 0; i < 60; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.enemies.telegraphSlot[primary], -1);
      expect(world.enemies.plateHealth[primary], 0.0);
    });

    test('places several portal children at once, not one', () {
      final (:world, :primary) = spawnGate();
      world.enemies.bossPhase[primary] = 2;
      world.tick(InputSnapshot());

      final List<int> portals = p3PortalsOf(world, primary);
      expect(portals.length, 3);
      final Set<int> childIndices = <int>{};
      for (final int p in portals) {
        expect(world.enemies.untargetable[p], 1);
        childIndices.add(world.enemies.bossChildIndex[p]);
      }
      expect(childIndices, <int>{0, 1, 2});
    });

    test('every portal spawns independently — several distinct spawners, '
        'not just one working portal', () {
      final (:world, :primary) = spawnGate();
      world.enemies.bossPhase[primary] = 2;

      for (int i = 0; i < 200; i++) {
        world.tick(InputSnapshot());
      }

      final Set<int> spawnerSlots = <int>{};
      for (int j = 0; j < world.entities.highWater; j++) {
        if (world.entities.alive[j] == 0) continue;
        if (world.entities.kind[j] != EntityKind.enemy.index) continue;
        final int spawner = world.enemies.spawnerSlot[j];
        if (p3PortalsOf(world, primary).contains(spawner)) {
          spawnerSlots.add(spawner);
        }
      }
      expect(spawnerSlots.length, greaterThan(1),
          reason: 'several portals should each have spawned something by '
              'now, not just one');
    });

    test('the primary\'s own death despawns every portal child — the room '
        'can still clear', () {
      final (:world, :primary) = spawnGate();
      world.enemies.bossPhase[primary] = 2;
      world.tick(InputSnapshot());
      final List<int> portals = p3PortalsOf(world, primary);
      expect(portals, isNotEmpty);

      world.entities.health[primary] = 0;
      world.tick(InputSnapshot());

      for (final int p in portals) {
        expect(world.entities.alive[p], 0,
            reason: 'a P3 portal child must not outlive the primary it '
                'belongs to');
      }
    });
  });
}
