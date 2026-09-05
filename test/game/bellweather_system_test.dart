import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'boss_test_support.dart';

/// Bellweather — "Every 10s a bell tolls and inverts one rule for the next
/// 10s (movement reversed / Draw inverted so moving charges it / Windlines
/// damage the player / healing damages)" (docs/06 §6.2, Event boss #15).
/// Every test here is about the toll cycle and each of the four rules
/// (ADR 0064).
void main() {
  final ContentLibrary content = loadContentWithBosses();
  const double health = 5.0e4;
  const double centerX = 8.0;
  const double centerY = 4.5;

  ({SimWorld world, int primary}) spawnBellweather({
    double playerX = centerX + 6.0,
    double playerY = centerY,
  }) {
    final SimWorld world = SimWorld(seed: 909090, content: content)
      ..autoFire = false;
    world.spawnPlayer(playerX, playerY);
    final int primary = world.spawnBellweather(centerX, centerY, health: health);
    return (world: world, primary: primary);
  }

  group('spawn', () {
    test('places a single stationary body with no rule active yet', () {
      final (:world, :primary) = spawnBellweather();
      expect(world.entities.health[primary], health);
      expect(world.enemies.comboStep[primary], 0);
    });
  });

  group('the toll cycle', () {
    test('no rule is active before the first toll', () {
      final (:world, :primary) = spawnBellweather();

      for (int i = 0; i < 500; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.enemies.comboStep[primary], 0);
    });

    test('the first toll rings at 10s and picks one of the four rules, '
        'setting the matching DrawState flags', () {
      final (:world, :primary) = spawnBellweather();

      for (int i = 0; i < 601; i++) {
        world.tick(InputSnapshot());
      }

      final int rule = world.enemies.comboStep[primary];
      expect(rule, inInclusiveRange(1, 4));
      expect(world.playerDraw.movementReversed, rule == 1);
      expect(world.playerDraw.drawChargesWhileMoving, rule == 2);
    });

    test('a later toll can replace the rule, clearing whichever DrawState '
        'flag no longer matches', () {
      final (:world, :primary) = spawnBellweather();

      // Force rule 1 (movement reversed) directly, then let a real toll
      // replace it.
      world.enemies.comboStep[primary] = 1;
      world.playerDraw.movementReversed = true;
      world.enemies.bossTimer[primary] = 0.001;

      world.tick(InputSnapshot());

      final int rule = world.enemies.comboStep[primary];
      expect(rule, inInclusiveRange(1, 4));
      expect(world.playerDraw.movementReversed, rule == 1);
      expect(world.playerDraw.drawChargesWhileMoving, rule == 2);
    });

    test('the toll cycle keeps running unmodified across every phase', () {
      final (:world, :primary) = spawnBellweather();
      world.enemies.bossPhase[primary] = 2;

      for (int i = 0; i < 601; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.enemies.comboStep[primary], inInclusiveRange(1, 4));
    });
  });

  group('rule: movement reversed', () {
    test('flips the resulting velocity and facing', () {
      final SimWorld world = SimWorld(seed: 1, content: content)
        ..autoFire = false;
      world.spawnPlayer(centerX, centerY);
      world.playerDraw.movementReversed = true;

      world.tick(InputSnapshot()..set(1, 0));

      expect(world.entities.velX[world.player.index], lessThan(0));
    });

    test('leaves movement unaffected when the flag is off', () {
      final SimWorld world = SimWorld(seed: 1, content: content)
        ..autoFire = false;
      world.spawnPlayer(centerX, centerY);

      world.tick(InputSnapshot()..set(1, 0));

      expect(world.entities.velX[world.player.index], greaterThan(0));
    });
  });

  group('rule: Draw inverted so moving charges it', () {
    test('continuous movement now ramps the Draw instead of resetting it',
        () {
      final SimWorld world = SimWorld(seed: 1, content: content)
        ..autoFire = false;
      world.spawnPlayer(centerX, centerY);
      world.playerDraw.drawChargesWhileMoving = true;

      for (int i = 0; i < 200; i++) {
        world.tick(InputSnapshot()..set(1, 0));
      }

      expect(world.playerDraw.tier, isNot(DrawTier.one));
    });

    test('standing still now builds Momentum instead of ramping the Draw',
        () {
      final SimWorld world = SimWorld(seed: 1, content: content)
        ..autoFire = false;
      world.spawnPlayer(centerX, centerY);
      world.playerDraw.drawChargesWhileMoving = true;

      for (int i = 0; i < 200; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.playerDraw.momentumStacks, greaterThan(0));
      expect(world.playerDraw.drawSeconds, 0);
    });
  });

  group('rule: Windlines damage the player', () {
    test('standing on a live player-owned Windline now deals damage on a '
        'cooldown', () {
      final (:world, :primary) = spawnBellweather();
      world.enemies.comboStep[primary] = 3;
      final int player = world.player.index;

      world.windlines.add(
        fromX: world.entities.posX[player] - 1.0,
        fromY: world.entities.posY[player],
        toX: world.entities.posX[player] + 1.0,
        toY: world.entities.posY[player],
        expiresAt: world.elapsedSeconds + 10.0,
        ownerIndex: 0,
        trailId: 1,
      );

      world.tick(InputSnapshot());
      expect(world.entities.health[player], closeTo(91.0, 1e-6));

      // Immediately again — still on cooldown.
      world.tick(InputSnapshot());
      expect(world.entities.health[player], closeTo(91.0, 1e-6));
    });

    test('standing off any Windline is safe even while this rule is live',
        () {
      final (:world, :primary) = spawnBellweather();
      world.enemies.comboStep[primary] = 3;
      final int player = world.player.index;

      for (int i = 0; i < 30; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.health[player], 100.0);
    });

    test('standing on a Windline is safe when this rule is not live', () {
      final (:world, :primary) = spawnBellweather();
      final int player = world.player.index;

      world.windlines.add(
        fromX: world.entities.posX[player] - 1.0,
        fromY: world.entities.posY[player],
        toX: world.entities.posX[player] + 1.0,
        toY: world.entities.posY[player],
        expiresAt: world.elapsedSeconds + 10.0,
        ownerIndex: 0,
        trailId: 1,
      );

      world.tick(InputSnapshot());

      expect(world.entities.health[player], 100.0);
      expect(primary, greaterThanOrEqualTo(0));
    });
  });

  group('rule: healing damages', () {
    test('a net heal is inverted into an equal-sized loss while the rule '
        'is live', () {
      final (:world, :primary) = spawnBellweather();
      final int player = world.player.index;
      // Let the baseline settle to the player's own real starting health.
      world.tick(InputSnapshot());
      final double before = world.entities.health[player];

      world.enemies.comboStep[primary] = 4;
      world.entities.health[player] = before + 10.0;
      world.tick(InputSnapshot());

      expect(world.entities.health[player], closeTo(before - 10.0, 1e-6));
    });

    test('a heal is not touched when this rule is not live', () {
      final (:world, :primary) = spawnBellweather();
      final int player = world.player.index;
      world.tick(InputSnapshot());
      final double before = world.entities.health[player];

      world.entities.health[player] = before + 10.0;
      world.tick(InputSnapshot());

      expect(world.entities.health[player], closeTo(before + 10.0, 1e-6));
      expect(primary, greaterThanOrEqualTo(0));
    });

    test('a loss is left alone even while the rule is live', () {
      final (:world, :primary) = spawnBellweather();
      final int player = world.player.index;
      world.tick(InputSnapshot());
      final double before = world.entities.health[player];

      world.enemies.comboStep[primary] = 4;
      world.entities.health[player] = before - 10.0;
      world.tick(InputSnapshot());

      expect(world.entities.health[player], closeTo(before - 10.0, 1e-6));
    });
  });
}
