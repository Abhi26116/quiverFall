import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/hazard_store.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'boss_test_support.dart';

/// Vermillion, the Long Burn — P1 only (docs/06 §5): a single body that
/// walks toward the player, laying a lethal ground puddle behind it on a
/// fixed cadence — the arena floor "progressively becoming lethal" is
/// simply many of `EnemyAttack.dropPuddle`'s own hazards accumulating.
void main() {
  final ContentLibrary content = loadContentWithBosses();
  const double health = 1.0e7;
  const double centerX = 8.0;
  const double centerY = 4.5;

  ({SimWorld world, int primary}) spawnVermillion({
    double playerX = centerX + 3.0,
    double playerY = centerY,
  }) {
    final SimWorld world = SimWorld(seed: 808, content: content)
      ..autoFire = false;
    world.spawnPlayer(playerX, playerY);
    final int primary =
        world.spawnVermillion(centerX, centerY, health: health);
    return (world: world, primary: primary);
  }

  List<int> trailOf(SimWorld world, int primary) {
    final List<int> out = <int>[];
    for (int i = 0; i < world.hazards.capacity; i++) {
      if (!world.hazards.isAlive(i)) continue;
      if (world.hazards.kindAt(i) != HazardKind.puddle) continue;
      if (world.hazards.ownerAt(i) != primary) continue;
      out.add(i);
    }
    return out;
  }

  group('spawn', () {
    test('a single, unplated body', () {
      final (:world, :primary) = spawnVermillion();
      expect(world.entities.health[primary], health);
      expect(world.entities.maxHealth[primary], health);
      expect(world.enemies.isPlated(primary), isFalse);
      expect(trailOf(world, primary), isEmpty);
    });
  });

  group('P1', () {
    test('walks toward the player', () {
      final (:world, :primary) = spawnVermillion();
      final double startX = world.entities.posX[primary];

      for (int i = 0; i < 60; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.posX[primary], greaterThan(startX));
    });

    test('lays a trail segment roughly once a second', () {
      final (:world, :primary) = spawnVermillion();

      for (int i = 0; i < 65; i++) {
        world.tick(InputSnapshot());
      }
      expect(trailOf(world, primary), hasLength(1));

      for (int i = 0; i < 60; i++) {
        world.tick(InputSnapshot());
      }
      expect(trailOf(world, primary), hasLength(2));
    });

    test('the trail damages a player standing in it over time', () {
      final (:world, :primary) = spawnVermillion(playerX: centerX + 2.0);
      final int player = world.player.index;
      world.entities.health[player] = 100.0;
      world.entities.maxHealth[player] = 100.0;

      for (int i = 0; i < 65; i++) {
        world.tick(InputSnapshot());
      }
      expect(trailOf(world, primary), isNotEmpty);

      // Keep the player pinned on the segment's own spot for a full second.
      final int segment = trailOf(world, primary).first;
      final double segX = world.hazards.x[segment];
      final double segY = world.hazards.y[segment];
      for (int i = 0; i < 60; i++) {
        world.entities.posX[player] = segX;
        world.entities.posY[player] = segY;
        world.tick(InputSnapshot());
      }

      expect(world.entities.health[player], lessThan(100.0));
    });

    test('segments persist rather than expiring immediately', () {
      final (:world, :primary) = spawnVermillion();

      for (int i = 0; i < 65; i++) {
        world.tick(InputSnapshot());
      }
      expect(trailOf(world, primary), hasLength(1));

      // Well short of the 20s lifetime.
      for (int i = 0; i < 300; i++) {
        world.tick(InputSnapshot());
      }
      expect(trailOf(world, primary), isNotEmpty);
    });

    test('halts and stops laying trail once past P1', () {
      final (:world, :primary) = spawnVermillion();
      for (int i = 0; i < 30; i++) {
        world.tick(InputSnapshot());
      }
      world.enemies.bossPhase[primary] = 1;
      // `MovementSystem` still integrates the velocity `moveToward` set on
      // the tick just before the phase changed — one tick's worth of
      // residual drift, then `Steering.halt` (called later that same tick)
      // has actually taken effect. `posBefore` is captured after that
      // transitional tick, not before it.
      world.tick(InputSnapshot());
      final double posBefore = world.entities.posX[primary];
      final int trailBefore = trailOf(world, primary).length;

      for (int i = 0; i < 179; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.posX[primary], posBefore);
      expect(trailOf(world, primary), hasLength(trailBefore));
    });
  });
}
