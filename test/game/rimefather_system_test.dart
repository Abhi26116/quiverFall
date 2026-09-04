import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'boss_test_support.dart';

/// Rimefather — "Tests: Frost, and forced movement" (docs/06 §6). P1: a
/// stationary body whose cone deals a modest hit and, on a *second* hit
/// inside a rolling 4s window, roots the player outright. P2 adds a
/// spreading ice field that boosts Momentum's own effectiveness (ADR
/// 0038) — the friction half of that card is not implemented; see that
/// ADR for why.
void main() {
  final ContentLibrary content = loadContentWithBosses();
  const double health = 1.0e7;
  const double centerX = 8.0;
  const double centerY = 4.5;

  ({SimWorld world, int primary}) spawnRimefather({
    double playerX = centerX + 3.0,
    double playerY = centerY,
  }) {
    final SimWorld world = SimWorld(seed: 606060, content: content)
      ..autoFire = false;
    world.spawnPlayer(playerX, playerY);
    final int primary = world.spawnRimefather(centerX, centerY, health: health);
    return (world: world, primary: primary);
  }

  group('spawn', () {
    test('a single, stationary body', () {
      final (:world, :primary) = spawnRimefather();
      expect(world.entities.health[primary], health);
      expect(world.entities.maxHealth[primary], health);
      expect(world.entities.posX[primary], centerX);
      expect(world.entities.posY[primary], centerY);
    });
  });

  group('the freezing cone', () {
    test('deals its own modest hit once it resolves', () {
      final (:world, :primary) = spawnRimefather();
      expect(primary, greaterThanOrEqualTo(0));
      final int player = world.player.index;
      expect(world.entities.health[player], 100.0);

      // Wind-up is 0.6s; resolve lands on/around tick 36.
      for (int i = 0; i < 40; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.health[player], closeTo(91.0, 0.01));
    });

    test('a player who dodges out of the cone before it resolves takes no '
        'hit and builds no streak', () {
      final (:world, :primary) = spawnRimefather();
      expect(primary, greaterThanOrEqualTo(0));
      final int player = world.player.index;

      // The wind-up's own aim is fixed the instant it begins — one tick in.
      world.tick(InputSnapshot());
      // Well outside the 5u range and off to the side.
      world.entities.posX[player] = centerX;
      world.entities.posY[player] = centerY + 8.9;

      for (int i = 0; i < 39; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.health[player], 100.0);
      expect(world.playerDraw.isRooted, isFalse);
    });

    test('a single hit alone does not root the player', () {
      final (:world, :primary) = spawnRimefather();
      expect(primary, greaterThanOrEqualTo(0));

      for (int i = 0; i < 40; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.playerDraw.isRooted, isFalse);
    });

    test('two hits within 4s root the player for 1.2s', () {
      final (:world, :primary) = spawnRimefather();
      expect(primary, greaterThanOrEqualTo(0));

      // First resolve ~0.6s (tick 36); cooldown 1.5s puts the second
      // wind-up's own resolve at ~2.7s (tick ~162) — comfortably inside the
      // 4s streak window and long before the cooldown math could put it
      // outside. Run well past that.
      for (int i = 0; i < 170; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.playerDraw.isRooted, isTrue);
      expect(world.playerDraw.rootRemaining, greaterThan(1.0));
    });

    test('rooted, the player cannot move even while holding a direction',
        () {
      final (:world, :primary) = spawnRimefather();
      expect(primary, greaterThanOrEqualTo(0));
      final int player = world.player.index;

      for (int i = 0; i < 170; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.playerDraw.isRooted, isTrue);

      final double beforeX = world.entities.posX[player];
      final double beforeY = world.entities.posY[player];
      world.tick(InputSnapshot()..stickX = 1);

      expect(world.entities.posX[player], beforeX);
      expect(world.entities.posY[player], beforeY);
    });

    test('a streak that goes cold resets — the third hit after a long gap '
        "doesn't instantly root", () {
      final (:world, :primary) = spawnRimefather();
      expect(primary, greaterThanOrEqualTo(0));
      final int player = world.player.index;

      // Let exactly one hit land.
      for (int i = 0; i < 40; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.playerDraw.isRooted, isFalse);

      // Dodge out of range for well over 4s so the streak window itself
      // expires, not just so a cast is dodged.
      world.entities.posX[player] = centerX;
      world.entities.posY[player] = centerY + 8.9;
      for (int i = 0; i < 300; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.playerDraw.isRooted, isFalse);

      // Step back into range for exactly one more resolve.
      world.entities.posX[player] = centerX + 3.0;
      world.entities.posY[player] = centerY;
      for (int i = 0; i < 40; i++) {
        world.tick(InputSnapshot());
      }

      // A fresh streak's first hit, not a stale streak's second — no root.
      expect(world.playerDraw.isRooted, isFalse);
    });
  });

  group('P2: spreading ice', () {
    test('grows outward from a standing start', () {
      final (:world, :primary) = spawnRimefather();
      world.enemies.bossPhase[primary] = 1;

      for (int i = 0; i < 60; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.enemies.bossSweepAngle[primary], greaterThan(0));
    });

    test('boosts the player\'s own Momentum effectiveness while standing '
        'in it', () {
      final (:world, :primary) = spawnRimefather();
      world.enemies.bossPhase[primary] = 1;
      expect(world.playerDraw.momentumEffectivenessMultiplier, 1.0);

      // The ice starts at radius 0 and grows — give it a moment to cover
      // the default-spawned player 3u away (at 0.4u/s, about 7.5s).
      for (int i = 0; i < 480; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.playerDraw.momentumEffectivenessMultiplier, 1.5);
    });

    test('a player outside the ice is not boosted', () {
      final (:world, :primary) = spawnRimefather(playerX: centerX + 8.9);
      world.enemies.bossPhase[primary] = 1;

      // Comfortably past the ice reaching its own 6u cap.
      for (int i = 0; i < 1000; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.playerDraw.momentumEffectivenessMultiplier, 1.0);
    });

    test('the multiplier only scales Momentum\'s own bonuses, applied '
        'through DrawState directly', () {
      final (:world, :primary) = spawnRimefather();
      world.playerDraw.momentumStacks = 5;
      final double baseline = world.playerDraw.moveSpeedBonus;

      world.playerDraw.momentumEffectivenessMultiplier = 1.5;
      expect(world.playerDraw.moveSpeedBonus, closeTo(baseline * 1.5, 1e-9));
      expect(primary, greaterThanOrEqualTo(0));
    });
  });

  List<int> mirrorsOf(SimWorld world, int primary) {
    final List<int> found = <int>[];
    for (int j = 0; j < world.entities.highWater; j++) {
      if (world.entities.alive[j] == 0) continue;
      if (world.enemies.bossParent[j] != primary) continue;
      found.add(j);
    }
    return found;
  }

  int realMirrorOf(SimWorld world, int primary) {
    final int realOrdinal = world.enemies.bossActiveChildIndex[primary];
    return mirrorsOf(world, primary)
        .firstWhere((int j) => world.enemies.bossChildIndex[j] == realOrdinal);
  }

  group('P3: the ice-mirrors', () {
    test('shatters into three targetable mirrors, exactly one marked real',
        () {
      final (:world, :primary) = spawnRimefather();
      world.enemies.bossPhase[primary] = 2;
      world.tick(InputSnapshot());

      final List<int> mirrors = mirrorsOf(world, primary);
      expect(mirrors.length, 3);
      for (final int m in mirrors) {
        expect(world.enemies.untargetable[m], 0,
            reason: 'a mirror the player can never mistakenly hit would '
                'make the puzzle meaningless');
      }
      final int realOrdinal = world.enemies.bossActiveChildIndex[primary];
      expect(mirrors.where((int m) => world.enemies.bossChildIndex[m] == realOrdinal).length, 1);
    });

    test('damaging the real mirror reduces the shared health', () {
      final (:world, :primary) = spawnRimefather();
      world.enemies.bossPhase[primary] = 2;
      world.tick(InputSnapshot());
      final int real = realMirrorOf(world, primary);
      final double before = world.entities.health[real];

      world.entities.health[real] -= 1000;
      world.tick(InputSnapshot());

      expect(world.entities.health[real], before - 1000);
      expect(world.entities.health[primary], before - 1000);
    });

    test('damaging a fake mirror is refunded in full and heals the real '
        'one instead', () {
      final (:world, :primary) = spawnRimefather();
      world.enemies.bossPhase[primary] = 2;
      world.tick(InputSnapshot());
      final int real = realMirrorOf(world, primary);
      final int fake =
          mirrorsOf(world, primary).firstWhere((int j) => j != real);

      // Leave headroom below max health so the heal is actually visible
      // rather than clamped away.
      world.entities.health[real] -= 5000;
      world.tick(InputSnapshot());
      final double realHealthBefore = world.entities.health[real];
      final double fakeHealthBefore = world.entities.health[fake];

      world.entities.health[fake] -= 1000;
      world.tick(InputSnapshot());

      expect(world.entities.health[fake], fakeHealthBefore,
          reason: 'a decoy is never actually killable — the hit is '
              'refunded in full');
      expect(world.entities.health[real], realHealthBefore + 1000,
          reason: 'wrong-target damage heals the real one instead');
    });

    test("the primary's own death despawns every mirror", () {
      final (:world, :primary) = spawnRimefather();
      world.enemies.bossPhase[primary] = 2;
      world.tick(InputSnapshot());
      final List<int> mirrors = mirrorsOf(world, primary);
      final int real = realMirrorOf(world, primary);

      world.entities.health[real] = 0;
      world.tick(InputSnapshot());

      for (final int m in mirrors) {
        expect(world.entities.alive[m], 0,
            reason: 'a mirror must not outlive the primary it belongs to');
      }
    });
  });

  group('P3 also stops the cone and the ice', () {
    test('resets the Momentum multiplier and stops growing the ice', () {
      final (:world, :primary) = spawnRimefather();
      world.enemies.bossPhase[primary] = 1;
      for (int i = 0; i < 480; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.playerDraw.momentumEffectivenessMultiplier, 1.5);
      final double iceRadiusBefore = world.enemies.bossSweepAngle[primary];

      world.enemies.bossPhase[primary] = 2;
      world.tick(InputSnapshot());
      expect(world.playerDraw.momentumEffectivenessMultiplier, 1.0);

      // No further casts, no further ice growth, even given plenty of
      // time.
      final int player = world.player.index;
      final double healthBefore = world.entities.health[player];
      for (int i = 0; i < 300; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.entities.health[player], healthBefore);
      expect(world.enemies.bossSweepAngle[primary], iceRadiusBefore);
    });

    test('clears a live wind-up telegraph rather than leaving it stranded',
        () {
      final (:world, :primary) = spawnRimefather();
      world.enemies.bossPhase[primary] = 1;

      // Catch it genuinely mid-wind-up — a resolved cast's own brief
      // lethal flash telegraph naturally expires on its own almost
      // immediately, so checking right after an arbitrary number of
      // ticks (rather than deliberately mid-cycle) would not actually
      // exercise this cleanup at all.
      bool caughtWindUp = false;
      for (int i = 0; i < 300; i++) {
        world.tick(InputSnapshot());
        if (world.enemies.state[primary] == AiState.windUp.index) {
          caughtWindUp = true;
          break;
        }
      }
      expect(caughtWindUp, isTrue, reason: 'never observed a live wind-up');
      expect(world.enemies.telegraphSlot[primary], greaterThanOrEqualTo(0));

      world.enemies.bossPhase[primary] = 2;
      world.tick(InputSnapshot());
      expect(world.enemies.telegraphSlot[primary], -1);
    });
  });
}
