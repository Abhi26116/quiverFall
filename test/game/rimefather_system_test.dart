import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'boss_test_support.dart';

/// Rimefather — "Tests: Frost, and forced movement" (docs/06 §6). P1 only:
/// a stationary body whose cone deals a modest hit and, on a *second* hit
/// inside a rolling 4s window, roots the player outright — every test here
/// that isn't about the cone's own damage is about `DrawState.rootRemaining`.
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

  group('past P1', () {
    test('stops attacking and clears any live telegraph', () {
      final (:world, :primary) = spawnRimefather();
      world.tick(InputSnapshot());
      expect(world.enemies.telegraphSlot[primary], greaterThanOrEqualTo(0));

      world.enemies.bossPhase[primary] = 1;
      world.tick(InputSnapshot());
      expect(world.enemies.telegraphSlot[primary], -1);

      // No further casts even given plenty of time.
      final int player = world.player.index;
      final double healthBefore = world.entities.health[player];
      for (int i = 0; i < 300; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.entities.health[player], healthBefore);
    });
  });
}
