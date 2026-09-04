import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'boss_test_support.dart';

/// Gaunt, the Iron Tide — P1 only (docs/06 §2): a single body whose frontal
/// 180° arc takes a flat 5% at any Draw tier, and whose shield turns to
/// track the player at a capped rate, which is what makes flanking real.
void main() {
  final ContentLibrary content = loadContentWithBosses();
  const double health = 1.0e7;
  const double centerX = 8.0;
  const double centerY = 4.5;

  ({SimWorld world, int primary}) spawnGaunt({
    double playerX = centerX + 4.0,
    double playerY = centerY,
  }) {
    final SimWorld world = SimWorld(seed: 606, content: content)
      ..autoFire = false
      ..playerAttack = 1000;
    world.spawnPlayer(playerX, playerY);
    final int primary = world.spawnGaunt(centerX, centerY, health: health);
    return (world: world, primary: primary);
  }

  void fireOneShotAt(SimWorld world, DrawTier tier) {
    final int chargeTicks = switch (tier) {
      DrawTier.one => 0,
      DrawTier.two => 30,
      DrawTier.three => 80,
    };
    for (int i = 0; i < chargeTicks; i++) {
      world.tick(InputSnapshot());
    }
    world.autoFire = true;
    world.tick(InputSnapshot());
    world.autoFire = false;
    for (int i = 0; i < 150; i++) {
      world.tick(InputSnapshot());
    }
  }

  group('spawn', () {
    test('a single, always-plated body facing east by default', () {
      final (:world, :primary) = spawnGaunt();

      expect(world.entities.health[primary], health);
      expect(world.entities.maxHealth[primary], health);
      expect(world.enemies.isPlated(primary), isTrue);
      expect(world.entities.facing[primary], 0.0);
    });
  });

  group('the frontal arc', () {
    test('takes a flat ~5% regardless of Draw tier — not the usual '
        'Tier-III-breaks-plate rule', () {
      final tierOne = spawnGaunt();
      fireOneShotAt(tierOne.world, DrawTier.one);
      final double dmgTierOne = health - tierOne.world.entities.health[tierOne.primary];
      expect(dmgTierOne, greaterThan(0));

      final tierThree = spawnGaunt();
      fireOneShotAt(tierThree.world, DrawTier.three);
      final double dmgTierThree =
          health - tierThree.world.entities.health[tierThree.primary];

      // Both hits go through the same flat 5% armour factor — the only
      // difference between them is Tier III's own 2.10x damage multiplier
      // (docs/01 §1.1), not an armour bypass. Cinder Choir's own plate
      // produces a ~20x swing here (ADR 0018); Gaunt's own "Tests: flanking"
      // requires it not to.
      expect(dmgTierThree, closeTo(dmgTierOne * 2.10, dmgTierOne * 0.05));
    });

    test('a shot from directly behind bypasses the shield entirely', () {
      final (:world, :primary) = spawnGaunt(playerX: centerX - 4.0);
      // Fired before any meaningful rotation accumulates — Steering
      // .faceToward is capped at 70°/s, so one tick moves the shield well
      // under a degree.
      world.autoFire = true;
      world.tick(InputSnapshot());
      world.autoFire = false;
      for (int i = 0; i < 150; i++) {
        world.tick(InputSnapshot());
      }

      final double dmg = health - world.entities.health[primary];
      // Full damage (1000, matching Tier I's own 1.0x multiplier on the
      // 1000 playerAttack) — a frontal hit would have taken only 5% of
      // that (50).
      expect(dmg, closeTo(1000.0, 1.0));
    });
  });

  group('P1 tracks and advances', () {
    test('the shield turns toward the player, capped at 70°/s', () {
      final (:world, :primary) = spawnGaunt(
        playerX: centerX,
        playerY: centerY - 4.0,
      );
      // South of the boss — a 90° turn from the default facing (east).

      world.tick(InputSnapshot());
      // At 70°/s, one 1/60s tick can turn at most 70/60 ≈ 1.167°.
      final double facing = world.entities.facing[primary];
      expect(facing.abs(), lessThan(0.03)); // ~1.7°, generous tick margin
      expect(facing, isNot(0.0), reason: 'it should have started turning');
    });

    test('the boss advances toward the player over time', () {
      final (:world, :primary) = spawnGaunt();
      final double startX = world.entities.posX[primary];

      for (int i = 0; i < 120; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.posX[primary], greaterThan(startX),
          reason: 'the player is east of it — it should have advanced east');
    });

    test('movement and turning stop once past P1', () {
      final (:world, :primary) = spawnGaunt(
        playerX: centerX,
        playerY: centerY - 4.0,
      );
      // Let it move for real first — a stale velocity from mid-stride is
      // exactly what a P1→P2 transition must not leave it sliding on.
      for (int i = 0; i < 30; i++) {
        world.tick(InputSnapshot());
      }
      world.enemies.bossPhase[primary] = 1;
      final double posBefore = world.entities.posX[primary];
      final double facingBefore = world.entities.facing[primary];

      for (int i = 0; i < 120; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.posX[primary], posBefore);
      expect(world.entities.facing[primary], facingBefore);
    });
  });
}
