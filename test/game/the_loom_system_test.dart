import 'dart:math' as math;

import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/telegraph.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'boss_test_support.dart';

/// The Loom — "Weaves a slowly tightening lattice of crimson threads
/// across the arena... Player Windlines cut threads. The purest
/// expression of the game's mechanic as a survival tool rather than a
/// damage tool" (docs/06 §6.3, Endless Descent boss #17). Every test here
/// is about the threads themselves, not the boss's own body — it neither
/// moves nor attacks directly (ADR 0057).
void main() {
  final ContentLibrary content = loadContentWithBosses();
  const double health = 1.0e7;
  const double centerX = 8.0;
  const double centerY = 4.5;

  ({SimWorld world, int primary}) spawnTheLoom({
    double playerX = centerX + 6.0,
    double playerY = centerY,
  }) {
    final SimWorld world = SimWorld(seed: 171717, content: content)
      ..autoFire = false;
    world.spawnPlayer(playerX, playerY);
    final int primary = world.spawnTheLoom(centerX, centerY, health: health);
    return (world: world, primary: primary);
  }

  List<int> threadsOf(SimWorld world, int primary) {
    final List<int> found = <int>[];
    for (int j = 0; j < world.entities.highWater; j++) {
      if (world.entities.alive[j] == 0) continue;
      if (world.enemies.bossParent[j] != primary) continue;
      found.add(j);
    }
    return found;
  }

  group('spawn', () {
    test('a single, stationary body', () {
      final (:world, :primary) = spawnTheLoom();
      expect(world.entities.health[primary], health);
      expect(world.entities.maxHealth[primary], health);
      expect(world.entities.posX[primary], centerX);
      expect(world.entities.posY[primary], centerY);
    });
  });

  group('weaving threads', () {
    test('weaves a new thread on its own cadence', () {
      final (:world, :primary) = spawnTheLoom();
      expect(threadsOf(world, primary), isEmpty);

      // P1's own 3.0s interval.
      for (int i = 0; i < 181; i++) {
        world.tick(InputSnapshot());
      }

      final List<int> threads = threadsOf(world, primary);
      expect(threads.length, 1);
      final int thread = threads.first;
      expect(world.enemies.untargetable[thread], 1);
      expect(world.enemies.telegraphSlot[thread], greaterThanOrEqualTo(0));
      expect(world.telegraphs.severityAt(world.enemies.telegraphSlot[thread]),
          TelegraphSeverity.lethal);
    });

    test('threads accumulate but never exceed the cap', () {
      final (:world, :primary) = spawnTheLoom();
      world.enemies.bossPhase[primary] = 2; // fastest add rate

      // Comfortably enough 1.0s cycles to reach the 24-thread cap.
      for (int i = 0; i < 3000; i++) {
        world.tick(InputSnapshot());
      }

      expect(threadsOf(world, primary).length, 24);
    });

    test("P2's own add rate is faster than P1's", () {
      final (:world, :primary) = spawnTheLoom();
      for (int i = 0; i < 600; i++) {
        world.tick(InputSnapshot());
      }
      final int p1Count = threadsOf(world, primary).length;

      final (world: world2, primary: primary2) = spawnTheLoom();
      world2.enemies.bossPhase[primary2] = 1;
      for (int i = 0; i < 600; i++) {
        world2.tick(InputSnapshot());
      }
      final int p2Count = threadsOf(world2, primary2).length;

      expect(p2Count, greaterThan(p1Count));
    });
  });

  group('standing on a thread', () {
    test('deals the Thresher\'s own persistent-aura anchor', () {
      final (:world, :primary) = spawnTheLoom();
      for (int i = 0; i < 181; i++) {
        world.tick(InputSnapshot());
      }
      final int thread = threadsOf(world, primary).first;
      final int t = world.enemies.telegraphSlot[thread];
      final double midX = (world.telegraphs.xAt(t) + world.telegraphs.toXAt(t)) / 2;
      final double midY = (world.telegraphs.yAt(t) + world.telegraphs.toYAt(t)) / 2;

      final int player = world.player.index;
      world.entities.posX[player] = midX;
      world.entities.posY[player] = midY;
      expect(world.entities.health[player], 100.0);

      world.tick(InputSnapshot());

      // 100 - 9 == 91.
      expect(world.entities.health[player], closeTo(91.0, 1e-6));
    });
  });

  group('cutting a thread', () {
    test('a player Windline crossing a thread removes it — no longer '
        'damages anyone standing on it', () {
      final (:world, :primary) = spawnTheLoom();
      for (int i = 0; i < 181; i++) {
        world.tick(InputSnapshot());
      }
      final int thread = threadsOf(world, primary).first;
      final int t = world.enemies.telegraphSlot[thread];
      final double x0 = world.telegraphs.xAt(t);
      final double y0 = world.telegraphs.yAt(t);
      final double x1 = world.telegraphs.toXAt(t);
      final double y1 = world.telegraphs.toYAt(t);
      final double midX = (x0 + x1) / 2;
      final double midY = (y0 + y1) / 2;

      // A short player-owned segment through the thread's own midpoint,
      // perpendicular to it — guaranteed to cross regardless of the
      // thread's own (randomly placed) angle.
      final double dx = x1 - x0;
      final double dy = y1 - y0;
      final double len = math.sqrt(dx * dx + dy * dy);
      final double perpX = -dy / len;
      final double perpY = dx / len;
      world.windlines.add(
        fromX: midX - perpX,
        fromY: midY - perpY,
        toX: midX + perpX,
        toY: midY + perpY,
        expiresAt: world.elapsedSeconds + 999,
        ownerIndex: 0,
        trailId: -9001,
      );

      world.tick(InputSnapshot());

      expect(world.entities.alive[thread], 0);
      expect(threadsOf(world, primary), isEmpty);

      // Standing exactly where the (now-cut) thread used to be causes no
      // further damage.
      final int player = world.player.index;
      world.entities.posX[player] = midX;
      world.entities.posY[player] = midY;
      for (int i = 0; i < 60; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.entities.health[player], 100.0);
    });

    test("an enemy-owned line does not cut a thread — only the player's "
        'own', () {
      final (:world, :primary) = spawnTheLoom();
      for (int i = 0; i < 181; i++) {
        world.tick(InputSnapshot());
      }
      final int thread = threadsOf(world, primary).first;
      final int t = world.enemies.telegraphSlot[thread];
      final double x0 = world.telegraphs.xAt(t);
      final double y0 = world.telegraphs.yAt(t);
      final double x1 = world.telegraphs.toXAt(t);
      final double y1 = world.telegraphs.toYAt(t);
      final double midX = (x0 + x1) / 2;
      final double midY = (y0 + y1) / 2;
      final double dx = x1 - x0;
      final double dy = y1 - y0;
      final double len = math.sqrt(dx * dx + dy * dy);
      final double perpX = -dy / len;
      final double perpY = dx / len;

      world.windlines.add(
        fromX: midX - perpX,
        fromY: midY - perpY,
        toX: midX + perpX,
        toY: midY + perpY,
        expiresAt: world.elapsedSeconds + 999,
        ownerIndex: primary, // not the player
        trailId: -9002,
      );

      world.tick(InputSnapshot());

      expect(world.entities.alive[thread], 1);
    });
  });

  group('death', () {
    test("the primary's own death despawns every thread — the room can "
        'still clear', () {
      final (:world, :primary) = spawnTheLoom();
      for (int i = 0; i < 181; i++) {
        world.tick(InputSnapshot());
      }
      final List<int> threads = threadsOf(world, primary);
      expect(threads, isNotEmpty);

      world.entities.health[primary] = 0;
      world.tick(InputSnapshot());

      for (final int th in threads) {
        expect(world.entities.alive[th], 0,
            reason: 'a thread must not outlive the primary it belongs to');
      }
    });
  });
}
