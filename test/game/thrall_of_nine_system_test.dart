import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'boss_test_support.dart';

/// Thrall of the Nine — "Nine floating sigils orbit; each grants the
/// Thrall one ability. Destroying a sigil removes that ability
/// permanently" (docs/06 §9). Most tests here are about the sigils
/// themselves — their own independent health, their orbit, and what
/// happens to the rotation once one dies — rather than any single attack.
void main() {
  final ContentLibrary content = loadContentWithBosses();
  const double health = 1.0e7;
  const double centerX = 8.0;
  const double centerY = 4.5;

  ({SimWorld world, int primary}) spawnThrall({
    double playerX = centerX + 4.0,
    double playerY = centerY,
  }) {
    final SimWorld world = SimWorld(seed: 909909, content: content)
      ..autoFire = false;
    world.spawnPlayer(playerX, playerY);
    final int primary = world.spawnThrallOfNine(centerX, centerY, health: health);
    return (world: world, primary: primary);
  }

  List<int> sigilsOf(SimWorld world, int primary) {
    final List<int> found = <int>[];
    for (int j = 0; j < world.entities.highWater; j++) {
      if (world.entities.alive[j] == 0) continue;
      if (world.enemies.bossParent[j] != primary) continue;
      found.add(j);
    }
    found.sort(
        (int a, int b) => world.enemies.bossChildIndex[a] - world.enemies.bossChildIndex[b]);
    return found;
  }

  group('spawn', () {
    test('a single, stationary body orbited by nine independent sigils', () {
      final (:world, :primary) = spawnThrall();
      expect(world.entities.health[primary], health);
      expect(world.entities.maxHealth[primary], health);
      expect(world.entities.posX[primary], centerX);
      expect(world.entities.posY[primary], centerY);

      final List<int> sigils = sigilsOf(world, primary);
      expect(sigils.length, 9);

      final Set<int> childIndices = <int>{};
      for (final int s in sigils) {
        // Each sigil holds its own small health pool, not linked to the
        // Thrall's own.
        expect(world.enemies.linkedHealthSlot[s], -1);
        expect(world.entities.health[s], closeTo(health * 0.05, 1));
        expect(world.entities.maxHealth[s], closeTo(health * 0.05, 1));
        childIndices.add(world.enemies.bossChildIndex[s]);

        final double dx = world.entities.posX[s] - centerX;
        final double dy = world.entities.posY[s] - centerY;
        final double dist = dx * dx + dy * dy;
        expect(dist, closeTo(3.0 * 3.0, 0.01));
      }
      expect(childIndices, <int>{0, 1, 2, 3, 4, 5, 6, 7, 8});
    });
  });

  group('the orbit', () {
    test('sigils actually move over time, staying the same distance out',
        () {
      final (:world, :primary) = spawnThrall();
      final int sigil = sigilsOf(world, primary).first;
      final double startX = world.entities.posX[sigil];
      final double startY = world.entities.posY[sigil];

      for (int i = 0; i < 60; i++) {
        world.tick(InputSnapshot());
      }

      final double x = world.entities.posX[sigil];
      final double y = world.entities.posY[sigil];
      expect(x != startX || y != startY, isTrue,
          reason: 'a sigil should have moved along its orbit by now');

      final double dx = x - centerX;
      final double dy = y - centerY;
      expect(dx * dx + dy * dy, closeTo(3.0 * 3.0, 0.05));
    });
  });

  group('the rotation', () {
    test('the first turn (sigil 0, a cone) can actually hit the player', () {
      final (:world, :primary) = spawnThrall();
      expect(primary, greaterThanOrEqualTo(0));
      final int player = world.player.index;
      expect(world.entities.health[player], 100.0);

      // Wind-up is 0.6s; resolve lands on/around tick 36.
      for (int i = 0; i < 40; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.health[player], lessThan(100.0));
    });

    test('destroying a sigil permanently removes it from the rotation', () {
      final (:world, :primary) = spawnThrall();
      final List<int> sigils = sigilsOf(world, primary);
      final int sigilZero = sigils[0];
      world.entities.health[sigilZero] = 0;

      // The very first turn may already have been selected in the same
      // tick the kill landed — `ThrallOfNineSystem.update` runs before
      // `AiSystem`'s own death pass reaps a sigil that same tick, the
      // identical one-transitional-tick ordering every fixed-order boss
      // system already carries (ADR 0023). Run a full turn (at most 1.6s
      // == 96 ticks) so that stale pick, if it happened, finishes and the
      // rotation moves on for real before asserting anything.
      for (int i = 0; i < 100; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.entities.alive[sigilZero], 0);

      // Several more full rotations' worth of ticks.
      for (int i = 0; i < 800; i++) {
        world.tick(InputSnapshot());
        expect(world.enemies.bossActiveChildIndex[primary], isNot(0),
            reason: 'sigil 0 is dead and must never get another turn');
      }
    });

    test('a sigil is independently damageable — killing it does not touch '
        "the Thrall's own health", () {
      final (:world, :primary) = spawnThrall();
      final int sigil = sigilsOf(world, primary).first;
      final double thrallHealthBefore = world.entities.health[primary];

      world.entities.health[sigil] = 0;
      world.tick(InputSnapshot());

      expect(world.entities.alive[sigil], 0);
      expect(world.entities.health[primary], thrallHealthBefore);
    });
  });

  group('P2: two abilities simultaneously', () {
    test('the orbit accelerates', () {
      final (:world, :primary) = spawnThrall();
      world.enemies.bossPhase[primary] = 1;
      for (int i = 0; i < 30; i++) {
        world.tick(InputSnapshot());
      }
      final double angleInP2 = world.enemies.bossSweepAngle[primary];

      final (world: world2, primary: primary2) = spawnThrall();
      for (int i = 0; i < 30; i++) {
        world2.tick(InputSnapshot());
      }
      final double angleInP1 = world2.enemies.bossSweepAngle[primary2];

      expect(angleInP2, greaterThan(angleInP1));
    });

    test('casts a second ability, on a second sigil, alongside the first',
        () {
      final (:world, :primary) = spawnThrall();
      world.enemies.bossPhase[primary] = 1;
      world.tick(InputSnapshot());

      final int first = world.enemies.bossActiveChildIndex[primary];
      final int second = world.enemies.comboStep[primary];
      expect(second, isNot(first),
          reason: 'P2 must select a second ability, not just the first');

      expect(world.enemies.telegraphSlot[primary], greaterThanOrEqualTo(0));

      final int secondSlot = sigilsOf(world, primary)
          .firstWhere((int s) => world.enemies.bossChildIndex[s] == second);
      expect(world.enemies.telegraphSlot[secondSlot], greaterThanOrEqualTo(0));
    });

    test('both abilities can hit the same player independently', () {
      // 3u east — within the first ability's own cone (5u range, facing
      // dead-on) and the second's own line (9u reach, same facing).
      final (:world, :primary) = spawnThrall(playerX: centerX + 3.0);
      world.enemies.bossPhase[primary] = 1;
      final int player = world.player.index;
      expect(world.entities.health[player], 100.0);

      for (int i = 0; i < 40; i++) {
        world.tick(InputSnapshot());
      }

      // Two independent 9% hits (a fraction of *max* health each, not
      // compounding) — 100 - 9 - 9.
      expect(world.entities.health[player], closeTo(82.0, 1e-6));
    });
  });

  group('past P2', () {
    test('freezes the orbit, stops the rotation, and clears every live '
        'telegraph', () {
      final (:world, :primary) = spawnThrall();
      for (int i = 0; i < 10; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.enemies.telegraphSlot[primary], greaterThanOrEqualTo(0));

      world.enemies.bossPhase[primary] = 2;
      world.tick(InputSnapshot());
      expect(world.enemies.telegraphSlot[primary], -1);

      final int sigil = sigilsOf(world, primary).first;
      final double sigilX = world.entities.posX[sigil];
      final double sigilY = world.entities.posY[sigil];
      final int activeIndexBefore = world.enemies.bossActiveChildIndex[primary];

      for (int i = 0; i < 200; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.posX[sigil], sigilX);
      expect(world.entities.posY[sigil], sigilY);
      expect(world.enemies.bossActiveChildIndex[primary], activeIndexBefore);
    });
  });
}
