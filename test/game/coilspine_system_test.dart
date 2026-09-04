import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'boss_test_support.dart';

/// Coilspine — "A 24-segment serpent. Each segment is individually
/// damageable; destroying segments shortens it and changes its movement
/// pattern. Killing head-first is fast but enrages it; killing tail-first
/// is slow but safe" (docs/06 §6.3, Endless Descent boss #18). Every test
/// here is about the chain-following movement, segment death, and the
/// head-vs-tail enrage rule (ADR 0058).
void main() {
  final ContentLibrary content = loadContentWithBosses();
  const double health = 2.4e5; // divides evenly by 24 segments
  const double centerX = 8.0;
  const double centerY = 4.5;

  ({SimWorld world, int primary}) spawnCoilspine({
    double playerX = centerX + 6.0,
    double playerY = centerY,
  }) {
    final SimWorld world = SimWorld(seed: 242424, content: content)
      ..autoFire = false;
    world.spawnPlayer(playerX, playerY);
    final int primary = world.spawnCoilspine(centerX, centerY, health: health);
    return (world: world, primary: primary);
  }

  List<int> segmentsOf(SimWorld world, int primary) {
    final List<int> found = List<int>.filled(24, -1);
    for (int j = 0; j < world.entities.highWater; j++) {
      if (world.entities.alive[j] == 0) continue;
      if (world.enemies.bossParent[j] != primary) continue;
      found[world.enemies.bossChildIndex[j]] = j;
    }
    return found;
  }

  group('spawn', () {
    test('24 independently-healthed segments plus an invisible primary',
        () {
      final (:world, :primary) = spawnCoilspine();
      expect(world.enemies.untargetable[primary], 1);

      final List<int> segments = segmentsOf(world, primary);
      expect(segments.where((int s) => s >= 0).length, 24);

      double sum = 0;
      for (final int s in segments) {
        expect(world.entities.health[s], closeTo(health / 24, 1e-6));
        sum += world.entities.health[s];
      }
      expect(world.entities.health[primary], closeTo(sum, 1e-6));
      expect(world.entities.maxHealth[primary], closeTo(health, 1e-6));
    });
  });

  group('movement', () {
    test('the head chases the player over time', () {
      final (:world, :primary) = spawnCoilspine();
      final int head = segmentsOf(world, primary)[0];
      final double startX = world.entities.posX[head];

      for (int i = 0; i < 120; i++) {
        world.tick(InputSnapshot());
      }

      // Player is due east of the spawn point.
      expect(world.entities.posX[head], greaterThan(startX));
    });

    test('the body uncoils into a trailing chain behind the head', () {
      final (:world, :primary) = spawnCoilspine();

      for (int i = 0; i < 300; i++) {
        world.tick(InputSnapshot());
      }

      final List<int> segments = segmentsOf(world, primary);
      for (int k = 1; k < 24; k++) {
        final double dx = world.entities.posX[segments[k - 1]] -
            world.entities.posX[segments[k]];
        final double dy = world.entities.posY[segments[k - 1]] -
            world.entities.posY[segments[k]];
        final double dist = (dx * dx + dy * dy).abs();
        // Never drifts arbitrarily far behind its own leader — the
        // standoff distance keeps every consecutive pair close.
        expect(dist, lessThan(4.0),
            reason: 'segment $k should be trailing close to segment ${k - 1}');
      }
    });
  });

  group('segment death', () {
    test('killing a middle segment does not break the chain — segments '
        'behind it reattach to whichever is now nearest ahead', () {
      final (:world, :primary) = spawnCoilspine();
      for (int i = 0; i < 300; i++) {
        world.tick(InputSnapshot());
      }
      final List<int> before = segmentsOf(world, primary);

      // Kill segment 10.
      world.entities.health[before[10]] = 0;
      for (int i = 0; i < 5; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.entities.alive[before[10]], 0);

      // Segment 11 should now be trailing segment 9, not stuck reaching
      // for a dead leader — run it forward and confirm it keeps closing
      // toward segment 9 rather than sitting frozen in place.
      final int seg9 = before[9];
      final int seg11 = before[11];
      world.entities.posX[seg11] = world.entities.posX[seg9] + 10.0;
      world.entities.posY[seg11] = world.entities.posY[seg9];
      final double distBefore =
          (world.entities.posX[seg11] - world.entities.posX[seg9]).abs();

      for (int i = 0; i < 60; i++) {
        world.tick(InputSnapshot());
      }

      final double distAfter =
          (world.entities.posX[seg11] - world.entities.posX[seg9]).abs();
      expect(distAfter, lessThan(distBefore),
          reason: 'segment 11 should have closed the gap toward segment 9');
    });

    test('the room clears once every segment and the primary are dead',
        () {
      final (:world, :primary) = spawnCoilspine();
      final List<int> segments = segmentsOf(world, primary);

      for (final int s in segments) {
        world.entities.health[s] = 0;
      }
      for (int i = 0; i < 5; i++) {
        world.tick(InputSnapshot());
      }

      for (final int s in segments) {
        expect(world.entities.alive[s], 0);
      }
      expect(world.entities.alive[primary], 0);
    });
  });

  group('head-vs-tail enrage', () {
    test('killing the head while other segments survive enrages the '
        'whole body permanently', () {
      final (:world, :primary) = spawnCoilspine();
      final List<int> segments = segmentsOf(world, primary);

      world.entities.health[segments[0]] = 0;
      // One tick for the ordinary death pass (which runs after this
      // boss's own `update`, the same tick order every boss in this
      // roster shares) to actually reap the head; only the tick after
      // that sees `alive == 0` and latches the enrage flag — the same
      // one-transitional-tick shape every phase-boundary check in this
      // roster already accounts for (ADR 0023).
      world.tick(InputSnapshot());
      world.tick(InputSnapshot());

      expect(world.enemies.comboStep[primary], isNot(0));

      // Stays enraged even after every remaining segment is later
      // killed tail-first — a one-way latch, not a live head-alive
      // check.
      for (int k = 23; k >= 1; k--) {
        world.entities.health[segments[k]] = 0;
        world.tick(InputSnapshot());
        if (k > 1) expect(world.enemies.comboStep[primary], isNot(0));
      }
    });

    test('killing every segment tail-first, head last, never enrages it',
        () {
      final (:world, :primary) = spawnCoilspine();
      final List<int> segments = segmentsOf(world, primary);

      for (int k = 23; k >= 1; k--) {
        world.entities.health[segments[k]] = 0;
        world.tick(InputSnapshot());
        expect(world.enemies.comboStep[primary], 0,
            reason: 'the head is still alive at segment $k\'s own death');
      }

      // Only the head remains; killing it now ends the fight rather
      // than enraging a body that no longer has anything left in it.
      world.entities.health[segments[0]] = 0;
      world.tick(InputSnapshot());
      expect(world.entities.alive[primary], 0);
    });
  });

  group('contact damage', () {
    test('touching a live segment damages the player on a shared '
        'cooldown', () {
      final (:world, :primary) = spawnCoilspine();
      final int head = segmentsOf(world, primary)[0];
      final int player = world.player.index;
      world.entities.posX[player] = world.entities.posX[head];
      world.entities.posY[player] = world.entities.posY[head];
      expect(world.entities.health[player], 100.0);

      world.tick(InputSnapshot());

      // 100 - 9 == 91.
      expect(world.entities.health[player], closeTo(91.0, 1e-6));

      // Immediately again — still on cooldown, no further damage yet.
      world.tick(InputSnapshot());
      expect(world.entities.health[player], closeTo(91.0, 1e-6));
    });
  });
}
