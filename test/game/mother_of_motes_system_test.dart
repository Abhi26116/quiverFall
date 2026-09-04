import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'boss_test_support.dart';

/// Mother of Motes — "Spawns 200+ Motes over the fight. Pure crowd-clear
/// check" (docs/06 §6.3, Endless Descent boss #19). One mechanic across
/// all three phases — the spawn rate itself escalating, not changing in
/// kind — so every test here is about the spawn cycle's own cadence and
/// its lifetime total, not new per-phase behaviour (ADR 0056).
void main() {
  final ContentLibrary content = loadContentWithBosses();
  const double health = 1.0e7;
  const double centerX = 8.0;
  const double centerY = 4.5;

  ({SimWorld world, int primary}) spawnMotherOfMotes({
    double playerX = centerX + 6.0,
    double playerY = centerY,
  }) {
    final SimWorld world = SimWorld(seed: 191919, content: content)
      ..autoFire = false;
    world.spawnPlayer(playerX, playerY);
    final int primary =
        world.spawnMotherOfMotes(centerX, centerY, health: health);
    return (world: world, primary: primary);
  }

  List<int> motesOf(SimWorld world, int primary) {
    final List<int> found = <int>[];
    for (int j = 0; j < world.entities.highWater; j++) {
      if (world.entities.alive[j] == 0) continue;
      if (world.entities.kind[j] != EntityKind.enemy.index) continue;
      if (world.enemies.spawnerSlot[j] != primary) continue;
      found.add(j);
    }
    return found;
  }

  group('spawn', () {
    test('a single, stationary body', () {
      final (:world, :primary) = spawnMotherOfMotes();
      expect(world.entities.health[primary], health);
      expect(world.entities.maxHealth[primary], health);
      expect(world.entities.posX[primary], centerX);
      expect(world.entities.posY[primary], centerY);
    });

    test('never itself lands a hit — only what it spawns can', () {
      final (:world, :primary) = spawnMotherOfMotes();
      expect(primary, greaterThanOrEqualTo(0));

      for (int i = 0; i < 300; i++) {
        world.tick(InputSnapshot());
      }

      for (int i = 0; i < world.events.count; i++) {
        if (world.events.typeAt(i) != SimEventType.playerHit) continue;
        expect(world.events.entityBAt(i), isNot(primary),
            reason: 'the Mother herself must never be a playerHit source');
      }
    });
  });

  group('summoning Motes', () {
    test('spawns a real, independent Mote on its first cycle', () {
      final (:world, :primary) = spawnMotherOfMotes();

      // Wind-up is 0.5s; P1's own 0.8s cooldown means the first cycle
      // resolves on/around tick 30.
      for (int i = 0; i < 35; i++) {
        world.tick(InputSnapshot());
      }

      final List<int> motes = motesOf(world, primary);
      expect(motes.length, 1);
      final int mote = motes.first;
      expect(world.entities.contentIndex[mote], greaterThanOrEqualTo(0));
      expect(world.entities.kind[mote], EntityKind.enemy.index);
      expect(world.enemies.liveAdds[primary], 1);
    });

    test('never exceeds the simultaneous spawn cap even when idle forever',
        () {
      final (:world, :primary) = spawnMotherOfMotes();
      // Simulates "already at the cap" without needing to wait out 16
      // real spawn cycles to reach it organically.
      world.enemies.liveAdds[primary] = 16;

      for (int i = 0; i < 400; i++) {
        world.tick(InputSnapshot());
      }

      expect(motesOf(world, primary), isEmpty);
    });

    test('the lifetime total keeps growing past the simultaneous cap', () {
      final (:world, :primary) = spawnMotherOfMotes();

      // ~1.3s per cycle at P1's own rate (0.5s wind-up + 0.8s cooldown) —
      // comfortably more than 16 cycles' worth of ticks.
      for (int i = 0; i < 1400; i++) {
        world.tick(InputSnapshot());
        // Killing every live Mote the instant it lands keeps the
        // simultaneous count at zero, so the cap never gates a further
        // spawn — only the lifetime total should keep climbing.
        for (final int m in motesOf(world, primary)) {
          world.entities.health[m] = 0;
        }
      }

      expect(world.enemies.comboStep[primary], greaterThan(16),
          reason: 'the lifetime total is not the same counter as the '
              'simultaneous cap');
    });
  });

  group('the escalating rate', () {
    test("P2's own spawn rate is faster than P1's", () {
      final (:world, :primary) = spawnMotherOfMotes();
      for (int i = 0; i < 600; i++) {
        world.tick(InputSnapshot());
        for (final int m in motesOf(world, primary)) {
          world.entities.health[m] = 0;
        }
      }
      final int p1Total = world.enemies.comboStep[primary];

      final (world: world2, primary: primary2) = spawnMotherOfMotes();
      world2.enemies.bossPhase[primary2] = 1;
      for (int i = 0; i < 600; i++) {
        world2.tick(InputSnapshot());
        for (final int m in motesOf(world2, primary2)) {
          world2.entities.health[m] = 0;
        }
      }
      final int p2Total = world2.enemies.comboStep[primary2];

      expect(p2Total, greaterThan(p1Total));
    });

    test("P3's own spawn rate is faster than P2's", () {
      final (:world, :primary) = spawnMotherOfMotes();
      world.enemies.bossPhase[primary] = 1;
      for (int i = 0; i < 600; i++) {
        world.tick(InputSnapshot());
        for (final int m in motesOf(world, primary)) {
          world.entities.health[m] = 0;
        }
      }
      final int p2Total = world.enemies.comboStep[primary];

      final (world: world2, primary: primary2) = spawnMotherOfMotes();
      world2.enemies.bossPhase[primary2] = 2;
      for (int i = 0; i < 600; i++) {
        world2.tick(InputSnapshot());
        for (final int m in motesOf(world2, primary2)) {
          world2.entities.health[m] = 0;
        }
      }
      final int p3Total = world2.enemies.comboStep[primary2];

      expect(p3Total, greaterThan(p2Total));
    });
  });
}
