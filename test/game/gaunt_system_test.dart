import 'dart:math' as math;

import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/telegraph.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'boss_test_support.dart';

/// Gaunt, the Iron Tide — P1/P2 (docs/06 §2): a single body whose frontal
/// 180° arc takes a flat 5% at any Draw tier, and whose shield turns to
/// track the player at a capped rate, which is what makes flanking real.
/// P2 adds a shockwave slam and a faster rotation rate (ADR 0035).
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

  });

  group('P2: the shockwave slam', () {
    test('the rotation rate rises to 110°/s', () {
      final (:world, :primary) = spawnGaunt(
        playerX: centerX,
        playerY: centerY - 4.0,
      );
      world.enemies.bossPhase[primary] = 1;

      world.tick(InputSnapshot());
      // At 110°/s, one 1/60s tick can turn at most 110/60 ≈ 1.833° —
      // noticeably more than P1's own ~1.167° cap in the same tick.
      final double facing = world.entities.facing[primary].abs();
      expect(facing, greaterThan(70 / 60 * math.pi / 180));
      expect(facing, lessThan(0.04));
    });

    test('winds up, then resolves a lethal ring at the stated 5u radius',
        () {
      final (:world, :primary) = spawnGaunt(playerX: centerX + 2.0);
      world.enemies.bossPhase[primary] = 1;
      final int player = world.player.index;
      expect(world.entities.health[player], 100.0);

      world.tick(InputSnapshot());
      final int telegraphSlot = world.enemies.telegraphSlot[primary];
      expect(telegraphSlot, greaterThanOrEqualTo(0));
      expect(world.telegraphs.severityAt(telegraphSlot), TelegraphSeverity.warning);

      // Wind-up is 1.8s (108 ticks); comfortable margin past it.
      for (int i = 0; i < 115; i++) {
        world.tick(InputSnapshot());
      }

      // 9% * 2.10 — the same derived "heavy hit" every other boss's own
      // slam/shot already uses.
      expect(world.entities.health[player], closeTo(100.0 * (1 - 0.189), 1e-6));
    });

    test('a player outside 5u when it resolves takes nothing', () {
      final (:world, :primary) = spawnGaunt(playerX: centerX + 2.0);
      world.enemies.bossPhase[primary] = 1;
      // Committed one tick in, same as every other telegraphed circle.
      world.tick(InputSnapshot());

      final int player = world.player.index;
      world.entities.posX[player] = centerX + 8.9;
      world.entities.posY[player] = centerY;

      for (int i = 0; i < 115; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.health[player], 100.0);
    });

    test('keeps advancing between slams', () {
      final (:world, :primary) = spawnGaunt(playerX: centerX + 6.0);
      world.enemies.bossPhase[primary] = 1;
      final double startX = world.entities.posX[primary];

      // Past the first slam's own wind-up + cooldown (108 + 120 ticks).
      for (int i = 0; i < 240; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.posX[primary], greaterThan(startX));
    });
  });

  group('P3: the Ripper-style combo', () {
    test('the shield is dropped permanently — a frontal hit now takes full '
        'damage', () {
      final (:world, :primary) = spawnGaunt(); // due east, facing default
      world.enemies.bossPhase[primary] = 2;
      world.tick(InputSnapshot());
      expect(world.enemies.plateHealth[primary], 0.0);

      world.autoFire = true;
      world.tick(InputSnapshot());
      world.autoFire = false;
      for (int i = 0; i < 150; i++) {
        world.tick(InputSnapshot());
      }

      // Full damage (1000, matching Tier I's own 1.0x multiplier on the
      // 1000 playerAttack) — P1's own frontal plate would have taken only
      // 5% of that.
      final double dmg = health - world.entities.health[primary];
      expect(dmg, closeTo(1000.0, 1.0));
    });

    test('moves at +80% of P1\'s own speed while closing', () {
      // Far enough that it stays out of the combo's own 2.6u reach for
      // the whole test — 6u out, closing at 1.8u/s over 1.0s leaves it
      // 4.2u out, still clear.
      final (:world, :primary) = spawnGaunt(playerX: centerX + 6.0);
      world.enemies.bossPhase[primary] = 2;
      final double startX = world.entities.posX[primary];

      for (int i = 0; i < 60; i++) {
        world.tick(InputSnapshot());
      }

      // 1.0 (P1's own speed) * 1.8, over 60 ticks == 1.0s.
      expect(world.entities.posX[primary] - startX, closeTo(1.8, 0.05));
    });

    test('a full three-hit combo lands two openers then a heavier finisher',
        () {
      final (:world, :primary) = spawnGaunt(playerX: centerX + 1.0);
      world.enemies.bossPhase[primary] = 2;
      final int player = world.player.index;

      // Two 0.35s opener wind-ups plus one 0.8s finisher wind-up, with a
      // margin for the ticks each swing's own resolve/re-begin costs.
      for (int i = 0; i < 95; i++) {
        world.tick(InputSnapshot());
      }

      // Two openers (_p3AttackDamage * 0.36 each) plus one finisher
      // (_p3AttackDamage, the same derived heavy hit as the P2 shockwave):
      // 100 - 100*(0.06804 + 0.06804 + 0.189) == 67.492.
      expect(world.entities.health[player], closeTo(67.492, 0.5));
      // The combo reset for the next cycle rather than getting stuck on
      // the finisher.
      expect(world.enemies.comboStep[primary], 0);
    });

    test('enough damage during the finisher\'s own wind-up staggers it, '
        'cancelling that hit', () {
      final (:world, :primary) = spawnGaunt(playerX: centerX + 1.0);
      world.enemies.bossPhase[primary] = 2;
      final int player = world.player.index;

      // Advance to exactly the finisher's own wind-up (comboStep reaches
      // 2 only once both openers have resolved).
      bool reachedFinisherWindUp = false;
      for (int i = 0; i < 200; i++) {
        world.tick(InputSnapshot());
        if (world.enemies.comboStep[primary] == 2 &&
            world.enemies.stateOf(primary) == AiState.windUp) {
          reachedFinisherWindUp = true;
          break;
        }
      }
      expect(reachedFinisherWindUp, isTrue);

      final double healthBeforeStagger = world.entities.health[player];
      // More than ripperStaggerFraction (8%) of Gaunt's own max health.
      world.enemies.damageDuringWindUp[primary] = health * 0.10;

      // Past the finisher's own 0.8s wind-up.
      for (int i = 0; i < 55; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.enemies.stateOf(primary), AiState.staggered);
      expect(world.enemies.comboStep[primary], 0);
      // The finisher's own hit never landed — staggering cancels it.
      expect(world.entities.health[player], healthBeforeStagger);
    });
  });
}
