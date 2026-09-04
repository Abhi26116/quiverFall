import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/telegraph.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'boss_test_support.dart';

/// The Quiverfall — "P1 — The First Shard: A vast descending shard fires
/// converging amber lines from the arena edges. Safe space is the
/// intersection gaps" (docs/06 §12). Mechanically Cinder Choir's own P2
/// tether sweep (ADR 0019) at a grander scale — most of these tests mirror
/// `cinder_choir_system_test.dart`'s own P2 group almost line for line.
void main() {
  final ContentLibrary content = loadContentWithBosses();
  const double health = 1.0e7;
  const double centerX = 8.0;
  const double centerY = 4.5;

  ({SimWorld world, int primary, List<int> spokes}) spawnQuiverfall({
    double playerX = centerX + 4.0,
    double playerY = centerY,
  }) {
    final SimWorld world = SimWorld(seed: 120120, content: content)
      ..autoFire = false;
    world.spawnPlayer(playerX, playerY);
    final int primary = world.spawnTheQuiverfall(centerX, centerY, health: health);
    final List<int> spokes = <int>[];
    for (int j = 0; j < world.entities.highWater; j++) {
      if (world.entities.alive[j] == 0) continue;
      if (world.enemies.bossParent[j] != primary) continue;
      spokes.add(j);
    }
    spokes.sort(
        (int a, int b) => world.enemies.bossChildIndex[a] - world.enemies.bossChildIndex[b]);
    return (world: world, primary: primary, spokes: spokes);
  }

  group('spawn', () {
    test('a single, directly-damageable body plus eight untargetable spoke '
        'anchors', () {
      final (:world, :primary, :spokes) = spawnQuiverfall();
      expect(world.entities.health[primary], health);
      expect(world.entities.maxHealth[primary], health);
      expect(world.enemies.untargetable[primary], 0);

      expect(spokes.length, 8);
      final Set<int> childIndices = <int>{};
      for (final int s in spokes) {
        expect(world.enemies.untargetable[s], 1);
        childIndices.add(world.enemies.bossChildIndex[s]);
      }
      expect(childIndices, <int>{0, 1, 2, 3, 4, 5, 6, 7});
    });
  });

  group('the converging sweep', () {
    // Right next to the primary's own position — the shared origin of
    // every spoke — so the player is "on" all eight regardless of the
    // live sweep angle, without needing to compute it.
    ({SimWorld world, int primary, List<int> spokes}) spawnAtCenter() =>
        spawnQuiverfall(playerX: centerX + 0.05);

    test('starts as a warning — no damage while it holds', () {
      final (:world, :primary, :spokes) = spawnAtCenter();

      for (int i = 0; i < 20; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.health[world.player.index], 100.0);
      final int telegraphSlot = world.enemies.telegraphSlot[spokes[0]];
      expect(telegraphSlot, greaterThanOrEqualTo(0));
      expect(world.telegraphs.severityAt(telegraphSlot), TelegraphSeverity.warning);
    });

    test('turns lethal and damages the player once the warning passes', () {
      final (:world, :primary, :spokes) = spawnAtCenter();
      expect(primary, greaterThanOrEqualTo(0));

      for (int i = 0; i < 60; i++) {
        world.tick(InputSnapshot());
      }

      final int player = world.player.index;
      // Reused from the Thresher (ADR 0019, ADR 0032): 9% of max HP.
      expect(world.entities.health[player], closeTo(91.0, 1e-6));
      final int telegraphSlot = world.enemies.telegraphSlot[spokes[0]];
      expect(world.telegraphs.severityAt(telegraphSlot), TelegraphSeverity.lethal);
    });

    test('damage respects its own cooldown, then lands again', () {
      final (:world, :primary, :spokes) = spawnAtCenter();
      expect(primary, greaterThanOrEqualTo(0));
      final int player = world.player.index;
      world.entities.health[player] = 1000;
      world.entities.maxHealth[player] = 1000;

      for (int i = 0; i < 60; i++) {
        world.tick(InputSnapshot());
      }
      final double afterFirst = world.entities.health[player];
      expect(afterFirst, lessThan(1000));

      for (int i = 0; i < 10; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.entities.health[player], afterFirst);

      for (int i = 0; i < 40; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.entities.health[player], lessThan(afterFirst));
    });

    test('the sweep angle actually advances', () {
      final (:world, :primary, :spokes) = spawnQuiverfall();
      expect(spokes.length, 8);

      for (int i = 0; i < 30; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.enemies.bossSweepAngle[primary], greaterThan(0));
    });
  });

  group('the primary\'s own death', () {
    test('despawns every spoke anchor — the room can still clear', () {
      final (:world, :primary, :spokes) = spawnQuiverfall();
      expect(spokes, isNotEmpty);

      world.entities.health[primary] = 0;
      world.tick(InputSnapshot());

      for (final int s in spokes) {
        expect(world.entities.alive[s], 0,
            reason: 'a spoke anchor must not outlive the primary it belongs to');
      }
    });
  });

  group('past P1', () {
    test('stops sweeping and clears every live spoke telegraph', () {
      final (:world, :primary, :spokes) = spawnQuiverfall();
      world.tick(InputSnapshot());
      expect(world.enemies.telegraphSlot[spokes[0]], greaterThanOrEqualTo(0));

      world.enemies.bossPhase[primary] = 1;
      world.tick(InputSnapshot());
      for (final int s in spokes) {
        expect(world.enemies.telegraphSlot[s], -1);
      }

      // No further hazard even given plenty of time — nothing here
      // replaces the sweep once P1 ends, since P2 is not built.
      final int player = world.player.index;
      final double healthBefore = world.entities.health[player];
      for (int i = 0; i < 300; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.entities.health[player], healthBefore);
      // Spoke anchors themselves are untouched — still alive, just idle.
      for (final int s in spokes) {
        expect(world.entities.alive[s], 1);
      }
    });
  });
}
