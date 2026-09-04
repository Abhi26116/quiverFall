import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'boss_test_support.dart';

/// The Hollow Warden — "Mirrors movement inverted (Echo AI). It Draws —
/// its own arc is visible, so the player can read exactly when its heavy
/// shot lands" (docs/06 §4). Every test here is really about
/// `world.hollowWardenDraw`, the second live [DrawState] in the game.
void main() {
  final ContentLibrary content = loadContentWithBosses();
  const double health = 1.0e7;
  const double centerX = 8.0;
  const double centerY = 4.5;

  ({SimWorld world, int primary}) spawnWarden({
    double playerX = centerX + 3.0,
    double playerY = centerY,
  }) {
    final SimWorld world = SimWorld(seed: 400400, content: content)
      ..autoFire = false;
    world.spawnPlayer(playerX, playerY);
    final int primary = world.spawnHollowWarden(centerX, centerY, health: health);
    return (world: world, primary: primary);
  }

  group('spawn', () {
    test('a single body at the arena centre', () {
      final (:world, :primary) = spawnWarden();
      expect(world.entities.health[primary], health);
      expect(world.entities.maxHealth[primary], health);
      expect(world.entities.posX[primary], centerX);
      expect(world.entities.posY[primary], centerY);
      expect(world.hollowWardenDraw.drawSeconds, 0.0);
    });
  });

  group('the mirror', () {
    test('chases the mirror of the player about the arena centre, facing '
        'the player as it goes', () {
      final (:world, :primary) = spawnWarden();
      // Player at (11, 4.5); arena is 16x9, so the mirror is (5, 4.5) —
      // the Warden must move *away* from the player's own side.
      for (int i = 0; i < 30; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.entities.posX[primary], lessThan(centerX));
      expect(world.entities.facing[primary], closeTo(0.0, 0.05));
    });

    test('stops once it catches its own mirror point', () {
      // Player placed so the mirror point starts within arrival distance
      // of the Warden's own spawn — no real travel needed.
      final (:world, :primary) = spawnWarden(
        playerX: centerX + 0.05,
      );
      world.tick(InputSnapshot());
      expect(world.entities.velX[primary], 0.0);
      expect(world.entities.velY[primary], 0.0);
    });
  });

  group('the Draw', () {
    test('ramps while the mirror has settled, exactly like the player\'s '
        'own', () {
      final (:world, :primary) = spawnWarden(
        playerX: centerX + 0.05,
      );
      expect(primary, greaterThanOrEqualTo(0));

      for (int i = 0; i < 40; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.hollowWardenDraw.drawSeconds, greaterThan(0.5));
    });

    test('resets the instant the player moves the mirror point away', () {
      final (:world, :primary) = spawnWarden(
        playerX: centerX + 0.05,
      );
      expect(primary, greaterThanOrEqualTo(0));

      for (int i = 0; i < 40; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.hollowWardenDraw.drawSeconds, greaterThan(0));

      // Move the player far enough that the mirror point moves well past
      // arrival distance.
      final int player = world.player.index;
      world.entities.posX[player] = centerX + 5.0;
      world.tick(InputSnapshot());

      expect(world.hollowWardenDraw.drawSeconds, 0.0);
    });

    test('a heavy shot fires once it reaches Tier III, and it hits', () {
      final (:world, :primary) = spawnWarden(
        playerX: centerX + 0.05,
      );
      expect(primary, greaterThanOrEqualTo(0));
      final int player = world.player.index;
      expect(world.entities.health[player], 100.0);

      // Tier III is 1.10s (66 ticks); a little travel time on top for the
      // bolt itself to actually land.
      for (int i = 0; i < 100; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.health[player], lessThan(100.0));
      // The ramp reset the instant it fired.
      expect(world.hollowWardenDraw.drawSeconds, lessThan(1.10));
    });
  });

  group('P2: Windlines and Confluence', () {
    test('a heavy shot lays a Windline of its own, owned by the Warden', () {
      final (:world, :primary) = spawnWarden(
        playerX: centerX + 0.05,
      );
      world.enemies.bossPhase[primary] = 1;

      for (int i = 0; i < 100; i++) {
        world.tick(InputSnapshot());
      }

      bool foundOwnLine = false;
      for (int s = 0; s < world.windlines.capacity; s++) {
        if (!world.windlines.isAlive(s)) continue;
        if (world.windlines.ownerAt(s) == primary) foundOwnLine = true;
      }
      expect(foundOwnLine, isTrue,
          reason: 'a P2 heavy shot should lay its own Windline segment');
    });

    test('threading its own older Windline scales the heavy shot up', () {
      final (:world, :primary) = spawnWarden(
        playerX: centerX + 0.05,
      );
      world.enemies.bossPhase[primary] = 1;
      final int player = world.player.index;

      // The Warden's mirror point sits within arrival distance of its own
      // spawn (see the "stops once it catches its own mirror point" test
      // above), so it stays put at (centerX, centerY) facing dead along
      // +x toward the player the whole fight — every heavy shot travels
      // the same horizontal line, y == centerY, x from centerX outward.
      // A perpendicular segment placed across that line, well clear of
      // the parallel-rejection band, is guaranteed to be threaded by the
      // very first shot.
      world.windlines.add(
        fromX: centerX + 2.0,
        fromY: centerY - 2.0,
        toX: centerX + 2.0,
        toY: centerY + 2.0,
        expiresAt: world.elapsedSeconds + 999,
        ownerIndex: primary,
        trailId: -12345,
      );

      for (int i = 0; i < 100; i++) {
        world.tick(InputSnapshot());
      }

      // Bare heavy shot: 0.06 * 2.10 == 12.6% of max health. One threaded
      // stack adds ConfluenceTuning.bonusByStacks[1] == 0.40 on top:
      // 100 - 100 * 0.126 * 1.40 == 82.36.
      expect(world.entities.health[player], closeTo(82.36, 1e-6));
    });

    test('a heavy shot that threads nothing deals the bare amount', () {
      final (:world, :primary) = spawnWarden(
        playerX: centerX + 0.05,
      );
      world.enemies.bossPhase[primary] = 1;
      final int player = world.player.index;

      for (int i = 0; i < 100; i++) {
        world.tick(InputSnapshot());
      }

      // 100 - 100 * 0.126 == 87.4, no Confluence bonus.
      expect(world.entities.health[player], closeTo(87.4, 1e-6));
    });

    test('the player is slowed while standing on one of its live Windlines',
        () {
      final (:world, :primary) = spawnWarden();
      world.enemies.bossPhase[primary] = 1;
      final int player = world.player.index;
      final double px = world.entities.posX[player];
      final double py = world.entities.posY[player];

      world.windlines.add(
        fromX: px - 2.0,
        fromY: py,
        toX: px + 2.0,
        toY: py,
        expiresAt: world.elapsedSeconds + 999,
        ownerIndex: primary,
        trailId: -54321,
      );

      world.tick(InputSnapshot());

      expect(world.playerDraw.windlineSlowFactor, closeTo(0.92, 1e-9));
    });

    test('the player is not slowed standing clear of any Warden line', () {
      final (:world, :primary) = spawnWarden();
      world.enemies.bossPhase[primary] = 1;
      world.tick(InputSnapshot());
      expect(world.playerDraw.windlineSlowFactor, 1.0);
    });
  });

  group('past P2', () {
    test('halts the mirror, freezes the Draw, and clears the player\'s '
        'slow', () {
      final (:world, :primary) = spawnWarden(
        playerX: centerX + 0.05,
      );
      for (int i = 0; i < 20; i++) {
        world.tick(InputSnapshot());
      }
      final double drawBefore = world.hollowWardenDraw.drawSeconds;
      expect(drawBefore, greaterThan(0));

      world.playerDraw.windlineSlowFactor = 0.5;

      world.enemies.bossPhase[primary] = 2;
      // One extra tick for the halt to actually take effect — the same
      // one-transitional-tick ordering every other boss's own phase-halt
      // test already accounts for (ADR 0023).
      world.tick(InputSnapshot());
      final double posXAfterHalt = world.entities.posX[primary];
      final double posYAfterHalt = world.entities.posY[primary];
      expect(world.playerDraw.windlineSlowFactor, 1.0);

      for (int i = 0; i < 60; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.posX[primary], posXAfterHalt);
      expect(world.entities.posY[primary], posYAfterHalt);
      expect(world.hollowWardenDraw.drawSeconds, drawBefore);
    });
  });
}
